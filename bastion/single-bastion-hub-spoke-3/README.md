<properties
pageTitle= 'Hub-spoke vnets with Azure Bastion in one hub vnet'
description= "Hub-spoke vnets with Azure Bastion in one hub vnet"
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
   ms.workload="Azure vnet peering, Azure Bastion"
   ms.date="24/07/2022"
   ms.review=""
   ms.author="fabferri" />

# Hub-spoke vnets with Azure Bastion in one hub vnet
The article describes a scenario with hub-spoke vnets in peering, with Azure Bastion deployed only in one hub vnet. The network diagram is reported below:

[![1]][1]

The configuration aims to use a single Azure Bastion in hub1 to manage all the VMs in the local hub-spoke vnets, as well as in the remote hub-spoke vnets. Let's briefly discuss the configuration:
- the configuration does not use UDRs; routing is automatically established through the nva2, route server1 (rs1) and route server2 (rs2)
- in nva2 is enabled the IP forwarding (in the NIC and in the OS). Through cloud-init file (**cloud-init-nva2.txt**) at VM bootstrap, in nva2 is installed and configured FRR (Free Range Routing). FRR in nva2 establishes two eBGP sessions with the route server **rs1** in hub1 and two eBGP sessions with the route server **rs2** in hub2 vnet.   
-the pering with spoke vnets are created with the following setting:
   - in the hub vnets hub1 and hub2:     <br>
      "allowVirtualNetworkAccess": true, <br>
      "allowForwardedTraffic": true,     <br>
      **"allowGatewayTransit": true,**   <br>
      **"useRemoteGateways": false,**    <br>
   - in the spoke vnets spoke1, spoke2, spoke3, spoke4:
      "allowVirtualNetworkAccess": true, <br>
      "allowForwardedTraffic": true,     <br>
      **"allowGatewayTransit": false,**  <br>
      **"useRemoteGateways": true,**     <br>
- the Azure Bastion has to be deployed with **Standard** SKU; the properties of Azure Bastion are configured as:<br>
   "disableCopyPaste": false,            <br>
   "enableFileCopy": true,               <br>
   **"enableIpConnect": true,**          <br>
   "enableShareableLink": false,         <br>
   "enableTunneling": true,              <br>
The property **enableIpConnect** is required to connect via Bastion to the VMs via private IP address;
- Azure Bastion can reach out the remote spoke3 and spoke4 vnets through the vnet peering between hub1 and hub2. 
- the configuration allows to the bastion in hub1 to manage all the VMs; the configuration does not create routing between spoke vnets in different hubs (all the spokes vnets do not communicates each other)


## <a name="list of files"></a>2. Project files

| File name                 | Description                                                                       |
| ------------------------- | --------------------------------------------------------------------------------- |
| **init.json**             | define the value of input variables required for the full deployment              |
| **01-vnets.json**         | ARM template to deploy spoke vnets, hub vnets, Azure bastions, route server, VMs  |
| **01-vnets.ps1**          | powershell script to run **01-vnets.json**                                        |
| **cloud-init-nva2.txt**   | cloud-init file to install and configure FRR in nva2                              |
| **nva2-config.txt**       | FRR configuration applied to nva2                                                 |

To run the project, follow the steps in sequence:
1. change/modify the value of input variables in the file **init.json**
2. run the powershell script **01-vnets.ps1**; at the end of execution the two hub-spoke will be created, with the VMs
3. connect to nva2 through Bastion and use the vtysh shell to verify the BGP peering between nva2 and the route servers **rs1** and **rs2**


The meaning of input variables in **init.json** are shown below:
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
    "locationvnet1": "AZURE_LOCATION_vnet1",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "authenticationType": "password",
    "adminPasswordOrKey": "ADMINISTRATOR_PASSWORD",
    "mngIP": "PUBLIC_IP_ADDRESS_TO_FILTER_SSH_ACCESS_TO_VMS - it can be empty string, if you do not want to filter access!"
}
```

The ARM template uses the customer script extension to install ngix and setup a simple homepage.

## <a name="IP routing"></a>2. IP routing
The ARM template uses cloud-init to setup ip forwarding, install and configure FRR (Free Range Routing) to create a BGP peering with the route server **rs1** in the hub1 and BGP peering with the route server **rs2** in the hub2:

[![2]][2]

The route server in hub1 learns the address space of the spoke3 (10.0.3.0/24) and spoke4 (10.0.4.0/24) vnets:

```powershell
Get-AzRouteServerPeerlearnedRoute -RouteServerName rs1 -ResourceGroupName $rgName -peername $peerName |ft

