#!/bin/bash
# Script to create Azure VNet and Azure VM
# Azure CLI version - Bash
#
# The script uses a bash function to create VNet and Azure VM
# When the function is invoked, it checks the existence of the Azure VNet. If it doesn't exist, the script creates it.
#
# The variables used in the script are read from the file init.json
# The file init.json must contain the following variables:
#    "subscriptionName": "SUBSCRIPTION_NAME_GOES_HERE",
#    "rgName": "RESOURCE_GROUP_NAME_GOES_HERE",
#    "location": "LOCATION_GOES_HERE",
#    "adminUsername": "ADMINISTRATOR_USERNAME_GOES_HERE",
#    "adminPassword": "ADMINISTRATOR_PASSWORD_GOES_HERE"
#

## Function to create the Azure VM ##
CreateVM() {
    local rgName="$1"
    local location="$2"
    local vnetName="$3"
    local subnet1Name="$4"
    local subnet2Name="$5"
    local addrPrefix="$6"
    local subnet1Prefix="$7"
    local subnet2Prefix="$8"
    local publisher="$9"
    local offer="${10}"
    local sku="${11}"
    local version="${12}"
    local vmSize="${13}"
    local vmName="${14}"
    local adminUsername="${15}"
    local adminPassword="${16}"

    local vmPubIP="${vmName}-pubIP"
    local nicName="${vmName}-nic"
    local nsgName="${vmName}-nsg"

    ## Create resource Group ##
    rgExists=$(az group exists --name "$rgName")
    if [ "$rgExists" == "true" ]; then
        echo "Resource group: $rgName exists, skipping"
    else
        az group create --name "$rgName" --location "$location"
    fi

    ## Create network security group ##
    echo "$(date) - Creating NSG: $nsgName"
    nsgExists=$(az network nsg show --name "$nsgName" --resource-group "$rgName" --query "name" -o tsv 2>/dev/null)
    if [ -n "$nsgExists" ]; then
        echo "$(date) - NSG: $nsgName exists, skipping"
    else
        az network nsg create \
            --name "$nsgName" \
            --resource-group "$rgName" \
            --location "$location"

        az network nsg rule create \
            --name "rule-SSH-in" \
            --nsg-name "$nsgName" \
            --resource-group "$rgName" \
            --priority 100 \
            --direction Inbound \
            --access Allow \
            --protocol "*" \
            --source-port-ranges "*" \
            --destination-port-ranges 22 \
            --source-address-prefixes "*" \
            --destination-address-prefixes "*" \
            --description "allow-SSH-in"
    fi

    ## Create public IP ##
    echo "$(date) - Creating public IP: $vmPubIP"
    pipExists=$(az network public-ip show --name "$vmPubIP" --resource-group "$rgName" --query "name" -o tsv 2>/dev/null)
    if [ -n "$pipExists" ]; then
        echo "$(date) - Public IP: $vmPubIP exists, skipping"
    else
        az network public-ip create \
            --name "$vmPubIP" \
            --resource-group "$rgName" \
            --location "$location" \
            --allocation-method Static \
            --sku Standard \
            --tier Regional \
            --zone 1 2 3
    fi

    ## Create VNet if it doesn't exist ##
    vnetExists=$(az network vnet show --name "$vnetName" --resource-group "$rgName" --query "name" -o tsv 2>/dev/null)
    if [ -n "$vnetExists" ]; then
        echo "$(date) - vnet: $vnetName exists, skipping"
    else
        echo "$(date) - Creating vnet: $vnetName"
        # shellcheck disable=SC2086
        az network vnet create \
            --name "$vnetName" \
            --resource-group "$rgName" \
            --location "$location" \
            --address-prefixes $addrPrefix

        # shellcheck disable=SC2086
        az network vnet subnet create \
            --name "$subnet1Name" \
            --vnet-name "$vnetName" \
            --resource-group "$rgName" \
            --address-prefixes $subnet1Prefix

        # shellcheck disable=SC2086
        az network vnet subnet create \
            --name "$subnet2Name" \
            --vnet-name "$vnetName" \
            --resource-group "$rgName" \
            --address-prefixes $subnet2Prefix

        echo "$(date) - vnet: $vnetName created"
    fi

    ## Create NIC with dual-stack (IPv4 and IPv6) ##
    echo "$(date) - Creating NIC: $nicName"
    nicExists=$(az network nic show --name "$nicName" --resource-group "$rgName" --query "name" -o tsv 2>/dev/null)
    if [ -n "$nicExists" ]; then
        echo "$(date) - NIC: $nicName exists, skipping"
    else
        # Create NIC with primary IPv4 configuration
        az network nic create \
            --name "$nicName" \
            --resource-group "$rgName" \
            --location "$location" \
            --vnet-name "$vnetName" \
            --subnet "$subnet1Name" \
            --network-security-group "$nsgName" \
            --public-ip-address "$vmPubIP"

        # Add IPv6 IP configuration to the NIC
        az network nic ip-config create \
            --name "ipconfig-ipv6" \
            --nic-name "$nicName" \
            --resource-group "$rgName" \
            --private-ip-address-version IPv6 \
            --vnet-name "$vnetName" \
            --subnet "$subnet1Name"
    fi

    ## Create VM ##
    echo "$(date) - Checking VM: $vmName"
    vmExists=$(az vm show --name "$vmName" --resource-group "$rgName" --query "name" -o tsv 2>/dev/null)
    if [ -n "$vmExists" ]; then
        echo "$(date) - VM: $vmName exists, skipping"
    else
        echo "$(date) - Creating VM: $vmName"
        imageUrn="${publisher}:${offer}:${sku}:${version}"
        
        az vm create \
            --name "$vmName" \
            --resource-group "$rgName" \
            --location "$location" \
            --nics "$nicName" \
            --image "$imageUrn" \
            --size "$vmSize" \
            --admin-username "$adminUsername" \
            --admin-password "$adminPassword" \
            --authentication-type password \
            --os-disk-delete-option Delete \
            --nic-delete-option Delete

        echo "$(date) - VM: $vmName has been deployed."
    fi
}

