# Automate the install of Google Drive.
# Script made by Mattias Magnusson 2026-02-12
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tp = "C:\TempPath"
if (-not (Test-Path $tp)) {
    New-Item -Path $tp -ItemType Directory -Force | Out-Null
}
$file = "GoogleDriveSetup.exe"
$dlLink = "https://dl.google.com/drive-file-stream/$file"
$InstallerPath = Join-Path $tp $file
(New-Object System.Net.WebClient).DownloadFile($dlLink, $InstallerPath)
Start-Process $InstallerPath -Wait -ArgumentList "--silent" -Verb RunAs
Start-Process taskkill.exe -Wait -ArgumentList "/F /IM GoogleDriveFS.exe"
Remove-Item $InstallerPath
