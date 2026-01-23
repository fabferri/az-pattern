# Script to create a VPN Gateway gw2 with active-active mode, supporting IPv4 and IPv6
#
$vnetName = "on-prem-vnet2"
$VNetAddressPrefix = @("10.2.0.0/16", "fd:0:2::/48","fd:0:3::/48")
$SubnetName = "subnet1" 
$GatewaySubnet = @("10.2.0.0/24", "fd:0:2:e::/64")
$Subnet = @("10.2.1.0/24", "fd:0:2:1::/64")
$GatewayName = "gw2"
$PublicIP1 = "$GatewayName-pip1"
$PublicIP2 = "$GatewayName-pip2"
$GatewayIPConfig1 = "$GatewayName-ipconfig1"
$GatewayIPConfig2 = "$GatewayName-ipconfig2"
$VPNType = "RouteBased"
$GatewayType = "Vpn"

$pathFiles = Split-Path -Parent $PSCommandPath
$inputParams = 'init.json'
$inputParamsFile = "$pathFiles\$inputParams"

try {
     $arrayParams = (Get-Content -Raw $inputParamsFile | ConvertFrom-Json)
     $subscriptionName = $arrayParams.subscriptionName
     $rgName = $arrayParams.rgName
     $location = $arrayParams.location
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                       else { Write-Host '   resource group name...: '$rgName -ForegroundColor Yellow }    
if (!$location) { Write-Host 'variable $location is null' ; Exit }                   else { Write-Host '   location..............: '$location -ForegroundColor Yellow }

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id


# Create Resource Group 
Write-Host $(Get-Date)'- Creating Resource Group' -ForegroundColor Cyan
Try {
    $rg = Get-AzResourceGroup -Name $rgName -ErrorAction Stop
    Write-Host $(Get-Date)'-Resource exists, skipping'
}
Catch {
    $rg = New-AzResourceGroup -Name $rgName -Location $location
}

# Create a Virtual Network
Write-Host $(Get-Date)'- Checking Virtual Network' -ForegroundColor Cyan
Try {
    $vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName -ErrorAction Stop
    Write-Host $(Get-Date)'- Virtual Network exists, skipping creation'
}
Catch {
    Write-Host $(Get-Date)'- Creating Virtual Network' -ForegroundColor Cyan
    $subnet1 = New-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -AddressPrefix $GatewaySubnet
    $subnet2 = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $Subnet
    $vnet = New-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName `
        -Location $Location -AddressPrefix $VNetAddressPrefix -Subnet $subnet1, $subnet2
}

# Check and add GatewaySubnet if it doesn't exist
$gatewaySubnetConfig = Get-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet -ErrorAction SilentlyContinue
if ($null -eq $gatewaySubnetConfig) {
    Write-Host $(Get-Date)'- Adding GatewaySubnet' -ForegroundColor Cyan
    Add-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -AddressPrefix $GatewaySubnet -VirtualNetwork $vnet
    $vnet | Set-AzVirtualNetwork
}
else {
    Write-Host $(Get-Date)'- GatewaySubnet exists, skipping'
}

# Refresh VNet object after potential changes
$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName

# Check and add Subnet if it doesn't exist
$subnetConfig = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $vnet -ErrorAction SilentlyContinue
if ($null -eq $subnetConfig) {
    Write-Host $(Get-Date)'- Adding $SubnetName' -ForegroundColor Cyan
    Add-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $Subnet -VirtualNetwork $vnet
    $vnet | Set-AzVirtualNetwork
}
else {
    Write-Host $(Get-Date)"- $SubnetName exists, skipping"
}

# Request public IP addresses
Write-Host $(Get-Date)'- Checking Public IP addresses' -ForegroundColor Cyan
$gwpip1 = Get-AzPublicIpAddress -Name $PublicIP1 -ResourceGroupName $rgName -ErrorAction SilentlyContinue
if ($null -eq $gwpip1) {
    Write-Host $(Get-Date)"- Creating $PublicIP1" -ForegroundColor Cyan
    $gwpip1 = New-AzPublicIpAddress -Name $PublicIP1 -ResourceGroupName $rgName -Location $Location -AllocationMethod Static -Sku Standard -Tier Regional -Zone 1,2,3
}
else {
    Write-Host $(Get-Date)"- $PublicIP1 exists, skipping"
}

$gwpip2 = Get-AzPublicIpAddress -Name $PublicIP2 -ResourceGroupName $rgName -ErrorAction SilentlyContinue
if ($null -eq $gwpip2) {
    Write-Host $(Get-Date)"- Creating $PublicIP2" -ForegroundColor Cyan
    $gwpip2 = New-AzPublicIpAddress -Name $PublicIP2 -ResourceGroupName $rgName -Location $Location -AllocationMethod Static -Sku Standard -Tier Regional -Zone 1,2,3
}
else {
    Write-Host $(Get-Date)"- $PublicIP2 exists, skipping"
}

# Create the gateway IP addressing configuration
$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet
$gwipconfig1 = New-AzVirtualNetworkGatewayIpConfig -Name $GatewayIPConfig1 -SubnetId $subnet.Id -PublicIpAddressId $gwpip1.Id
$gwipconfig2 = New-AzVirtualNetworkGatewayIpConfig -Name $GatewayIPConfig2 -SubnetId $subnet.Id -PublicIpAddressId $gwpip2.Id

# Create the VPN Gateway with VpnGw2 sku, Generation2 and active-passive mode
New-AzVirtualNetworkGateway -Name $GatewayName -ResourceGroupName $rgName `
    -Location $Location -IpConfigurations $gwipconfig1, $gwipconfig2 -GatewayType $GatewayType `
    -VpnType $VPNType -GatewaySku VpnGw2AZ -EnableActiveActiveFeature