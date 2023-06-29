<properties
pageTitle= 'Hub-spoke vnets with Azure firewalls and Route Servers'
description= "Hub-spoke vnets with Azure firewalls and Route Servers"
documentationcenter: na
services=""
documentationCenter="github"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="howto-Azure-examples"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="Azure vnet peering, Azure firewall and Azure Route Server"
   ms.date="18/07/2022"
   ms.review=""
   ms.author="fabferri" />

# Hub-spoke vnets with Azure firewalls and Route Servers
The article describes a scenario with hub-spoke vnets in peering. The network diagram is reported below:

[![1]][1]

Only two spoke vnets are in peering with each hub; the logic remains the same increasing the number of spoke vnets. <br>

A network diagram with more details, is shown the follogin diagram:

[![2]][2]

The configuration aims to make intercommunication any-to-any with traffic in transit through the Azure firewalls. 
* all the UDRs applied to the subnets in the spoke vnets have BGP propagation disabled and only the default route 0.0.0.0/0, pointing to the private IP address of the local Azure firewall
* the Azure firewall subnets have a UDR to guarantee that traffic with destination of remote spoke is sent through the vnet peering
* vnet peering between hub and spokes are created without Remote Gateway transit; the networks of spoke vnets are advertised on-premises through the NVAs
* To keep the deployment simple, the firewall policies have two network security rules: 
   * a rule connection with allow traffic from source address 10.0.0.0/8 to the destination network 10.0.0.0/8
   * a rule connection to allow traffic from spoke vnets and hub vnet to internet

Below a network diagram with communication paths

[![3]][3]

Below a summary of data paths:
```
spoke1 <--> azfw1 <--> spoke2
spoke1 <--> azfw1 <--> azfw2 <--> spoke3
spoke1 <--> azfw1 <--> azfw2 <--> spoke4
spoke1 <--> azfw1 <--> ER GTW1 <--> ER circuit <--> on-premises
spoke2 <--> azfw1 <--> spoke1
spoke2 <--> azfw1 <--> azfw2 <--> spoke3
spoke2 <--> azfw1 <--> azfw2 <--> spoke4
spoke2 <--> azfw1 <--> ER GTW2 <--> ER circuit <--> on-premises
spoke1 <--> vmhub1 
spoke2 <--> vmhub1
spoke3 <--> vmhub2
spoke4 <--> vmhub2
vmhub1 <--> vmhub2
vmhub1 <--> ER GTW1 <--> ER circuit <--> on-premises
vmhub2 <--> ER GTW2 <--> ER circuit <--> on-premises
bastion1 <--> spoke1
bastion1 <--> spoke2
bastion2 <--> spoke3
bastion2 <--> spoke4

```

Some routing considerations:
- Each NVA is in BGP peering with Route Server and advertises the networks of the spoke vnets to the route server. In the BGP advertisements, it is specified as next-hop the IP address of the Azure firewall:

**nva1** advertises:
```console
10.0.1.0/24 next-hop IP address: 10.11.0.4
10.0.2.0/24 next-hop IP address: 10.11.0.4
```

**nva2** advertises:
```console
10.0.3.0/24 next-hop IP address: 10.12.0.4
10.0.4.0/24 next-hop IP address: 10.12.0.4
```

- The route server advertises the received networks of the spoke vnets to the ExpressRoute Gateway. 
- a UDR applied to the GatewaySubnet routes the IP traffic from on-premises network, with destination a spoke vnets, to the local Azure firewall.


### <a name="list of files"></a>1. Project files

| File name              | Description                                                                                              |
| ---------------------- | -------------------------------------------------------------------------------------------------------- |
| **init.json**          | define the value of input variables required for the full deployment                                     |
| **01-azfw.json**       | ARM template to deploy spoke vnets, hub vnets,Azure firewalls, Azure bastions, vnet peering, UDRs        |
| **01-azfw.ps1**        | powershell script to deploy **01-azfw.json**                                                             |
| **cloud-init-nva1.txt**| cloud-init file to setup FRR and BGP in nva1. <br> **cloud-init-nva1.txt** is used in **02-rs.json**     |
| **cloud-init-nva2.txt**| cloud-init file to setup FRR and BGP in nva2. <br> **cloud-init-nva2.txt** is used in **02-rs.json**     |
| **02-rs.json**         | ARM template to deploy the route servers, rs1 and rs2, and create the BGP peering **rs1<->nva1**, **rs2<->nva2** |
| **02-rs.ps1**          | powershell to script to run **02-rs.json**                                                               | 
| **03-fw-logs.json**    | ARM template to create log analytics workspace and activate the diagnostic setting logs for Azure firewalls **azfw1**, **azfw2**|
| **03-fw-logs.ps1**     | powershell script to deploy **03-fw-logs.json** |

