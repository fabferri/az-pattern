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

The configuration aims to make intercommunication any-to-any with traffic in transit through the Azure firewalls. The routing has an easy configuration because most of work is done by the NVAs and Route Servers and it doesn't require complex UDRs. 
* all the UDRs applied to the subnets in the spoke vnets have only the default route 0.0.0.0/0, pointing to the nearest Azure firewall
* the Azure firewall subnets do not have any UDR

To keep the deployment simple, the firewall policies have two network security rules: 
* a rule connection with allow traffic from source address 10.0.0.0/8 to the destination network 10.0.0.0/8
* a rule connection to allow traffic from spoke vnets and hub vnet to internet

Below a network diagram with communication paths:

[![2]][2]

Below some communication paths:
```
spoke1 <--> azfw1 <--> spoke2
spoke1 <--> azfw1 <--> azfw2 <--> spoke3
spoke1 <--> azfw1 <--> azfw2 <--> spoke4
spoke1 <--> azfw1 <--> ER GTW <--> ER circuit <--> on-premises
spoke2 <--> azfw1 <--> azfw2 <--> spoke3
spoke2 <--> azfw1 <--> azfw2 <--> spoke4
spoke2 <--> azfw1 <--> ER GTW <--> ER circuit <--> on-premises
spoke1 <--> appvm1 
spoke2 <--> appvm1
spoke3 <--> appvm2
spoke4 <--> appvm2
appvm1 <--> appvm2
```

The NVA in vnet1 is in BGP peering with route server and advertises the networks of the spoke vnets to the route server; in the BGP advertisement the NVA set the IP of the next-hop to the IP address of the Azure firewall:

```console
10.0.1.0/24 next-hop IP address: 10.1.0.4
10.0.2.0/24 next-hop IP address: 10.1.0.4
10.0.3.0/24 next-hop IP address: 10.2.0.4
10.0.4.0/24 next-hop IP address: 10.2.0.4
```
[![3]][3]

The route server advertises the received networks of the spoke vnets to the Expressroute Gateway. The ExpressRoute Gateway will advertise the address of spoke vnets (spoke1, spoke2, spoke3 and spoke4) to on-premises.
when the IP packet from on-premises network, with destination a spoke vnet, reach out the Expressroute Gateway will be forwarded to the proper Azure firewall.


### <a name="list of files"></a>2. Files

| File name             | Description                                                |
| --------------------- | ---------------------------------------------------------- |
| **azfw.json**         | ARM template to deploy spoke vnets, hub vnets,Azure firewalls, Azure bastions, NVA and VMs |
| **azfw.ps1**          | powershell script to run **azfw.json**                     |
| **cloud-init.txt**    | cloud init file to install FRR in the NVA                  |
| **init.json**         | define the value of input variables required for the full deployment |
| **rs.json**           | ARM template to deploy the route server in vnet1, the Expressroute Gateway and the connection with the ExpressRoute circuit |
| **rs.ps1**            | powershell to script to run **rs.json**                    | 
| **vnet-peering.json** | ARM template to create vnet peering between hub1-vnet1 and hub2-vnet1 |
| **vnet-peering.ps1**  | powershell to script to run **vnet-peering.json**          |

