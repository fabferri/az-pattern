# AZ CLI script to create the subnet peering
# The script runs in powershell and required the AZ powershell module
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

$peeringNamevnet1tovnet2 = "$vnet1Name_to_$vnet2Name"
$peeringNamevnet2tovnet1 = "$vnet2Name_to_$vnet1Name"

# select the Azure subscription
az account set --subscription $subscriptionName


az network vpn-gateway show --name $vpnGw --resource-group $rg

write-host "$(Get-Date) - execute peering: $peeringNamevnet1tovnet2"
az network vnet peering create --name $peeringNamevnet1tovnet2 `
    --resource-group $rg --vnet-name $vnet1Name --remote-vnet $vnet2Name `
    --allow-forwarded-traffic true `
    --allow-gateway-transit true `
    --use-remote-gateways false `
    --allow-vnet-access true `
    --peer-complete-vnet false `
    --local-subnet-names $vnet1Subnet1Name $vnet1GatewaySubnetName `
    --remote-subnet-names $vnet2Subnet3Name $vnet2Subnet4Name

az network vnet peering create --name $peeringNamevnet2tovnet1 `
    --resource-group $rg --vnet-name $vnet2Name --remote-vnet $vnet1Name `
    --allow-forwarded-traffic true `
    --allow-gateway-transit false `
    --use-remote-gateways true `
    --allow-vnet-access true  `
    --peer-complete-vnet false `
    --local-subnet-names $vnet2Subnet3Name $vnet2Subnet4Name `
    --remote-subnet-names $vnet1Subnet1Name $vnet1GatewaySubnetName

# subnet peering synchronization
az network vnet peering update --name $peeringNamevnet1tovnet2 `
    --resource-group $rg `
    --vnet-name $vnet1Name `
    --local-subnet-names $vnet1Subnet1Name $vnet1GatewaySubnetName

# subnet peering synchronization
az network vnet peering update --name $peeringNamevnet2tovnet1 `
    --resource-group $rg `
    --vnet-name $vnet2Name `
    --remote-subnet-names $vnet2Subnet3Name $vnet2Subnet4Name