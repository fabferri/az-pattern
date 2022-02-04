# powershell script to create Resource Group and Keyvault
# administrator username and password are stored in keyvault secret
#
################# Input parameters #################
$inputParams = 'init.json'
$armTemplateFile = '00-keyvault.json'
$deploymentName = 'keyvault-vwan'

####################################################
$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"

# reading the input parameter file $inputParams and convert the values in hashtable 
If (Test-Path -Path $pathFiles\$inputParams) 
{
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
          $message = '{0} = {1} ' -f $key, $hash[$key]
          Write-Output $message
          Try { New-Variable -Name $key -Value $hash[$key] -ErrorAction Stop }
          Catch { Set-Variable -Name $key -Value $hash[$key] }
     }
} 
else { Write-Warning "$inputParams file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit } else { Write-Host '   resource group name...: '$ResourceGroupName -ForegroundColor Yellow }
if (!$keyVaultName) { Write-Host 'variable $keyVaultName is null' ; Exit }           else { Write-Host '   keyVault Name.........: '$keyVaultName -ForegroundColor Yellow }
if (!$keyVaultAccessPoliciesObjectId) { Write-Host 'variable $keyVaultAccessPoliciesObjectId is null' ; Exit } else { Write-Host '   keyVault AccessPolicies ObjectId...: '$keyVaultAccessPoliciesObjectId -ForegroundColor Yellow }
if (!$hub1location) { Write-Host 'variable $hub1location is null' ; Exit }           else { Write-Host '   hub1 location.........: '$hub1location -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }         else { Write-Host '   administrator username: '$adminUsername -ForegroundColor Green }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }         else { Write-Host '   administrator Password: '$adminPassword -ForegroundColor Green }
if (!$RGTagExpireDate) { Write-Host 'variable $RGTagExpireDate is null' ; Exit }     else { Write-Host '   RGTagExpireDate.......: '$RGTagExpireDate -ForegroundColor Yellow }
if (!$RGTagContact) { Write-Host 'variable $RGTagContact is null' ; Exit }           else { Write-Host '   RGTagContact..........: '$RGTagContact -ForegroundColor Yellow }
if (!$RGTagNinja) { Write-Host 'variable $RGTagNinja is null' ; Exit }               else { Write-Host '   RGTagNinja............: '$RGTagNinja -ForegroundColor Yellow }
if (!$RGTagUsage) { Write-Host 'variable $RGTagUsage is null' ; Exit }               else { Write-Host '   RGTagUsage............: '$RGTagUsage -ForegroundColor Yellow }
######

$rgName = $ResourceGroupName
$location = $hub1location

$StartTime = Get-Date
$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id


# Create Resource Group 
Write-Host "$(Get-Date) - Creating Resource Group: "$rgName -ForegroundColor Cyan
Try {$rg = Get-AzResourceGroup -Name $rgName -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $rgName -Location $location}

# Add Tag Values to the Resource Group
Set-AzResourceGroup -Name $rgName -Tag @{Expires=$RGTagExpireDate; Contacts=$RGTagContact; Pathfinder=$RGTagNinja; Usage=$RGTagUsage} | Out-Null

# Remove the keyvault in softdelete state
try { 
     $kv = Get-AzKeyVault -InRemovedState -VaultName $keyVaultName -Location $location 
     if ($kv -ne $null) {
          Remove-AzKeyVault -InRemovedState -Location $location -VaultName $keyVaultName -Force
     }
} catch {
     Write-Host "error in remove keyvault in softdelete state"
}

$parameters=@{
     "keyVaultName" = $keyVaultName;
     "secretName" = $adminUsername;
     "secretValue" = $adminPassword;
     "location" = $hub1location;
     "keyVaultAccessPoliciesObjectId" = $keyVaultAccessPoliciesObjectId
     }

$startTime = Get-Date
write-host "$startTime - running ARM template:"$templateFile
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

# End printout the runtime
$endTime = Get-Date
$TimeDiff = New-TimeSpan $startTime $endTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins,$Secs
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Script completed" -ForegroundColor Green
Write-Host "  Time to complete: $RunTime" -ForegroundColor Yellow
Write-Host
