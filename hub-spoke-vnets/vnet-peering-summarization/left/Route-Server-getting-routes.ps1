$subscriptionName = "ExpressRoute-Lab"  
$rgName = "ASH-Cust13_02"   
$vrName = "rs-hub00" 
$peer1Name = "bgp-conn1"
$peer2Name = "bgp-conn2"

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
write-host "-------------------------------------------------" -ForegroundColor Yellow

write-host "route advertised to nva2:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerAdvertisedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer2Name -WarningAction Ignore | ft

write-host "route learned from nva2:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerLearnedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer2Name -WarningAction Ignore | ft