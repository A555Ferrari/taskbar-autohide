<#
.SYNOPSIS
    Installiert TaskbarAutoHide fuer den aktuellen Benutzer (kein Admin noetig).

.DESCRIPTION
    Kopiert die Dateien nach %LOCALAPPDATA%\TaskbarAutoHide, legt eine geplante
    Aufgabe "TaskbarAutoHide" an (Start bei Anmeldung) und startet sie sofort.
    Eine vorhandene config.json im Zielordner bleibt erhalten.
    Falls die geplante Aufgabe nicht angelegt werden kann (z.B. durch Richtlinien),
    wird stattdessen eine Verknuepfung im Autostart-Ordner erstellt.

.PARAMETER Mode
    Optional: monitors, dock oder either - ueberschreibt den Modus in der config.json.
#>
[CmdletBinding()]
param(
    [ValidateSet('monitors', 'dock', 'either')][string]$Mode
)

$ErrorActionPreference = 'Stop'
$taskName = 'TaskbarAutoHide'
$target = Join-Path $env:LOCALAPPDATA 'TaskbarAutoHide'

# Dateien aus einer ZIP/einem Download sind von Windows als "blockiert" markiert
Get-ChildItem -Path $PSScriptRoot -File | Unblock-File -ErrorAction SilentlyContinue

Write-Host "Installiere nach $target ..."
New-Item -ItemType Directory -Path $target -Force | Out-Null

foreach ($f in 'TaskbarAutoHide.ps1', 'Find-Dock.ps1', 'Uninstall.ps1', 'Update.ps1', 'Manage.ps1', 'tah.cmd', 'VERSION') {
    Copy-Item -Path (Join-Path $PSScriptRoot $f) -Destination $target -Force
}
$cfgTarget = Join-Path $target 'config.json'
if (-not (Test-Path $cfgTarget)) {
    Copy-Item -Path (Join-Path $PSScriptRoot 'config.json') -Destination $cfgTarget
}

if ($Mode) {
    $cfg = Get-Content $cfgTarget -Raw | ConvertFrom-Json
    $cfg.mode = $Mode
    $cfg | ConvertTo-Json | Set-Content -Path $cfgTarget -Encoding UTF8
    Write-Host "Modus in config.json auf '$Mode' gesetzt."
}

