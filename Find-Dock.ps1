<#
.SYNOPSIS
    Hilft, ein Erkennungsmuster fuer die Dockingstation zu finden.

.DESCRIPTION
    Zwei Schritte:
      1. Ohne Dock:   .\Find-Dock.ps1 -Save
      2. Mit Dock:    .\Find-Dock.ps1 -Compare
    Schritt 2 listet alle Geraete, die nur MIT Dock vorhanden sind. Daraus ein
    eindeutiges Muster (z.B. "*Dock*" oder "*USB GbE*") in die config.json
    unter "dockMatch" eintragen und "mode" auf "dock" oder "either" stellen.

.PARAMETER Save
    Speichert die aktuell vorhandenen Geraete als Basis (ohne Dock ausfuehren).

.PARAMETER Compare
    Zeigt Geraete, die seit -Save neu dazugekommen sind (mit Dock ausfuehren).
#>
[CmdletBinding()]
param(
    [switch]$Save,
    [switch]$Compare
)

$baseFile = Join-Path $env:TEMP 'taskbar-autohide-baseline.json'

function Get-Present {
    Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName } |
        Select-Object FriendlyName, InstanceId, Class
}

if ($Save) {
    Get-Present | ConvertTo-Json | Set-Content -Path $baseFile -Encoding UTF8
    Write-Host "Basis gespeichert ($baseFile). Jetzt Dock anschliessen und '.\Find-Dock.ps1 -Compare' ausfuehren."
    return
}

if ($Compare) {
    if (-not (Test-Path $baseFile)) {
        Write-Warning 'Keine Basis gefunden. Erst ohne Dock "-Save" ausfuehren.'
        return
    }
    $before = @(Get-Content $baseFile -Raw | ConvertFrom-Json)
    $beforeIds = $before.InstanceId
    $new = Get-Present | Where-Object { $beforeIds -notcontains $_.InstanceId }
    if (-not $new) {
        Write-Host 'Keine neuen Geraete gefunden. Dock wirklich angeschlossen?'
        return
    }
    Write-Host 'Neu mit Dock vorhanden:'
    $new | Sort-Object Class, FriendlyName | Format-Table -AutoSize
    Write-Host 'Tipp: Ein Eintrag mit "Dock", "Hub" oder dem Netzwerkadapter der Dock eignet sich meist gut.'
    return
}

Write-Host 'Aktuell vorhandene Geraete:'
Get-Present | Sort-Object Class, FriendlyName | Format-Table -AutoSize
Write-Host 'Fuer einen Vorher/Nachher-Vergleich: -Save (ohne Dock), dann -Compare (mit Dock).'
