###   get the routing table from the router server in vnet1
###  
###
$subscriptionName = "ExpressRoute-Lab"  
$rgName = "ASH-Cust13-2"   
$vrName = "rs1" 
$peer1Name = "bgpconn-nva1"

$ctx = (Get-AzContext).Name  
if ($ctx -ne "ExpressRouteLab") { 
  # select the Azure subscription
  $subscr = Get-AzSubscription -SubscriptionName $subscriptionName
  Set-AzContext -Subscription $subscr.Id -ErrorAction Stop
}

write-host "route advertised to nva:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerAdvertisedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name -WarningAction Ignore | ft

write-host "route learned from nva:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerLearnedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name -WarningAction Ignore | ft