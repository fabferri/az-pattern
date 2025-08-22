# # AZ CLI script to create vnet10 and VPN Gateway
# The script runs in powershell and required the AZ powershell module
#
# https://learn.microsoft.com/en-us/azure/vpn-gateway/bgp-how-to-cli
#
$subscriptionName='Hybrid-PM-Test-2'
$rg='test-GatewaySubnet-extension'
$location='uksouth'
$vnet1Name='vnet1'

$vnet1Subnet1Name='subnet11'
$vnet1GatewaySubnetName='GatewaySubnet'
$vnet1AddressSpace='10.0.1.0/24'
$vnet1Subnet1Address='10.0.1.0/27'
$vnet1GatewaySubnetAddress='10.0.1.224/27'

$vnpGwName='gw1'
$vpnGwpip1= "$vnpGwName-pip1"
$vpnGwpip2= "$vnpGwName-pip2"
$vpngw1ASN= 65001


# select the Azure subscription
az account set --subscription $subscriptionName

# create Resource Group
write-host "$(Get-Date) - create resource group: $rg"
az group create --name $rg --location $location

# create vnet1
write-host "$(Get-Date) - create vnet1: $vnet1Name"
az network vnet create `
    --name $vnet1Name --resource-group $rg --location $location --address-prefix $vnet1AddressSpace

#create a subnet1 in vnet1
write-host "$(Get-Date) - create subnet: $vnet1Subnet1Name"
az network vnet subnet create `
    --name $vnet1Subnet1Name --resource-group $rg --vnet-name $vnet1Name --address-prefix $vnet1Subnet1Address

#create a GatewaySubnet in vnet1
write-host "$(Get-Date) - create subnet: $vnet1GatewaySubnetName"
az network vnet subnet create `
    --name $vnet1GatewaySubnetName --resource-group $rg --vnet-name $vnet1Name --address-prefix $vnet1GatewaySubnetAddress



# create public IP1 for VPN Gateway
write-host "$(Get-Date) - Create public IPs for VPN Gateway: $vpnGwpip1"
az network public-ip create --name $vpnGwpip1 --resource-group $rg --allocation-method Static --sku Standard --version IPv4 --zone 1 2 3
write-host "$(Get-Date) - Create public IPs for VPN Gateway: $vpnGwpip2"
az network public-ip create --name $vpnGwpip2 --resource-group $rg --allocation-method Static --sku Standard --version IPv4 --zone 1 2 3

write-host "$(Get-Date) - Create the VPN Gateway: $vnpGwName"
az network vnet-gateway create --name $vnpGwName --public-ip-addresses $vpnGwpip1 $vpnGwpip2 `
  --resource-group $rg --vnet $vnet1Name --gateway-type Vpn --vpn-type RouteBased `
  --sku VpnGw2AZ --vpn-gateway-generation Generation2 --asn $vpngw1ASN --no-wait

  write-host "$(Get-Date) - VPN Gateway: $vnpGwName deployed"



