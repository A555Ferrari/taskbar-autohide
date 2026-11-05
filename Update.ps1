<#
.SYNOPSIS
    Laedt die neueste Version von GitHub und installiert sie (Update in einem Schritt).

.DESCRIPTION
    Laedt das ZIP von GitHub, entpackt es in einen temporaeren Ordner, fuehrt dessen
    Install.ps1 aus und raeumt wieder auf. Die config.json bleibt erhalten.
    Laeuft nur, wenn du es startest, nie automatisch.

    Erstinstallation oder Update ohne vorhandene Dateien, direkt aus GitHub:
    irm https://raw.githubusercontent.com/A555Ferrari/taskbar-autohide/main/Update.ps1 | iex

    Anderen Branch laden: vorher $env:TAH_BRANCH = 'branchname' setzen.
#>

$ErrorActionPreference = 'Stop'

$branch = if ($env:TAH_BRANCH) { $env:TAH_BRANCH } else { 'main' }
$url = "https://github.com/A555Ferrari/taskbar-autohide/archive/refs/heads/$branch.zip"
$work = Join-Path $env:TEMP ('TaskbarAutoHide-Update-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$zip = "$work.zip"

try {
    Write-Host "Lade $url ..."
    # Aeltere Windows PowerShell-Versionen brauchen TLS 1.2 ausdruecklich.
    # Den System-Proxy mit Windows-Anmeldung nutzen (Firmennetz).
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.Proxy = [System.Net.WebRequest]::GetSystemWebProxy()
    $wc.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    $wc.DownloadFile($url, $zip)

    Expand-Archive -Path $zip -DestinationPath $work -Force
    $install = Get-ChildItem -Path $work -Recurse -Filter 'Install.ps1' | Select-Object -First 1
    if (-not $install) { throw 'Install.ps1 wurde im Download nicht gefunden.' }

    $verFile = Join-Path $install.DirectoryName 'VERSION'
    if (Test-Path $verFile) { Write-Host ('Neue Version: {0}' -f (Get-Content $verFile -Raw).Trim()) }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $install.FullName
}
catch {
    Write-Warning "Update fehlgeschlagen: $($_.Exception.Message)"
    Write-Host 'Tipp: Ist github.com im Netz erreichbar? Sonst die ZIP im Browser laden und Install.ps1 von Hand ausfuehren.'
}
finally {
    Remove-Item -Path $zip -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $work -Recurse -Force -ErrorAction SilentlyContinue
}
