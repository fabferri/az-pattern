################# Input parameters #################
$deploymentName = 'vpn1'
$armTemplateFile = '02-vpn.json'
$inputParams = 'init.json'
$rootCertFile = 'P2SRoot.cer'
$ContainerName ='cert1'
####################################################
$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"

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
   
# checking the values of variables from init-var.json
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '  subscription name......: '$subscriptionName -ForegroundColor Yellow }
if (!$rgNameVPN) { Write-Host 'variable $rgNameVPN is null' ; Exit }                 else { Write-Host '  resource group name VPN: '$rgNameVPN -ForegroundColor Yellow }
if (!$rgNameCert) { Write-Host 'variable $rgNameCert is null' ; Exit }               else { Write-Host '  rg name Certificates...: '$rgNameCert -ForegroundColor Yellow }
if (!$location) { Write-Host 'variable $location is null' ; Exit }                   else { Write-Host '  location...............: '$location -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }         else { Write-Host '  adminUsername..........: '$adminUsername -ForegroundColor Red }   
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }         else { Write-Host '  adminPassword..........: '$adminPassword -ForegroundColor Red }     

$rgName = $rgNameVPN
# create a local folder named 'cert'
New-Item -Path $pathFiles -Name 'cert' -ItemType Directory -Force


# Download from the storage account the 'P2SRoot.cer'
#
$storageContext=(get-AzStorageAccount -ResourceGroupName $rgNameCert).Context
$containerName=(Get-AzStorageContainer -Context $storageContext).Name
$rootCert = @{
    Blob        = $rootCertFile
    Container   = $containerName
    Destination = "$pathFiles\cert"
    Context     = $storageContext
  }
Get-AzStorageBlobContent @rootCert -Verbose

If (Test-Path -Path $pathFiles\cert\$rootCertFile){
     write-host 'root certificate file: '$rootCertFile' found'
   }
   else { Write-Warning "$rootCertFile file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }


# collect the root certificate from local file; extraction of content is done through regular expression
$pattern = "-----BEGIN CERTIFICATE-----([\s\S]*?)-----END CERTIFICATE-----"

$file= "$pathFiles\cert\$rootCertFile"
$string = Get-Content $file -Raw
$vpnRootCertContent = [regex]::match($string, $pattern).Groups[1].Value
write-host "root certificate content:" 
Write-Host $vpnRootCertContent -ForegroundColor Cyan

$parameters = @{
    "location1"   = $location;
    "vpnRootCert" = $vpnRootCertContent
}


$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating Resource Group' -ForegroundColor Cyan
Try {
    Get-AzResourceGroup -Name $rgName -ErrorAction Stop
    Write-Host 'Resource exists, skipping'
}
Catch { New-AzResourceGroup -Name $rgName -Location $location }


$StartTime = Get-Date
Write-Host "$StartTime - ARM template:"$templateFile -ForegroundColor Yellow
New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime: $RunTime" -ForegroundColor Yellow

write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime -ForegroundColor Yellow
write-host "end time..: "$(Get-Date) -ForegroundColor Yellow