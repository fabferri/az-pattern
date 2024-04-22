$inputParams = 'init.json'
$profileFolderName = 'client'
####################################################
$pathFiles = Split-Path -Parent $PSCommandPath


# reading the input parameter file $inputParams and convert the values in hashtable 
If (Test-Path -Path $pathFiles\$inputParams) {
     # convert the json into PSCustomObject
     $jsonObj = Get-Content -Raw $pathFiles\$inputParams | ConvertFrom-Json
     if ($null -eq $jsonObj) {
          Write-Host "file $inputParams is empty"
          Exit
     }
     # convert the PSCustomObject in hashtable
     if ($jsonObj -is [psobject]) {
          $hash = @{}
          foreach ($property in $jsonObj.PSObject.Properties) {
               $hash[$property.Name] = $property.Value
          }
     }
     foreach ($key in $hash.keys) {
          Try { New-Variable -Name $key -Value $hash[$key] -ErrorAction Stop }
          Catch { Set-Variable -Name $key -Value $hash[$key] }
     }
} 
else { Write-Warning "$inputParams file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }
   
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '  subscription name......: '$subscriptionName -ForegroundColor Yellow }
if (!$rgNameVPN) { Write-Host 'variable $rgNameVPN is null' ; Exit }                 else { Write-Host '  resource group name VPN: '$rgNameVPN -ForegroundColor Yellow }
if (!$vpnGtwName) { Write-Host 'variable $vpnGtwName is null' ; Exit }               else { Write-Host '  name VPN Gateway.......: '$vpnGtwName -ForegroundColor Yellow }
if (!$rgNameCert) { Write-Host 'variable $rgNameCert is null' ; Exit }               else { Write-Host '  rg name Certificates...: '$rgNameCert -ForegroundColor Yellow }

$rgName = $rgNameVPN
$rgStorage = $rgNameCert
$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# create a directory 'C:\client'
New-Item -Path $pathFiles -Name $profileFolderName -ItemType Directory -Force
Write-Host '' 

# Get the Azure Gateway DNS Name
Write-Host "$(Get-Date) - getting Gateway P2S Client package url"
try {
    $vpnClientConfig = New-AzVpnClientConfiguration -ResourceGroupName $rgName -Name $vpnGtwName -AuthenticationMethod "EAPTLS" -ErrorAction Stop
}
catch {
    Write-Warning "VPN Client URL was unavailable."; 
    Exit
}

Invoke-WebRequest -Uri $vpnClientConfig.VpnProfileSASUrl -OutFile "$pathFiles\$profileFolderName\Client.zip"
Write-Host "  expanding zip file"
Expand-Archive -Path "$pathFiles\$profileFolderName\Client.zip" -Force

Write-Host "  getting Gateway URL"
[xml]$xmlFile = get-content -Path "$pathFiles\$profileFolderName\Generic\VpnSettings.xml"
$urlAzGW = $xmlFile.VpnProfile.VpnServer
Write-Host 'vpn server URI: '$urlAzGW

$myFile = "$pathFiles\$profileFolderName\AzureVPN\azurevpnconfig.xml"
Write-Host $myFile

# get storage account name and resource group name
$storageAccountName=(Get-AzStorageAccount -ResourceGroupName $rgStorage).StorageAccountName 

$storageContext=(Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $rgStorage).Context
$containerName=(Get-AzStorageContainer -Context $storageContext).Name
Write-Host $storageAccountName
Write-Host $containerName

$clientCert = @{
    File        = $myFile
    Container   = $containerName
    Blob        = "azurevpnconfig.xml"
    Context     = $storageContext
    StandardBlobTier = 'Hot'
  }
Set-AzStorageBlobContent @clientCert -Force -Verbose