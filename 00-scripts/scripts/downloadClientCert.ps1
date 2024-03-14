### download the client certificate from storage account and install it in the Cert:\CurrentUser\My
###
param(
    [Parameter(Mandatory = $false, HelpMessage = 'client certificate number values:[1,2,3,4,...]', ValueFromPipeline = $true)]
    [int]$clientCertSeq = 1
)

if ($clientCertSeq -le 0) { $clientCertSeq = 1 }
write-host 'number client certificates: '$clientCertSeq


$clientCertFile = 'certClient' + ([string]$clientCertSeq) + '.pfx'
$passwordCertFile = 'certpwd.txt'
$vpnProfileFile = 'azurevpnconfig.xml'
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
$storageAccountName = (Get-AzStorageAccount).StorageAccountName
$resourceGroupName = (Get-AzStorageAccount).ResourceGroupName
$storageContext = (Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName).Context
$containerName = (Get-AzStorageContainer -Context $storageContext).Name


try {
    $clientCert = @{
        Blob        = $clientCertFile
        Container   = $containerName
        Destination = "$pathFolder$folderName"
        Context     = $storageContext
    }
    Get-AzStorageBlobContent @clientCert -Force -Verbose
}
catch { 
    # the blob doesn't exist...
    Write-Host "Blob $clientCertFile Not Found"
}


try {
    $passwordCert = @{
        Blob        = $passwordCertFile
        Container   = $containerName
        Destination = "$pathFolder$folderName"
        Context     = $storageContext
    }
    Get-AzStorageBlobContent $passwordCert -Force -Verbose
}
catch { 
    # the blob doesn't exist...
    Write-Host "Blob $passwordCertFile Not Found"
}

try {
    $vpnProfile = @{
        Blob        = $vpnProfileFile
        Container   = $containerName
        Destination = "$pathFolder$folderName"
        Context     = $storageContext
    }
    Get-AzStorageBlobContent $vpnProfile -Force -Verbose
}
catch { 
    # the blob doesn't exist...
    Write-Host "Blob: $vpnProfileFile Not Found"
}



$fullPathCertClientFile = "$pathFolder$folderName\$clientCertFile"
$fullPathPwdFile = "$pathFolder$folderName\$passwordCertFile"

If (Test-Path -Path $fullPathCertClientFile) {
    write-host 'client certificate file: '$fullPathCertClientFile' found'
}
else { Write-Warning "$fullPathCertClientFile file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

If (Test-Path -Path $fullPathPwdFile) {
    write-host 'certificate password file: '$fullPathPwdFile' found'
}
else { Write-Warning "$fullPathPwdFile file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

# create a powershell scriptt add the client digital certificate 
$scriptLoadCert = @'
param(
    [Parameter(Mandatory = $false, HelpMessage = 'client certificate number values:[1,2,3,4,...]', ValueFromPipeline = $true)]
    [int]$clientCertSeq = 1
)

if ($clientCertSeq -le 0) { $clientCertSeq = 1 }
write-host 'number client certificates: '$clientCertSeq

$clientCertFile = 'certClient'+ ([string]$clientCertSeq)+'.pfx'
$passwordCertFile = 'certpwd.txt'
$certPath =  "C:\cert"

$pathFolder = [string](Split-Path -Path $certPath -Parent)
$folderName = [string](Split-Path -Path $certPath -Leaf)
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
Import-PfxCertificate -Password $pwdCertSecString -FilePath $fullPathCertClientFile -CertStoreLocation Cert:\CurrentUser\My
'@
Set-Content  "$pathFolder$folderName\loadClientCert.ps1" $scriptLoadCert

