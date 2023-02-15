<properties
pageTitle= 'hackathon: hub-spoke vnets configuration with ExpressRoute connection in failover through a transit vnet'
description= "hackathon: hub-spoke vnets configuration with ExpressRoute connection in failover through a transit vnet"
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
   ms.workload="Azure ExpressRoute Gateway, Azure Route Server"
   ms.date="14/02/2023"
   ms.review=""
   ms.author="fabferri" />

## hackathon: hub-spoke vnets configuration with ExpressRoute connection in failover through a transit vnet

### Caveat: the configuration is for <ins>testing ONLY</ins>

The article describes a scenario with hub-spoke vnets in peering and ExpressRoute Gateway in the hub vnet for the connection with on-premises networks. The high-level network diagram is shown below:

[![1]][1]

The purpose of transit vnet is to guarantee the connection with on-premises network, when the Connection between the Gateway1 in hub and the Expressroute circuit is deleted. The configuration can be useful in the process of migration from ExpressRoute Gateway from non-zoning SKU (Standard, HighPerformance, UltraPerformance) to the zoning SKU (ErGw1Az, ErGw2Az, ErGw3Az), in the case the time of disconnection with on-premises networks is not acceptable for customers. 
The migration process of ExpressRoute Gateway from non-zoning SKU to zoning SKU requires few steps in sequence:
- deletion of the ExpressRoute Connection, 
- deletion of the ExpressRoute Gateway, 
- creation of new ExpressRoute Gateway in zoning SKU,
- creation of new ExpressRoute Connection, between the new ExpressRoute Gateway and the ExpressRoute circuit.
Along the process of ExpressRoute Gateway migration, the configuration with transit vnet aims to route the traffic though an alternative path between the hub-spoke vnets and the on-premises networks.

[![2]][2]

The full network diagram with the configuration details is shown below:

[![3]][3]

Let's discuss briefly the configuration:
- the vnet peering in spoke sides are created with the following attributes: <br>
  - "allowVirtualNetworkAccess": true, <br>
  - "allowForwardedTraffic": true,     <br>
  - **"allowGatewayTransit": false,**   <br>
  - **"useRemoteGateways": true,**    <br>
- the configuration has UDR in the spoke vnet to force the traffic to transit through the firewall in the hub vnet. The UDR has the BGP propagation disabled; the subnet in spoke vnet does not receive the networks on-premises but the address space of spoke vnet is sent anyway to on-premises through the ExpressRoute Gateway
- in the hub vnet runs a **nva2** with BGP routing features, able to support AS-override and route filtering (route-map) in BGP advertisements inbound and outbound  
- each Route Server has a fix ASN 655515 that it can't be changed
- two eBGP session are established between the route server **rs1** in the hub and the **nva2** deployed in the transit vnet
- two eBGP session are created between the route server **rs2** in the transit vnet and the **nva2** 
- the configuration requires in **nva2** the following BGP capabilities:
   - capability to create eBGP peering simultaneosly with **rs1** and **rs2**.
   - capability in eBGP to apply <ins>**AS-overwrite**</ins>. This is required to avoid discard of IP network prefixes in the Route Servers. _[In eBGP the AS loop detection is done by scanning the full AS path (as specified in the AS_PATH attribute), and checking that the autonomous system number of the local system does not appear in the AS path]_
   - capability in eBGP to leave the <ins>**next-hop unchanged**</ins> 
- in the setup **nva2** runs in Ubuntu (22.04) VM and BGP implemented by FRRouting (open-source SW) 
- the current setup uses a single **nva2**. The configuration has a single point of failure in the NVA. It is possibile anyway make a deployment with two NVAs to achieve a better resilience
- the data path between VMs in hub-spoke and on-premises does not transit through the **nva2**. When the traffic transit through the transit vnet, the **nva2** SKU does not impact with throughput to/from on-premises,   

A full diagram in condition of failover through the Connection liked to the transit vnet is show below:

[![4]][4]

When the primary connection between the hub vnet and the ExpressRoute circuit is deleted, the data traffic between the spoke vnet and the on-premises does not pass through the **nva2**; **nva2** is not in the data path:

[![5]][5]

## <a name="list of files"></a>1. File list

