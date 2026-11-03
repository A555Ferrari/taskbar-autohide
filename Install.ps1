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

Write-Host "Installiere nach $target ..."
New-Item -ItemType Directory -Path $target -Force | Out-Null

foreach ($f in 'TaskbarAutoHide.ps1', 'Find-Dock.ps1', 'Uninstall.ps1') {
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
$psArgs = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""

# Alte Instanz beenden, falls vorhanden
Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
    Where-Object { $_.CommandLine -like '*TaskbarAutoHide.ps1*' -and $_.ProcessId -ne $PID } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

$viaTask = $false
try {
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $psArgs
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit ([TimeSpan]::Zero) `
        -MultipleInstances IgnoreNew -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName
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

Start-Sleep -Seconds 2
Write-Host ''
Write-Host 'Aktueller Status:'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -Status
Write-Host ''
Write-Host "Fertig. Konfiguration: $cfgTarget"
Write-Host "Log:            $(Join-Path $target 'TaskbarAutoHide.log')"
