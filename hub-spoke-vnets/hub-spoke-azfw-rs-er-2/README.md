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
The article describes a scenario with hub-spoke vnets in peering; the high level diagram is shown below:

[![1]][1]


The network diagram with details is reported below:

[![2]][2]

The configuration aims to make intercommunication any-to-any with traffic in transit through the Azure firewalls. The routing has an easy configuration because most of work is done by the NVA and Route Server and it doesn't require complex UDRs. 
* all the UDRs applied to the subnets in the spoke vnets have only the default route 0.0.0.0/0, pointing to the nearest Azure firewall
* the Azure firewall subnets do not have any UDR

To keep the deployment simple, the firewall policies have two network security rules: 
* a network rule collection with multiple entries to allow traffic between spoke vnets

| Name    | Source type | Source       | Protocol | Destination Ports | Destination Type | Destination |
| ------- | ----------- | ------------ | -------- | ----------------- | ---------------- | ----------- |
| spoke1  | IP Address  | 10.0.1.0/24  | Any      | \*                | IP Address       | 10.0.0.0/8  |
| spoke2  | IP Address  | 10.0.2.0/24  | Any      | \*                | IP Address       | 10.0.0.0/8  |
| spoke3  | IP Address  | 10.0.3.0/24  | Any      | \*                | IP Address       | 10.0.0.0/8  |
| spoke4  | IP Address  | 10.0.4.0/24  | Any      | \*                | IP Address       | 10.0.0.0/8  |
| on-prem | IP Address  | 10.1.34.0/24 | Any      | \*                | IP Address       | 10.0.0.0/8  |

* a network rule collection to allow traffic from 10.0.0.0/8 to internet

| Name                  | Source type | Source     | Protocol | Destination Ports | Destination Type | Destination |
| --------------------- | ----------- | ---------- | -------- | ----------------- | ---------------- | ----------- |
| localnetw-to-internet | IP Address  | 10.0.0.0/8 | Any      | \*                | IP Address       | 0.0.0.0/0   |

Below a network diagram with communication paths:

[![3]][3]

Below some communication paths:
```
spoke1 <--> azfw1 <--> spoke2
spoke1 <--> azfw1 <--> azfw2 <--> spoke3
spoke1 <--> azfw1 <--> azfw2 <--> spoke4
spoke1 <--> azfw1 <--> ER GTW <--> ER circuit <--> on-premises
spoke2 <--> azfw1 <--> azfw2 <--> spoke3
spoke2 <--> azfw1 <--> azfw2 <--> spoke4
spoke2 <--> azfw1 <--> ER GTW <--> ER circuit <--> on-premises
spoke1 <--> hub1vm 
spoke2 <--> hub1vm
spoke3 <--> hub2vm
spoke4 <--> hub2vm
hub1vm <--> hub2vm

```

The NVA in vnet1 is in BGP peering with route server and advertises the networks of the spoke vnets to the route server; in the BGP advertisement the NVA set the IP of the next-hop to the IP address of the Azure firewall:

```console
10.0.1.0/24 next-hop IP address: 10.11.0.4
10.0.2.0/24 next-hop IP address: 10.11.0.4
10.0.3.0/24 next-hop IP address: 10.12.0.4
10.0.4.0/24 next-hop IP address: 10.12.0.4
```
[![4]][4]

The route server receives from NVA the networks of spoke vnets and advertises the received networks to the ExpressRoute Gateway. The ExpressRoute Gateway will advertise the address of spoke vnets (spoke1, spoke2, spoke3 and spoke4) to on-premises.
The IP packets from on-premises network, with destination a spoke vnet, reach out the Expressroute Gateway are forwarded to the proper Azure firewall.


### <a name="list of files"></a>2. Files

