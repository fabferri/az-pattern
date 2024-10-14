<properties
pageTitle= 'hub-spoke vnets with Route Server in hub and in the firewall vnet' 
description= "hub-spoke vnets with Route Server in hub and in the firewall vnet"
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
   ms.workload="Route Server, Azure vnet peering, Azure firewall, ExpressRoute"
   ms.date="24/10/2024"
   ms.review=""
   ms.author="fabferri" />

# Hub-spoke vnets with Route Server in hub and in the firewall vnet

## NOTE: the configuration described in this article is for testing ONLY. In a production environment, it is recommended a hub-spoke topology with azure firewall located in the hub vnet.

The article describes a scenario with hub-spoke vnets in peering and a connection with on-premises through ExpressRoute circuit. The high-level network diagram is shown below:

[![1]][1]

The configuration is designed to enable communication between the Spoke1 VNet and on-premises network via the ExpressRoute circuit.
<br>
The full diagram inclusive of IP address space is shown below:

[![2]][2]

<br>

Let's go through the configuration:
- the customer's edge routers advertise to the ExpressRoute circuit the major network 10.1.35.0/25
- the traffic between the spoke1 vnet and the on-premises network does <ins>not</ins> transit through the nva1
- all the vnet peering are created with the following attributes: <br>
   - "allowVirtualNetworkAccess": true, 
   - "allowForwardedTraffic": true,     
   - **"allowGatewayTransit": false,**   
   - **"useRemoteGateways": false,**    
- the spoke1 vnet has a UDR with default route: <br> 
  Destination network: **0.0.0.0/0**, type: **Virtual Network Appliance**, next-hop IP: **PrivateIPAzureFirewall**
- each Route Server has a fix ASN: 655515 that it can't be changed. 
- two eBGP sessions are established between **nva1** and the route server **fw-rs1** deployed in firewall vnet
- two eBGP sessions are established between **nva1** and the route server **hub-rs1** deployed in hub vnet
- the **nva1** in hub vnet requires the following BGP configuration:
   - **nva1** applies filtering in BGP advertisements inbound and outbound by route-map. 
   - when **nva1** advertises on-premises network 10.1.35.0/25 to the **fw-rs1**, it applies next-hop unchanged and AS PATH replace. <br> AS PATH replace is required to avoid discard of IP network prefixes in the Route Servers. <br> _[ this is expected becasue in eBGP session, AS loop detection is done by scanning the full AS path (as specified in the AS_PATH attribute), and checking that the autonomous system number of the local system does not appear in the AS path]_
   - the **nva1** advertises the address space of the spoke1 vnet to the **hub-rs** with next-hop the IP of the Azure firewall



## <a name="list of files"></a>1. Project files

| File name                 | Description                                                                        |
| ------------------------- | ---------------------------------------------------------------------------------- |
| **01-vnet-vms.json**      | ARM template to deploy spoke vnets, hub vnet, and VMs  in the hub ans spoke vnets  |
| **01-vnet-vms.ps1**       | powershell script to run **01-vnet-vms.json**                                      |
| **02-rs.json**            | ARM template to deploy Route Serves in hub vnet and firewall vnet and create the BGP connections with nva1|
| **02-rs.jps1**            | powershell script to run **02-rs.json**    |
| **03-azfw.json**          | Create the azure firewall in f2-vnet       |
| **03-azfw.ps1**           | powershell script to run **03-azfw.json**  |
| **frr-config.txt**        | FRR configuration       |