LocalAddress Network     NextHop   SourcePeer Origin AsPath      Weight
------------ -------     -------   ---------- ------ ------      ------
10.1.0.5     10.0.1.0/24 10.2.0.10 10.2.0.10  EBgp   65001-65001  32768
10.1.0.5     10.2.0.0/24 10.2.0.10 10.2.0.10  EBgp   65001-65001  32768
10.1.0.5     10.1.0.0/24 10.2.0.10 10.2.0.10  EBgp   65001-65001  32768
10.1.0.5     10.0.4.0/24 10.2.0.10 10.2.0.10  EBgp   65001-65001  32768
10.1.0.5     10.0.3.0/24 10.2.0.10 10.2.0.10  EBgp   65001-65001  32768
10.1.0.5     10.0.2.0/24 10.2.0.10 10.2.0.10  EBgp   65001-65001  32768
10.1.0.4     10.0.1.0/24 10.2.0.10 10.2.0.10  EBgp   65001-65001  32768
10.1.0.4     10.2.0.0/24 10.2.0.10 10.2.0.10  EBgp   65001-65001  32768
10.1.0.4     10.1.0.0/24 10.2.0.10 10.2.0.10  EBgp   65001-65001  32768
10.1.0.4     10.0.4.0/24 10.2.0.10 10.2.0.10  EBgp   65001-65001  32768
10.1.0.4     10.0.3.0/24 10.2.0.10 10.2.0.10  EBgp   65001-65001  32768
10.1.0.4     10.0.2.0/24 10.2.0.10 10.2.0.10  EBgp   65001-65001  32768
```

The route server in hub1 advertises to the nva2 the address space of the hub1 (10.1.0.0/24):

```powershell
Get-AzRouteServerPeerAdvertisedRoute -RouteServerName rs1 -ResourceGroupName $rgName -peername $peerName |ft

LocalAddress Network     NextHop  SourcePeer Origin AsPath Weight
------------ -------     -------  ---------- ------ ------ ------
10.1.0.5     10.1.0.0/24 10.1.0.5            Igp    65515       0
10.1.0.5     10.0.1.0/24 10.1.0.5            Igp    65515       0
10.1.0.5     10.0.2.0/24 10.1.0.5            Igp    65515       0
10.1.0.4     10.1.0.0/24 10.1.0.4            Igp    65515       0
10.1.0.4     10.0.1.0/24 10.1.0.4            Igp    65515       0
10.1.0.4     10.0.2.0/24 10.1.0.4            Igp    65515       0
````

The local address [10.1.0.4, 10.1.0.5] are the internal IPs of the router server. The address space of hub1 10.1.0.0/24 is advertised to the nva2 and set as next-hop the route server IPs.

The route server **rs2** learns :
```powershell
Get-AzRouteServerPeerlearnedRoute -RouteServerName rs2 -ResourceGroupName $rgName -peername $peerName |ft

LocalAddress Network     NextHop    SourcePeer Origin AsPath Weight
------------ -------     -------    ---------- ------ ------ ------
10.2.0.133   10.2.0.0/24 10.2.0.133            Igp    65515       0
10.2.0.133   10.0.4.0/24 10.2.0.133            Igp    65515       0
10.2.0.133   10.0.3.0/24 10.2.0.133            Igp    65515       0
10.2.0.132   10.2.0.0/24 10.2.0.132            Igp    65515       0
10.2.0.132   10.0.4.0/24 10.2.0.132            Igp    65515       0
10.2.0.132   10.0.3.0/24 10.2.0.132            Igp    65515       0

Get-AzRouteServerPeerAdvertisedRoute -RouteServerName rs2 -ResourceGroupName $rgName -peername $peerName |ft
LocalAddress Network     NextHop    SourcePeer Origin AsPath Weight
------------ -------     -------    ---------- ------ ------ ------
10.2.0.133   10.2.0.0/24 10.2.0.133            Igp    65515       0
10.2.0.133   10.0.4.0/24 10.2.0.133            Igp    65515       0
10.2.0.133   10.0.3.0/24 10.2.0.133            Igp    65515       0
10.2.0.132   10.2.0.0/24 10.2.0.132            Igp    65515       0
10.2.0.132   10.0.4.0/24 10.2.0.132            Igp    65515       0
10.2.0.132   10.0.3.0/24 10.2.0.132            Igp    65515       0
```
The route server rs2 advertises to nva2 the networks 10.2.0.0/24 (hub2), 10.0.3.0/24 (spoke3), 10.0.4.0/24 (spoke4)
Those networks are learnt in rs2 via IGP. 