To run the project, follow the steps in sequence:
1. change/modify the value of input variables in the file **init.json**
2. run the powershell script **azfw.ps1**
3. run the powershell script **rs.ps1** 
4. run the powershell script **vnet-peering.ps1** 

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
    "locationvnet1": "AZURE_LOCATION_vnet1",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "authenticationType": "password",
    "adminPasswordOrKey": "ADMINISTRATOR_PASSWORD",
    "mngIP": "PUBLIC_IP_ADDRESS_TO_FILTER_SSH_ACCESS_TO_VMS-it can be empty string!",
    "er_subscriptionId": "AZURE_SUBSCRIPTION_ID_WHERE_IS_DEPLOYED_THE_EXPRESSROUTE_CIRCUIT",
    "er_resourceGroup": "RESOUCE_GROUP_NAME_WHERE_IS_DEPLOYED_THE_EXPRESSROUTE_CIRCUIT",
    "er_circuitName": "NAME_OF_EXPRESSROUTE_CIRCUIT",
    "er_authorizationKey": "ANUTHORIZATION_KEY_TO_JOIN_TO_THE_EXPRESSROUTE_CIRCUIT"
}
```
## <a name="NVA"></a>3. FRR in NVA
Quagga was removed from Ubuntu 22.04 and replaced by FRRouting  (https://frrouting.org/).<br>
The installation of **FRR** (Free Range Routing) in the NVA is automatically executed by ARM template, through cloud-init (file: **cloud-init.txt**)
FRR requires the configuration of **Inbound** and **Outbound** path policies, in order FRR will accept and send inbound and outbound BGP updates. This is visualized by the command:

```console
show ip bgp neighbor
...
  Inbound updates discarded due to missing policy
  Outbound updates discarded due to missing policy
...
```

To avoid BGP update discard a route-map inboud and outboud is associated with BGP peering:
```console
router bgp 65001
 bgp router-id 10.101.0.50
 neighbor 10.101.0.4 remote-as 65515
 neighbor 10.101.0.5 remote-as 65515
 !
 address-family ipv4 unicast
  network 10.0.1.0/24
  network 10.0.2.0/24
  network 10.0.3.0/24
  network 10.0.4.0/24
  neighbor 10.101.0.4 soft-reconfiguration inbound
  neighbor 10.101.0.4 route-map BGP_IN in
  neighbor 10.101.0.4 route-map BGP_OUT out
  neighbor 10.101.0.5 soft-reconfiguration inbound
  neighbor 10.101.0.5 route-map BGP_IN in
  neighbor 10.101.0.5 route-map BGP_OUT out
 exit-address-family
exit
!
ip prefix-list BGP_IN seq 10 permit 0.0.0.0/0 le 32
ip prefix-list BGP_OUT1 seq 10 permit 10.0.1.0/24
ip prefix-list BGP_OUT1 seq 20 permit 10.0.2.0/24
ip prefix-list BGP_OUT2 seq 10 permit 10.0.3.0/24
ip prefix-list BGP_OUT2 seq 20 permit 10.0.4.0/24
!
route-map BGP_OUT permit 10
 match ip address prefix-list BGP_OUT1
 set ip next-hop 10.1.0.4
exit
!
route-map BGP_OUT permit 20
 match ip address prefix-list BGP_OUT2
 set ip next-hop 10.2.0.4
exit
!
route-map BGP_IN permit 10
 match ip address prefix-list BGP_IN
