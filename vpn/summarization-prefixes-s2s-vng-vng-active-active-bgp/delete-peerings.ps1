#
# Script to delete VNet peerings between spoke VNets and hub VNet
# Removes both sides of each peering
#
################# Input parameters #################
$inputParams = 'init.json'
$hubVNetName = 'vnet1'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$inputParamsFile = "$pathFiles\$inputParams"

try {
     $arrayParams = (Get-Content -Raw $inputParamsFile | ConvertFrom-Json)
     $subscriptionName = $arrayParams.subscriptionName
     $rgName = $arrayParams.rgName
     $spoke1 = $arrayParams.spoke1
     $spoke2 = $arrayParams.spoke2
     $spoke3 = $arrayParams.spoke3
     $spoke4 = $arrayParams.spoke4
     $spoke5 = $arrayParams.spoke5
     $spoke6 = $arrayParams.spoke6
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                       else { Write-Host '   resource group name...: '$rgName -ForegroundColor Yellow }

$spokeVNets = @($spoke1, $spoke2, $spoke3, $spoke4, $spoke5, $spoke6)

# Set subscription
try {
     az account set --subscription $subscriptionName
     if ($LASTEXITCODE -ne 0) { throw "az account set failed with exit code $LASTEXITCODE" }
}
catch {
     Write-Host 'error in setting subscription: '$subscriptionName -ForegroundColor Red
     Write-Host $_.Exception.Message -ForegroundColor Red
     Exit
}

foreach ($spoke in $spokeVNets) {
    Write-Host "Deleting peering $hubVNetName <-> $spoke" -ForegroundColor Cyan

    # Delete Hub -> Spoke peering
    az network vnet peering delete `
      --resource-group $rgName `
      --vnet-name $hubVNetName `
      --name "$hubVNetName-to-$spoke"
    Write-Host "deleted peering $hubVNetName-to-$spoke" -ForegroundColor Cyan
    
    # Delete Spoke -> Hub peering
    az network vnet peering delete `
      --resource-group $rgName `
      --vnet-name $spoke `
      --name "$spoke-to-$hubVNetName"
    Write-Host "deleted peering $spoke-to-$hubVNetName" -ForegroundColor Cyan
}

Write-Host 'All VNet peerings deleted.' -ForegroundColor Green
