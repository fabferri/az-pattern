#  Deployment of Virtual WAN
#
#
# VARIABLES:
#   $location : Azure region where deploy the virtual hub1 in Azure virtual WAN
#   $armTemplateFile: ARM template file
#
#
# VARIABLES: specified in init.json 
#
$inputParams = 'init.json'
$armTemplateFile = 'vwan.json'
$deploymentName = 'vwan-deployment'
####################################################
$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"

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
Write-Host "-------------------------------------------------------------"
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit } else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$resourceGroupName) { Write-Host 'variable $resourceGroupName is null' ; Exit } else { Write-Host '   resource group name...: '$resourceGroupName -ForegroundColor Yellow }
if (!$keyVaultName) { Write-Host 'variable $keyVaultName is null' ; Exit } else { Write-Host '   keyVault Name...: '$keyVaultName -ForegroundColor Yellow }
if (!$keyVaultAccessPoliciesObjectId) { Write-Host 'variable $keyVaultAccessPoliciesObjectId is null' ; Exit } else { Write-Host '   keyVault AccessPolicies ObjectId...: '$keyVaultAccessPoliciesObjectId -ForegroundColor Yellow }
if (!$ssrlocation) { Write-Host 'variable $ssrlocation is null' ; Exit } else { Write-Host '   ssr location.........: '$ssrlocation -ForegroundColor Yellow }
if (!$ssrAdministratorUsername) { Write-Host 'variable $ssrAdministratorUsername is null' ; Exit } else { Write-Host '   ssrAdministratorUsername.........: '$ssrAdministratorUsername -ForegroundColor Yellow }
if (!$ssrPubRSAKey) { Write-Host 'variable $ssrPubRSAKey is null' ; Exit } else { Write-Host '   ssrPubRSAKey.........: '$ssrPubRSAKey -ForegroundColor Yellow }
if (!$location) { Write-Host 'variable $location is null' ; Exit } else { Write-Host '   location: '$location -ForegroundColor Green }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit } else { Write-Host '   adminUsername: '$adminUsername -ForegroundColor Green }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit } else { Write-Host '   adminPAssword: '$adminPassword -ForegroundColor Green }

if (!$RGTagExpireDate) { Write-Host 'variable $RGTagExpireDate is null' ; Exit } else { Write-Host '   RGTagExpireDate.......: '$RGTagExpireDate -ForegroundColor Yellow }
if (!$RGTagContact) { Write-Host 'variable $RGTagContact is null' ; Exit } else { Write-Host '   RGTagContact..........: '$RGTagContact -ForegroundColor Yellow }
if (!$RGTagNinja) { Write-Host 'variable $RGTagNinja is null' ; Exit } else { Write-Host '   RGTagNinja............: '$RGTagNinja -ForegroundColor Yellow }
if (!$RGTagUsage) { Write-Host 'variable $RGTagUsage is null' ; Exit } else { Write-Host '   RGTagUsage............: '$RGTagUsage -ForegroundColor Yellow }
$rgName = $resourceGroupName

$parameters=@{
              "hub1location"= $location
              }

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Login Check
Try {Write-Host 'Using Subscription: ' -NoNewline
     Write-Host $((Get-AzContext).Name) -ForegroundColor Green}
Catch {
    Write-Warning 'You are not logged in dummy. Login and try again!'
    Return}

Write-Host "$(Get-Date) - subscription name........:"$subscriptionName -ForegroundColor Cyan
Write-Host "$(Get-Date) - resource group...........:"$rgName -ForegroundColor Cyan
Write-Host "$(Get-Date) - location virtual hub1....:"$location -ForegroundColor Cyan

# Create Resource Group 
Write-Host "$(Get-Date)-Creating Resource Group $rgName " -ForegroundColor Cyan
Try {$rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location  }

if ((Get-AzResourceGroup -Name $rgName).Tags -eq $null)
{
  # Add Tag Values to the Resource Group
  Set-AzResourceGroup -Name $rgName -Tag @{Expires=$RGTagExpireDate; Contacts=$RGTagContact; Pathfinder=$RGTagNinja; Usage=$RGTagUsage} | Out-Null
}

$runTime=Measure-Command {
    write-host "$(Get-Date)-running ARM template:"$templateFile
    New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}

write-host "runtime: "$runTime.ToString() -ForegroundColor Yellow
write-host "$(Get-Date)-end deployment" -ForegroundColor Yellow