exit
```

The FRR advertises the network prefixes in BGP to the route server only if the networks are reachable in IGP; in the configuration this is achieved with static routes:
```console
ip route 10.0.1.0/24 10.101.0.33
ip route 10.0.2.0/24 10.101.0.33
ip route 10.0.3.0/24 10.101.0.33
ip route 10.0.4.0/24 10.101.0.33
```
where 10.101.0.33 is the IP address of the default gateway in nvasubnet.

Some useful commands:
* show bgp summary
* show bgp nexthop
* show ip bgp
* from your OS shell: ip route

### Debug messages

A debug command does not cause any terminal output in vtysh because vtysh doesn't currently support log monitoring. That's also why **terminal monitor** is missing from vtysh - the command does exist on telnet, and does work there.
Let's follow the process to activate bgp debug.

1. configure logging to a file, inside the vtysh (config): 
```console
nva(config)# log file /var/log/frr/bgpd.log 
```
FRR automatically defaults to severity 7 (debug) logging.

2. Restart FRR (systemctl restart frr) 
3. Turn on debugs for BGP in vtysh: 
```console
 nva# debug bgp neighbor-events
 nva# debug bgp keepalives
 ```
4. Check the log file /var/log/frr/bgpd.log
 
**NOTE:**
To write debug messages to the log file, you must run the log syslog debug command to configure FRR with syslog severity 7 (debug); otherwise, when you issue a debug command such as, "debug bgp neighbor-events", no output is sent to /var/log/frr/frr.log. 
However, when you manually define a log target with the log file /var/log/frr/debug.log command, FRR automatically defaults to severity 7 (debug) logging and the output is logged to /var/log/frr/debug.log.

### BGP Timers

```console
neighbor <IP_peer> timers <keep-alive> <hold-down>
```
In route server the keep-alive and hold-down timers are fixed:  keep-alive timer is set to 60 seconds and the hold-down timer 180 seconds.

## <a name="Azure firewall"></a>4. Azure firewall
By default, AzureFirewallSubnet has a 0.0.0.0/0 route with the NextHopType value set to Internet.

Azure Firewall must have direct Internet connectivity. If your AzureFirewallSubnet learns a default route to your on-premises network via BGP, or you associate a UDR to the AzureFirewallSubnet, you must override that with a 0.0.0.0/0 UDR with the NextHopType value set as Internet to maintain direct Internet connectivity. 
By default, Azure Firewall doesn't support forced tunnelling to an on-premises network.

The Network Rule Collection in firewall policy doesn't use IP Groups, but the major private network 10.0.0.0/8 as source and destination. The easy approach is doable in test environment, but the security policy should be reviewed in production environment with better customization. 

## <a name="routes"></a>5. Routes

### vmspoke1 effective routes
| Source  | State   | Address Prefixes | Next Hop Type     | Next Hop IP Address | User Defined Route Name |
| ------- | ------- | ---------------- | ----------------- | ------------------- | ----------------------- |
| Default | Active  | 10.0.1.0/24      | Virtual network   |                     | |
| Default | Active  | 10.1.0.0/24      | VNet peering      |                     | |
| Default | Invalid | 0.0.0.0/0        | Internet          |                     | |
| User    | Active  | 0.0.0.0/0        | Virtual appliance | 10.1.0.4            | defaultRoute-to-azfw    |

### vmspoke3 effective routes
| Source  | State   | Address Prefixes | Next Hop Type     | Next Hop IP Address | User Defined Route Name |
| ------- | ------- | ---------------- | ----------------- | ------------------- | ----------------------- |
| Default | Active  | 10.0.3.0/24      | Virtual network   |                     | |
| Default | Active  | 10.2.0.0/24      | VNet peering      |                     | |
| Default | Invalid | 0.0.0.0/0        | Internet          |                     | |
| User    | Active  | 0.0.0.0/0        | Virtual appliance | 10.2.0.4            | defaultRoute-to-azfw    |

### ExpressRoute Gateway 
```powershell
Get-AzVirtualNetworkGatewayAdvertisedRoute -VirtualNetworkGatewayName $gtwName -ResourceGroupName $rgName -peer 10.101.0.228 | ft

LocalAddress Network       NextHop      SourcePeer Origin AsPath      Weight
------------ -------       -------      ---------- ------ ------      ------
10.101.0.237 10.101.0.0/24 10.101.0.237            Igp    65515            0
10.101.0.237 10.2.0.0/24   10.101.0.237            Igp    65515            0
10.101.0.237 10.1.0.0/24   10.101.0.237            Igp    65515            0
10.101.0.237 10.0.4.0/24   10.101.0.237            Igp    65515-65001      0
10.101.0.237 10.0.3.0/24   10.101.0.237            Igp    65515-65001      0
10.101.0.237 10.0.2.0/24   10.101.0.237            Igp    65515-65001      0
10.101.0.237 10.0.1.0/24   10.101.0.237            Igp    65515-65001      0


Get-AzVirtualNetworkGatewayLearnedRoute -VirtualNetworkGatewayName $gtwName -ResourceGroupName $rgName  | ft

