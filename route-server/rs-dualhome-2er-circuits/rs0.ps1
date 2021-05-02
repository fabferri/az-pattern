###   Create the router server in vnet0
###  
###
$subscriptionName = "ExpressRoute-Lab"  
$rgName = "ASH-Cust13-2"   
$vnetName = "ASH-Cust13-vnet0"

$vrName = "rs0" 
$location = "eastus"
$vrSubnetName = "RouteServerSubnet"

$peering1Name = "bgpconn-nva1"
$nva1IP = "10.101.3.10"
$nva1ASN = 65001
$peering2Name = "bgpconn-nva2"
$nva2IP = "10.102.3.10"
$nva2ASN = 65002

# select the Azure subscription
$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Set-AzContext -Subscription $subscr.Id -ErrorAction Stop


$vnet =Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName

#get virtual router subnetId
$vrSubnetId = (Get-AzVirtualNetworkSubnetConfig -Name $vrSubnetName -VirtualNetwork $vnet).Id


Try {
    $vr = Get-AzVirtualRouter -RouterName $vrName -ResourceGroupName $rgName -ErrorAction Stop
    }
Catch {
       write-host "$(get-date) - start deployment of the Virtual Router: "$vrName -ForegroundColor Yellow
       $runTime=Measure-Command {
          $vr = New-AzVirtualRouter -Name $vrName -ResourceGroupName $rgName -Location $location -HostedSubnet $vrSubnetId
      }
       write-host "elapsed time to create the Virtual Router: "$runTime.ToString() -ForegroundColor Yellow
       write-host "$(get-date) - deployment Route server completed!" -ForegroundColor Yellow
    }



# getting  virtual router IPs and the virtual router ASN
Write-Host "$(Get-Date) - get virtual router :" -ForegroundColor Yellow
Get-AzVirtualRouter -RouterName $vrName -ResourceGroupName $rgName

$runTime=Measure-Command {
   Write-Host "$(Get-Date) - update the virtual router allow-branch-to-branch"
   Update-AzVirtualRouter -RouterName $vrName -ResourceGroupName $rgName -AllowBranchToBranchTraffic 
}
Write-Host "$(Get-Date) - end update VR" 
Write-Host "elapsed time update operation: "$runTime.ToString() -ForegroundColor Cyan

Write-Host ""
Try {
   Write-Host "$(Get-Date) - virtual router peer:" -ForegroundColor Cyan
   get-AzVirtualRouterPeer -ResourceGroupName $rgName -PeerName $peering1Name -VirtualRouterName $vrName -ErrorAction Stop
}
catch {
   #Set up peering with an NVA
   Add-AzVirtualRouterPeer -PeerName $peering1Name -PeerIp $nva1IP -PeerAsn $nva1ASN -VirtualRouterName $vrName -ResourceGroupName $rgName
}
Try {
   Write-Host "$(Get-Date) - virtual router peer:" -ForegroundColor Cyan
   get-AzVirtualRouterPeer -ResourceGroupName $rgName -PeerName $peering2Name -VirtualRouterName $vrName -ErrorAction Stop
}
catch {
   #Set up peering with an NVA
   Add-AzVirtualRouterPeer -PeerName $peering2Name -PeerIp $nva2IP -PeerAsn $nva2ASN -VirtualRouterName $vrName -ResourceGroupName $rgName
}
Write-Host "$(Get-Date) - end of deployment"

# remove the virtual router.
# Remove-AzVirtualRouter -RouterName $vrName -ResourceGroupName $rgName
