### download the client certificate from storage account and install it in the Cert:\CurrentUser\My
###
param(
    [Parameter(Mandatory = $false, HelpMessage = 'administrator username', ValueFromPipeline = $true)]
    [string]$adminUsername,
    [Parameter(Mandatory = $false, HelpMessage = 'administrator password', ValueFromPipeline = $true)]
    [string]$adminPassword,
    [Parameter(Mandatory = $false, HelpMessage = 'client certificate number values:[1,2,3,4,...]', ValueFromPipeline = $true)]
    [int]$clientCertSeq = 1
)

if ($clientCertSeq -le 0) { $clientCertSeq = 1 }
write-host 'number client certificates: '$clientCertSeq


$clientCertFile = 'certClient'+ ([string]$clientCertSeq)+'.pfx'
$passwordCertFile = 'certpwd.txt'
$certPath = 'C:\cert\'

$pathFolder = [string](Split-Path -Path $certPath -Parent)
$folderName = [string](Split-Path -Path $certPath -Leaf)


### install NuGet, Az.Account module , Az.Storage module 
Write-Host "Installing Azurepowershell Modules"
try {
    Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Stop | Out-Null
    Write-Host "  NuGet already registered, skipping"
}
catch {
    Install-PackageProvider -Name NuGet -Scope AllUsers  -Force | Out-Null
    Write-Host "  NuGet registered"
}

if ($null -ne (Get-Module Az.Accounts -ListAvailable)) {
    Write-Host "  Az.Account module already installed, skipping"
}
else {
    Install-Module Az.Accounts -Scope AllUsers -Force | Out-Null
    Write-Host "  Az.Account module installed"
}

if ($null -ne (Get-Module Az.Storage -ListAvailable)) {
    Write-Host "  Az.Storage module already installed, skipping"
}
else {
    Install-Module Az.Storage -Scope AllUsers -Force | Out-Null
    Write-Host "  Az.Storage module installed"
}


# create a local folder named 'cert'
New-Item -Path $pathFolder -Name $folderName -ItemType Directory -Force
Write-Host '' 

Connect-AzAccount -Identity

# get storage account name and resource group name
$storageAccountName=(Get-AzStorageAccount).StorageAccountName
$resourceGroupName=(Get-AzStorageAccount).ResourceGroupName
$storageContext=(Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName).Context
$containerName=(Get-AzStorageContainer -Context $storageContext).Name



$clientCert = @{
    Blob        = $clientCertFile
    Container   = $containerName
    Destination = "$pathFolder$folderName"
    Context     = $storageContext
  }
Get-AzStorageBlobContent @clientCert -Force -Verbose

$passwordCert = @{
     Blob        = $passwordCertFile
     Container   = $containerName
     Destination = "$pathFolder$folderName"
     Context     = $storageContext
   }
Get-AzStorageBlobContent @passwordCert -Force -Verbose


$fullPathCertClientFile = "$pathFolder$folderName\$clientCertFile"
$fullPathPwdFile = "$pathFolder$folderName\$passwordCertFile"

If (Test-Path -Path $fullPathCertClientFile){
     write-host 'client certificate file: '$fullPathCertClientFile' found'
   }
else { Write-Warning "$fullPathCertClientFile file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

If (Test-Path -Path $fullPathPwdFile){
     write-host 'certificate password file: '$fullPathPwdFile' found'
   }
else { Write-Warning "$fullPathPwdFile file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }


$pwdCert= Get-Content -Path $fullPathPwdFile
$pwdCertSecString = ConvertTo-SecureString $pwdCert -AsPlainText -Force
#Import-PfxCertificate -Password $pwdCertSecString -FilePath $fullPathCertClientFile -CertStoreLocation Cert:\CurrentUser\My

# write username and password of the administrator in text files
# Set-Content C:\cert\administratorUsername.txt $adminUsername
# Set-Content C:\cert\administratorPassword.txt $adminPassword


$pw = ConvertTo-SecureString -String $adminPassword -AsPlainText -Force
#$cred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $env:computername\$adminUsername,$pw
#$cred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $adminUsername,$pw
$cred = New-Object System.Management.Automation.PSCredential ($adminUsername, $pw)
#Start-Process -FilePath Import-PfxCertificate -ArgumentList "-Password $global:pwdCertSecString -FilePath $global:fullPathCertClientFile -CertStoreLocation Cert:\CurrentUser\My" -Credential $cred -WorkingDirectory "$pathFolder$folderName" -Wait
#Start-Process -FilePath Import-PfxCertificate -ArgumentList "-Password $pwdCertSecString","-FilePath $fullPathCertClientFile","-CertStoreLocation Cert:\CurrentUser\My" -Credential $cred -WorkingDirectory "$pathFolder$folderName" -Wait

Start-Process -FilePath "C:\Windows\system32\certutil.exe" -ArgumentList "-user","-p $local:pwdCert","-importPFX $local:fullPathCertClientFile","noRoot" -Credential $cred -WorkingDirectory "$pathFolder$folderName" -Wait

#Start-Process -FilePath "certutil.exe" -ArgumentList "-user","-p $global:pwdCert","-importPFX $global:fullPathCertClientFile" -Credential $cred -WorkingDirectory "$pathFolder$folderName" -Wait
#Start-Process -FilePath "C:\Windows\system32\certutil.exe" -ArgumentList "-user","-p $global:pwdCert","-importPFX $global:fullPathCertClientFile","noRoot" -Credential $cred -WorkingDirectory "$pathFolder$folderName" -Wait
Exit
#=======================



#Enable-PSRemoting -SkipNetworkProfileCheck -Force
#Set-NetFirewallRule -Name 'WINRM-HTTP-In-TCP' -RemoteAddress Any

Set-NetConnectionProfile -NetworkCategory Private
Set-NetFirewallRule -Name 'WINRM-HTTP-In-TCP' -RemoteAddress Any -Profile Any
#Enable-PSRemoting -SkipNetworkProfileCheck -Force

# To fix the issue when Window Remote Management service and its listener functionality are broken
# Restore the listener configuration
winrm invoke Restore winrm/Config
winrm quickconfig -quiet
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force 
#ConvertFrom-SecureString -SecureString $adminPassword -AsPlainText 
$pw = ConvertTo-SecureString -String $adminPassword -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $env:computername\$adminUsername,$pw
$s = New-PSSession -Credential $cred -ComputerName $env:computername 
Invoke-Command -Session $s -ScriptBlock { 
param($clientCertSeq) 

Set-ExecutionPolicy Unrestricted -Force
$certPath = 'C:\cert\'
whoami > 'C:\cert\whoami.txt'
$pathFolder = [string](Split-Path -Path $certPath -Parent)
$folderName = [string](Split-Path -Path $certPath -Leaf)
$clientCertFile = 'certClient'+ ([string]$clientCertSeq)+'.pfx'
$passwordCertFile = 'certpwd.txt'
$fullPathCertClientFile = "$pathFolder$folderName\$clientCertFile"
$fullPathPwdFile = "$pathFolder$folderName\$passwordCertFile" 
$pwdCert= Get-Content -Path $fullPathPwdFile

$pwdCertSecString = ConvertTo-SecureString $pwdCert -AsPlainText -Force
Import-PfxCertificate -Password $pwdCertSecString -FilePath $fullPathCertClientFile -CertStoreLocation Cert:\CurrentUser\My
} -ArgumentList $clientCertSeq

#Remove-NetFirewallRule -Name 'WINRM-HTTP-In-TCP' 