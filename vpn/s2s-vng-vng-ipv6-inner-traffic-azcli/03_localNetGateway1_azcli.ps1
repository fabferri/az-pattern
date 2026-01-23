# Script to create two Local Network Gateways representing on-premises gateway gw1
# The Local network Gateway will be used in gw2 to create the VPN connection
# Azure CLI version
#
$gw1 = "gw1"
$gw1PublicIP1 = "$gw1-pip1"
$gw1PublicIP2 = "$gw1-pip2"

$LocalNetworkGatewayName1 = "lng11"
$LocalNetworkGatewayName2 = "lng12"
$LocalAddressPrefix1 = "10.1.0.0/16"
$LocalAddressPrefix2 = "fd:0:1::/48"

$pathFiles = Split-Path -Parent $PSCommandPath
$inputParams = 'init.json'
$inputParamsFile = "$pathFiles\$inputParams"

try {
    $arrayParams = (Get-Content -Raw $inputParamsFile | ConvertFrom-Json)
    $subscriptionName = $arrayParams.subscriptionName
    $rgName = $arrayParams.rgName
    $location = $arrayParams.location
}
catch {
    Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
    Exit
}

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit } else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                     else { Write-Host '   resource group name...: '$rgName -ForegroundColor Yellow }
if (!$location) { Write-Host 'variable $location is null' ; Exit }                 else { Write-Host '   location..............: '$location -ForegroundColor Yellow }

# Set the subscription
az account set --subscription $subscriptionName

# Get the public IP addresses of gw1
$gw1pip1 = az network public-ip show --name $gw1PublicIP1 --resource-group $rgName --query "ipAddress" -o tsv
$gw1pip2 = az network public-ip show --name $gw1PublicIP2 --resource-group $rgName --query "ipAddress" -o tsv

Write-Host "$(Get-Date) - gw1 Public IP 1: $gw1pip1" -ForegroundColor Yellow
Write-Host "$(Get-Date) - gw1 Public IP 2: $gw1pip2" -ForegroundColor Yellow

# Create Local Network Gateway 1
Write-Host "$(Get-Date) - Creating Local Network Gateway: $LocalNetworkGatewayName1" -ForegroundColor Cyan
az network local-gateway create `
    --name $LocalNetworkGatewayName1 `
    --resource-group $rgName `
    --location $location `
    --gateway-ip-address $gw1pip1 `
    --local-address-prefixes $LocalAddressPrefix1 $LocalAddressPrefix2

# Create Local Network Gateway 2
Write-Host "$(Get-Date) - Creating Local Network Gateway: $LocalNetworkGatewayName2" -ForegroundColor Cyan
az network local-gateway create `
    --name $LocalNetworkGatewayName2 `
    --resource-group $rgName `
    --location $location `
    --gateway-ip-address $gw1pip2 `
    --local-address-prefixes $LocalAddressPrefix1 $LocalAddressPrefix2

Write-Host "$(Get-Date) - Local Network Gateways created successfully" -ForegroundColor Green
