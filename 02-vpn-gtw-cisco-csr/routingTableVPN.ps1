###
###  routes received via BGP in the Azure VPN Gateway
###
$subscriptionName  = "AzDev"        ### Azure subscription where is deployed the VPN Gateway
$rg_vpn            = "rg-vpn"       ### resource group of the VPN Gateway
$vpnName           = "vpnGw"        ### VPN gateway name

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$gtw=Get-AzVirtualNetworkGateway -Name $vpnName -ResourceGroupName $rg_vpn
Get-AzVirtualNetworkGatewayLearnedRoute -VirtualNetworkGatewayName $vpnName -ResourceGroupName $rg_vpn | ft