################### start of the main script ###################

# Get the directory of the script
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
inputParamsFile="${scriptDir}/init.json"

# VNet1 configuration
vnet1Name="vnet1"
vnet1AddressPrefix="10.1.0.0/16 fd:0:1::/48"
vnet1subnet1Name="subnet1"
gw1SubnetAddress="10.1.0.0/24 fd:0:1:e::/64"
vnet1subnet1Address="10.1.1.0/24 fd:0:1:1::/64"

# VNet2 configuration
vnet2Name="on-prem-vnet2"
vnet2AddressPrefix="10.2.0.0/16 fd:0:2::/48 fd:0:3::/48"
vnet2subnet1Name="subnet1"
gw2SubnetAddress="10.2.0.0/24 fd:0:2:e::/64"
vnet2subnet1Address="10.2.1.0/24 fd:0:2:1::/64"

# VM configuration
vmPublisher="canonical"
vmOffer="ubuntu-24_04-lts"
vmSKU="server"
vmVersion="latest"
vmSize="Standard_B2s"

# Read parameters from init.json
if [ ! -f "$inputParamsFile" ]; then
    echo "Error: Cannot find parameters file: $inputParamsFile"
    exit 1
fi

subscriptionName=$(jq -r '.subscriptionName' "$inputParamsFile")
rgName=$(jq -r '.rgName' "$inputParamsFile")
location=$(jq -r '.location' "$inputParamsFile")
adminUsername=$(jq -r '.adminUsername' "$inputParamsFile")
adminPassword=$(jq -r '.adminPassword' "$inputParamsFile")

# Check if values are set
echo "$(date) - values from file: init.json"
if [ -z "$subscriptionName" ] || [ "$subscriptionName" == "null" ]; then
    echo "variable subscriptionName is null"
    exit 1
else
    echo "  subscription name.....: $subscriptionName"
fi

if [ -z "$rgName" ] || [ "$rgName" == "null" ]; then
    echo "variable rgName is null"
    exit 1
else
    echo "  resource group name...: $rgName"
fi

if [ -z "$location" ] || [ "$location" == "null" ]; then
    echo "variable location is null"
    exit 1
else
    echo "  location..............: $location"
fi

if [ -z "$adminUsername" ] || [ "$adminUsername" == "null" ]; then
    echo "variable adminUsername is null"
    exit 1
else
    echo "  adminUsername.........: $adminUsername"
fi

if [ -z "$adminPassword" ] || [ "$adminPassword" == "null" ]; then
    echo "variable adminPassword is null"
    exit 1
else
    echo "  adminPassword.........: $adminPassword"
fi

# Set the subscription
az account set --subscription "$subscriptionName"

## VM1 configuration - call CreateVM function ##
CreateVM "$rgName" "$location" "$vnet1Name" "$vnet1subnet1Name" "GatewaySubnet" \
    "$vnet1AddressPrefix" "$vnet1subnet1Address" "$gw1SubnetAddress" \
    "$vmPublisher" "$vmOffer" "$vmSKU" "$vmVersion" "$vmSize" "vm1" \
    "$adminUsername" "$adminPassword"

## VM2 configuration - call CreateVM function ##
CreateVM "$rgName" "$location" "$vnet2Name" "$vnet2subnet1Name" "GatewaySubnet" \
    "$vnet2AddressPrefix" "$vnet2subnet1Address" "$gw2SubnetAddress" \
    "$vmPublisher" "$vmOffer" "$vmSKU" "$vmVersion" "$vmSize" "vm2" \
    "$adminUsername" "$adminPassword"

echo "$(date) - All VMs created successfully"
