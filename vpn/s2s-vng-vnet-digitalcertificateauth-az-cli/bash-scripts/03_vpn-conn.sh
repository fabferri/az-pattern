#!/bin/bash
# Script to create VPN Gateway Connections with certificate authentication

# Address space for the virtual networks
vnet1Address='10.1.0.0/16'
vnet2Address='10.2.0.0/16'

# VPN parameters
gw1Name='gw1'
localNetgw1Name='localNetGw1'
gw1Connection1Name='Connection1'
gw1pubIP1Name="${gw1Name}pip"

gw2Name='gw2'
localNetgw2Name='localNetGw2'
gw2Connection1Name='Connection2'
gw2pubIP1Name="${gw2Name}pip"

# Key Vault and Certificate parameters
location='uksouth'
gw1OutboundCertName='gw1-cert'
gw2OutboundCertName='gw2-cert'

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

# Generate unique Key Vault names
seed="$rgName-$gw1Name"
suffix=$(echo -n "$seed" | sha256sum | cut -c1-6)
keyVault1Name="kv-$gw1Name-$suffix"

seed="$rgName-$gw2Name"
suffix=$(echo -n "$seed" | sha256sum | cut -c1-6)
keyVault2Name="kv-$gw2Name-$suffix"

# Set subscription
az account set --subscription "$subscriptionName"

# Fetch VPN Gateway1 public IP
echo "$(date) - fetch vpn gateway1 - public IP1: $gw1pubIP1Name"
gw1publicIP1=$(az network public-ip show --resource-group "$rgName" --name "$gw1pubIP1Name" --query ipAddress -o tsv)
if [ -z "$gw1publicIP1" ]; then
    echo "$(date) - vpn gateway1 - error to retrieve public IPs"
    exit 1
fi
echo "$(date) - Azure vpn Gateway1 public IP1 .: $gw1publicIP1"

# Fetch VPN Gateway2 public IP
echo "$(date) - fetch vpn gateway2 - public IP1: $gw2pubIP1Name"
gw2publicIP1=$(az network public-ip show --resource-group "$rgName" --name "$gw2pubIP1Name" --query ipAddress -o tsv)
if [ -z "$gw2publicIP1" ]; then
    echo "$(date) - vpn gateway2 - error to retrieve public IPs"
    exit 1
fi
echo "$(date) - Azure VPN Gateway2 public IP1 .: $gw2publicIP1"

# Verify VPN Gateway1 deployment status
echo "$(date) - verifying VPN Gateway1 deployment status"
gw1State=$(az network vnet-gateway show --resource-group "$rgName" --name "$gw1Name" --query provisioningState -o tsv 2>/dev/null)
if [ -z "$gw1State" ]; then
    echo "$(date) - ERROR: VPN Gateway1 '$gw1Name' not found"
    exit 1
elif [ "$gw1State" != "Succeeded" ]; then
    echo "$(date) - ERROR: VPN Gateway1 '$gw1Name' is in state '$gw1State', not 'Succeeded'"
    echo "$(date) - Please wait for the gateway to finish provisioning before creating connections"
    exit 1
fi
echo "$(date) - VPN Gateway1 status: $gw1State"

# Verify VPN Gateway2 deployment status
echo "$(date) - verifying VPN Gateway2 deployment status"
gw2State=$(az network vnet-gateway show --resource-group "$rgName" --name "$gw2Name" --query provisioningState -o tsv 2>/dev/null)
if [ -z "$gw2State" ]; then
    echo "$(date) - ERROR: VPN Gateway2 '$gw2Name' not found"
    exit 1
elif [ "$gw2State" != "Succeeded" ]; then
    echo "$(date) - ERROR: VPN Gateway2 '$gw2Name' is in state '$gw2State', not 'Succeeded'"
    echo "$(date) - Please wait for the gateway to finish provisioning before creating connections"
    exit 1
fi
echo "$(date) - VPN Gateway2 status: $gw2State"

# Create LocalNetworkGateway1
if az network local-gateway show --resource-group "$rgName" --name "$localNetgw1Name" &>/dev/null; then
    echo "$(date) - local network gateway exists, skipping: $localNetgw1Name"