LocalAddress Network       NextHop      SourcePeer   Origin  AsPath      Weight
------------ -------       -------      ----------   ------  ------      ------
10.101.0.236 10.101.0.0/24              10.101.0.236 Network              32768
10.101.0.236 10.2.0.0/24                10.101.0.236 Network              32768
10.101.0.236 10.1.0.0/24                10.101.0.236 Network              32768
10.101.0.236 10.11.30.0/24 10.101.0.228 10.101.0.228 EBgp    12076-12076  32769
10.101.0.236 10.11.30.0/24 10.101.0.229 10.101.0.229 EBgp    12076-12076  32769
10.101.0.236 10.12.30.0/24 10.101.0.228 10.101.0.228 EBgp    12076-12076  32769
10.101.0.236 10.12.30.0/24 10.101.0.229 10.101.0.229 EBgp    12076-12076  32769
10.101.0.236 10.2.30.0/25  10.101.0.228 10.101.0.228 EBgp    12076-65021  32769
10.101.0.236 10.0.1.0/24   10.1.0.4     10.101.0.4   IBgp    65001        32768
10.101.0.236 10.0.1.0/24   10.1.0.4     10.101.0.5   IBgp    65001        32768
10.101.0.236 10.0.2.0/24   10.1.0.4     10.101.0.4   IBgp    65001        32768
10.101.0.236 10.0.2.0/24   10.1.0.4     10.101.0.5   IBgp    65001        32768
10.101.0.236 10.0.3.0/24   10.2.0.4     10.101.0.4   IBgp    65001        32768
10.101.0.236 10.0.3.0/24   10.2.0.4     10.101.0.5   IBgp    65001        32768
10.101.0.236 10.0.4.0/24   10.2.0.4     10.101.0.4   IBgp    65001        32768
10.101.0.236 10.0.4.0/24   10.2.0.4     10.101.0.5   IBgp    65001        32768
10.101.0.236 10.11.30.0/24 10.101.0.228 10.101.0.4   IBgp    12076-12076  32768
10.101.0.236 10.12.30.0/24 10.101.0.228 10.101.0.4   IBgp    12076-12076  32768
```
- address space of the spoke1 10.0.1.0/24 is reachable across the next-hop IP: 10.1.0.4 (azfw1)
- address space of the spoke2 10.0.2.0/24 is reachable across the next-hop IP: 10.1.0.4 (azfw1)
- address space of the spoke1 10.0.3.0/24 is reachable across the next-hop IP: 10.2.0.4 (azfw2)
- address space of the spoke2 10.0.4.0/24 is reachable across the next-hop IP: 10.2.0.4 (azfw2)

### Route Server

```powershell
Get-AzRouteServerPeerLearnedRoute -ResourceGroupName $rgName -RouteServerName $rsName -PeerName $bgpPeerName |ft

LocalAddress Network     NextHop  SourcePeer  Origin AsPath Weight
------------ -------     -------  ----------  ------ ------ ------
10.101.0.4   10.0.1.0/24 10.1.0.4 10.101.0.50 EBgp   65001   32768
10.101.0.4   10.0.2.0/24 10.1.0.4 10.101.0.50 EBgp   65001   32768
10.101.0.4   10.0.3.0/24 10.2.0.4 10.101.0.50 EBgp   65001   32768
10.101.0.4   10.0.4.0/24 10.2.0.4 10.101.0.50 EBgp   65001   32768
10.101.0.5   10.0.1.0/24 10.1.0.4 10.101.0.50 EBgp   65001   32768
10.101.0.5   10.0.2.0/24 10.1.0.4 10.101.0.50 EBgp   65001   32768
10.101.0.5   10.0.3.0/24 10.2.0.4 10.101.0.50 EBgp   65001   32768
10.101.0.5   10.0.4.0/24 10.2.0.4 10.101.0.50 EBgp   65001   32768

Get-AzRouteServerPeerAdvertisedRoute -ResourceGroupName $rgName -RouteServerName $rsName -PeerName $bgpPeerName |ft

