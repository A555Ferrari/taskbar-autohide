<#
.SYNOPSIS
    Entfernt TaskbarAutoHide wieder.

.PARAMETER KeepAutoHide
    Taskleiste NICHT zurueck auf "immer sichtbar" stellen.

.PARAMETER RemoveFiles
    Auch den Installationsordner %LOCALAPPDATA%\TaskbarAutoHide loeschen
    (inkl. config.json und Log). Nur sinnvoll, wenn dieses Script aus dem
    Repo-Ordner gestartet wird, nicht aus dem Installationsordner.
#>
[CmdletBinding()]
param(
    [switch]$KeepAutoHide,
    [switch]$RemoveFiles
)

$taskName = 'TaskbarAutoHide'
$target = Join-Path $env:LOCALAPPDATA 'TaskbarAutoHide'

# Geplante Aufgabe
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host 'Geplante Aufgabe entfernt.'
}

# Autostart-Verknuepfung (Fallback)
$lnk = Join-Path ([Environment]::GetFolderPath('Startup')) "$taskName.lnk"
if (Test-Path $lnk) {
    Remove-Item $lnk -Force
    Write-Host 'Autostart-Verknuepfung entfernt.'
}

# Laufende Instanz beenden
Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
    Where-Object { $_.CommandLine -like '*TaskbarAutoHide.ps1*' -and $_.ProcessId -ne $PID } |
    ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        Write-Host "Prozess $($_.ProcessId) beendet."
    }

# Taskleiste wieder dauerhaft anzeigen
if (-not $KeepAutoHide) {
    $script = Join-Path $PSScriptRoot 'TaskbarAutoHide.ps1'
    if (-not (Test-Path $script)) { $script = Join-Path $target 'TaskbarAutoHide.ps1' }
    if (Test-Path $script) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -Force Show
    }
}

if ($RemoveFiles -and (Test-Path $target)) {
    if ($PSScriptRoot -ieq $target) {
        Write-Warning 'Script laeuft aus dem Installationsordner - Ordner bitte manuell loeschen oder Uninstall.ps1 aus dem Repo starten.'
    } else {
        Remove-Item $target -Recurse -Force
        Write-Host "Ordner $target geloescht."
    }
}

Write-Host 'Fertig.'