| File name                | Description                                                           |
| ------------------------ | --------------------------------------------------------------------- |
| **init.json**            | define the value of input variables required for the full deployment  |
| **01-azfw.json**         | ARM template to deploy spoke vnets, hub vnets,Azure firewalls, Azure bastions, NVA and VMs |
| **01-azfw.ps1**          | powershell script to run **azfw.json**                                |
| **cloud-init.txt**       | cloud-init file to install and configure FRR in the NVA               |
| **02-rs.json**           | ARM template to deploy the Route Server in vnet1, the ExpressRoute Gateway and the connection with the ExpressRoute circuit |
| **02-rs.ps1**            | powershell to script to run **02-rs.json**                            | 
| **03-vnet-peering.json** | ARM template to create vnet peering between hub1-vnet1 and hub2-vnet1 |
| **03vnet-peering.ps1**   | powershell to script to run **03-vnet-peering.json**                  |
| **04-azfw-logs.json**    | ARM template to create a log analytics workspace to store the diagnostic logs of Azure firewalls azfw1, azfw2 |
| **04-azfw-logs.ps1**     | powershell to script to run **04-azfw-logs.json**                     |

To run the project, follow the steps in sequence:
1. change/modify the value of input variables in the file **init.json**
2. run the powershell script **01-azfw.ps1**
3. run the powershell script **02-rs.ps1** 
4. run the powershell script **03-vnet-peering.ps1**

The excution out-of-order of scripts will cause a deployment failure. <br>
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
    "er_subscriptionId1": "AZURE_SUBSCRIPTION_ID_WHERE_IS_DEPLOYED_THE_EXPRESSROUTE_CIRCUIT1",
    "er_resourceGroup1": "RESOUCE_GROUP_NAME_WHERE_IS_DEPLOYED_THE_EXPRESSROUTE_CIRCUIT1",
    "er_circuitName1": "NAME_OF_EXPRESSROUTE_CIRCUIT1",
    "er_authorizationKey1": "AUTHORIZATION_KEY_TO_JOIN_TO_THE_EXPRESSROUTE_CIRCUIT1"
}
```
The ARM template **01-azfw.json** creates Ubuntu VMs in hub1, hub2 and in the spoke vnets and use a customer script extension to install nginx with simple home page. The presence of web server allows an easy check of the communications between VMs. 

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
  neighbor 10.101.0.4 timers 60 180
  neighbor 10.101.0.5 remote-as 65515
  neighbor 10.101.0.5 timers 60 180
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
ip prefix-list BGP_OUT1 seq 10 permit 10.0.1.0/24 
ip prefix-list BGP_OUT1 seq 20 permit 10.0.2.0/24
ip prefix-list BGP_OUT2 seq 10 permit 10.0.3.0/24
ip prefix-list BGP_OUT2 seq 20 permit 10.0.4.0/24  
ip prefix-list BGP_IN seq 10 permit 0.0.0.0/0 le 32
!
route-map BGP_OUT permit 10
  match ip address prefix-list BGP_OUT1
  set ip next-hop 10.11.0.4
route-map BGP_OUT permit 20
  match ip address prefix-list BGP_OUT2
  set ip next-hop 10.12.0.4
  exit
!
route-map BGP_IN permit 10
  match ip address prefix-list BGP_IN
  exit
!
```

The FRR advertises the network prefixes in BGP to the route server only if the networks are reachable in IGP; in the configuration this is achieved with static routes:
```console
ip route 10.0.1.0/24 10.101.0.33
ip route 10.0.2.0/24 10.101.0.33
ip route 10.0.3.0/24 10.101.0.33
ip route 10.0.4.0/24 10.101.0.33
```
where 10.101.0.33 is the IP address of the default gateway in **nvasubnet** of the **vnet1**.

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
In Route Server the keep-alive and hold-down timers are fixed:  keep-alive timer is set to 60 seconds and the hold-down timer 180 seconds.

## <a name="Azure firewall"></a>4. Azure firewall
By default, **AzureFirewallSubnet** has a **0.0.0.0/0** route with the <ins>NextHopType</ins> value set to **Internet**.

Azure Firewall must have direct Internet connectivity. If your **AzureFirewallSubnet** learns a default route to your on-premises network via BGP, or you associate a UDR to the **AzureFirewallSubnet**, you must override that with a 0.0.0.0/0 UDR with the NextHopType value set as Internet to maintain direct Internet connectivity. 
By default, Azure Firewall doesn't support forced tunnelling to an on-premises network.

The Network Rule Collection in firewall policy doesn't use IP Groups, but the major private network 10.0.0.0/8 as source and destination. The easy approach is doable in test environment, but the security policy should be reviewed in production environment with better customization. 

## <a name="routes"></a>5. Routes

