# description: fetch the routes tables from the Azure Route Server
#
#  $subscriptionName: Azure subscription name
#  $rgName: name of the resource group
#  $vrName: name of the Azure Route Server
#  $peer1Name: name of the peering between the route server and csr1
#  $peer2Name: name of the peering between the route server and csr2
#
#
$subscriptionName = "AzDev1"  
$rgName = "rs03"   
$vrName = "rs01" 
$peer1Name = "bgpconn-nva1"
$peer2Name = "bgpconn-nva2"

$ctx = (Get-AzContext).Name  
if ($ctx -ne "ExpressRouteLab") { 
  # select the Azure subscription
  $subscr = Get-AzSubscription -SubscriptionName $subscriptionName
  Set-AzContext -Subscription $subscr.Id -ErrorAction Stop
}

write-host "route advertised to csr1:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerAdvertisedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name -WarningAction Ignore | ft

write-host "route learned from csr1:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerLearnedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name -WarningAction Ignore | ft

write-host "-------------------------------------------------" -ForegroundColor Yellow

write-host "route advertised to csr2:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerAdvertisedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer2Name -WarningAction Ignore | ft

write-host "route learned from csr2:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerLearnedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer2Name -WarningAction Ignore | ft