Before running the powershell scripts, customize the values of input variables:
```powershell
$adminUsername = 'ADMINISTRATOR_USERNAME'
$adminPassword = 'ADMNISTRATOR_PASSWORD'
$subscriptionName = 'AZURE_SUBSCRIPTION_NAME'
$deploymentName = 'DEPLOYMENT_NAME'
$location = 'AZURE_REGION_NAME'   
$rgName = 'RESOURCE_GROUP_NAME'
```
The ARM template **01-vnet-vms.json** uses an existing ExpressRoute circuit and requires the following values:
- `"erSubscriptionId"`: <ins>Subscription Id</ins> where is deployed the ExpressRoute circuit 
- `"erResourceGroup"` : <ins>Resource Group name</ins> where is deployed the ExpressRoute circuit
- `"erCircuitName"` : <ins>name of the ExpressRoute circuit</ins>
- `"erCircuitAuthorizationKey"`: <ins>authorization code</ins> to establish a connection with the ExpressRoute circuit
Before deploying the **01-vnet-vms.json** adjust the correct variables value.

<br>

> [!NOTE]
> `Route Server behaviour` <br>
> Shutdown one of BGP peering between nva1 and route server breaks the routing between the on-premises network and the spoke1 vnet. <br>
> Each route server pretends to have with the **nva1** both of BGP peering up. <br>
> i.e. one of following command in nva1 breakes the communication between the on-premises network and the spoke1 vnet: <br>
> neighbor 10.50.0.68 shutdown <br>
> OR <br>
> neighbor 10.50.0.69 shutdown <br>

## <a name="route-map in nva"></a>2. Filtering BGP advertisement by route-map

The **nva1** filters the BGP advertisements by route-map:
- **route-map FILTER-IN**: accepts all the BGP advertisements received
- **route-map TO-RS-HUB**: filter the IP network prefixes advertised in BGP from the nva1 to hub-rs1.  
- **route-map TO-RS-FW**: filter the IP network prefixes advertised in BGP from the nva1 to fw-rs1.  
- BGP Timers in Route Server are fixed: **Keep-alive** timer is set to 60 seconds and the **Hold-down** timer 180 seconds. 

BGP filtering applied to **nva1** is shown in the diagram:

[![3]][3]



## <a name="nva1 configurations"></a>3. FRR configuration
Enable IP forwarding:
```bash
sed -i -e '$a\net.ipv4.ip_forward = 1' /etc/sysctl.conf
# to apply the change
sysctl -p
# check the change
sysctl net.ipv4.ip_forward
```


In nva1 can be installed and check the FRR: 
```bash
sudo apt update 
sudo apt install frr 
sudo systemctl enable frr
sudo systemctl start frr
```
Enable BGP daemon in FRR:
```bash
# enable bgp daemon
sed -i -e 's/^bgpd=no/bgpd=yes/' /etc/frr/daemons
# restart FRR
systemctl restart frr
# check FRR status
systemctl status frr
```
 