### vmspoke1 effective routes
| Source  | State   | Address Prefixes | Next Hop Type     | Next Hop IP Address | User Defined Route Name |
| ------- | ------- | ---------------- | ----------------- | ------------------- | ----------------------- |
| Default | Active  | 10.0.1.0/24      | Virtual network   |                     | |
| Default | Active  | 10.11.0.0/24     | VNet peering      |                     | |
| Default | Invalid | 0.0.0.0/0        | Internet          |                     | |
| User    | Active  | 0.0.0.0/0        | Virtual appliance | 10.11.0.4           | defaultRoute-to-azfw    |

### vmspoke3 effective routes
| Source  | State   | Address Prefixes | Next Hop Type     | Next Hop IP Address | User Defined Route Name |
| ------- | ------- | ---------------- | ----------------- | ------------------- | ----------------------- |
| Default | Active  | 10.0.3.0/24      | Virtual network   |                     | |
| Default | Active  | 10.12.0.0/24     | VNet peering      |                     | |
| Default | Invalid | 0.0.0.0/0        | Internet          |                     | |
| User    | Active  | 0.0.0.0/0        | Virtual appliance | 10.12.0.4           | defaultRoute-to-azfw    |

### ExpressRoute Gateway 
```powershell
Get-AzVirtualNetworkGatewayAdvertisedRoute -VirtualNetworkGatewayName $gtwName -ResourceGroupName $rgName -peer 10.101.0.228 | ft

LocalAddress Network       NextHop      SourcePeer Origin AsPath      Weight
------------ -------       -------      ---------- ------ ------      ------
10.101.0.236 10.101.0.0/24 10.101.0.236            Igp    65515            0
10.101.0.236 10.0.1.0/24   10.101.0.236            Igp    65515-65001      0
10.101.0.236 10.0.2.0/24   10.101.0.236            Igp    65515-65001      0
10.101.0.236 10.0.3.0/24   10.101.0.236            Igp    65515-65001      0
10.101.0.236 10.0.4.0/24   10.101.0.236            Igp    65515-65001      0
10.101.0.236 10.12.0.0/23  10.101.0.236            Igp    65515            0
10.101.0.236 10.11.0.0/23  10.101.0.236            Igp    65515            0


Get-AzVirtualNetworkGatewayLearnedRoute -VirtualNetworkGatewayName $gtwName -ResourceGroupName $rgName  | ft

LocalAddress Network       NextHop      SourcePeer   Origin  AsPath      Weight
------------ -------       -------      ----------   ------  ------      ------
10.101.0.236 10.101.0.0/24              10.101.0.236 Network              32768
10.101.0.236 10.0.1.0/24   10.11.0.4    10.101.0.4   IBgp    65001        32768
10.101.0.236 10.0.1.0/24   10.11.0.4    10.101.0.5   IBgp    65001        32768
10.101.0.236 10.0.2.0/24   10.11.0.4    10.101.0.4   IBgp    65001        32768
10.101.0.236 10.0.2.0/24   10.11.0.4    10.101.0.5   IBgp    65001        32768
10.101.0.236 10.0.3.0/24   10.12.0.4    10.101.0.4   IBgp    65001        32768
10.101.0.236 10.0.3.0/24   10.12.0.4    10.101.0.5   IBgp    65001        32768
10.101.0.236 10.0.4.0/24   10.12.0.4    10.101.0.4   IBgp    65001        32768
10.101.0.236 10.0.4.0/24   10.12.0.4    10.101.0.5   IBgp    65001        32768
10.101.0.236 10.1.34.0/25  10.101.0.228 10.101.0.228 EBgp    12076-65020  32769
10.101.0.236 10.1.34.0/25  10.101.0.229 10.101.0.229 EBgp    12076-65020  32769
10.101.0.236 10.12.0.0/23               10.101.0.236 Network              32768
10.101.0.236 10.11.0.0/23               10.101.0.236 Network              32768
```
- address space of the spoke1 10.0.1.0/24 is reachable across the next-hop IP: 10.11.0.4 (azfw1)
- address space of the spoke2 10.0.2.0/24 is reachable across the next-hop IP: 10.11.0.4 (azfw1)
- address space of the spoke1 10.0.3.0/24 is reachable across the next-hop IP: 10.12.0.4 (azfw2)
- address space of the spoke2 10.0.4.0/24 is reachable across the next-hop IP: 10.12.0.4 (azfw2)