```console
nva2# show ip bgp
BGP table version is 12, local router ID is 10.2.0.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*= 10.0.1.0/24      10.1.0.5                               0 65515 i
*>                  10.1.0.4                               0 65515 i
*= 10.0.2.0/24      10.1.0.5                               0 65515 i
*>                  10.1.0.4                               0 65515 i
*= 10.0.3.0/24      10.2.0.132                             0 65515 i
*>                  10.2.0.133                             0 65515 i
*= 10.0.4.0/24      10.2.0.132                             0 65515 i
*>                  10.2.0.133                             0 65515 i
*= 10.1.0.0/24      10.1.0.5                               0 65515 i
*>                  10.1.0.4                               0 65515 i
*= 10.2.0.0/24      10.2.0.132                             0 65515 i
*>                  10.2.0.133                             0 65515 i

Displayed  6 routes and 12 total paths
```

Network prefixes advertised to / received from **rs1**: 
```console
nva2# show ip bgp neighbors 10.1.0.4 advertised-routes 
BGP table version is 12, local router ID is 10.2.0.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.1.0/24      0.0.0.0                                0 65001 i
*> 10.0.2.0/24      0.0.0.0                                0 65001 i
*> 10.0.3.0/24      0.0.0.0                                0 65001 i
*> 10.0.4.0/24      0.0.0.0                                0 65001 i
*> 10.1.0.0/24      0.0.0.0                                0 65001 i
*> 10.2.0.0/24      0.0.0.0                                0 65001 i

Total number of prefixes 6

nva2# show ip bgp neighbors 10.1.0.4 received-routes
BGP table version is 12, local router ID is 10.2.0.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.1.0/24      10.1.0.4                               0 65515 i
*> 10.0.2.0/24      10.1.0.4                               0 65515 i
*> 10.1.0.0/24      10.1.0.4                               0 65515 i

Total number of prefixes 3
```

Network prefixes advertised to / received from **rs2**: 
```console
nva2# show ip bgp neighbors 10.2.0.132 advertised-routes 
BGP table version is 12, local router ID is 10.2.0.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.1.0/24      0.0.0.0                                0 65001 i
*> 10.0.2.0/24      0.0.0.0                                0 65001 i
*> 10.0.3.0/24      0.0.0.0                                0 65001 i
*> 10.0.4.0/24      0.0.0.0                                0 65001 i
*> 10.1.0.0/24      0.0.0.0                                0 65001 i
*> 10.2.0.0/24      0.0.0.0                                0 65001 i

Total number of prefixes 6

nva2# show ip bgp neighbors 10.2.0.132 received-routes 
BGP table version is 12, local router ID is 10.2.0.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.3.0/24      10.2.0.132                             0 65515 i
*> 10.0.4.0/24      10.2.0.132                             0 65515 i
*> 10.2.0.0/24      10.2.0.132                             0 65515 i

Total number of prefixes 3
```


