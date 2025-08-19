# # AZ CLI script to create vnet10 and VPN Gateway
# The script runs in powershell and required the AZ powershell module
#
# https://learn.microsoft.com/en-us/azure/vpn-gateway/bgp-how-to-cli
#
$subscriptionName='Hybrid-PM-Test-2'
$rg='test-subnetpeering'
$location='uksouth'
$vnet1Name='vnet1'
$vnet2Name='vnet2'

$vnet1Subnet1Name='subnet11'
$vnet1GatewaySubnetName='GatewaySubnet'
$vnet1AddressSpace='10.0.1.0/24'
$vnet1Subnet1Address='10.0.1.0/27'
$vnet1GatewaySubnetAddress='10.0.1.192/26'

$vnet2Subnet1Name='subnet21'
$vnet2Subnet2Name='subnet22'
$vnet2Subnet3Name='subnet23'
$vnet2Subnet4Name='subnet24'
$vnet2AddressSpace='10.0.2.0/24'
$vnet2Subnet1Address='10.0.2.0/27'
$vnet2Subnet2Address='10.0.2.32/27'
$vnet2Subnet3Address='10.0.2.64/27'
$vnet2Subnet4Address='10.0.2.96/27'

$vnpGwName='gw1'
$vpnGwpip1= "$vnpGwName-pip1"
$vpnGwpip2= "$vnpGwName-pip2"
$vpngw1ASN= 65001



# select the Azure subscription
az account set --subscription $subscriptionName

# create Resource Group
write-host "$(Get-Date) - create resource group: $rg"
az group create --name $rg --location $location

#create two vnets: hub and spoke vnets
write-host "$(Get-Date) - create vnet1: $vnet1Name"
az network vnet create `
    --name $vnet1Name --resource-group $rg --location $location --address-prefix $vnet1AddressSpace

write-host "$(Get-Date) - create vnet2: $vnet2Name"
az network vnet create `
    --name $vnet2Name --resource-group $rg --location $location --address-prefix $vnet2AddressSpace

#create a subnet with multiple prefixes.
write-host "$(Get-Date) - create subnet: $vnet1Subnet1Name"
az network vnet subnet create `
    --name $vnet1Subnet1Name --resource-group $rg --vnet-name $vnet1Name --address-prefix $vnet1Subnet1Address

write-host "$(Get-Date) - create subnet: $vnet1GatewaySubnetName"
az network vnet subnet create `
    --name $vnet1GatewaySubnetName --resource-group $rg --vnet-name $vnet1Name --address-prefix $vnet1GatewaySubnetAddress

write-host "$(Get-Date) - create subnet: $vnet2Subnet1Name"
az network vnet subnet create `
    --name $vnet2Subnet1Name --resource-group $rg --vnet-name $vnet2Name --address-prefix $vnet2Subnet1Address

write-host "$(Get-Date) - create subnet: $vnet2Subnet2Name"
az network vnet subnet create `
    --name $vnet2Subnet2Name --resource-group $rg --vnet-name $vnet2Name --address-prefix $vnet2Subnet2Address

write-host "$(Get-Date) - create subnet: $vnet2Subnet3Name"
az network vnet subnet create `
    --name $vnet2Subnet3Name --resource-group $rg --vnet-name $vnet2Name --address-prefix $vnet2Subnet3Address

write-host "$(Get-Date) - create subnet: $vnet2Subnet4Name"
az network vnet subnet create `
    --name $vnet2Subnet4Name --resource-group $rg --vnet-name $vnet2Name --address-prefix $vnet2Subnet4Address


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



