for i in `seq 1 2000`; do curl http://10.0.2.10; done
for i in `seq 1 2000`; do curl http://10.0.3.10; done
for i in `seq 1 2000`; do curl http://10.0.4.10; done


for i in `seq 1 2000`; do curl http://10.0.1.10; done
for i in `seq 1 2000`; do curl http://10.0.3.10; done
for i in `seq 1 2000`; do curl http://10.0.4.10; done


for i in `seq 1 2000`; do curl http://10.0.1.10; done
for i in `seq 1 2000`; do curl http://10.0.2.10; done
for i in `seq 1 2000`; do curl http://10.0.4.10; done

in nva1
tcpdump -n -q net 10.0.1.0/24


3410
ssh PathLabUser@sea.pathlab.xyz -p 3410

PathLabUser
OyJcK0`rg4Vmn@?_8.5,

to be deleted: SEA-Cust34-VNet01-gw-er-conn
    Virtual network:SEA-Cust34-VNet01
    Virtual network gateway:SEA-Cust34-VNet01-gw-er
    Circuit:SEA-Cust34-ER



(Get-AzVirtualNetworkGateway -Name gw1 -ResourceGroupName test-fw02).BgpSettings.BgpPeeringAddress

Get-AzVirtualNetworkGatewayLearnedRoute -VirtualNetworkGatewayName gw1 -ResourceGroupName test-fw | ft
Get-AzVirtualNetworkGatewayLearnedRoute -VirtualNetworkGatewayName gw2 -ResourceGroupName test-fw | ft
###

$bgpPeerStatus = Get-AzVirtualNetworkGatewayBGPPeerStatus -VirtualNetworkGatewayName gw1 -ResourceGroupName test-fw
$bgpPeerStatus[0].Neighbor
$bgpPeerStatus[1].Neighbor
Get-AzVirtualNetworkGatewayAdvertisedRoute -VirtualNetworkGatewayName gw1 -ResourceGroupName test-fw -Peer $bgpPeerStatus[0].Neighbor

Get-AzVirtualNetworkGatewayAdvertisedRoute -VirtualNetworkGatewayName gw1 -ResourceGroupName test-fw -Peer 10.11.1.228 | ft
Get-AzVirtualNetworkGatewayAdvertisedRoute -VirtualNetworkGatewayName gw1 -ResourceGroupName test-fw -Peer 10.11.1.229 | ft