#!/bin/bash
# Script to create two VPN connections in VPN Gateway gw2
# Azure CLI version - Bash
#

# Variables
LocalNetworkGatewayName1="lng11"
LocalNetworkGatewayName2="lng12"
Gateway1Name="gw2"
ConnectionName1="conn21"
ConnectionName2="conn22"

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

# Get subscription ID for shared key computation
subscriptionId=$(az account show --query "id" -o tsv)

# Computation of the shared key
# Deterministic - same seed always produces same key
seed="${subscriptionId}${rgName}"
sharedKey=$(echo -n "$seed" | sha256sum | cut -c1-16)
echo "$(date) - Computed shared key: $sharedKey"

# Create VPN Connection 1
echo "$(date) - Creating VPN Connection: $ConnectionName1"
az network vpn-connection create \
    --name "$ConnectionName1" \
    --resource-group "$rgName" \
    --location "$location" \
    --vnet-gateway1 "$Gateway1Name" \
    --local-gateway2 "$LocalNetworkGatewayName1" \
    --shared-key "$sharedKey"

echo "$(date) - Created VPN Connection: $ConnectionName1"

# Create VPN Connection 2
echo "$(date) - Creating VPN Connection: $ConnectionName2"
az network vpn-connection create \
    --name "$ConnectionName2" \
    --resource-group "$rgName" \
    --location "$location" \
    --vnet-gateway1 "$Gateway1Name" \
    --local-gateway2 "$LocalNetworkGatewayName2" \
    --shared-key "$sharedKey"

echo "$(date) - Created VPN Connection: $ConnectionName2"

echo "$(date) - VPN Connections created successfully"