LocalAddress Network       NextHop    SourcePeer Origin AsPath            Weight
------------ -------       -------    ---------- ------ ------            ------
10.101.0.4   10.101.0.0/24 10.101.0.4            Igp    65515                  0
10.101.0.4   10.2.0.0/24   10.101.0.4            Igp    65515                  0
10.101.0.4   10.1.0.0/24   10.101.0.4            Igp    65515                  0
10.101.0.4   10.11.30.0/24 10.101.0.4            Igp    65515-12076-12076      0
10.101.0.4   10.12.30.0/24 10.101.0.4            Igp    65515-12076-12076      0
10.101.0.4   10.2.30.0/25  10.101.0.4            Igp    65515-12076-65021      0
10.101.0.5   10.101.0.0/24 10.101.0.5            Igp    65515                  0
10.101.0.5   10.2.0.0/24   10.101.0.5            Igp    65515                  0
10.101.0.5   10.1.0.0/24   10.101.0.5            Igp    65515                  0
10.101.0.5   10.11.30.0/24 10.101.0.5            Igp    65515-12076-12076      0
10.101.0.5   10.12.30.0/24 10.101.0.5            Igp    65515-12076-12076      0
10.101.0.5   10.2.30.0/25  10.101.0.5            Igp    65515-12076-65021      0
```
10.0.1.0/24: address space of the spoke1
10.0.2.0/24: address space of the spoke2
10.0.3.0/24: address space of the spoke3
10.0.4.0/24: address space of the spoke4
10.11.30.0/24: network prefix advertised from a remote vnet linked to the ExpressRoute circuit (hairpinning propagation)
10.12.30.0/24: network prefix advertised from a remote vnet linked to the ExpressRoute circuit (hairpinning propagation)
10.2.30.0/25: on-premises network advertised from edge routers with ASN 65021

### BGP routing in NVA
```console
nva# show ip bgp
BGP table version is 4, local router ID is 10.101.0.50, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.1.0/24      0.0.0.0                  0         32768 i
*> 10.0.2.0/24      0.0.0.0                  0         32768 i
*> 10.0.3.0/24      0.0.0.0                  0         32768 i
*> 10.0.4.0/24      0.0.0.0                  0         32768 i
   10.1.0.0/24      10.101.0.5                             0 65515 i
                    10.101.0.4                             0 65515 i
   10.2.0.0/24      10.101.0.5                             0 65515 i
                    10.101.0.4                             0 65515 i
   10.2.30.0/25     10.101.0.5                             0 65515 12076 65021 i
                    10.101.0.4                             0 65515 12076 65021 i
   10.11.30.0/24    10.101.0.5                             0 65515 12076 12076 i
                    10.101.0.4                             0 65515 12076 12076 i
   10.12.30.0/24    10.101.0.5                             0 65515 12076 12076 i
                    10.101.0.4                             0 65515 12076 12076 i
   10.101.0.0/24    10.101.0.5                             0 65515 i
                    10.101.0.4                             0 65515 i

Displayed  10 routes and 16 total paths



nva# show bgp summary

IPv4 Unicast Summary (VRF default):
BGP router identifier 10.101.0.50, local AS number 65001 vrf-id 0
BGP table version 4
RIB entries 19, using 3496 bytes of memory
Peers 2, using 1446 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
10.101.0.4      4      65515      6356      5579        0    0    0 00:45:02            6        4 N/A
10.101.0.5      4      65515      6359      5571        0    0    0 3d03h42m            6        4 N/A

