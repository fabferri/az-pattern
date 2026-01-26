#!/bin/bash
# Script to create a VPN Gateway gw2 with active-active mode, supporting IPv4 and IPv6
# Azure CLI version - Bash
#

# Variables
vnetName="on-prem-vnet2"
VNetAddressPrefix1="10.2.0.0/16"
VNetAddressPrefix2="fd:0:2::/48"
VNetAddressPrefix3="fd:0:3::/48"
SubnetName="subnet1"
GatewaySubnetPrefix1="10.2.0.0/24"
GatewaySubnetPrefix2="fd:0:2:e::/64"
SubnetPrefix1="10.2.1.0/24"
SubnetPrefix2="fd:0:2:1::/64"

GatewayName="gw2"
PublicIP1="${GatewayName}-pip1"
PublicIP2="${GatewayName}-pip2"
VPNType="RouteBased"
GatewayType="Vpn"

# Get the directory of the script
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
inputParamsFile="${scriptDir}/init.json"

# Read parameters from init.json
if [ ! -f "$inputParamsFile" ]; then
    echo "Error: Cannot find parameters file: $inputParamsFile"
    exit 1
fi

subscriptionName=$(jq -r '.subscriptionName' "$inputParamsFile")
rgName=$(jq -r '.rgName' "$inputParamsFile")
location=$(jq -r '.location' "$inputParamsFile")

# Check if values are set
echo "$(date) - values from file: init.json"
if [ -z "$subscriptionName" ] || [ "$subscriptionName" == "null" ]; then
    echo "variable subscriptionName is null"
    exit 1
else
    echo "   subscription name.....: $subscriptionName"
fi

if [ -z "$rgName" ] || [ "$rgName" == "null" ]; then
    echo "variable rgName is null"
    exit 1
else
    echo "   resource group name...: $rgName"
fi

if [ -z "$location" ] || [ "$location" == "null" ]; then
    echo "variable location is null"
    exit 1
else
    echo "   location..............: $location"
fi

# Set the subscription
az account set --subscription "$subscriptionName"

# Create Resource Group
echo "$(date) - Creating Resource Group"
rgExists=$(az group exists --name "$rgName")
if [ "$rgExists" == "true" ]; then
    echo "$(date) - Resource Group exists, skipping"
else
    az group create --name "$rgName" --location "$location"
fi

# Create a Virtual Network with GatewaySubnet and subnet1
echo "$(date) - Checking Virtual Network"
vnetExists=$(az network vnet show --name "$vnetName" --resource-group "$rgName" --query "name" -o tsv 2>/dev/null)
if [ -n "$vnetExists" ]; then
    echo "$(date) - Virtual Network exists, skipping creation"
else
    echo "$(date) - Creating Virtual Network"
    az network vnet create \
        --name "$vnetName" \
        --resource-group "$rgName" \
        --location "$location" \
        --address-prefixes "$VNetAddressPrefix1" "$VNetAddressPrefix2" "$VNetAddressPrefix3"
fi

# Check and add GatewaySubnet if it doesn't exist
echo "$(date) - Checking GatewaySubnet"
gatewaySubnetExists=$(az network vnet subnet show --name "GatewaySubnet" --vnet-name "$vnetName" --resource-group "$rgName" --query "name" -o tsv 2>/dev/null)
if [ -n "$gatewaySubnetExists" ]; then
    echo "$(date) - GatewaySubnet exists, skipping"
else
    echo "$(date) - Adding GatewaySubnet"
    az network vnet subnet create \
        --name "GatewaySubnet" \
        --vnet-name "$vnetName" \
        --resource-group "$rgName" \
        --address-prefixes "$GatewaySubnetPrefix1" "$GatewaySubnetPrefix2"
fi

# Check and add Subnet if it doesn't exist
echo "$(date) - Checking $SubnetName"
subnetExists=$(az network vnet subnet show --name "$SubnetName" --vnet-name "$vnetName" --resource-group "$rgName" --query "name" -o tsv 2>/dev/null)
if [ -n "$subnetExists" ]; then
    echo "$(date) - $SubnetName exists, skipping"
else
    echo "$(date) - Adding $SubnetName"
    az network vnet subnet create \
        --name "$SubnetName" \
        --vnet-name "$vnetName" \
        --resource-group "$rgName" \
        --address-prefixes "$SubnetPrefix1" "$SubnetPrefix2"
fi

# Request public IP addresses
echo "$(date) - Checking Public IP addresses"
pip1Exists=$(az network public-ip show --name "$PublicIP1" --resource-group "$rgName" --query "name" -o tsv 2>/dev/null)
if [ -n "$pip1Exists" ]; then
    echo "$(date) - $PublicIP1 exists, skipping"
else
    echo "$(date) - Creating $PublicIP1"
    az network public-ip create \
        --name "$PublicIP1" \
        --resource-group "$rgName" \
        --location "$location" \
        --allocation-method Static \
        --sku Standard \
        --tier Regional \
        --zone 1 2 3
fi

pip2Exists=$(az network public-ip show --name "$PublicIP2" --resource-group "$rgName" --query "name" -o tsv 2>/dev/null)
if [ -n "$pip2Exists" ]; then
    echo "$(date) - $PublicIP2 exists, skipping"
else
    echo "$(date) - Creating $PublicIP2"
    az network public-ip create \
        --name "$PublicIP2" \
        --resource-group "$rgName" \
        --location "$location" \
        --allocation-method Static \
        --sku Standard \
        --tier Regional \
        --zone 1 2 3
fi

# Create the VPN Gateway with VpnGw2AZ sku and active-active mode
echo "$(date) - Creating VPN Gateway (this may take 30-45 minutes)"
az network vnet-gateway create \
    --name "$GatewayName" \
    --resource-group "$rgName" \
    --location "$location" \
    --vnet "$vnetName" \
    --gateway-type "$GatewayType" \
    --vpn-type "$VPNType" \
    --sku VpnGw2AZ \
    --public-ip-addresses "$PublicIP1" "$PublicIP2" \
    --no-wait

echo "$(date) - VPN Gateway creation initiated. Checking deployment status..."

# Loop to check the VPN Gateway provisioning status
checkInterval=10  # seconds between checks
while true; do
    provisioningState=$(az network vnet-gateway show \
        --name "$GatewayName" \
        --resource-group "$rgName" \
        --query "provisioningState" -o tsv 2>/dev/null)
    
    if [ "$provisioningState" == "Succeeded" ]; then
        echo "$(date) - VPN Gateway '$GatewayName' is deployed successfully!"
        break
    elif [ "$provisioningState" == "Failed" ]; then
        echo "$(date) - VPN Gateway '$GatewayName' deployment failed!"
        break
    else
        echo "$(date) - VPN Gateway '$GatewayName' provisioning state: $provisioningState. Waiting $checkInterval seconds..."
        sleep $checkInterval
    fi
done
