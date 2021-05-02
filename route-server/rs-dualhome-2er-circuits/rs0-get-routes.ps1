###   get the routing tables from the router server in vnet0
###  
###
$subscriptionName = "ExpressRoute-Lab"  
$rgName = "ASH-Cust13-2"   
$vrName = "rs0" 
$peer1Name = "bgpconn-nva1"
$peer2Name = "bgpconn-nva2"

$ctx = (Get-AzContext).Name  
if ($ctx -ne "ExpressRouteLab") { 
  # select the Azure subscription
  $subscr = Get-AzSubscription -SubscriptionName $subscriptionName
  Set-AzContext -Subscription $subscr.Id -ErrorAction Stop
}

write-host "route advertised to nva1:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerAdvertisedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name -WarningAction Ignore | ft

write-host "route learned from nva1:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerLearnedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name -WarningAction Ignore | ft

write-host "-------------------------------------------------" -ForegroundColor Yellow

write-host "route advertised to nva2:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerAdvertisedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer2Name -WarningAction Ignore | ft

write-host "route learned from nva2:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerLearnedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer2Name -WarningAction Ignore | ft