In FFR to access to the command line interface run the shell command:  **vtysh** <br>
The file **/etc/frr/vtysh.conf** provides configuration information for the **vtysh** command tool:
```
service integrated-vtysh-config
```
FFR configuration:
```console
SEA-Cust33-nva1# show run
Building configuration...

Current configuration:
!
frr version 8.4.2
frr defaults traditional
hostname SEA-Cust33-nva1
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
ip route 0.0.0.0/0 10.17.33.1
ip route 10.0.4.4/32 10.17.33.1
ip route 10.0.4.5/32 10.17.33.1
ip route 10.0.5.4/32 10.17.33.1
ip route 10.0.5.5/32 10.17.33.1
ip route 10.0.6.4/32 10.17.33.1
ip route 10.0.6.5/32 10.17.33.1
ip route 10.17.33.68/32 10.17.33.1
ip route 10.17.33.69/32 10.17.33.1
!
router bgp 65001
 bgp router-id 10.17.33.10
 neighbor 10.0.4.4 remote-as 65515
 neighbor 10.0.4.4 ebgp-multihop 3
 neighbor 10.0.4.4 timers 60 180
 neighbor 10.0.4.5 remote-as 65515
 neighbor 10.0.4.5 ebgp-multihop 3
 neighbor 10.0.4.5 timers 60 180
 neighbor 10.0.5.4 remote-as 65515
 neighbor 10.0.5.4 ebgp-multihop 3
 neighbor 10.0.5.4 timers 60 180
 neighbor 10.0.5.5 remote-as 65515
 neighbor 10.0.5.5 ebgp-multihop 3
 neighbor 10.0.5.5 timers 60 180
 neighbor 10.0.6.4 remote-as 65515
 neighbor 10.0.6.4 ebgp-multihop 3
 neighbor 10.0.6.4 timers 60 180
 neighbor 10.0.6.5 remote-as 65515
 neighbor 10.0.6.5 ebgp-multihop 3
 neighbor 10.0.6.5 timers 60 180
 neighbor 10.17.33.68 remote-as 65515
 neighbor 10.17.33.68 ebgp-multihop 3
 neighbor 10.17.33.68 timers 60 180
 neighbor 10.17.33.69 remote-as 65515
 neighbor 10.17.33.69 ebgp-multihop 3
 neighbor 10.17.33.69 timers 60 180
 !
 address-family ipv4 unicast
  network 0.0.0.0/0
  aggregate-address 10.0.4.0/22
  neighbor 10.0.4.4 as-override
  neighbor 10.0.4.4 soft-reconfiguration inbound
  neighbor 10.0.4.4 route-map SPIN in
  neighbor 10.0.4.4 route-map SPOUT out
  neighbor 10.0.4.5 as-override
  neighbor 10.0.4.5 soft-reconfiguration inbound
  neighbor 10.0.4.5 route-map SPIN in
  neighbor 10.0.4.5 route-map SPOUT out
  neighbor 10.0.5.4 as-override
  neighbor 10.0.5.4 soft-reconfiguration inbound
  neighbor 10.0.5.4 route-map SPIN in
  neighbor 10.0.5.4 route-map SPOUT out
  neighbor 10.0.5.5 as-override
  neighbor 10.0.5.5 soft-reconfiguration inbound
  neighbor 10.0.5.5 route-map SPIN in
  neighbor 10.0.5.5 route-map SPOUT out
  neighbor 10.0.6.4 as-override
  neighbor 10.0.6.4 soft-reconfiguration inbound
  neighbor 10.0.6.4 route-map SPIN in
  neighbor 10.0.6.4 route-map SPOUT out
  neighbor 10.0.6.5 as-override
  neighbor 10.0.6.5 soft-reconfiguration inbound
  neighbor 10.0.6.5 route-map SPIN in
  neighbor 10.0.6.5 route-map SPOUT out
  neighbor 10.17.33.68 as-override
  neighbor 10.17.33.68 soft-reconfiguration inbound
  neighbor 10.17.33.68 route-map RSIN in
  neighbor 10.17.33.68 route-map RSOUT out
  neighbor 10.17.33.69 as-override
  neighbor 10.17.33.69 soft-reconfiguration inbound
  neighbor 10.17.33.69 route-map RSIN in
  neighbor 10.17.33.69 route-map RSOUT out
 exit-address-family
exit
!
ip prefix-list DEFFW seq 10 permit 0.0.0.0/0
ip prefix-list HUB-VNET seq 10 deny 10.17.33.0/24
ip prefix-list ONPREM seq 10 permit 10.0.0.0/8
ip prefix-list SPMAJOR seq 10 permit 10.0.4.0/22
ip prefix-list SPOKE-VNET seq 10 deny 10.0.4.0/24
ip prefix-list SPOKE-VNET seq 20 deny 10.0.5.0/24
ip prefix-list SPOKE-VNET seq 30 deny 10.0.6.0/24
ip prefix-list SPOKE-VNET seq 50 permit 10.0.0.0/8
!
route-map SPIN permit 20
exit
!
route-map RSIN permit 20
 match ip address prefix-list ONPREM
exit
!
route-map FW permit 10
 match ip address prefix-list DEFFW
 set ip next-hop 10.100.0.10
exit
!
route-map SPOUT permit 20
 match ip address prefix-list SPOKE-VNET
 set ip next-hop unchanged
exit
!
route-map SPOUT permit 30
 match ip address prefix-list DEFFW
 set ip next-hop 10.100.0.10
exit
!
route-map SPOUT permit 40
 match ip address prefix-list SPMAJOR
 set ip next-hop 10.17.33.254
exit
!
route-map RSOUT deny 5
 match ip address prefix-list DEFFW
exit
!
route-map RSOUT deny 6
 match ip address prefix-list SPMAJOR
exit
!
route-map RSOUT permit 10
 set ip next-hop unchanged
exit
!
end
SEA-Cust33-nva1#
```


