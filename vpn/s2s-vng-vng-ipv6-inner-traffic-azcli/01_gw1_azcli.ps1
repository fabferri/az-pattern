# Script to create a VPN Gateway gw1 with active-active mode, supporting IPv4 and IPv6
# Azure CLI version
#
$vnetName = "vnet1"
$VNetAddressPrefix1 = "10.1.0.0/16"
$VNetAddressPrefix2 = "fd:0:1::/48"
$SubnetName = "subnet1"
$GatewaySubnetPrefix1 = "10.1.0.0/24"
$GatewaySubnetPrefix2 = "fd:0:1:e::/64"
$SubnetPrefix1 = "10.1.1.0/24"
$SubnetPrefix2 = "fd:0:1:1::/64"

$GatewayName = "gw1"
$PublicIP1 = "$GatewayName-pip1"
$PublicIP2 = "$GatewayName-pip2"
$VPNType = "RouteBased"
$GatewayType = "Vpn"

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

# Create Resource Group
Write-Host "$(Get-Date) - Creating Resource Group" -ForegroundColor Cyan
$rgExists = az group exists --name $rgName
if ($rgExists -eq "true") {
    Write-Host "$(Get-Date) - Resource Group exists, skipping"
}
else {
    az group create --name $rgName --location $location
}

# Create a Virtual Network with GatewaySubnet and subnet1
Write-Host "$(Get-Date) - Checking Virtual Network" -ForegroundColor Cyan
$vnetExists = az network vnet show --name $vnetName --resource-group $rgName --query "name" -o tsv 2>$null
if ($vnetExists) {
    Write-Host "$(Get-Date) - Virtual Network exists, skipping creation"
}
else {
    Write-Host "$(Get-Date) - Creating Virtual Network" -ForegroundColor Cyan
    az network vnet create `
        --name $vnetName `
        --resource-group $rgName `
        --location $location `
        --address-prefixes $VNetAddressPrefix1 $VNetAddressPrefix2
}

# Check and add GatewaySubnet if it doesn't exist
Write-Host "$(Get-Date) - Checking GatewaySubnet" -ForegroundColor Cyan
$gatewaySubnetExists = az network vnet subnet show --name "GatewaySubnet" --vnet-name $vnetName --resource-group $rgName --query "name" -o tsv 2>$null
if ($gatewaySubnetExists) {
    Write-Host "$(Get-Date) - GatewaySubnet exists, skipping"
}
else {
    Write-Host "$(Get-Date) - Adding GatewaySubnet" -ForegroundColor Cyan
    az network vnet subnet create `
        --name "GatewaySubnet" `
        --vnet-name $vnetName `
        --resource-group $rgName `
        --address-prefixes $GatewaySubnetPrefix1 $GatewaySubnetPrefix2
}

# Check and add Subnet if it doesn't exist
Write-Host "$(Get-Date) - Checking $SubnetName" -ForegroundColor Cyan
$subnetExists = az network vnet subnet show --name $SubnetName --vnet-name $vnetName --resource-group $rgName --query "name" -o tsv 2>$null
if ($subnetExists) {
    Write-Host "$(Get-Date) - $SubnetName exists, skipping"
}
else {
    Write-Host "$(Get-Date) - Adding $SubnetName" -ForegroundColor Cyan
    az network vnet subnet create `
        --name $SubnetName `
        --vnet-name $vnetName `
        --resource-group $rgName `
        --address-prefixes $SubnetPrefix1 $SubnetPrefix2
}

# Request public IP addresses
Write-Host "$(Get-Date) - Checking Public IP addresses" -ForegroundColor Cyan
$pip1Exists = az network public-ip show --name $PublicIP1 --resource-group $rgName --query "name" -o tsv 2>$null
if ($pip1Exists) {
    Write-Host "$(Get-Date) - $PublicIP1 exists, skipping"
}
else {
    Write-Host "$(Get-Date) - Creating $PublicIP1" -ForegroundColor Cyan
    az network public-ip create `
        --name $PublicIP1 `
        --resource-group $rgName `
        --location $location `
        --allocation-method Static `
        --sku Standard `
        --tier Regional `
        --zone 1 2 3
}

$pip2Exists = az network public-ip show --name $PublicIP2 --resource-group $rgName --query "name" -o tsv 2>$null
if ($pip2Exists) {
    Write-Host "$(Get-Date) - $PublicIP2 exists, skipping"
}
else {
    Write-Host "$(Get-Date) - Creating $PublicIP2" -ForegroundColor Cyan
    az network public-ip create `
        --name $PublicIP2 `
        --resource-group $rgName `
        --location $location `
        --allocation-method Static `
        --sku Standard `
        --tier Regional `
        --zone 1 2 3
}

# Create the VPN Gateway with VpnGw2AZ sku and active-active mode
Write-Host "$(Get-Date) - Creating VPN Gateway (this may take 30-45 minutes)" -ForegroundColor Cyan
az network vnet-gateway create `
    --name $GatewayName `
    --resource-group $rgName `
    --location $location `
    --vnet $vnetName `
    --gateway-type $GatewayType `
    --vpn-type $VPNType `
    --sku VpnGw2AZ `
    --public-ip-addresses $PublicIP1 $PublicIP2 `
    --no-wait

Write-Host "$(Get-Date) - VPN Gateway creation initiated. Checking deployment status..." -ForegroundColor Green

# Loop to check the VPN Gateway provisioning status
$checkInterval = 10  # seconds between checks
while ($true) {
    $provisioningState = az network vnet-gateway show `
        --name $GatewayName `
        --resource-group $rgName `
        --query "provisioningState" -o tsv 2>$null
    
    if ($provisioningState -eq "Succeeded") {
        Write-Host "$(Get-Date) - VPN Gateway '$GatewayName' is deployed successfully!" -ForegroundColor Green
        break
    }
    elseif ($provisioningState -eq "Failed") {
        Write-Host "$(Get-Date) - VPN Gateway '$GatewayName' deployment failed!" -ForegroundColor Red
        break
    }
    else {
        Write-Host "$(Get-Date) - VPN Gateway '$GatewayName' provisioning state: $provisioningState. Waiting $checkInterval seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds $checkInterval
    }
}