| File name                 | Description                                                                       |
| ------------------------- | --------------------------------------------------------------------------------- |
| **01-vnet-vms.json**      | ARM template to deploy spoke vnets, hub vnets, vnet peerings and VMs              |
| **01-vnet-vms.ps1**       | powershell script to run **01-vnet-vms.json**                                     |
| **02-vnet2-vms.json**     | ARM template to deploy transit vnet, nva2, Expressroute Gateway in vnet2 and ExpressRoute Connection 2 with the Expressroute circuit  |
| **02-vnet2-vms.ps1**      | powershell script to run **02-vnet2-vms.json**                                    |
| **03-rs1.json**           | deployment of **rs1** in hub vnet                                                 |
| **03-rs1.ps1**            | powershell script to run **03-rs1.json**                                          |
| **04-rs2.json**           | deployment of **rs2** in transit vnet                                             |
| **04-rs2.ps1**            | powershell script to run **04-rs2.json**                                          |
| **05-spoke-vnet.json**    | ARM template to deploy spoke1 vnet and spok1 vm                                   |
| **05-spoke-vnet.ps1**     | powershell script to run **05-spoke-vnet.json**                                   |
| **06-vnet-peering.json**  | ARM template to create vnet peering between spoke1 and hub and between hub and transit vnet |
| **06-vnet-peering.ps1**   | powershell script to run **06-vnet-peering.json**                                 |
| **07-er-conn-vnet1.json** | ARM template to create the ExpressRoute connection between the hub and the ExpressRoute circuit| 
| **07-er-conn-vnet1.ps1**  | powershell script to run **07-er-conn-vnet1.json**                                |
| **nva2-frr-config.txt**   | FFR configuration deployed in **nva2**                                            |

<br>

Before running the powershell scripts, assign the value of the variables:
```powershell
$adminUsername = 'ADMINISTRATOR_USERNAME'
$adminPassword = 'ADMINISTRATOR_PASSWORD'
$subscriptionName = 'NAME_OF_AZURE_SUBSCRIPTION'
$location = 'AZURE_REGION_HUB_SPOKE_VNETS'   
$rgName = 'NAME_OF_THE_RESOURCE_GROUP'
```

For a successful deployment, the value of variables should be consistent across all the powershell scripts.
<br>




## <a name="nva1 configurations"></a>2. nva2 setup
Enable IP forwarding:
```bash
sed -i -e '$a\net.ipv4.ip_forward = 1' /etc/sysctl.conf
# to apply the change
sysctl -p
# check the change
sysctl net.ipv4.ip_forward
```

