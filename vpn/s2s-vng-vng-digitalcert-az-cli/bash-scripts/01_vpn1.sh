#!/bin/bash
# Script to create VPN Gateway with certificate authentication using managed identity and Key Vault
# The script creates a managed identity with readonly access to Key Vault integration to access the digital certificate required to establish a Connection
# $subscriptionName and $rgName collected by "init.json" file

vnet1Name='vnet1'
gw1Name='gw1'
gw1pubIP1Name="${gw1Name}pip"

gw1UserIdentityName='gw1-s2s-kv'
gw1ConfigName='gw1-config'
location='uksouth'

vnet1subnet1Name='Tenant'
vnet1Address='10.1.0.0/16'
gw1SubnetAddress='10.1.0.0/24'
vnet1subnet1Address='10.1.1.0/24'
gw1OutboundCertName='gw1-cert'

pathFiles="$(dirname "$0")"
inputParams='init.json'
inputParamsFile="$pathFiles/$inputParams"

# Read parameters from JSON file
if [ ! -f "$inputParamsFile" ]; then
    echo "$(date) - error in reading the parameters file: $inputParamsFile"
    exit 1
fi

subscriptionName=$(jq -r '.subscriptionName' "$inputParamsFile")
rgName=$(jq -r '.rgName' "$inputParamsFile")

# Check the values of variables
echo "$(date) - values from file: $inputParams"
if [ -z "$subscriptionName" ] || [ "$subscriptionName" == "null" ]; then echo 'variable subscriptionName is null'; exit 1; else echo "   subscription name.....: $subscriptionName"; fi
if [ -z "$rgName" ] || [ "$rgName" == "null" ]; then echo 'variable rgName is null'; exit 1; else echo "   resource group name...: $rgName"; fi

# Generate unique Key Vault name
seed="$rgName-$gw1Name"
suffix=$(echo -n "$seed" | sha256sum | cut -c1-6)
keyVault1Name="kv-$gw1Name-$suffix"

# Set subscription
az account set --subscription "$subscriptionName"

# Create Resource Group
echo "$(date) - Creating Resource Group"
if az group show --name "$rgName" &>/dev/null; then
    echo "Resource exists, skipping"
else
    az group create --name "$rgName" --location "$location"
fi

# Add Tag Values to the Resource Group
az group update --name "$rgName" --tags usage="s2s-digitalcertificates" --output none

# Create Virtual Network
echo "$(date) - Creating Virtual Network"
if az network vnet show --resource-group "$rgName" --name "$vnet1Name" &>/dev/null; then
    echo "  resource exists, skipping"
else
    az network vnet create \
        --resource-group "$rgName" \
        --name "$vnet1Name" \
        --address-prefix "$vnet1Address" \
        --location "$location"
    
    # Add Subnets
    echo "$(date) - Adding subnets"
    az network vnet subnet create \
        --resource-group "$rgName" \
        --vnet-name "$vnet1Name" \
        --name "$vnet1subnet1Name" \
        --address-prefix "$vnet1subnet1Address"
    
    az network vnet subnet create \
        --resource-group "$rgName" \
        --vnet-name "$vnet1Name" \
        --name "GatewaySubnet" \
        --address-prefix "$gw1SubnetAddress"
fi

# Create or get managed identity
echo "$(date) - Getting managed identity: $gw1UserIdentityName"
if ! az identity show --resource-group "$rgName" --name "$gw1UserIdentityName" &>/dev/null; then
    echo "$(date) - Creating managed identity: $gw1UserIdentityName"
    az identity create --resource-group "$rgName" --name "$gw1UserIdentityName" --location "$location"
    echo "$(date) - Created managed identity: $gw1UserIdentityName"
fi

gw1UserIdentityId=$(az identity show --resource-group "$rgName" --name "$gw1UserIdentityName" --query id -o tsv)
gw1UserIdentityPrincipalId=$(az identity show --resource-group "$rgName" --name "$gw1UserIdentityName" --query principalId -o tsv)

# Create Key Vault with RBAC enabled
if ! az keyvault show --name "$keyVault1Name" --resource-group "$rgName" &>/dev/null; then
    echo "$(date) - clearing any older Key Vaults (this may take 30 seconds or more)."
    # Purge soft-deleted key vaults
    deletedVaults=$(az keyvault list-deleted --query "[].name" -o tsv)
    for vault in $deletedVaults; do
        az keyvault purge --name "$vault" 2>/dev/null || true
    done
    echo "$(date) - creating new Key Vault with RBAC enabled"
    az keyvault create --name "$keyVault1Name" --resource-group "$rgName" --location "$location"
else
    echo "$(date) - keyvault already exists, skipping creation: $keyVault1Name"
fi

keyVaultResourceId=$(az keyvault show --name "$keyVault1Name" --resource-group "$rgName" --query id -o tsv)
echo "$(date) - Key Vault ResourceId: $keyVaultResourceId"

# Grant managed identity access to Key Vault using RBAC
echo "$(date) - granting managed identity RBAC access to Key Vault: $keyVault1Name"