### Route Server

```powershell
Get-AzRouteServerPeerLearnedRoute -ResourceGroupName $rgName -RouteServerName $rsName -PeerName $bgpPeerName |ft

LocalAddress Network     NextHop   SourcePeer  Origin AsPath Weight
------------ -------     -------   ----------  ------ ------ ------
10.101.0.4   10.0.1.0/24 10.11.0.4 10.101.0.50 EBgp   65001   32768
10.101.0.4   10.0.2.0/24 10.11.0.4 10.101.0.50 EBgp   65001   32768
10.101.0.4   10.0.3.0/24 10.12.0.4 10.101.0.50 EBgp   65001   32768
10.101.0.4   10.0.4.0/24 10.12.0.4 10.101.0.50 EBgp   65001   32768
10.101.0.5   10.0.1.0/24 10.11.0.4 10.101.0.50 EBgp   65001   32768
10.101.0.5   10.0.2.0/24 10.11.0.4 10.101.0.50 EBgp   65001   32768
10.101.0.5   10.0.3.0/24 10.12.0.4 10.101.0.50 EBgp   65001   32768
10.101.0.5   10.0.4.0/24 10.12.0.4 10.101.0.50 EBgp   65001   32768

Get-AzRouteServerPeerAdvertisedRoute -ResourceGroupName $rgName -RouteServerName $rsName -PeerName $bgpPeerName |ft

LocalAddress Network       NextHop    SourcePeer Origin AsPath            Weight
------------ -------       -------    ---------- ------ ------            ------
10.101.0.4   10.101.0.0/24 10.101.0.4            Igp    65515                  0
10.101.0.4   10.1.34.0/25  10.101.0.4            Igp    65515-12076-65020      0
10.101.0.4   10.12.0.0/23  10.101.0.4            Igp    65515                  0
10.101.0.4   10.11.0.0/23  10.101.0.4            Igp    65515                  0
10.101.0.5   10.101.0.0/24 10.101.0.5            Igp    65515                  0
10.101.0.5   10.1.34.0/25  10.101.0.5            Igp    65515-12076-65020      0
10.101.0.5   10.12.0.0/23  10.101.0.5            Igp    65515                  0
10.101.0.5   10.11.0.0/23  10.101.0.5            Igp    65515                  0
```
- 10.0.1.0/24: address space of the spoke1
- 10.0.2.0/24: address space of the spoke2
- 10.0.3.0/24: address space of the spoke3
- 10.0.4.0/24: address space of the spoke4
- 10.1.34.0/25: on-premises network advertised from edge routers with ASN 65021

