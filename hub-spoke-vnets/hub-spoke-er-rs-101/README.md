<properties
pageTitle= 'Simple hub-spoke vnet with Route Server and ExpressRoute Gateway'
description= "ARM template to create hub-spoke vnet with Route Server and ExpressRoute Gateway"
documentationCenter="https://github.com/fabferri/az-pattern"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="ARM templates"
   ms.topic="Azure Networking"
   ms.tgt_pltfrm="ExpressRoute, Azure Route Server"
   ms.workload="hub spoke, ExpressRoute Gateway, Azure Route Server"
   ms.date="07/08/2023"
   ms.author="fabferri" />

# Simple hub-spoke vnet with Route Server and ExpressRoute Gateway
The article walks through a configuration with hub-spoke vnet in peering, with ExpressRoute Gateway and Azure Route Server in the hub. The Azure ExpressRoute Gateway is connected to an on-premises network through an ExpressRoute circuit. The high-level network diagram is shown below:

[![1]][1]


The vnet peering between hub-spoke1 is created with the following attributes:

[![2]][2]


The full network diagram with UDRs appliend to the subnets is shown below:

[![3]][3]


- The on-premises network 10.1.34.0/25 is advertised from the customer's edge routers to the ExpressRoute circuit (MSEE routers). The MSEE routers advertise in BGP the on-premises network 10.1.34.0/25 to the ExpressRoute Gateway.
- an **nva** is deployed in the **hub** vnet and it runs in Ubuntu 22.04. By cloud-init a FRR is installed and configured to establish two eBGP peering with the Route Server. The **nva** advertises the address space of the **spoke1** to the Route Server. The **nva** works as IP packet forwarder.
- the Azure Route Server in **hub** establishes automatically iBGP sessions with the ExpressRoute Gateway. The Route Server works as reflector: 
   - the Azure Route Server advertises the networks learnt from the ExpressRoute Gateway to the **nva**
   - the Azure Route Server advertises the networks learnt from the **nva** to the ExpressRoute Gateway
- a UDR in the GatewaySubnet force the traffic from the on-premises network to transit through the **nva**, before reaching the **hubsubnet2** and  **spoke1**
- deployment of the Azure VMs in **hubsubnet2** and **spoke1subnet1** use custom script extension to install nginx with simple basic homepage

<br> 

The configuration wants to achieve the following transit in the communications: 
- enable the communication between the network on-premises and the workloads in the **hubsubnet2** with transit through the **nva** 
- enable the communication between the network on-premises and the workloads in the **spoke1** with transit through the **nva**

the diagram below shows the data paths:

[![4]][4]

## <a name="List of files"></a>1. List of project files

| file                    | description                                                                               |       
| ----------------------- |:----------------------------------------------------------------------------------------- |
| **init.json**           | input file to set the input variable across all the scripts and ARM templates             |
| **01-vnet-rs-er.json**  | ARM template to create hub, spoke1, Azure VPN Gateways, Azure Route Server, vnet peering  |
| **01-vnet-rs-er.ps1**   | powershell script to deploy the ARM template **01-vnet-rs-er.json**                       |
| **02-vms.json**         | ARM template to create Azure VMs                                                          |
| **02-vms.ps1**          | powershell script to deploy the ARM template **02-vms.json**                              |