## <a name="nva1 routing tables"></a>3. nva1 routing tables

BGP table in nva1:
```
nva1# show ip bgp summary

IPv4 Unicast Summary (VRF default):
BGP router identifier 10.50.0.10, local AS number 65001 vrf-id 0
BGP table version 4
RIB entries 7, using 1344 bytes of memory
Peers 4, using 2896 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
10.50.0.68      4      65515        16        15        0    0    0 00:10:29            2        1 N/A
10.50.0.69      4      65515        16        15        0    0    0 00:10:29            2        1 N/A
10.100.0.4      4      65515        15        16        0    0    0 00:10:29            1        1 N/A
10.100.0.5      4      65515        15        16        0    0    0 00:10:29            1        1 N/A

Total number of neighbors 4

nva1# show ip bgp
BGP table version is 4, local router ID is 10.50.0.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*= 10.1.35.0/25     10.50.0.69                             0 65515 12076 65020 i
*>                  10.50.0.68                             0 65515 12076 65020 i
*= 10.50.0.0/24     10.50.0.69                             0 65515 i
*>                  10.50.0.68                             0 65515 i
*= 10.100.0.0/24    10.100.0.5                             0 65515 i
*>                  10.100.0.4                             0 65515 i
*> 10.101.0.0/24    0.0.0.0                  0         32768 i

Displayed  4 routes and 7 total paths
```


The nva1 advertises to the Route Server in the hub vnet the following networks:
```console
nva1# show ip bgp neighbors 10.50.0.68 advertised-routes
BGP table version is 4, local router ID is 10.50.0.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.101.0.0/24    10.100.0.196             0         32768 i

Total number of prefixes 1
```

The nva1 learns from the Route Server in the hub vnet the following networks:
```console
nva1# show ip bgp neighbors 10.50.0.68 received-routes
BGP table version is 4, local router ID is 10.50.0.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.1.35.0/25     10.50.0.68                             0 65515 12076 65020 i
*> 10.50.0.0/24     10.50.0.68                             0 65515 i

Total number of prefixes 2
```



The nva1 advertises to the Route Server in the firewall vnet the following networks:
```console
nva1# show ip bgp neighbors 10.100.0.4 advertised-routes
BGP table version is 4, local router ID is 10.50.0.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.1.35.0/25     10.50.0.68                             0 65001 12076 65020 i

Total number of prefixes 1
```
The nva1 learns from the Route Server in the firewall vnet the following networks:
```
nva1# show ip bgp neighbors 10.100.0.4 received-routes
BGP table version is 4, local router ID is 10.50.0.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.100.0.0/24    10.100.0.4                             0 65515 i

Total number of prefixes 1
```

## <a name="Routing tables of the Route Servers in firewall vnet"></a>5. fw-rs1 routing table

```console
Get-AzRouteServerPeerLearnedRoute -ResourceGroupName $rgName -RouteServerName fw-rs1 -PeerName bgp-conn1 | ft
LocalAddress Network      NextHop    SourcePeer Origin AsPath                  Weight
------------ -------      -------    ---------- ------ ------                  ------
10.100.0.5   10.1.35.0/25 10.50.0.68 10.50.0.10 EBgp   65001-65001-12076-65020 32768
10.100.0.4   10.1.35.0/25 10.50.0.68 10.50.0.10 EBgp   65001-65001-12076-65020 32768

Get-AzRouteServerPeerAdvertisedRoute -ResourceGroupName $rgName -RouteServerName fw-rs1 -PeerName bgp-conn1 | ft
LocalAddress Network       NextHop    SourcePeer Origin AsPath Weight
------------ -------       -------    ---------- ------ ------ ------
10.100.0.5   10.100.0.0/24 10.100.0.5            Igp    65515  0
10.100.0.4   10.100.0.0/24 10.100.0.4            Igp    65515  0
```


