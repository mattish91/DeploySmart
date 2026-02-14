# Automate the install of BankID (Swedish = 1053).
# Script made by Mattias Magnusson 2026-02-14
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tp = "C:\TempPath" 
mkdir $tp -EA SilentlyContinue
$Url = "https://install.bankid.com/api/v1/latest/win"
$Installer = "BankID_installation.exe"
Invoke-WebRequest -Uri $Url -OutFile $tp\$Installer
Start-Process -FilePath $tp\$Installer -ArgumentList "/L1053 /qn" -Wait
Start-Sleep -Seconds 10
del $tp\$Installer