The meaning of input variables specified in the **init.json** are described here:
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "subscriptionName": "AZURE_SUBSCRITION_NAME",
    "ResourceGroupName": "RESOURCE_GROUP_NAME",
    "location1": "NAME_AZURE_REGION_VNET1",
    "location2": "NAME_AZURE_REGION_VNET2",
    "erSubscriptionId": "AZURE_SUBSCRIPTION_ID_WHERE_IS_DEPLOYED_ER_CIRCUIT",
    "erResourceGroup": "RESOURCE_GROUP_NAME_WHERE_IS_DEPLOYED_ER_CIRCUIT",
    "erCircuitName": "NAME_OF_THE_EXPRESSROUTE_CIRCUIT",
    "erAuthorizationKey": "AUTHROIZATION_KEY_OF_THE_EXPRESSROUTE_CIRCUIT"
}
```



## <a name="Routing tables"></a>2. Effective routing tables 

Effective routing table in **nva-nic**
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.100.0/24    | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.0.50.0/24     | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active | 10.1.34.0/25     | Virtual network gateway | 10.3.129.52         | \-                      |
| Virtual network gateway | Active | 10.1.34.0/25     | Virtual network gateway | 10.3.129.53         | \-                      |

Effective routing table in **vm-hubSubnet2-nic**:
| Source  | State   | Address Prefixes | Next Hop Type     | Next Hop IP Address | User Defined Route Name |
| ------- | ------- | ---------------- | ----------------- | ------------------- | ----------------------- |
| Default | Active  | 10.0.100.0/24    | Virtual network   | \-                  | \-                      |
| Default | Invalid | 10.0.50.0/24     | VNet peering      | \-                  | \-                      |
| Default | Active  | 0.0.0.0/0        | Internet          | \-                  | \-                      |
| User    | Active  | 10.0.50.0/24     | Virtual appliance | 10.0.100.10         | to-spoke1               |
| User    | Active  | 10.0.0.0/8       | Virtual appliance | 10.0.100.10         | to-10network            |

Effective routing table in **vm-spoke1Subnet1-nic**:
| Source  | State   | Address Prefixes | Next Hop Type     | Next Hop IP Address | User Defined Route Name |
| ------- | ------- | ---------------- | ----------------- | ------------------- | ----------------------- |
| Default | Active  | 10.0.50.0/24     | Virtual network   | \-                  | \-                      |
| Default | Invalid | 10.0.100.0/24    | VNet peering      | \-                  | \-                      |
| Default | Active  | 0.0.0.0/0        | Internet          | \-                  | \-                      |
| User    | Active  | 10.0.100.0/24    | Virtual appliance | 10.0.100.10         | to-hub                  |
| User    | Active  | 10.0.0.0/8       | Virtual appliance | 10.0.100.10         | to-10network            |

Networks advertised and learnt in Azure Route Server:

```powershell
Get-AzRouteServerPeerAdvertisedRoute -RouteServerName rs -ResourceGroupName test-er-rs-03 -PeerName conn1

LocalAddress Network       NextHop     SourcePeer Origin AsPath            Weight
------------ -------       -------     ---------- ------ ------            ------
10.0.100.68  10.0.100.0/24 10.0.100.68            Igp    65515             0
10.0.100.68  10.1.34.0/25  10.0.100.68            Igp    65515-12076-65020 0
10.0.100.69  10.0.100.0/24 10.0.100.69            Igp    65515             0
10.0.100.69  10.1.34.0/25  10.0.100.69            Igp    65515-12076-65020 0



Get-AzRouteServerPeerLearnedRoute -RouteServerName rs -ResourceGroupName test-er-rs-03 -PeerName conn1

LocalAddress Network      NextHop     SourcePeer  Origin AsPath Weight
------------ -------      -------     ----------  ------ ------ ------
10.0.100.68  10.0.50.0/24 10.0.100.10 10.0.100.10 EBgp   65001  32768
10.0.100.69  10.0.50.0/24 10.0.100.10 10.0.100.10 EBgp   65001  32768
```

- **10.100.0.68, 10.100.0.69**: IP addresses of the Azure Route Server
- **10.0.100.0/24**: IP address space of the **hub**
- **10.0.50.0/24**: IP address space of the **spoke1**
- **10.1.34.0/25**: IP address space of the on-premises network
- **12076**: Microsoft's ASN 
- **65020**: customer's ASN 

<br>

BGP table in **nva**:
```console
nva# show ip bgp neighbors 10.0.100.68 received-routes
BGP table version is 3, local router ID is 10.0.100.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.100.0/24    10.0.100.68                            0 65515 i
*> 10.1.34.0/25     10.0.100.68                            0 65515 12076 65020 i

Total number of prefixes 2
nva# show ip bgp neighbors 10.0.100.68 advertised-routes
BGP table version is 3, local router ID is 10.0.100.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.50.0/24     0.0.0.0                  0         32768 i
*> 10.0.100.0/24    0.0.0.0                                0 65515 i
*> 10.1.34.0/25     0.0.0.0                                0 65515 12076 65020 i

Total number of prefixes 3
```

<br>

Routing table in ExpressRoute Gateway:
```powershell
$bgpPeerStatus = Get-AzVirtualNetworkGatewayBGPPeerStatus -VirtualNetworkGatewayName ergw -ResourceGroupName test-er-rs-03 