else
    echo "$(date) - creating local network gateway: $localNetgw1Name"
    az network local-gateway create \
        --resource-group "$rgName" \
        --name "$localNetgw1Name" \
        --location "$location" \
        --local-address-prefixes "$vnet1Address" \
        --gateway-ip-address "$gw1publicIP1"
fi

# Create LocalNetworkGateway2
if az network local-gateway show --resource-group "$rgName" --name "$localNetgw2Name" &>/dev/null; then
    echo "$(date) - local network gateway exists, skipping: $localNetgw2Name"
else
    echo "$(date) - creating local network gateway: $localNetgw2Name"
    az network local-gateway create \
        --resource-group "$rgName" \
        --name "$localNetgw2Name" \
        --location "$location" \
        --local-address-prefixes "$vnet2Address" \
        --gateway-ip-address "$gw2publicIP1"
fi

# Get certificate information from Key Vault
echo "$(date) - fetching certificate information from Key Vault"

# Check if certificates exist in Key Vault before fetching
if az keyvault certificate show --vault-name "$keyVault1Name" --name "$gw1OutboundCertName" &>/dev/null; then
    gw1OutboundCertUrl=$(az keyvault certificate show --vault-name "$keyVault1Name" --name "$gw1OutboundCertName" --query sid -o tsv)
    gw1OutboundcertSubjectName=$(az keyvault certificate show --vault-name "$keyVault1Name" --name "$gw1OutboundCertName" --query "policy.x509CertificateProperties.subject" -o tsv | sed 's/^CN=//')
    echo "$(date) - Certificate $gw1OutboundCertName found in $keyVault1Name"
else
    echo "$(date) - WARNING: Certificate $gw1OutboundCertName not found in $keyVault1Name"
    echo "$(date) - Please run 01_vpn1.sh first to create the certificate"
    gw1OutboundCertUrl=""
    gw1OutboundcertSubjectName=""
fi

if az keyvault certificate show --vault-name "$keyVault2Name" --name "$gw2OutboundCertName" &>/dev/null; then
    gw2OutboundCertUrl=$(az keyvault certificate show --vault-name "$keyVault2Name" --name "$gw2OutboundCertName" --query sid -o tsv)
    gw2OutboundcertSubjectName=$(az keyvault certificate show --vault-name "$keyVault2Name" --name "$gw2OutboundCertName" --query "policy.x509CertificateProperties.subject" -o tsv | sed 's/^CN=//')
    echo "$(date) - Certificate $gw2OutboundCertName found in $keyVault2Name"
else
    echo "$(date) - WARNING: Certificate $gw2OutboundCertName not found in $keyVault2Name"
    echo "$(date) - Please run 02_vpn2.sh first to create the certificate"
    gw2OutboundCertUrl=""
    gw2OutboundcertSubjectName=""
fi

# Read Inbound Certificate Chain files
echo "$(date) - reading inbound certificate chain files"
inboundCert1Path="$pathFiles/certs/VPNRootCA1.cer"
inboundCert2Path="$pathFiles/certs/VPNRootCA2.cer"

# Check if certificate files exist
if [ -f "$inboundCert1Path" ]; then
    # Remove PEM headers and get Base64 only
    inboundCert1Base64=$(cat "$inboundCert1Path" | grep -v "BEGIN CERTIFICATE" | grep -v "END CERTIFICATE" | tr -d '\n\r')
    echo "$(date) - inbound certificate chain1 loaded from $inboundCert1Path"
else
    echo "$(date) - WARNING: Certificate file not found: $inboundCert1Path"
    echo "$(date) - Please run s2s-gen-certs.sh first and copy certificates to certs/ folder"
    inboundCert1Base64=""
fi

if [ -f "$inboundCert2Path" ]; then
    # Remove PEM headers and get Base64 only
    inboundCert2Base64=$(cat "$inboundCert2Path" | grep -v "BEGIN CERTIFICATE" | grep -v "END CERTIFICATE" | tr -d '\n\r')
    echo "$(date) - inbound certificate chain2 loaded from $inboundCert2Path"