### BGP routing in NVA
```console
nva# show ip bgp
BGP table version is 10, local router ID is 10.101.0.50, vrf id 0
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
*> 10.1.34.0/25     10.101.0.4                             0 65515 12076 65020 i
*=                  10.101.0.5                             0 65515 12076 65020 i
*> 10.11.0.0/23     10.101.0.4                             0 65515 i
*=                  10.101.0.5                             0 65515 i
*= 10.12.0.0/23     10.101.0.5                             0 65515 i
*>                  10.101.0.4                             0 65515 i
*= 10.101.0.0/24    10.101.0.5                             0 65515 i
*>                  10.101.0.4                             0 65515 i

Displayed  8 routes and 12 total paths



nva# show bgp summary

IPv4 Unicast Summary (VRF default):
BGP router identifier 10.101.0.50, local AS number 65001 vrf-id 0
BGP table version 10
RIB entries 15, using 2760 bytes of memory
Peers 2, using 1446 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
10.101.0.4      4      65515       356       311        0    0    0 05:07:37            4        4 N/A
10.101.0.5      4      65515       358       311        0    0    0 05:07:37            4        4 N/A

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

wireshark with BGP display filtering is shown below; in the picture is selected the BGP update message route server instance 10.101.0.4 to the NVA (10.101.0.50) :  
[![5]][5]

by update message the route server advertise the hub1, hub2, vnet1 addess spaces.

A second update message is send from the Route Server to the nva to advertise the network 10.1.34.0/25 to the nva:

[![6]][6]

- Path Attribute - Origin: IGP
- Path Attribute - AS_PATH: 65515 12076 65020 
- Path attribute - NEXT_HOP: 10.101.0.4 (IP address of route server)
- Network Layer Reachability Information (NLRI):
  - 10.1.34.0/24  (address space in on-premises)

Two update messages are sent from the nva (10.101.0.50) to the route server (10.101.0.4), see below:

[![7]][7]

- Path Attribute - Origin: IGP
- Path Attribute - AS_PATH: 65001 (ASN of the NVA)
- Path attribute - NEXT_HOP: 10.11.0.4 (IP address of azfw1)
- Network Layer Reachability Information (NLRI):
  - 10.0.1.0/24  (address space of the spoke1)
  - 10.0.2.0/24  (address space of the spoke2)

<br>
- Path Attribute - Origin: IGP
- Path Attribute - AS_PATH: 65001 (ASN of the NVA)
- Path attribute - NEXT_HOP: 10.12.0.4 (IP address of azfw2)
- Network Layer Reachability Information (NLRI):
  - 10.0.3.0/24  (address space of the spoke1)
  - 10.0.4.0/24  (address space of the spoke2)

## <a name="routes"></a>7. Checking the transit by tcptraceroute

```console
root@vmspoke1:~# traceroute -p 80 10.0.2.10
traceroute to 10.0.2.10 (10.0.2.10), 30 hops max, 60 byte packets
 1  10.11.0.6 (10.11.0.6)  4.942 ms 10.11.0.5 (10.11.0.5)  4.908 ms 10.11.0.6 (10.11.0.6)  4.893 ms
 2  10.0.2.10 (10.0.2.10)  6.223 ms * *

root@vmspoke1:~# traceroute -p 80 10.0.3.10
traceroute to 10.0.3.10 (10.0.3.10), 30 hops max, 60 byte packets
 1  10.11.0.6 (10.11.0.6)  2.408 ms  2.384 ms  2.368 ms
 2  10.12.0.5 (10.12.0.5)  4.868 ms 10.12.0.6 (10.12.0.6)  6.476 ms 10.12.0.5 (10.12.0.5)  4.839 ms
 3  * * 10.0.3.10 (10.0.3.10)  6.697 ms

root@vmspoke1:~# traceroute -p 80 10.0.4.10
traceroute to 10.0.4.10 (10.0.4.10), 30 hops max, 60 byte packets
 1  10.11.0.6 (10.11.0.6)  1.917 ms  2.323 ms  2.308 ms
 2  10.12.0.6 (10.12.0.6)  4.253 ms 10.12.0.5 (10.12.0.5)  4.426 ms  4.412 ms
 3  * 10.0.4.10 (10.0.4.10)  5.386 ms  5.372 ms

root@vmspoke1:~# traceroute -p 80 10.1.34.10
traceroute to 10.1.34.10 (10.1.34.10), 30 hops max, 60 byte packets
 1  10.11.0.5 (10.11.0.5)  2.327 ms 10.11.0.6 (10.11.0.6)  2.186 ms 10.11.0.5 (10.11.0.5)  2.278 ms
 2  * 10.101.0.228 (10.101.0.228)  138.422 ms  138.408 ms
 3  * * *
 4  * * *
 5  * * *
 6  * * 10.1.34.10 (10.1.34.10)  138.122 ms
```
## <a name="caveats"></a>8. Caveats/limitations
The network configuration described in the article has some limitations.<br>
A single nva does not provide enough resilience; a potetial failure in the nva or in the BGP peerings with Route Server will cause a communication failure with on-premises networks.    

`Tags: route server, hub-spoke vnets` <br>
`date: 18-06-22` <br>
`date: 02-07-23` <br>

<!--Image References-->

[1]: ./media/high-level-diagram.png "high level network diagram"
[2]: ./media/network-diagram.png "network diagram"
[3]: ./media/network-diagram2.png "tcp flow transit from vm2 to vm3"
[4]: ./media/routing.png "routing"
[5]: ./media/cap1.png "tcpdump capture in nva"
[6]: ./media/cap2.png "tcpdump capture in nva"
[7]: ./media/cap3.png "tcpdump capture in nva"
<!--Link References-->