To run the project, follow the steps in sequence:
1. change/modify the value of input variables in the file **init.json**
2. run the powershell script **01-azfw.ps1**
3. run the powershell script **02-rs.ps1** 
4. run the powershell script **03-fw-logs.ps1** 

The meaning of input variables in **init.json** are explained below:
```json
{
    "subscriptionName": "NAME_OF_AZURE_SUBSCRIPTION",
    "ResourceGroupName": "NAME_OF_RESOURCE_GROUP",
    "locationhub1": "AZURE_LOCATION_hub1_VNET",
    "locationspoke1": "AZURE_LOCATION_spoke1_VNET",
    "locationspoke2": "AZURE_LOCATION_spoke2_VNET",
    "locationhub2": "AZURE_LOCATION_hub2_VNET",
    "locationspoke3": "AZURE_LOCATION_spoke3_VNET",
    "locationspoke4": "AZURE_LOCATION_spoke4_VNET",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "authenticationType": "password",
    "adminPasswordOrKey": "ADMINISTRATOR_PASSWORD",
    "er_subscriptionId1": "AZURE_SUBSCRIPTION_ID_WHERE_IS_DEPLOYED_THE_EXPRESSROUTE_CIRCUIT_1",
    "er_resourceGroup1": "RESOUCE_GROUP_NAME_WHERE_IS_DEPLOYED_THE_EXPRESSROUTE_CIRCUIT_1",
    "er_circuitName1": "NAME_OF_EXPRESSROUTE_CIRCUIT_1",
    "er_authorizationKey1": "AUTHORIZATION_KEY_TO_JOIN_TO_THE_EXPRESSROUTE_CIRCUIT_1",
    "er_subscriptionId2": "AZURE_SUBSCRIPTION_ID_WHERE_IS_DEPLOYED_THE_EXPRESSROUTE_CIRCUIT_2",
    "er_resourceGroup2": "RESOUCE_GROUP_NAME_WHERE_IS_DEPLOYED_THE_EXPRESSROUTE_CIRCUIT_2",
    "er_circuitName2": "NAME_OF_EXPRESSROUTE_CIRCUIT_2",
    "er_authorizationKey2": "AUTHORIZATION_KEY_TO_JOIN_TO_THE_EXPRESSROUTE_CIRCUIT_2"
}
```
## <a name="NVA"></a>2. FRR in NVA

The installation of **FRR** (Free Range Routing) in the NVA is automatically executed by ARM template, through cloud-init (files: **cloud-init-nva1.txt**, **cloud-init-nva2.txt**)
FRR requires the configuration of **Inbound** and **Outbound** path policies, in order FRR will accept and send inbound and outbound BGP updates. This is visualized by the command:

```console
show ip bgp neighbor
...
  Inbound updates discarded due to missing policy
  Outbound updates discarded due to missing policy
...
```

Some useful FRR commands to run in **vtysh** shell:
* show ip bgp
* show bgp summary
* show bgp nexthop




## <a name="Azure firewall"></a>3. Azure firewall
By default, AzureFirewallSubnet has a 0.0.0.0/0 route with the NextHopType value set to Internet.

Azure Firewall must have direct Internet connectivity. If your AzureFirewallSubnet learns a default route to your on-premises network via BGP, or you associate a UDR to the AzureFirewallSubnet, you must override that with a 0.0.0.0/0 UDR with the NextHopType value set as Internet to maintain direct Internet connectivity. 
By default, Azure Firewall doesn't support forced tunnelling to an on-premises network.

The Network Rule Collection in firewall policy doesn't use IP Groups, but the major private network 10.0.0.0/8 as source and destination. The easy approach is doable in test environment, but the security policy should be reviewed in production environment with better customization. 

## <a name="Logs"></a>4. Logs

### **vmspoke1** effective routes
| Source  | State   | Address Prefixes | Next Hop Type     | Next Hop IP Address | User Defined Route Name |
| ------- | ------- | ---------------- | ----------------- | ------------------- | ----------------------- |
| Default | Active  | 10.0.1.0/24      | Virtual network   |                     | |
| Default | Active  | 10.11.0.0/23     | VNet peering      |                     | |
| Default | Invalid | 0.0.0.0/0        | Internet          |                     | |
| User    | Active  | 0.0.0.0/0        | Virtual appliance | 10.11.0.4           | defaultRoute-to-azfw    |

