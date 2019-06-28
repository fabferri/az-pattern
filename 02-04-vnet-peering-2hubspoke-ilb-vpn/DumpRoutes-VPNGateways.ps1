$subscriptionName = "AzureDemo3"     
$rgName           = "4"
$gtwName_dc0      = "gtw-dc0"
$gtwName_hub1     = "gtw-hub1"
$gtwName_hub2     = "gtw-hub2"

# select the Azure subscription
Set-AzContext $subscriptionName

# get the local BGP IP used to create BGP peering with neighbor 
try   {
        $vpngtw_dc0=Get-AzVirtualNetworkGateway -Name $gtwName_dc0 -ResourceGroupName $rgName -ErrorAction Stop 
        $ip_vpn_gtw_dc0=$vpngtw_dc0.BgpSettings.BgpPeeringAddress
      } 
catch {
        write-host "vpn gateway"$gtwName_dc0 "not found" -ForegroundColor Green
        Exit
      }


try   {
        $vpngtw_hub1=Get-AzVirtualNetworkGateway -Name $gtwName_hub1 -ResourceGroupName $rgName -ErrorAction Stop 
        $ip_vpn_gtw_hub1=$vpngtw_hub1.BgpSettings.BgpPeeringAddress
      } 
catch {
        write-host "vpn gateway"$gtwName_hub1 "not found" -ForegroundColor Green
        Exit
      }


try  {
       $vpngtw_hub2=Get-AzVirtualNetworkGateway -Name $gtwName_hub2 -ResourceGroupName $rgName -ErrorAction Stop 
       $ip_vpn_gtw_hub2=$vpngtw_hub2.BgpSettings.BgpPeeringAddress
      }
catch {
       write-host "vpn gateway"$gtwName_hub2 "not found" -ForegroundColor Green
       Exit
      }


# Routes advertised from the VPN gateway to the remote BGP peers
write-host ""
write-host "Routes advertised from the gateway: "$gtwName_dc0 " to the peer:"$ip_vpn_gtw_hub2 -ForegroundColor Cyan
Get-AzVirtualNetworkGatewayAdvertisedRoute `
   -VirtualNetworkGatewayName $gtwName_dc0 -ResourceGroupName $rgName -Peer $ip_vpn_gtw_hub2 | ft
write-host "----------------------------------------------------------------------------" -ForegroundColor Green
#
#
write-host "----------------------------------------------------------------------------" -ForegroundColor Green
write-host "Routes advertised from"$gtwName_hub1 "to the peer:"$ip_vpn_gtw_dc0 -ForegroundColor Cyan
Get-AzVirtualNetworkGatewayAdvertisedRoute `
   -VirtualNetworkGatewayName $gtwName_hub1 -ResourceGroupName $rgName -Peer $ip_vpn_gtw_dc0 | ft
write-host "----------------------------------------------------------------------------" -ForegroundColor Green

write-host "Routes advertised from the gateway: "$gtwName_hub1 " to the peer:"$ip_vpn_gtw_hub2 -ForegroundColor Cyan
Get-AzVirtualNetworkGatewayAdvertisedRoute `
   -VirtualNetworkGatewayName $gtwName_hub1 -ResourceGroupName $rgName -Peer $ip_vpn_gtw_hub2 | ft
write-host "----------------------------------------------------------------------------" -ForegroundColor Green
#
#
write-host "----------------------------------------------------------------------------" -ForegroundColor Green
write-host "Routes advertised from"$gtwName_hub2 "to the peer:"$ip_vpn_gtw_dc0 -ForegroundColor Cyan
Get-AzVirtualNetworkGatewayAdvertisedRoute `
   -VirtualNetworkGatewayName $gtwName_hub2 -ResourceGroupName $rgName -Peer $ip_vpn_gtw_dc0 | ft
write-host "----------------------------------------------------------------------------" -ForegroundColor Green

write-host "Routes advertised from the gateway: "$gtwName_hub2 " to the peer:"$ip_vpn_gtw_hub1 -ForegroundColor Cyan
Get-AzVirtualNetworkGatewayAdvertisedRoute `
   -VirtualNetworkGatewayName $gtwName_hub2 -ResourceGroupName $rgName -Peer $ip_vpn_gtw_hub1 | ft
write-host "----------------------------------------------------------------------------" -ForegroundColor Green

###### Lists routes learned by an Azure VPN gateway
write-host "----------------------------------------------------------------------------" -ForegroundColor Yellow
write-host "List of routes learned in: "$gtwName_dc0
Get-AzVirtualNetworkGatewayLearnedRoute `
   -VirtualNetworkGatewayName $gtwName_dc0 `
   -ResourceGroupName $rgName | ft

write-host "----------------------------------------------------------------------------" -ForegroundColor Yellow
write-host "List of routes learned in: "$gtwName_hub1
Get-AzVirtualNetworkGatewayLearnedRoute `
   -VirtualNetworkGatewayName $gtwName_hub1 `
   -ResourceGroupName $rgName | ft
write-host "----------------------------------------------------------------------------" -ForegroundColor Yellow
write-host "List of routes learned in: "$gtwName_hub2
Get-AzVirtualNetworkGatewayLearnedRoute `
   -VirtualNetworkGatewayName $gtwName_hub2 `
   -ResourceGroupName $rgName | ft
write-host "----------------------------------------------------------------------------" -ForegroundColor Yellow