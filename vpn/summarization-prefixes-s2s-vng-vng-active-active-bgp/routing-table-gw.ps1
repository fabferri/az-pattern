#
# Script to check BGP learned routes on both VPN gateways
#
################# Input parameters #################
$inputParams = 'init.json'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$inputParamsFile = "$pathFiles\$inputParams"

try {
     $arrayParams = (Get-Content -Raw $inputParamsFile | ConvertFrom-Json)
     $subscriptionName = $arrayParams.subscriptionName
     $rgName = $arrayParams.rgName
     $gateway1Name = $arrayParams.gateway1Name
     $gateway2Name = $arrayParams.gateway2Name
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                       else { Write-Host '   resource group name...: '$rgName -ForegroundColor Yellow }
if (!$gateway1Name) { Write-Host 'variable $gateway1Name is null' ; Exit }           else { Write-Host '   gateway1 name.........: '$gateway1Name -ForegroundColor Yellow }
if (!$gateway2Name) { Write-Host 'variable $gateway2Name is null' ; Exit }           else { Write-Host '   gateway2 name.........: '$gateway2Name -ForegroundColor Yellow }

az account set --subscription $subscriptionName

### BGP learned routes on gateway1
Write-Host "$(Get-Date) - BGP learned routes on $gateway1Name" -ForegroundColor Cyan
az network vnet-gateway list-learned-routes -n $gateway1Name -g $rgName -o table

### BGP learned routes on gateway2
Write-Host "$(Get-Date) - BGP learned routes on $gateway2Name" -ForegroundColor Cyan
az network vnet-gateway list-learned-routes -n $gateway2Name -g $rgName -o table