### **vmspoke3** effective routes
| Source  | State   | Address Prefixes | Next Hop Type     | Next Hop IP Address | User Defined Route Name |
| ------- | ------- | ---------------- | ----------------- | ------------------- | ----------------------- |
| Default | Active  | 10.0.3.0/24      | Virtual network   |                     | |
| Default | Active  | 10.12.0.0/23     | VNet peering      |                     | |
| Default | Invalid | 0.0.0.0/0        | Internet          |                     | |
| User    | Active  | 0.0.0.0/0        | Virtual appliance | 10.12.0.4           | defaultRoute-to-azfw    |

### **vmhub1** effective routes
| Source  | State   | Address Prefixes | Next Hop Type     | Next Hop IP Address | User Defined Route Name |
| ------- | ------- | ---------------- | ----------------- | ------------------- | ----------------------- |
| Default | Active  | 10.11.0.0/23     | Virtual network   |                     | |
| Default | Active  | 10.0.1.0/24      | Virtual network   |                     | |
| Default | Active  | 10.0.2.0/24      | Virtual network   |                     | |
| Default | Active  | 10.12.0.0/23     |Virtual network gateway   |              | |
| Default | Invalid | 0.0.0.0/0        | Internet          |                     | |
| User    | Active  | 0.0.0.0/0        | Virtual appliance | 10.11.0.4           | defaultRoute-to-azfw    |

[![4]][4]

### ExpressRoute Gateway 

```powershell
$bgpPeerStatus = Get-AzVirtualNetworkGatewayBGPPeerStatus -VirtualNetworkGatewayName $gwName -ResourceGroupName $rgName
$bgpPeerStatus[0].Neighbor
$bgpPeerStatus[1].Neighbor
Get-AzVirtualNetworkGatewayAdvertisedRoute -VirtualNetworkGatewayName $gwName -ResourceGroupName $rgName -Peer $bgpPeerStatus[0].Neighbor
```