The snippet of FRR configuration in nva2 is shown below:
```console
ip route 10.1.0.0/26 10.2.0.1
ip route 10.2.0.128/26 10.2.0.1
!
router bgp 65001
 bgp router-id 10.2.0.10
 neighbor 10.1.0.4 remote-as 65515
 neighbor 10.1.0.4 timers 60 180
 neighbor 10.1.0.5 remote-as 65515
 neighbor 10.1.0.5 timers 60 180
 neighbor 10.2.0.132 remote-as 65515
 neighbor 10.2.0.132 ebgp-multihop 3
 neighbor 10.2.0.132 timers 60 180
 neighbor 10.2.0.133 remote-as 65515
 neighbor 10.2.0.133 ebgp-multihop 3
 neighbor 10.2.0.133 timers 60 180
 !
 address-family ipv4 unicast
  neighbor 10.1.0.4 next-hop-self
  neighbor 10.1.0.4 as-override
  neighbor 10.1.0.4 soft-reconfiguration inbound
  neighbor 10.1.0.4 route-map BGP_IN in
  neighbor 10.1.0.4 route-map BGP_OUT out
  neighbor 10.1.0.5 next-hop-self
  neighbor 10.1.0.5 as-override
  neighbor 10.1.0.5 soft-reconfiguration inbound
  neighbor 10.1.0.5 route-map BGP_IN in
  neighbor 10.1.0.5 route-map BGP_OUT out
  neighbor 10.2.0.132 next-hop-self
  neighbor 10.2.0.132 as-override
  neighbor 10.2.0.132 soft-reconfiguration inbound
  neighbor 10.2.0.132 route-map BGP_IN in
  neighbor 10.2.0.132 route-map BGP_OUT out
  neighbor 10.2.0.133 next-hop-self
  neighbor 10.2.0.133 as-override
  neighbor 10.2.0.133 soft-reconfiguration inbound
  neighbor 10.2.0.133 route-map BGP_IN in
  neighbor 10.2.0.133 route-map BGP_OUT out
 exit-address-family
exit
!
ip prefix-list BGP_IN seq 10 permit 0.0.0.0/0 le 32
ip prefix-list BGP_OUT seq 10 permit 0.0.0.0/0 le 32
!
route-map BGP_IN permit 10
 match ip address prefix-list BGP_IN
exit
!
route-map BGP_OUT permit 10
 match ip address prefix-list BGP_OUT
exit
```
* The static routes: <br>
   **ip route 10.1.0.0/26 10.2.0.1**    <br>
   **ip route 10.2.0.128/26 10.2.0.1**  <br>
   are required to the **nva2** to reach out the private endpoints of rs1 and rs2. The IP address 10.2.0.1 is the default gateway of the nvaSubnet.

* The route-map associated with each peer: <br>
   **route-map BGP_IN in**   <br>
   **route-map BGP_OUT out** <br>
   are required becasue in FRR by default the BGP policy is to discard ingress and egress BGP advertisements. <br>
   In absence of route-map, the command **"show ip bgp neighbor"** shows the output:<br> 
   _Inbound updates discarded due to missing policy_  <br>
   _Outbound updates discarded due to missing policy_ <br>

* Loop prevention in eBGP is done by verifying the AS number in the AS Path. If the receiving router sees its own AS number in the AS Path of the received BGP packet, the packet is dropped. The receiving router assumes that the packet was originated from its own AS and has reached the same place from where it originated initially. The default behaviour can be override by the statement **"neighbor <IP_Addr_Peer> as-override"**. In our case we have the following routing:

[![3]][3]

The effective routing table in **vmspoke3**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.3.0/24      | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.2.0.0/24      | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active | 10.0.1.0/24      | Virtual network gateway | 10.2.0.10           | \-                      |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 10.2.0.10           | \-                      |
| Virtual network gateway | Active | 10.1.0.0/24      | Virtual network gateway | 10.2.0.10           | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |

The effective routing table in spoke3 shows: 
* address space 10.1.0.0/24 of the hub1, 
* the address space 10.0.1.0/24 of the spoke1, 
* the address space 10.0.2.0/24 of the spoke2, 

have all as next-hop the IP address of the nva2.<br> 

The effective routing table in **vmhub1**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.1.0.0/24      | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.0.1.0/24      | VNet peering            | \-                  | \-                      |
| Default                 | Active | 10.0.2.0/24      | VNet peering            | \-                  | \-                      |
| Default                 | Active | 10.2.0.0/24      | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 10.2.0.10           | \-                      |
| Virtual network gateway | Active | 10.0.4.0/24      | Virtual network gateway | 10.2.0.10           | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |

The effective routing table in **vmhub1** says: 
* address space 10.2.0.0/24 of the hub2 is reachable through vnet peering,
* the address space 10.0.3.0/24 of the spoke3 has as next-hop the IP 10.2.0.10 of the nva2, 
* the address space 10.0.4.0/24 of the spoke4 has as next-hop the IP 10.2.0.10 of the nva2.


The effective routing tables provide the evidence of right routing setting: 
* the IP packet from the bastion will pass across the nva2 to reach out the vmspoke3 and vmspoke4,
* the packets from vmspoke3 and vmspoke4 to the Azure bastion passes through the nva2.

<br>

`Tags: hub-spoke vnets, Azure Bastion, BGP` <br>
`date: 22-06-22`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/network-diagram2.png "BGP peering between rs1 and nva2 and between nva2 and rs2"
[3]: ./media/network-diagram3.png "BGP advertisements"
<!--Link References-->

