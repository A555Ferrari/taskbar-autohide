<#
.SYNOPSIS
    Zentraler Befehl fuer TaskbarAutoHide. Aufruf ueber "tah <befehl>" (siehe tah.cmd).

.DESCRIPTION
    Befehle: status, update, log, config, start, restart, stop, version, uninstall, help.
#>
param(
    [Parameter(Position = 0)]
    [string]$Command = 'help'
)

$ErrorActionPreference = 'Stop'
$dir = $PSScriptRoot
$taskName = 'TaskbarAutoHide'
$main = Join-Path $dir 'TaskbarAutoHide.ps1'

function Show-Help {
    Write-Host ''
    Write-Host 'TaskbarAutoHide - Befehle:'
    Write-Host '  tah status      Version, laeuft das Script?, Monitore, aktueller Zustand'
    Write-Host '  tah update      Neueste Version von GitHub installieren'
    Write-Host '  tah log         Letzte Zeilen des Logs'
    Write-Host '  tah config      config.json im Editor oeffnen'
    Write-Host '  tah start       Script starten'
    Write-Host '  tah restart     Script neu starten'
    Write-Host '  tah stop        Script beenden (der Waechter startet es nach spaetestens 5 Minuten wieder)'
    Write-Host '  tah version     Installierte Version anzeigen'
    Write-Host '  tah uninstall   Alles entfernen'
    Write-Host '  tah help        Diese Uebersicht'
    Write-Host ''
}

function Show-Status {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $main -Status
}

function Stop-Tah {
    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
        Where-Object { $_.CommandLine -like '*TaskbarAutoHide.ps1*' -and $_.ProcessId -ne $PID } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Start-Tah {
    try {
        Start-ScheduledTask -TaskName $taskName
    } catch {
        Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$main`" -Background"
    }
}

switch ($Command.ToLowerInvariant()) {
    'status' {
        Show-Status
    }
    'start' {
        Start-Tah
        Start-Sleep -Seconds 2
        Show-Status
    }
    'restart' {
        Stop-Tah
        Start-Sleep -Seconds 1
        Start-Tah
        Start-Sleep -Seconds 2
        Show-Status
    }
    'stop' {
        Stop-Tah
        Write-Host 'Script beendet. Der Waechter der geplanten Aufgabe startet es nach spaetestens 5 Minuten wieder.'
        Write-Host 'Dauerhaft entfernen: tah uninstall'
    }
    'log' {
        $logFile = Join-Path $dir 'TaskbarAutoHide.log'
        if (Test-Path $logFile) { Get-Content $logFile -Tail 30 } else { Write-Host 'Noch kein Log vorhanden.' }
    }
    'config' {
        Start-Process -FilePath 'notepad.exe' -ArgumentList "`"$(Join-Path $dir 'config.json')`""
    }
    'version' {
        $verFile = Join-Path $dir 'VERSION'
        if (Test-Path $verFile) { (Get-Content $verFile -Raw).Trim() } else { 'unbekannt' }
    }
    'update' {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir 'Update.ps1')
    }
    'uninstall' {
        $answer = Read-Host 'TaskbarAutoHide wirklich komplett entfernen? (j/n)'
        if ($answer -match '^(j|y)') {
            # Von einer Kopie im Temp-Ordner ausfuehren, damit auch der Installationsordner geloescht werden kann
            $tmp = Join-Path $env:TEMP 'TaskbarAutoHide-Uninstall.ps1'
            Copy-Item -Path (Join-Path $dir 'Uninstall.ps1') -Destination $tmp -Force
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tmp -RemoveFiles
            Remove-Item -Path $tmp -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host 'Abgebrochen.'
        }
    }
    { $_ -in 'help', '-h', '--help', '/?' } {
        Show-Help
    }
    default {
        Write-Host "Unbekannter Befehl: $Command"
        Show-Help
    }
}