```powershell
Get-AzVirtualNetworkGatewayAdvertisedRoute -VirtualNetworkGatewayName gw1 -ResourceGroupName $rgName -peer 10.11.1.228 | ft

LocalAddress Network      NextHop     SourcePeer Origin AsPath      Weight
------------ -------      -------     ---------- ------ ------      ------
10.11.1.236  10.11.0.0/23 10.11.1.236            Igp    65515            0
10.11.1.236  10.0.1.0/24  10.11.1.236            Igp    65515-65001      0
10.11.1.236  10.0.2.0/24  10.11.1.236            Igp    65515-65001      0

Get-AzVirtualNetworkGatewayAdvertisedRoute -VirtualNetworkGatewayName gw2 -ResourceGroupName $rgName -Peer 10.12.1.228 | ft

LocalAddress Network      NextHop     SourcePeer Origin AsPath      Weight
------------ -------      -------     ---------- ------ ------      ------
10.12.1.237  10.12.0.0/23 10.12.1.237            Igp    65515            0
10.12.1.237  10.0.3.0/24  10.12.1.237            Igp    65515-65002      0
10.12.1.237  10.0.4.0/24  10.12.1.237            Igp    65515-65002      0

Get-AzVirtualNetworkGatewayLearnedRoute -VirtualNetworkGatewayName gw1 -ResourceGroupName $rgName  | ft

LocalAddress Network      NextHop     SourcePeer  Origin  AsPath      Weight
------------ -------      -------     ----------  ------  ------      ------
10.11.1.236  10.11.0.0/23             10.11.1.236 Network              32768
10.11.1.236  10.0.1.0/24  10.11.0.4   10.11.1.5   IBgp    65001        32768
10.11.1.236  10.0.1.0/24  10.11.0.4   10.11.1.4   IBgp    65001        32768
10.11.1.236  10.0.2.0/24  10.11.0.4   10.11.1.5   IBgp    65001        32768
10.11.1.236  10.0.2.0/24  10.11.0.4   10.11.1.4   IBgp    65001        32768
10.11.1.236  10.1.34.0/25 10.11.1.229 10.11.1.229 EBgp    12076-65020  32769
10.11.1.236  10.1.34.0/25 10.11.1.228 10.11.1.228 EBgp    12076-65020  32769
10.11.1.236  10.12.0.0/23 10.11.1.228 10.11.1.228 EBgp    12076-12076  32769
10.11.1.236  10.12.0.0/23 10.11.1.229 10.11.1.229 EBgp    12076-12076  32769
10.11.1.236  10.1.34.0/25 10.11.1.229 10.11.1.4   IBgp    12076-65020  32768
10.11.1.236  10.1.34.0/25 10.11.1.229 10.11.1.5   IBgp    12076-65020  32768

Get-AzVirtualNetworkGatewayLearnedRoute -VirtualNetworkGatewayName gw2 -ResourceGroupName $rgName  | ft

LocalAddress Network      NextHop     SourcePeer  Origin  AsPath      Weight
------------ -------      -------     ----------  ------  ------      ------
10.12.1.237  10.12.0.0/23             10.12.1.237 Network              32768
10.12.1.237  10.0.3.0/24  10.12.0.4   10.12.1.4   IBgp    65002        32768
10.12.1.237  10.0.3.0/24  10.12.0.4   10.12.1.5   IBgp    65002        32768
10.12.1.237  10.0.4.0/24  10.12.0.4   10.12.1.4   IBgp    65002        32768
10.12.1.237  10.0.4.0/24  10.12.0.4   10.12.1.5   IBgp    65002        32768
10.12.1.237  10.11.0.0/23 10.12.1.228 10.12.1.228 EBgp    12076-12076  32769
10.12.1.237  10.11.0.0/23 10.12.1.229 10.12.1.229 EBgp    12076-12076  32769
10.12.1.237  10.1.34.0/25 10.12.1.228 10.12.1.228 EBgp    12076-65020  32769
10.12.1.237  10.1.34.0/25 10.12.1.229 10.12.1.229 EBgp    12076-65020  32769
10.12.1.237  10.11.0.0/23 10.12.1.229 10.12.1.4   IBgp    12076-12076  32768
10.12.1.237  10.1.34.0/25 10.12.1.229 10.12.1.4   IBgp    12076-65020  32768
10.12.1.237  10.1.34.0/25 10.12.1.229 10.12.1.5   IBgp    12076-65020  32768
```
- address space of the spoke1 10.0.1.0/24 is reachable across the next-hop IP: 10.11.0.4 (azfw1)
- address space of the spoke2 10.0.2.0/24 is reachable across the next-hop IP: 10.11.0.4 (azfw1)
- address space of the spoke1 10.0.3.0/24 is reachable across the next-hop IP: 10.12.0.4 (azfw2)
- address space of the spoke2 10.0.4.0/24 is reachable across the next-hop IP: 10.12.0.4 (azfw2)

### Route Server

```powershell
Get-AzRouteServerPeerLearnedRoute -ResourceGroupName $rgName -RouteServerName rs1 -PeerName $bgpPeerName |ft

LocalAddress Network     NextHop   SourcePeer Origin AsPath Weight
------------ -------     -------   ---------- ------ ------ ------
10.11.1.5    10.0.1.0/24 10.11.0.4 10.11.1.50 EBgp   65001   32768
10.11.1.5    10.0.2.0/24 10.11.0.4 10.11.1.50 EBgp   65001   32768
10.11.1.4    10.0.1.0/24 10.11.0.4 10.11.1.50 EBgp   65001   32768
10.11.1.4    10.0.2.0/24 10.11.0.4 10.11.1.50 EBgp   65001   32768

Get-AzRouteServerPeerAdvertisedRoute -ResourceGroupName $rgName -RouteServerName rs1 -PeerName $bgpPeerName |ft

LocalAddress Network      NextHop   SourcePeer Origin AsPath            Weight
------------ -------      -------   ---------- ------ ------            ------
10.11.1.5    10.11.0.0/23 10.11.1.5            Igp    65515                  0
10.11.1.5    10.1.34.0/25 10.11.1.5            Igp    65515-12076-65020      0
10.11.1.5    10.12.0.0/23 10.11.1.5            Igp    65515-12076-12076      0
10.11.1.4    10.11.0.0/23 10.11.1.4            Igp    65515                  0
10.11.1.4    10.1.34.0/25 10.11.1.4            Igp    65515-12076-65020      0
10.11.1.4    10.12.0.0/23 10.11.1.4            Igp    65515-12076-12076      0
```
10.0.1.0/24: address space of the spoke1 <br>
10.0.2.0/24: address space of the spoke2 <br>
10.0.3.0/24: address space of the spoke3 <br>
10.0.4.0/24: address space of the spoke4 <br>
10.11.0.0/23: address space hub1 <br>
10.12.0.0/23: address space hub2 <br>
10.1.34.0/25: on-premises network advertised from edge routers with ASN 65021 <br>