## <a name="Routing tables of the Route Server in hub vnet"></a>6. Routing tables of the Route Server in hub vnet

```console
Get-AzRouteServerPeerLearnedRoute -ResourceGroupName $rgName -RouteServerName hub-rs1 -PeerName bgp-conn1 | ft
LocalAddress Network       NextHop      SourcePeer Origin AsPath Weight
------------ -------       -------      ---------- ------ ------ ------
10.50.0.69   10.101.0.0/24 10.100.0.196 10.50.0.10 EBgp   65001  32768
10.50.0.68   10.101.0.0/24 10.100.0.196 10.50.0.10 EBgp   65001  32768

Get-AzRouteServerPeerAdvertisedRoute -ResourceGroupName $rgName -RouteServerName hub-rs1 -PeerName bgp-conn1 | ft
LocalAddress Network      NextHop    SourcePeer Origin AsPath            Weight
------------ -------      -------    ---------- ------ ------            ------
10.50.0.69   10.50.0.0/24 10.50.0.69            Igp    65515             0
10.50.0.69   10.1.35.0/25 10.50.0.69            Igp    65515-12076-65020 0
10.50.0.68   10.50.0.0/24 10.50.0.68            Igp    65515             0
10.50.0.68   10.1.35.0/25 10.50.0.68            Igp    65515-12076-65020 0
```

## <a name="Routing tables of the Expressroute Gateway"></a>7. Routing tables of the Expressroute Gateway

```console
Get-AzVirtualNetworkGatewayLearnedRoute -VirtualNetworkGatewayName SEA-Cust33-hub-gw-er -ResourceGroupName $rgName | ft

LocalAddress Network       NextHop      SourcePeer  Origin  AsPath      Weight
------------ -------       -------      ----------  ------  ------      ------
10.50.0.205  10.50.0.0/24               10.50.0.205 Network             32768
10.50.0.205  10.1.35.0/25  10.50.0.196  10.50.0.196 EBgp    12076-65020 32769
10.50.0.205  10.1.35.0/25  10.50.0.197  10.50.0.197 EBgp    12076-65020 32769
10.50.0.205  10.101.0.0/24 10.100.0.196 10.50.0.68  IBgp    65001       32768
10.50.0.205  10.101.0.0/24 10.100.0.196 10.50.0.69  IBgp    65001       32768

$bgpPeerStatus=Get-AzVirtualNetworkGatewayBGPPeerStatus -VirtualNetworkGatewayName SEA-Cust33-hub-gw-er -ResourceGroupName $rgName
Get-AzVirtualNetworkGatewayAdvertisedRoute -VirtualNetworkGatewayName SEA-Cust33-hub-gw-er -ResourceGroupName $rgName -Peer $bgpPeerStatus[0].Neighbor | ft

LocalAddress Network       NextHop     SourcePeer Origin AsPath      Weight
------------ -------       -------     ---------- ------ ------      ------
10.50.0.205  10.50.0.0/24  10.50.0.205            Igp    65515       0
10.50.0.205  10.101.0.0/24 10.50.0.205            Igp    65515-65001 0
```



## <a name="effective touting table of VM in fw vnet "></a>8. Effective routing table fw-vm1-nic 

| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.100.0.0/24    | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.50.0.0/24     | VNet peering            | \-                  | \-                      |
| Default                 | Active | 10.101.0.0/24    | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active | 10.1.35.0/25     | Virtual network gateway | 10.50.0.68          | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |



`Tags: Route Server, hub-spoke vnets` <br>
`date: 14-10-2024`

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "full network diagram with address space"
[3]: ./media/network-diagram3.png "BGP filtering applied in nva1"

<!--Link References-->