$script = Join-Path $target 'TaskbarAutoHide.ps1'
$psArgs = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`" -Background"

# Unsichtbarer Start: "conhost.exe --headless" erzeugt gar kein Fenster (auch nicht unter Windows Terminal).
# Wird nur genutzt, wenn es verfuegbar ist und nachweislich funktioniert (siehe Pruefung unten).
$conhost = Join-Path $env:SystemRoot 'System32\conhost.exe'
$headless = (Test-Path $conhost) -and ([Environment]::OSVersion.Version.Build -ge 18362)

function Test-Running {
    $m = $null
    if ([System.Threading.Mutex]::TryOpenExisting('Local\TaskbarAutoHide', [ref]$m)) { $m.Dispose(); return $true }
    return $false
}

# Alte Instanz beenden, falls vorhanden
Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
    Where-Object { $_.CommandLine -like '*TaskbarAutoHide.ps1*' -and $_.ProcessId -ne $PID } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

$viaTask = $false
try {
    # Zwei Ausloeser: bei der Anmeldung und alle 5 Minuten (Waechter). Faellt das Script aus
    # (z.B. nach Ruhezustand oder Abmelden), startet die Aufgabe es spaetestens nach 5 Minuten neu.
    # Laeuft es noch, wird der Start wegen MultipleInstances=IgnoreNew uebersprungen
    # (kein Doppelstart, kein Fenster-Aufblitzen).
    $logonTrigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
    $watchdogTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
        -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit ([TimeSpan]::Zero) `
        -MultipleInstances IgnoreNew -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive
    foreach ($attempt in 1..2) {
        if ($headless) {
            $action = New-ScheduledTaskAction -Execute $conhost -Argument "--headless powershell.exe $psArgs"
        } else {
            $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $psArgs
        }
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($logonTrigger, $watchdogTrigger) `
            -Settings $settings -Principal $principal -Force | Out-Null
        Start-ScheduledTask -TaskName $taskName
        if (-not $headless) { break }
        $running = $false
        foreach ($i in 1..15) { Start-Sleep -Seconds 1; if (Test-Running) { $running = $true; break } }
        if ($running) { break }
        Write-Warning 'Unsichtbarer Start (conhost --headless) funktioniert hier nicht, verwende den normalen Start.'
        $headless = $false
    }
    $viaTask = $true
    Write-Host "Geplante Aufgabe '$taskName' angelegt und gestartet."
} catch {
    Write-Warning "Geplante Aufgabe nicht moeglich: $($_.Exception.Message)"
    Write-Host 'Weiche auf Autostart-Ordner aus ...'
    $startup = [Environment]::GetFolderPath('Startup')
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut((Join-Path $startup "$taskName.lnk"))
    $lnk.TargetPath = 'powershell.exe'
    $lnk.Arguments = $psArgs
    $lnk.WindowStyle = 7
    $lnk.Save()
    Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -WindowStyle Hidden
    Write-Host 'Autostart-Verknuepfung angelegt und Script gestartet.'
}

# Zusaetzliche Absicherung: Autostart ueber den Run-Key des Benutzers.
# Falls die geplante Aufgabe beim Login nicht startet (z.B. durch Richtlinien), greift dieser Weg.
# Doppelter Start ist unkritisch, das Script erlaubt nur eine Instanz (Mutex).
try {
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    # Mit Aufgabe: Run-Key startet die Aufgabe (so laeuft das Script immer als Aufgaben-Instanz).
    # Ohne Aufgabe (Fallback): Run-Key startet das Script direkt.
    $runValue = if ($viaTask -and $headless) { "`"$conhost`" --headless schtasks.exe /run /tn `"$taskName`"" }
                elseif ($viaTask) { "schtasks.exe /run /tn `"$taskName`"" }
                else { "powershell.exe $psArgs" }
    Set-ItemProperty -Path $runKey -Name $taskName -Value $runValue
    Write-Host 'Zusaetzlicher Autostart (Run-Key) eingetragen.'
} catch {
    Write-Warning "Run-Key nicht moeglich: $($_.Exception.Message)"
}

# Befehl 'tah' bereitstellen: Installationsordner zum Benutzer-PATH hinzufuegen (nur fuer dein Konto).
try {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @($userPath -split ';' | Where-Object { $_ })
    if ($parts -notcontains $target) {
        [Environment]::SetEnvironmentVariable('Path', (($parts + $target) -join ';'), 'User')
    }
    Write-Host "Befehl 'tah' eingerichtet (in einem NEUEN Terminal verfuegbar)."
} catch {
    Write-Warning "Befehl 'tah' nicht moeglich: $($_.Exception.Message)"
}

# Startmenue-Eintrag zum Aktualisieren (laeuft nur, wenn du ihn anklickst, nie automatisch).
try {
    $updateLnk = Join-Path ([Environment]::GetFolderPath('Programs')) 'TaskbarAutoHide aktualisieren.lnk'
    $sh = New-Object -ComObject WScript.Shell
    $lnk2 = $sh.CreateShortcut($updateLnk)
    $lnk2.TargetPath = 'powershell.exe'
    $lnk2.Arguments = "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$(Join-Path $target 'Update.ps1')`""
    $lnk2.WorkingDirectory = $target
    $lnk2.Description = 'TaskbarAutoHide auf die neueste Version von GitHub aktualisieren'
    $lnk2.Save()
    Write-Host "Startmenue-Eintrag 'TaskbarAutoHide aktualisieren' angelegt."
} catch {
    Write-Warning "Startmenue-Eintrag nicht moeglich: $($_.Exception.Message)"
}

Start-Sleep -Seconds 2
Write-Host ''
Write-Host 'Aktueller Status:'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -Status
Write-Host ''
Write-Host "Fertig. Installiert in: $target"
Write-Host "Konfiguration:  $cfgTarget"
Write-Host "Log:            $(Join-Path $target 'TaskbarAutoHide.log')"
Write-Host ''
Write-Host 'Befehle (in einem NEUEN Terminal):  tah status | tah update | tah log | tah config | tah help'