In nva2 can be installed the FRR; steps to install FRR in Ubuntu are available [FRR Debian repository](https://deb.frrouting.org/)
```bash
# download  the OpenPGP key for the APT repository
# the key should be downloaded over HTTPS to a location only writable by root, i.e. /usr/share/keyrings
curl -s https://deb.frrouting.org/frr/keys.asc |  gpg --dearmor > /usr/share/keyrings/frr.gpg

# possible values for FRRVER: frr-6 frr-7 frr-8 frr-stable
# frr-stable will be the latest official stable release
# Add the repository sources.list entry
FRRVER="frr-stable"
echo deb [arch=amd64 signed-by=/usr/share/keyrings/frr.gpg] https://deb.frrouting.org/frr $(lsb_release -s -c) $FRRVER | sudo tee -a /etc/apt/sources.list.d/frr.list

# update and install FRR
sudo apt update 
sudo apt install frr frr-pythontools
```

```bash
# enable bgp daemon
sed -i -e 's/^bgpd=no/bgpd=yes/' /etc/frr/daemons
systemctl restart frr
systemctl status frr
```

In **nva2**  to access to the command line interface of the FRR, as root privilege, run the shell command  **vtysh** <br>
The FRR configuration in **nva2** is shown below:
```console
SEA-Cust34-nva2# show run
Building configuration...

Current configuration:
!
frr version 8.4.2
frr defaults traditional
hostname SEA-Cust34-nva2
log syslog informational
no ip forwarding
no ipv6 forwarding
service integrated-vtysh-config
!
ip route 10.0.1.132/32 10.0.2.1
ip route 10.0.1.133/32 10.0.2.1
ip route 10.0.2.132/32 10.0.2.1
ip route 10.0.2.133/32 10.0.2.1
!
router bgp 65001
 bgp router-id 10.0.2.10
 neighbor 10.0.1.132 remote-as 65515
 neighbor 10.0.1.132 ebgp-multihop 3
 neighbor 10.0.1.132 timers 60 180
 neighbor 10.0.1.133 remote-as 65515
 neighbor 10.0.1.133 ebgp-multihop 3
 neighbor 10.0.1.133 timers 60 180
 neighbor 10.0.2.132 remote-as 65515
 neighbor 10.0.2.132 ebgp-multihop 3
 neighbor 10.0.2.132 timers 60 180
 neighbor 10.0.2.133 remote-as 65515
 neighbor 10.0.2.133 ebgp-multihop 3
 neighbor 10.0.2.133 timers 60 180
 !
 address-family ipv4 unicast
  neighbor 10.0.1.132 as-override
  neighbor 10.0.1.132 soft-reconfiguration inbound
  neighbor 10.0.1.132 route-map BGP_IN in
  neighbor 10.0.1.132 route-map BGP_OUT_RS1 out
  neighbor 10.0.1.133 as-override
  neighbor 10.0.1.133 soft-reconfiguration inbound
  neighbor 10.0.1.133 route-map BGP_IN in
  neighbor 10.0.1.133 route-map BGP_OUT_RS1 out
  neighbor 10.0.2.132 as-override
  neighbor 10.0.2.132 soft-reconfiguration inbound
  neighbor 10.0.2.132 route-map BGP_IN in
  neighbor 10.0.2.132 route-map BGP_OUT_RS2 out
  neighbor 10.0.2.133 as-override
  neighbor 10.0.2.133 soft-reconfiguration inbound
  neighbor 10.0.2.133 route-map BGP_IN in
  neighbor 10.0.2.133 route-map BGP_OUT_RS2 out
 exit-address-family
exit
!
ip prefix-list BGP_IN seq 10 permit 0.0.0.0/0 le 32
ip prefix-list BGP_OUT_RS1 seq 10 deny 10.0.1.0/24
ip prefix-list BGP_OUT_RS1 seq 20 deny 10.17.34.0/24
ip prefix-list BGP_OUT_RS1 seq 30 deny 10.0.50.0/24
ip prefix-list BGP_OUT_RS1 seq 50 permit 0.0.0.0/0 le 32
ip prefix-list BGP_OUT_RS2 seq 10 deny 10.1.34.0/25
ip prefix-list BGP_OUT_RS2 seq 20 deny 10.18.34.0/24
ip prefix-list BGP_OUT_RS2 seq 30 deny 10.0.2.0/24
ip prefix-list BGP_OUT_RS2 seq 50 permit 0.0.0.0/0 le 32
!
!
route-map BGP_IN permit 10
 match ip address prefix-list BGP_IN
exit
!
route-map BGP_OUT_RS1 permit 10
 match ip address prefix-list BGP_OUT_RS1
 set ip next-hop unchanged
exit
!
route-map BGP_OUT_RS2 permit 10
 match ip address prefix-list BGP_OUT_RS2
 set ip next-hop unchanged
exit
!
end
SEA-Cust34-nva2#
```
The FRR version used in **nva2** is **8.4.2** <br>
The FRR applies the following filters to the BGP advertisements:
- **neighbor <IPAddress_BGPpeer> route-map BGP_IN in**: it is the inbound filtering for BGP advertisements received from the Route servers  <br>
- **neighbor <IP_Address_RouteServer2> route-map BGP_OUT_RS1**: it is the outbound filtering for BGP advertisements sent from the **nva2** to the Route servers1  <br>
- **neighbor <IP_Address_RouteServer2> route-map BGP_OUT_RS2**: it is the outbound filtering for BGP advertisements sent from the **nva2** to the Route servers2  <br>

Loop prevention in eBGP is done by verifying the AS number in the AS Path. If the receiving router sees its own AS number in the AS Path of the received BGP packet, the packet is dropped. The receiving router assumes that the packet was originated from its own AS and has reached the same place from where it originated initially. The default eBGP behaviour can be override by the statement **neighbor <IP_Addr_Peer> as-override**. 

By default in eBGP the router advertised the IP network prefixes to a BGP peer with its IP as next-hop. To avoid the datapath transit through the **nva2** is required that the NVA does not apply a change of original IP next-hop. the statement **set ip next-hop unchanged** in the route-map allows to leave unchanged the IP of next-hop. <br>

In **nva1** to access to the command line interface of the FRR, as root privilege, run the shell command: **vtysh**

## <a name="routing tables"></a>3. Routing tables in case of failover through the transit vnet

### <a name="routing tables"></a>3.1 BGP routing table in nva2 
List of bgp networks in **nva2**:
```console
SEA-Cust34-nva2# show ip bgp
BGP table version is 7, local router ID is 10.0.2.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*= 10.0.1.0/24      10.0.1.133                             0 65515 i
*>                  10.0.1.132                             0 65515 i
*= 10.0.2.0/24      10.0.2.133                             0 65515 i
*>                  10.0.2.132                             0 65515 i
*= 10.0.50.0/24     10.0.1.133                             0 65515 i
*>                  10.0.1.132                             0 65515 i
*= 10.1.34.0/25     10.0.2.133                             0 65515 12076 65020 i
*>                  10.0.2.132                             0 65515 12076 65020 i
*= 10.17.34.0/24    10.0.1.133                             0 65515 i
*>                  10.0.1.132                             0 65515 i
*= 10.18.34.0/24    10.0.2.133                             0 65515 i
*>                  10.0.2.132                             0 65515 i
```

List of IP network prefixes sent to **SEA-Cust34-rs1** in hub vnet:
```console
SEA-Cust34-nva2# show ip bgp neighbors 10.0.1.132 advertised-routes
BGP table version is 7, local router ID is 10.0.2.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.2.0/24      10.0.2.132                             0 65001 i
*> 10.1.34.0/25     10.0.2.132                             0 65001 12076 65020 i
*> 10.18.34.0/24    10.0.2.132                             0 65001 i

Total number of prefixes 3
```

List of IP network prefixes received from **SEA-Cust34-rs1** in hub vnet:
```console
SEA-Cust34-nva2# show ip bgp neighbors 10.0.1.132 received-routes
BGP table version is 7, local router ID is 10.0.2.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.1.0/24      10.0.1.132                             0 65515 i
*> 10.0.50.0/24     10.0.1.132                             0 65515 i
*> 10.17.34.0/24    10.0.1.132                             0 65515 i

Total number of prefixes 3
```

List of IP network prefixes sent to **SEA-Cust34-rs2** in transit vnet:
```console
SEA-Cust34-nva2# show ip bgp neighbors 10.0.2.132 advertised-routes
BGP table version is 7, local router ID is 10.0.2.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.1.0/24      10.0.1.132                             0 65001 i
*> 10.0.50.0/24     10.0.1.132                             0 65001 i
*> 10.17.34.0/24    10.0.1.132                             0 65001 i

Total number of prefixes 3
```

List of IP network prefixes received from **SEA-Cust34-rs2** in transit vnet:
```console
SEA-Cust34-nva2# show ip bgp neighbors 10.0.2.132 received-routes
BGP table version is 7, local router ID is 10.0.2.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.2.0/24      10.0.2.132                             0 65515 i
*> 10.1.34.0/25     10.0.2.132                             0 65515 12076 65020 i
*> 10.18.34.0/24    10.0.2.132                             0 65515 i

Total number of prefixes 3
```
### <a name="routing tables in Route Servers"></a>3.2 BGP routing table in rs1
The **SEA-Cust34-rs1** learns the following network from the **nva2**:
```console
Get-AzRouteServerPeerlearnedRoute -RouteServerName SEA-Cust34-rs1 -ResourceGroupName $rgName -peername $peerName |ft

LocalAddress Network       NextHop    SourcePeer Origin AsPath                  Weight
------------ -------       -------    ---------- ------ ------                  ------
10.0.1.133   10.0.2.0/24   10.0.2.132 10.0.2.10  EBgp   65001-65001              32768
10.0.1.133   10.18.34.0/24 10.0.2.132 10.0.2.10  EBgp   65001-65001              32768
10.0.1.133   10.1.34.0/25  10.0.2.132 10.0.2.10  EBgp   65001-65001-12076-65020  32768
10.0.1.132   10.18.34.0/24 10.0.2.132 10.0.2.10  EBgp   65001-65001              32768
10.0.1.132   10.0.2.0/24   10.0.2.132 10.0.2.10  EBgp   65001-65001              32768
10.0.1.132   10.1.34.0/25  10.0.2.132 10.0.2.10  EBgp   65001-65001-12076-65020  32768
```

The **SEA-Cust34-rs1** advertises the following network from the **nva1**:
```
Get-AzRouteServerPeerAdvertisedRoute -RouteServerName SEA-Cust34-rs1 -ResourceGroupName $rgName -peername $peerName |ft

LocalAddress Network       NextHop    SourcePeer Origin AsPath Weight
------------ -------       -------    ---------- ------ ------ ------
10.0.1.133   10.17.34.0/24 10.0.1.133            Igp    65515       0
10.0.1.133   10.0.1.0/24   10.0.1.133            Igp    65515       0
10.0.1.133   10.0.50.0/24  10.0.1.133            Igp    65515       0
10.0.1.132   10.17.34.0/24 10.0.1.132            Igp    65515       0
10.0.1.132   10.0.1.0/24   10.0.1.132            Igp    65515       0
10.0.1.132   10.0.50.0/24  10.0.1.132            Igp    65515       0
```

### <a name="routing tables in Route Servers"></a>3.3 BGP routing table in rs2
The SEA-Cust34-rs2 in transit vnet learns the following networks from the **nva2**:
```console
Get-AzRouteServerPeerlearnedRoute -RouteServerName SEA-Cust34-rs2 -ResourceGroupName $rgName -peername $peerName |ft

LocalAddress Network       NextHop    SourcePeer Origin AsPath      Weight
------------ -------       -------    ---------- ------ ------      ------
10.0.2.132   10.0.50.0/24  10.0.1.132 10.0.2.10  EBgp   65001-65001  32768
10.0.2.132   10.0.1.0/24   10.0.1.132 10.0.2.10  EBgp   65001-65001  32768
10.0.2.132   10.17.34.0/24 10.0.1.132 10.0.2.10  EBgp   65001-65001  32768
10.0.2.133   10.0.50.0/24  10.0.1.132 10.0.2.10  EBgp   65001-65001  32768
10.0.2.133   10.0.1.0/24   10.0.1.132 10.0.2.10  EBgp   65001-65001  32768
10.0.2.133   10.17.34.0/24 10.0.1.132 10.0.2.10  EBgp   65001-65001  32768
```
The rs2 learns:
- the network 10.0.50.0/24 of the spoke vnet with next-hop the IP of the rs1. 
- the networks 10.17.34.0/24, 10.0.1.0/24 of hub vnet with next-hop of the IP of the rs1

<br>

The rs2 advertises the following networks from the **nva1**:
```
Get-AzRouteServerPeerAdvertisedRoute -RouteServerName SEA-Cust34-rs1 -ResourceGroupName $rgName -peername $peerName |ft

LocalAddress Network       NextHop    SourcePeer Origin AsPath            Weight
------------ -------       -------    ---------- ------ ------            ------
10.0.2.132   10.18.34.0/24 10.0.2.132            Igp    65515                  0
10.0.2.132   10.0.2.0/24   10.0.2.132            Igp    65515                  0
10.0.2.132   10.1.34.0/25  10.0.2.132            Igp    65515-12076-65020      0
10.0.2.133   10.18.34.0/24 10.0.2.133            Igp    65515                  0
10.0.2.133   10.0.2.0/24   10.0.2.133            Igp    65515                  0
10.0.2.133   10.1.34.0/25  10.0.2.133            Igp    65515-12076-65020      0
```

### <a name="effective route table"></a>3.4 Effective routing table in the nic of the spoke1vm1

[![6]][6]

### <a name="effective route table"></a>3.5 Effective routing table in the nic of the vm1 in the hub vnet

[![7]][7]

### <a name="effective route table"></a>3.6 Effective routing table in the nva2 in the transitve vnet

[![8]][8]

### <a name="Routing table in Route Server 1"></a>3.7 SEA-Cust34-rs1 routing table

[![9]][9]

### <a name="Routing table in Route Server 2"></a>3.8 SEA-Cust34-rs2 routing table

[![10]][10]

### <a name="Routing table in ExpressRoute Gateway"></a>3.9 Routing table in ExpressRoute Gateway in transit vnet

[![11]][11]

### <a name="Routing table in ExpressRoute Gateway"></a>3.10 Routing table in ExpressRoute circuit
[![12]][12]

`Tags: hub-spoke vnets, route server, NVA`
`date: 14-02-23`

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "routing in alternative path along the migration of ExpressRoute Gateway"
[3]: ./media/network-diagram3.png "full network diagram"
[4]: ./media/network-diagram4.png "failover diagram through the transit vnet"
[5]: ./media/network-diagram5.png "failover diagram through the transit vnet"
[6]: ./media/effectiveroutes-spokevm.png "effective routing table in the spoke vm"
[7]: ./media/effectiveroutes-hubvm.png "effective routing table in the hub vm"
[8]: ./media/effectiveroutes-nva2.png "effective routing table in nva2 in the transit vnet"
[9]: ./media/rs1.png "routing table in Route Server rs1"
[10]: ./media/rs2.png "routing table in Route Server rs2"
[11]: ./media/er-gw.png "routing table in Expressroute Gateway in transit vnet"
[12]: ./media/er-circuit.png "routing table in Expressroute circuit"

<!--Link References-->