Total number of neighbors 2
```
## <a name="routes"></a>6. Packet capture (pcap) in NVA
1. Login in the nva and run the tcpdump to capture the BGP packet between the NVA and the route server instance with IP 10.101.0.4:

```bash
root@nva:~# tcpdump -i eth0  'host 10.101.0.4' -w bgp.cap
```

2. login in vtysh shell to shudonw the BGP session between the NVA and 10.101.0.4:
```console
vtysh
nva# configure terminal 
nva(config)#
nva(config)# router bgp 65001
nva(config-router)# neighbor 10.101.0.4 shutdown
nva(config-router)# no neighbor 10.101.0.4 shutdown 
```
3. stop the tcpdump capture; a file bgp.cap is generated in the local folder of NVA.
4. copy the bgp.cap file from the NVA to a windows host with wireshark installed. 
5. by wireshark open the bgp.cap and set a display filter to "bgp"

wireshark with BGP display filtering is shown below; in the picture is selected the BGP update message from the NVA (10.101.0.50) to the route server instance 10.101.0.4:  
[![4]][4]

Two update messages are sent from NVA to the router server; let's see the content of the UDATE message.
The first update message shows the following Path attributes:


[![5]][5]

- Path Attribute - Origin: IGP
- Path Attribute - AS_PATH: 65001 (ASN of the NVA)
- Path attribute - NEXT_HOP: 10.1.0.4 (IP address of azfw1)
- Network Layer Reachability Information (NLRI):
  - 10.0.1.0/24  (address space of the spoke1)
  - 10.0.2.0/24  (address space of the spoke2)

The second message is displayed below:

[![6]][6]

- Path Attribute - Origin: IGP
- Path Attribute - AS_PATH: 65001 (ASN of the NVA)
- Path attribute - NEXT_HOP: 10.20.4 (IP address of azfw2)
- Network Layer Reachability Information (NLRI):
  - 10.0.3.0/24  (address space of the spoke1)
  - 10.0.4.0/24  (address space of the spoke2)

## <a name="routes"></a>7. Checking the transit by tcptraceroute

```console
root@vmspoke1:~# traceroute -p 80 10.0.2.10
traceroute to 10.0.2.10 (10.0.2.10), 30 hops max, 60 byte packets
 1  10.1.0.6 (10.1.0.6)  3.509 ms 10.1.0.7 (10.1.0.7)  3.344 ms 10.1.0.6 (10.1.0.6)  3.525 ms
 2  10.0.2.10 (10.0.2.10)  6.138 ms *  6.112 ms

root@vmspoke1:~# traceroute -p 80 10.0.3.10
traceroute to 10.0.3.10 (10.0.3.10), 30 hops max, 60 byte packets
 1  10.1.0.7 (10.1.0.7)  2.539 ms  2.516 ms 10.1.0.6 (10.1.0.6)  2.193 ms
 2  10.2.0.8 (10.2.0.8)  4.751 ms  4.736 ms  4.720 ms
 3  10.0.3.10 (10.0.3.10)  7.037 ms  7.023 ms  7.010 ms

 root@vmspoke1:~# traceroute -p 80 10.0.4.10
traceroute to 10.0.4.10 (10.0.4.10), 30 hops max, 60 byte packets
 1  10.1.0.6 (10.1.0.6)  2.471 ms 10.1.0.7 (10.1.0.7)  2.332 ms 10.1.0.6 (10.1.0.6)  2.420 ms
 2  10.2.0.8 (10.2.0.8)  3.826 ms 10.2.0.7 (10.2.0.7)  4.203 ms 10.2.0.8 (10.2.0.8)  3.798 ms
 3  10.0.4.10 (10.0.4.10)  5.829 ms * *

root@vmspoke1:~# traceroute -p 80 10.2.30.10
traceroute to 10.2.30.10 (10.2.30.10), 30 hops max, 60 byte packets
 1  10.1.0.7 (10.1.0.7)  2.953 ms 10.1.0.6 (10.1.0.6)  2.816 ms  2.802 ms
 2  10.101.0.228 (10.101.0.228)  70.488 ms * *
```
## <a name="caveats"></a>8. Caveats/limitations
The network configuration described in the article has some limitations.
1. the route server can receive in BGP max 1000 network prefixes and advertised max 500 network prefixes to the Expressroute Gateway. The limitation imposes a restriction on total number of spoke vnets. In case of a single address space of each spoke vnet, it will possible to create a maximum total number of 500 spoke vnets in peering with hub1 and hub2.
2. the Azure firewall has a max throughput of 30Gbps; the traffic in transit across the firewall for the communication inter-spoke is cap at 30Gbps.


`Tags: route server, hub-spoke vnets`
`date: 18-06-22`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/network-diagram2.png "tcp flow transit from vm2 to vm3"
[3]: ./media/routing.png "routing"
[4]: ./media/cap1.png "tcpdump capture in nva"
[5]: ./media/cap2.png "tcpdump capture in nva"
[6]: ./media/cap3.png "tcpdump capture in nva"
<!--Link References-->