# Assign "Key Vault Secrets User" role (for get/list secrets)
secretsUserRoleId="4633458b-17de-408a-b874-0445c86b69e6"
az role assignment create --assignee-object-id "$gw1UserIdentityPrincipalId" --assignee-principal-type ServicePrincipal \
    --role "$secretsUserRoleId" --scope "$keyVaultResourceId" 2>/dev/null || true

# Assign "Key Vault Certificate User" role (for get/list certificates)
certUserRoleId="db79e9a7-68ee-4b58-9aeb-b90e7c24fcba"
az role assignment create --assignee-object-id "$gw1UserIdentityPrincipalId" --assignee-principal-type ServicePrincipal \
    --role "$certUserRoleId" --scope "$keyVaultResourceId" 2>/dev/null || true

echo "$(date) - RBAC role assignments created for managed identity"

currentUser=$(az account show --query user.name -o tsv)
echo "$(date) - getting user account ID: $currentUser"

# Get current user's Object ID for RBAC assignment
currentUserObjectId=$(az ad user show --id "$currentUser" --query id -o tsv)

# Assign "Key Vault Certificates Officer" role (for full certificate management)
certOfficerRoleId="a4417e6f-fecd-4de8-b567-7b0420556985"

# Check if role assignment exists
existingAssignment=$(az role assignment list --assignee "$currentUserObjectId" --role "$certOfficerRoleId" --scope "$keyVaultResourceId" --query "[0].id" -o tsv)

if [ -z "$existingAssignment" ]; then
    echo "$(date) - Creating Role assignment for current user to Key Vault Certificates Officer role"
    az role assignment create --assignee-object-id "$currentUserObjectId" --assignee-principal-type User \
        --role "$certOfficerRoleId" --scope "$keyVaultResourceId"
    echo "$(date) - Role assignment created"
    # Wait for access policy propagation
    echo "$(date) - waiting 30 seconds for access policy changes to propagate..."
    sleep 30
else
    echo "$(date) - Role assignment already exists, skipping"
fi

echo "$(date) - RBAC role assignment created for user: $currentUser"

# Import certificate in keyvault
cert1FilePath="$pathFiles/certs/s2s-cert1.pfx"
if az keyvault certificate show --vault-name "$keyVault1Name" --name "$gw1OutboundCertName" &>/dev/null; then
    echo "$(date) - certificate already exists in keyvault, skipping: $gw1OutboundCertName"
else
    echo "$(date) - importing certificate in keyvault: $keyVault1Name"
    if [ -f "$cert1FilePath" ]; then
        az keyvault certificate import \
            --vault-name "$keyVault1Name" \
            --name "$gw1OutboundCertName" \
            --file "$cert1FilePath" \
            --password "12345"
        echo "$(date) - certificate imported successfully: $gw1OutboundCertName"
    else
        echo "$(date) - ERROR: certificate file not found: $cert1FilePath"
        echo "$(date) - Please run s2s-gen-certs.sh first to generate the certificates"
        exit 1
    fi
fi

# Create public IP for VPN Gateway
if az network public-ip show --resource-group "$rgName" --name "$gw1pubIP1Name" &>/dev/null; then
    echo "$(date) - public ip exists, skipping: $gw1pubIP1Name"
else
    az network public-ip create \
        --resource-group "$rgName" \
        --name "$gw1pubIP1Name" \
        --location "$location" \
        --allocation-method Static \
        --sku Standard \
        --tier Regional \
        --zone 1 2 3
    echo "$(date) - public ip created: $gw1pubIP1Name"
fi

# Create VirtualNetworkGateway with managed identity
echo "$(date) - checking if the vpn gateway exists: $gw1Name"
if az network vnet-gateway show --resource-group "$rgName" --name "$gw1Name" &>/dev/null; then
    echo "$(date) - vpn gateway exists, skipping: $gw1Name"
else
    echo "$(date) - creating vpn gateway: $gw1Name"
    az network vnet-gateway create \
        --resource-group "$rgName" \
        --name "$gw1Name" \
        --location "$location" \
        --public-ip-address "$gw1pubIP1Name" \
        --vnet "$vnet1Name" \
        --gateway-type Vpn \
        --vpn-type RouteBased \
        --sku VpnGw2AZ \
        --vpn-gateway-generation Generation2 \
        --no-wait false
    echo "$(date) - vpn gateway created: $gw1Name"
fi

# Update VPN gateway with managed identity
echo "$(date) - updating vpn gateway with managed identity"
az network vnet-gateway update \
    --resource-group "$rgName" \
    --name "$gw1Name" \
    --set "identity.type=UserAssigned" \
    --set "identity.userAssignedIdentities.\"$gw1UserIdentityId\"={}" 2>/dev/null || true

gw1ProvisioningState=$(az network vnet-gateway show --resource-group "$rgName" --name "$gw1Name" --query provisioningState -o tsv)
echo "$(date) - vpn gateway status: $gw1ProvisioningState"
echo "$(date) - vpn gateway with managed identity configured"