### BGP routing in NVA
```console
nva1# show ip bgp
BGP table version is 7, local router ID is 10.11.1.50, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.1.0/24      0.0.0.0                  0         32768 i
*> 10.0.2.0/24      0.0.0.0                  0         32768 i
*= 10.1.34.0/25     10.11.1.5                              0 65515 12076 65020 i
*>                  10.11.1.4                              0 65515 12076 65020 i
*= 10.11.0.0/23     10.11.1.4                              0 65515 i
*>                  10.11.1.5                              0 65515 i
*= 10.12.0.0/23     10.11.1.5                              0 65515 12076 12076 i
*>                  10.11.1.4                              0 65515 12076 12076 i

nva2# show ip bgp
BGP table version is 8, local router ID is 10.12.1.50, vrf id 0
Default local pref 100, local AS 65002
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.3.0/24      0.0.0.0                  0         32768 i
*> 10.0.4.0/24      0.0.0.0                  0         32768 i
*= 10.1.34.0/25     10.12.1.5                              0 65515 12076 65020 i
*>                  10.12.1.4                              0 65515 12076 65020 i
*= 10.11.0.0/23     10.12.1.5                              0 65515 12076 12076 i
*>                  10.12.1.4                              0 65515 12076 12076 i
*= 10.12.0.0/23     10.12.1.5                              0 65515 i
*>                  10.12.1.4                              0 65515 i

Displayed  5 routes and 8 total paths

```
### BGP routing in ExpressRoute circuit private peering
```powershell
Get-AzExpressRouteCircuitRouteTable -ResourceGroupName $rgName -ExpressRouteCircuitName $erCircuitName -PeeringType 'AzurePrivatePeering' -DevicePath 'Primary'
```

```powershell
Get-AzExpressRouteCircuitRouteTable -ResourceGroupName SEA-Cust34 -ExpressRouteCircuitName SEA-Cust34-ER -PeeringType AzurePrivatePeering -Device Primary |ft

Network      NextHop       LocPrf Weight Path
-------      -------       ------ ------ ----
10.0.1.0/24  10.11.1.237               0 65515 65001
10.0.1.0/24  10.11.1.236*              0 65515 65001
10.0.2.0/24  10.11.1.237               0 65515 65001
10.0.2.0/24  10.11.1.236*              0 65515 65001
10.0.3.0/24  10.12.1.237               0 65515 65002
10.0.3.0/24  10.12.1.236*              0 65515 65002
10.0.4.0/24  10.12.1.237               0 65515 65002
10.0.4.0/24  10.12.1.236*              0 65515 65002
10.1.34.0/25 192.168.34.17             0 65020
10.11.0.0/23 10.11.1.237               0 65515
10.11.0.0/23 10.11.1.236*              0 65515
10.12.0.0/23 10.12.1.237               0 65515
10.12.0.0/23 10.12.1.236*              0 65515 
```

### Generate HTTP traffic betwen VMs
On each VM is installed by custom script extension nginx with a simple web page; using curl you can generate HTTP requests between VMs:

```bash
for i in `seq 1 2000`; do curl http://10.0.2.10; done
for i in `seq 1 2000`; do curl http://10.0.3.10; done
for i in `seq 1 2000`; do curl http://10.0.4.10; done
for i in `seq 1 2000`; do curl http://10.1.34.10; done
```

After few minutes, you can browse in Azure firewall logs, in log analytics workspace to see the traffic through the Azure firewalls.
The overall Azure Firewall log query in Log Analytics:
```console
AzureDiagnostics
| where Category == "AzureFirewallNetworkRule" or Category == "AzureFirewallApplicationRule"
```

Specifying the name of the firewall, i.e. AZFW2:
```
AzureDiagnostics 
| where Category == "AzureFirewallNetworkRule" and Resource == "AZFW2"
```

`Tags: route server, hub-spoke vnets` <br>
`date: 27-06-23`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/network-diagram-details.png "network diagram with details"
[3]: ./media/datapaths.png "data flows transit"
[4]: ./media/effective-routes.png "effective routes"


<!--Link References-->