$bgpPeerStatus[0].Neighbor
10.0.100.196

$bgpPeerStatus[1].Neighbor
10.0.100.197

get-AzVirtualNetworkGatewayAdvertisedRoute -VirtualNetworkGatewayName ergw -ResourceGroupName test-er-rs-03 -peer $bgpPeerStatus[0].Neighbor | ft

LocalAddress Network       NextHop      SourcePeer Origin AsPath      Weight
------------ -------       -------      ---------- ------ ------      ------
10.0.100.205 10.0.100.0/24 10.0.100.205            Igp    65515       0
10.0.100.205 10.0.50.0/24  10.0.100.205            Igp    65515-65001 0
```

Routing table in ExpressRoute circuit:
```powershell
C:\> Get-AzExpressRouteCircuitRouteTable -ResourceGroupName SEA-Cust34 -ExpressRouteCircuitName SEA-Cust34-ER -PeeringType AzurePrivatePeering -DevicePath Primary | ft

Network       NextHop       LocPrf Weight Path
-------       -------       ------ ------ ----
10.0.50.0/24  10.0.100.204         0      65515 65001
10.0.50.0/24  10.0.100.205*        0      65515 65001
10.0.100.0/24 10.0.100.204         0      65515
10.0.100.0/24 10.0.100.205*        0      65515
10.1.34.0/25  192.168.34.17        0      65020
```

## <a name="summary"></a>3. Transit verification in nva
To track the transit through  **nva**:
- in on-premises client runs by curl an HTTP request to the **vm-spoke1Subnet1Running** 
- in  **nva** to capture the traffic between on-premises client and **vm-spoke1Subnet1** by tcpdump:

```console
root@nva:~# tcpdump -nq net 10.1.34.0/25 or net 10.0.50.0/24
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
17:50:14.553875 IP 10.1.34.10.35822 > 10.0.50.10.80: tcp 0
17:50:14.553942 IP 10.0.100.10 > 10.1.34.10: ICMP redirect 10.0.50.10 to host 10.0.100.1, length 68
17:50:14.553954 IP 10.1.34.10.35822 > 10.0.50.10.80: tcp 0
17:50:14.555736 IP 10.0.50.10.80 > 10.1.34.10.35822: tcp 0
17:50:14.555749 IP 10.0.100.10 > 10.0.50.10: ICMP redirect 10.1.34.10 to host 10.0.100.1, length 68
17:50:14.555751 IP 10.0.50.10.80 > 10.1.34.10.35822: tcp 0
17:50:14.702390 IP 10.1.34.10.35822 > 10.0.50.10.80: tcp 0
17:50:14.702390 IP 10.1.34.10.35822 > 10.0.50.10.80: tcp 74
17:50:14.702427 IP 10.1.34.10.35822 > 10.0.50.10.80: tcp 0
17:50:14.702438 IP 10.1.34.10.35822 > 10.0.50.10.80: tcp 74
17:50:14.703259 IP 10.0.50.10.80 > 10.1.34.10.35822: tcp 0
17:50:14.703259 IP 10.0.50.10.80 > 10.1.34.10.35822: tcp 311
17:50:14.703263 IP 10.0.50.10.80 > 10.1.34.10.35822: tcp 0
17:50:14.703265 IP 10.0.50.10.80 > 10.1.34.10.35822: tcp 311
17:50:14.851031 IP 10.1.34.10.35822 > 10.0.50.10.80: tcp 0
17:50:14.851031 IP 10.1.34.10.35822 > 10.0.50.10.80: tcp 0
17:50:14.851068 IP 10.1.34.10.35822 > 10.0.50.10.80: tcp 0
17:50:14.851077 IP 10.1.34.10.35822 > 10.0.50.10.80: tcp 0
17:50:14.856547 IP 10.0.50.10.80 > 10.1.34.10.35822: tcp 0
17:50:14.856571 IP 10.0.50.10.80 > 10.1.34.10.35822: tcp 0
17:50:15.002856 IP 10.1.34.10.35822 > 10.0.50.10.80: tcp 0
17:50:15.002900 IP 10.0.100.10 > 10.1.34.10: ICMP redirect 10.0.50.10 to host 10.0.100.1, length 60
17:50:15.002905 IP 10.1.34.10.35822 > 10.0.50.10.80: tcp 0
```
The tcpdump capture shows a symmetric transit through the **nva**.

<br>

To track the transit through  **nva**:
- in on-premises client runs by curl an HTTP request to the **vm-hubSubnet2** 
- in  **nva** to capture the traffic between on-premises client and **vm-hubSubnet2** by tcpdump:
```
root@nva:~# tcpdump -nq net 10.1.34.0/25 or net 10.0.100.32/27
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
18:35:41.236577 IP 10.1.34.10.44112 > 10.0.100.50.80: tcp 0
18:35:41.236621 IP 10.0.100.10 > 10.1.34.10: ICMP redirect 10.0.100.50 to host 10.0.100.1, length 68
18:35:41.236626 IP 10.1.34.10.44112 > 10.0.100.50.80: tcp 0
18:35:41.237495 IP 10.0.100.50.80 > 10.1.34.10.44112: tcp 0
18:35:41.237506 IP 10.0.100.10 > 10.0.100.50: ICMP redirect 10.1.34.10 to host 10.0.100.1, length 68
18:35:41.237508 IP 10.0.100.50.80 > 10.1.34.10.44112: tcp 0
18:35:41.384470 IP 10.1.34.10.44112 > 10.0.100.50.80: tcp 0
18:35:41.384470 IP 10.1.34.10.44112 > 10.0.100.50.80: tcp 75
18:35:41.384531 IP 10.0.100.10 > 10.1.34.10: ICMP redirect 10.0.100.50 to host 10.0.100.1, length 60
18:35:41.384540 IP 10.1.34.10.44112 > 10.0.100.50.80: tcp 0
18:35:41.384544 IP 10.1.34.10.44112 > 10.0.100.50.80: tcp 75
18:35:41.386140 IP 10.0.100.50.80 > 10.1.34.10.44112: tcp 0
18:35:41.386157 IP 10.0.100.10 > 10.0.100.50: ICMP redirect 10.1.34.10 to host 10.0.100.1, length 60
18:35:41.386161 IP 10.0.100.50.80 > 10.1.34.10.44112: tcp 0
18:35:41.387792 IP 10.0.100.50.80 > 10.1.34.10.44112: tcp 308
18:35:41.387815 IP 10.0.100.50.80 > 10.1.34.10.44112: tcp 308
18:35:41.534755 IP 10.1.34.10.44112 > 10.0.100.50.80: tcp 0
18:35:41.534755 IP 10.1.34.10.44112 > 10.0.100.50.80: tcp 0
18:35:41.534783 IP 10.0.100.10 > 10.1.34.10: ICMP redirect 10.0.100.50 to host 10.0.100.1, length 60
18:35:41.534787 IP 10.1.34.10.44112 > 10.0.100.50.80: tcp 0
18:35:41.534789 IP 10.1.34.10.44112 > 10.0.100.50.80: tcp 0
18:35:41.535374 IP 10.0.100.50.80 > 10.1.34.10.44112: tcp 0
18:35:41.535388 IP 10.0.100.10 > 10.0.100.50: ICMP redirect 10.1.34.10 to host 10.0.100.1, length 60
18:35:41.535390 IP 10.0.100.50.80 > 10.1.34.10.44112: tcp 0
18:35:41.681887 IP 10.1.34.10.44112 > 10.0.100.50.80: tcp 0
18:35:41.681911 IP 10.1.34.10.44112 > 10.0.100.50.80: tcp 0
```
The tcpdump capture shows a symmetric transit through the **nva**. 

## <a name="Estimated deployment time"></a>4. Estimated deployment time

- **01-vnet-rs-er.json**: ~ 30 minutes
- **02-vms.json**: ~ 5 minutes


`Tags: hub-spoke vnet, Route Server, ExpressRoute` <br>
`date: 25-08-23`

<!--Image References-->
[1]: ./media/network-diagram01.png "high level network diagram"
[2]: ./media/network-diagram02.png "network diagram with vnet peering properties"
[3]: ./media/network-diagram03.png "full network diagram"
[4]: ./media/network-diagram04.png "data paths with thransit through the nva"
<!--Link References-->

