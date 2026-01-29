#!/bin/bash
###
### Bash script to create Azure VNet and Azure VM
### The script uses a function to create VNet and Azure VM
### when the function to create the VM is invoked, it checks the existence of the Azure VNet
### If the Azure VNet doesn't exist, the script creates it.
###

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
    if az group show --name "$rgName" &>/dev/null; then
        echo "Resource group: $rgName exists, skipping"
    else
        az group create --name "$rgName" --location "$location"
    fi

    ## Create network security group ##
    echo "$(date) - Creating NSG: $nsgName"
    if az network nsg show --resource-group "$rgName" --name "$nsgName" &>/dev/null; then
        echo "$(date) - NSG: $nsgName exists, skipping"
    else
        az network nsg create \
            --resource-group "$rgName" \
            --name "$nsgName" \
            --location "$location"
        
        az network nsg rule create \
            --resource-group "$rgName" \
            --nsg-name "$nsgName" \
            --name "rule-SSH-in" \
            --priority 100 \
            --direction Inbound \
            --access Allow \
            --protocol "*" \
            --source-port-ranges "*" \
            --destination-port-ranges 22 \
            --source-address-prefixes "*" \
            --destination-address-prefixes "*"
    fi

    ## Create public IP ##
    echo "$(date) - Creating public IP: $vmPubIP"
    if az network public-ip show --resource-group "$rgName" --name "$vmPubIP" &>/dev/null; then
        echo "$(date) - Public IP: $vmPubIP exists, skipping"
    else
        az network public-ip create \
            --resource-group "$rgName" \
            --name "$vmPubIP" \
            --location "$location" \
            --allocation-method Static \
            --sku Standard \
            --tier Regional \
            --zone 1 2 3
    fi

    ## Create VNet if it doesn't exist ##
    if az network vnet show --resource-group "$rgName" --name "$vnetName" &>/dev/null; then
        echo "$(date) - vnet: $vnetName exists, skipping"
    else
        az network vnet create \
            --resource-group "$rgName" \
            --name "$vnetName" \
            --address-prefix "$addrPrefix" \
            --location "$location"
        
        az network vnet subnet create \
            --resource-group "$rgName" \
            --vnet-name "$vnetName" \
            --name "$subnet1Name" \
            --address-prefix "$subnet1Prefix"
        
        az network vnet subnet create \
            --resource-group "$rgName" \
            --vnet-name "$vnetName" \
            --name "$subnet2Name" \
            --address-prefix "$subnet2Prefix"
        
        echo "$(date) - vnet: $vnetName created"
    fi

    ## Create NIC ##
    echo "$(date) - creating NIC: $nicName"
    if az network nic show --resource-group "$rgName" --name "$nicName" &>/dev/null; then
        echo "$(date) - NIC: $nicName exists, skipping"
    else
        az network nic create \
            --resource-group "$rgName" \
            --name "$nicName" \
            --location "$location" \
            --vnet-name "$vnetName" \
            --subnet "$subnet1Name" \
            --public-ip-address "$vmPubIP" \
            --network-security-group "$nsgName"
    fi

    ## Create VM ##
    echo "$(date) - getting VM: $vmName"
    if az vm show --resource-group "$rgName" --name "$vmName" &>/dev/null; then
        echo "$(date) - VM: $vmName exists, skipping"
    else
        echo "$(date) - creating VM: $vmName"
        az vm create \
            --resource-group "$rgName" \
            --name "$vmName" \
            --location "$location" \
            --nics "$nicName" \
            --image "${publisher}:${offer}:${sku}:${version}" \
            --size "$vmSize" \
            --admin-username "$adminUsername" \
            --admin-password "$adminPassword" \
            --os-disk-name "${vmName}-OSdisk" \
            --boot-diagnostics-storage ""
        echo "$(date) - VM: $vmName has been deployed."
    fi
}

################### Start of the main script ###################
pathFiles="$(dirname "$0")"
inputParams='init.json'
inputParamsFile="$pathFiles/$inputParams"

location='uksouth'
vnet1Name='vnet1'
vnet1subnet1Name='Tenant'
vnet1Address='10.1.0.0/16'
gw1SubnetAddress='10.1.0.0/24'
vnet1subnet1Address='10.1.1.0/24'

vnet2Name='vnet2'
vnet2subnet1Name='Tenant'
vnet2Address='10.2.0.0/16'
gw2SubnetAddress='10.2.0.0/24'
vnet2subnet1Address='10.2.1.0/24'

vmPublisher="canonical"
vmOffer="ubuntu-24_04-lts"
vmSKU="server"
vmVersion="latest"
vmSize="Standard_B2s"

# Read parameters from JSON file
if [ ! -f "$inputParamsFile" ]; then
    echo "$(date) - error in reading the parameters file: $inputParamsFile"
    exit 1
fi

subscriptionName=$(jq -r '.subscriptionName' "$inputParamsFile")
rgName=$(jq -r '.rgName' "$inputParamsFile")
adminUsername=$(jq -r '.adminUsername' "$inputParamsFile")
adminPassword=$(jq -r '.adminPassword' "$inputParamsFile")

# Check the values of variables
echo "$(date) - values from file: $inputParams"
if [ -z "$subscriptionName" ] || [ "$subscriptionName" == "null" ]; then echo 'variable subscriptionName is null'; exit 1; else echo "  subscription name.....: $subscriptionName"; fi
if [ -z "$rgName" ] || [ "$rgName" == "null" ]; then echo 'variable rgName is null'; exit 1; else echo "  resource group name...: $rgName"; fi
if [ -z "$adminUsername" ] || [ "$adminUsername" == "null" ]; then echo 'variable adminUsername is null'; exit 1; else echo "  adminUsername.........: $adminUsername"; fi
if [ -z "$adminPassword" ] || [ "$adminPassword" == "null" ]; then echo 'variable adminPassword is null'; exit 1; else echo "  adminPassword.........: $adminPassword"; fi

# Set subscription
az account set --subscription "$subscriptionName"

## Create VM1 ##
CreateVM "$rgName" "$location" "$vnet1Name" "$vnet1subnet1Name" "GatewaySubnet" \
    "$vnet1Address" "$vnet1subnet1Address" "$gw1SubnetAddress" \
    "$vmPublisher" "$vmOffer" "$vmSKU" "$vmVersion" "$vmSize" \
    "vm1" "$adminUsername" "$adminPassword"

## Create VM2 ##
CreateVM "$rgName" "$location" "$vnet2Name" "$vnet2subnet1Name" "GatewaySubnet" \
    "$vnet2Address" "$vnet2subnet1Address" "$gw2SubnetAddress" \
    "$vmPublisher" "$vmOffer" "$vmSKU" "$vmVersion" "$vmSize" \
    "vm2" "$adminUsername" "$adminPassword"
