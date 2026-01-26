#!/bin/bash
# Script to create two Local Network Gateways representing on-premises gateway gw2
# The Local network Gateway will be used in gw1 to create the VPN connection
# Azure CLI version - Bash
#

# Variables
gw2="gw2"
gw2PublicIP1="${gw2}-pip1"
gw2PublicIP2="${gw2}-pip2"

LocalNetworkGatewayName1="lng21"
LocalNetworkGatewayName2="lng22"
LocalAddressPrefix1="10.2.0.0/16"
LocalAddressPrefix2="fd:0:2::/48"
LocalAddressPrefix3="fd:0:3::/48"

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

# Get the public IP addresses of gw2
gw2pip1=$(az network public-ip show --name "$gw2PublicIP1" --resource-group "$rgName" --query "ipAddress" -o tsv)
gw2pip2=$(az network public-ip show --name "$gw2PublicIP2" --resource-group "$rgName" --query "ipAddress" -o tsv)

echo "$(date) - gw2 Public IP 1: $gw2pip1"
echo "$(date) - gw2 Public IP 2: $gw2pip2"

# Create Local Network Gateway 1
echo "$(date) - Creating Local Network Gateway: $LocalNetworkGatewayName1"
az network local-gateway create \
    --name "$LocalNetworkGatewayName1" \
    --resource-group "$rgName" \
    --location "$location" \
    --gateway-ip-address "$gw2pip1" \
    --local-address-prefixes "$LocalAddressPrefix1" "$LocalAddressPrefix2" "$LocalAddressPrefix3"

# Create Local Network Gateway 2
echo "$(date) - Creating Local Network Gateway: $LocalNetworkGatewayName2"
az network local-gateway create \
    --name "$LocalNetworkGatewayName2" \
    --resource-group "$rgName" \
    --location "$location" \
    --gateway-ip-address "$gw2pip2" \
    --local-address-prefixes "$LocalAddressPrefix1" "$LocalAddressPrefix2" "$LocalAddressPrefix3"

echo "$(date) - Local Network Gateways created successfully"
