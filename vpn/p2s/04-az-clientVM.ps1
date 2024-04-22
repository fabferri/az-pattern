################ INPUT VARIABLES ###################
$deploymentName = 'clientVM'
$armTemplateFile = '04-az-clientVM.json'
$inputParams = 'init.json'
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
if (!$rgNameCert) { Write-Host 'variable $rgNameCert is null' ; Exit }               else { Write-Host '  rg name Certificates...: '$rgNameCert -ForegroundColor Yellow }
if (!$rgNameClient) { Write-Host 'variable $rgNameClient is null' ; Exit }           else { Write-Host '  resource group name....: '$rgrgNameClient -ForegroundColor Yellow }
if (!$location) { Write-Host 'variable $location is null' ; Exit }                   else { Write-Host '  location...............: '$location -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }         else { Write-Host '  adminUsername..........: '$adminUsername -ForegroundColor Red }   
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }         else { Write-Host '  adminPassword..........: '$adminPassword -ForegroundColor Red }     
if (!$vmNameClient) { Write-Host 'variable $vmNameClient is null' ; Exit }           else { Write-Host '  vmNameClient...........: '$vmNameClient -ForegroundColor Cyan }     

$rgName = $rgNameClient
$clientCertSeq = 3
$clientCertFile = 'certClient'+([string]$clientCertSeq)+'.pfx'
$passwordCertFile = 'certpwd.txt'

# create a local folder named 'cert'
New-Item -Path $pathFiles -Name 'cert' -ItemType Directory -Force


# Download from the storage account the 'P2SRoot.cer'
#
$storageContext=(get-AzStorageAccount -ResourceGroupName $rgNameCert).Context
$containerName=(Get-AzStorageContainer -Context $storageContext).Name
$clientCert = @{
    Blob        = $clientCertFile
    Container   = $containerName
    Destination = "$pathFiles\cert"
    Context     = $storageContext
  }
Get-AzStorageBlobContent @clientCert -Force -Verbose

$passwordCert = @{
     Blob        = $passwordCertFile
     Container   = $containerName
     Destination = "$pathFiles\cert"
     Context     = $storageContext
   }
 Get-AzStorageBlobContent @passwordCert -Force -Verbose
 

If (Test-Path -Path $pathFiles\cert\$clientCertFile){
     write-host 'client certificate file: '$clientCertFile' found'
   }
else { Write-Warning "$clientCertFile file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

If (Test-Path -Path $pathFiles\cert\$passwordCertFile){
     write-host 'client certificate file: '$passwordCertFile' found'
   }
else { Write-Warning "$passwordCertFile file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }



$storageAccountName = (get-AzStorageAccount -ResourceGroupName $rgNameCert).StorageAccountName

$parameters = @{
     "location"      = $location;
     "adminUsername" = $adminUsername;
     "adminPassword" = $adminPassword;
     "vmName"        = $vmNameClient;
     "storageAccountName" = $storageAccountName;
     "storageAccountResourceGroupName" = $rgNameCert;
     "clientCertSeq" = $clientCertSeq
}

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group
Try {
     Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
     $rg = Get-AzResourceGroup -Name $rgName -ErrorAction Stop
     Write-Host '  resource exists, skipping'
}
Catch {
     $rg = New-AzResourceGroup -Name $rgName -Location $location  
}

$StartTime = Get-Date
Write-Host "$StartTime - ARM template:"$templateFile -ForegroundColor Yellow
New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime: $RunTime" -ForegroundColor Yellow

Exit
#write-host "$(Get-Date) - install az.Storage and Az.Identity modules in the VM: $vmName " -ForegroundColor Cyan
#Invoke-AzVmRunCommand -ResourceGroupName $rgName -VMName $vmName -CommandId RunPowerShellScript -ScriptPath "$pathFiles\install-az-powershell.ps1" 

#write-host "$(Get-Date) - copy the digitial certificate to the storage account" -ForegroundColor Cyan
#Invoke-AzVmRunCommand -ResourceGroupName $rgName -VMName $vmName -CommandId RunPowerShellScript -ScriptPath "$pathFiles\transfer-to-storage.ps1"
# Invoke-AzVmRunCommand -ResourceGroupName client-t1 -VMName client1VM -CommandId RunPowerShellScript -ScriptString 'C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.10.15\Downloads\0\downloadClientCert.ps1' -Parameter  @{clientCertSeq = 1}