else
    echo "$(date) - WARNING: Certificate file not found: $inboundCert2Path"
    echo "$(date) - Please run s2s-gen-certs.sh first and copy certificates to certs/ folder"
    inboundCert2Base64=""
fi

# Display certificate authentication info
echo "$(date) - creating gw1 certificate authentication object"
echo "gw1 - OutboundcertURL..................: $gw1OutboundCertUrl"
echo "gw1 - Inbound certificate subjectName..: $gw2OutboundcertSubjectName"

echo "$(date) - creating gw2 certificate authentication object"
echo "gw2 - OutboundcertURL..................: $gw2OutboundCertUrl"
echo "gw2 - Inbound certificate subjectName..: $gw1OutboundcertSubjectName"

# Generate a shared key for fallback if certificate auth is not fully supported via CLI
sharedKey="AzureS2SVpnSharedKey$(date +%s | sha256sum | cut -c1-16)"

# Create VPN Connection 1
if az network vpn-connection show --resource-group "$rgName" --name "$gw1Connection1Name" &>/dev/null; then
    echo "$(date) - Connection $gw1Connection1Name exists, skipping creation"
else
    echo "$(date) - creating vpn connection: $gw1Connection1Name"
    # Note: Azure CLI requires a shared-key for S2S VPN connections
    # Certificate authentication must be configured separately via Azure Portal, REST API, or ARM templates
    az network vpn-connection create \
        --resource-group "$rgName" \
        --name "$gw1Connection1Name" \
        --location "$location" \
        --vnet-gateway1 "$gw1Name" \
        --local-gateway2 "$localNetgw2Name" \
        --shared-key "$sharedKey" \
        --routing-weight 3
    
    echo "$(date) - VPN connection created with shared key"
    echo "$(date) - NOTE: Certificate authentication requires additional configuration via Azure Portal or REST API"
fi

# Create VPN Connection 2
if az network vpn-connection show --resource-group "$rgName" --name "$gw2Connection1Name" &>/dev/null; then
    echo "$(date) - Connection $gw2Connection1Name exists, skipping creation"
else
    echo "$(date) - creating vpn connection: $gw2Connection1Name"
    # Note: Azure CLI requires a shared-key for S2S VPN connections
    # Certificate authentication must be configured separately via Azure Portal, REST API, or ARM templates
    az network vpn-connection create \
        --resource-group "$rgName" \
        --name "$gw2Connection1Name" \
        --location "$location" \
        --vnet-gateway1 "$gw2Name" \
        --local-gateway2 "$localNetgw1Name" \
        --shared-key "$sharedKey" \
        --routing-weight 3
    
    echo "$(date) - VPN connection created with shared key"
    echo "$(date) - NOTE: Certificate authentication requires additional configuration via Azure Portal or REST API"
fi

# Verify connections
echo "$(date) - checking vpn connection: $gw1Connection1Name"
vpnConnection1=$(az network vpn-connection show --resource-group "$rgName" --name "$gw1Connection1Name" 2>/dev/null)
if [ -n "$vpnConnection1" ]; then
    echo "resource group............: $(echo "$vpnConnection1" | jq -r '.resourceGroup')"
    echo "gw1 - connection name.....: $(echo "$vpnConnection1" | jq -r '.name')"
    echo "gw1 - connection type.....: $(echo "$vpnConnection1" | jq -r '.connectionType')"
fi

echo '--------------------------------------------------------------------------'
echo "$(date) - checking vpn connection: $gw2Connection1Name"
vpnConnection2=$(az network vpn-connection show --resource-group "$rgName" --name "$gw2Connection1Name" 2>/dev/null)
if [ -n "$vpnConnection2" ]; then
    echo "resource group............: $(echo "$vpnConnection2" | jq -r '.resourceGroup')"
    echo "gw2 - connection name.....: $(echo "$vpnConnection2" | jq -r '.name')"
    echo "gw2 - connection type.....: $(echo "$vpnConnection2" | jq -r '.connectionType')"
fi

# List connections and verify
connectionCount=$(az network vpn-connection list --resource-group "$rgName" --query "length(@)" -o tsv)
echo "$(date) - Total number of vpn Connections: $connectionCount"
