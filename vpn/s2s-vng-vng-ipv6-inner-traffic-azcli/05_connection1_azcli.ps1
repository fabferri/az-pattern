# Script to create two VPN connections in gw1
# Azure CLI version
#
$LocalNetworkGatewayName1 = 'lng21'
$LocalNetworkGatewayName2 = 'lng22'
$Gateway1Name = "gw1"
$ConnectionName1 = "conn11"
$ConnectionName2 = "conn12"

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

# Get subscription ID for shared key computation
$subscriptionId = az account show --query "id" -o tsv

# Computation of the shared key
# Deterministic - same seed always produces same key
$seed = $subscriptionId + $rgName
$hash = [System.Security.Cryptography.SHA256]::Create()
$bytes = $hash.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($seed))
$sharedKey = [Convert]::ToBase64String($bytes).Substring(0, 16)  # 16 chars
Write-Host "$(Get-Date) - Computed shared key: $sharedKey" -ForegroundColor Yellow

# Create VPN Connection 1
Write-Host "$(Get-Date) - Creating VPN Connection: $ConnectionName1" -ForegroundColor Cyan
az network vpn-connection create `
    --name $ConnectionName1 `
    --resource-group $rgName `
    --location $location `
    --vnet-gateway1 $Gateway1Name `
    --local-gateway2 $LocalNetworkGatewayName1 `
    --shared-key $sharedKey

Write-Host "$(Get-Date) - Created VPN Connection: $ConnectionName1" -ForegroundColor Cyan

# Create VPN Connection 2
Write-Host "$(Get-Date) - Creating VPN Connection: $ConnectionName2" -ForegroundColor Cyan
az network vpn-connection create `
    --name $ConnectionName2 `
    --resource-group $rgName `
    --location $location `
    --vnet-gateway1 $Gateway1Name `
    --local-gateway2 $LocalNetworkGatewayName2 `
    --shared-key $sharedKey

Write-Host "$(Get-Date) - Created VPN Connection: $ConnectionName2" -ForegroundColor Cyan

Write-Host "$(Get-Date) - VPN Connections created successfully" -ForegroundColor Green
