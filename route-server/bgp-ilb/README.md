<properties
pageTitle= 'BGP peering through an internal load balancer'
description= "BGP peering through an internal load balancer"
documentationcenter: na
services=""
documentationCenter="na"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="na"
   ms.date="18/11/2021"
   ms.author="fabferri" />

## BGP peering through an internal load balancer

The article walks you through a configuration with three NVAs: one NVA in the frontend subnet establish BGP session with NVA in the backend pool of the load balancer. In BGP advertisement the NVAs in the backend pool set as next-hop IP, the frontend IP of the internal load balancer (LB).  

The network diagram is reported below:

[![1]][1]

The deployment use Cisco CSR as NVAs:
* **csr1**: it doesn't change the next-hop IP in BGP updates
* **csr2**: in the BGP updates, the next-hop IP is set to the frontend IP of the LB
* **csr3**: in the BGP updates, the next-hop IP is set to the frontend IP of the LB

The static routes in the cisco CSRs are important to define the interface the BGP advertisement has to establish the BGP peering:
- csr1 the peering is established through the nic1:
   * ip route 10.0.3.0 255.255.255.0 10.0.2.1
   * ip route 10.0.5.0 255.255.255.0 10.0.2.1

<br>

- csr2 the peering is established through the nic1:
   * ip route 10.0.2.0 255.255.255.0 10.0.5.1

<br>

- csr3 the peering is established through the nic1:
   * ip route 10.0.2.0 255.255.255.0 10.0.5.1


<br>
To keep simple the ARM template compact the nic associated with the CSRs are created in the loop with reference to the LB:

```json
"ipConfigurations": [
    {
        "name": "ipconf-nic1",
        "properties": {
            "privateIPAllocationMethod": "Static",
            "privateIPAddress": "[variables('csrArray')[copyIndex()].subnet2csrAddress]",
            "subnet": {
                "id": "[resourceId('Microsoft.Network/virtualNetworks/subnets', variables('csrArray')[copyIndex()].vnetName, variables('csrArray')[copyIndex()].subnet2Name )]"
            },
            "loadBalancerBackendAddressPools": "[if(equals(variables('csrArray')[copyIndex()].loadBalancerBackendAddressPools, ''), json('null'), variables('csrArray')[copyIndex()].loadBalancerBackendAddressPools)]"
        }
    }
]
```
The **"loadBalancerBackendAddressPools"** is set to **json('null')** if the **variables('csrArray')[copyIndex()].loadBalancerBackendAddressPools** is empty.
The function resolves the creation of the nic1 in the csr1, that's no associated with the backendpool of the LB. 

**Files:**
| File name           | Description                                                   |
| ------------------- |-------------------------------------------------------------- |
| **lb.json**         | ARM template to deploy th Azure VNet, NVAs and VM             |
| **lb.ps1**          | powershell script to run **lb.json**                          |


 
> **[!NOTE]**
>
> Before spinning up the ARM template you should edit the file **lb.ps1** and customize the variables:
> * **$subscriptionName**: name of your Azure subscription 
> * **$adminUsername**: the administrator username of the Azure VM 
> * **$adminPassword**: the administrator password of the Azure VM 
> * **$mngIP**: the management public IP address to connect to the CSRs and Azure VM in SSH
> 

<br>

As reported in the Cisco documentation:

1. Time to Live (TTL) on eBGP packets is set to one. BGP packets drop in transit if a multihop eBGP session is attempted (TTL on IBGP packets is set to 255, which allows for multihop sessions).

2. in outgoing EBGP updates, the BGP next hop is changed to router’s own IP address (source address of the EBGP session). You can always set the BGP next hop to any value you like with an outbound route-map. EBGP next hop is not changed if the BGP next hop in the BGP table belongs to the same IP subnet as the EBGP neighbor to which the update is sent. In our configuration a route-map is required to change the BGP next-hop IP address:
```
router bgp 65010
  address-family ipv4
    neighbor 10.0.2.10 route-map LB out

route-map LB permit 10
 set community 11111:22222
 set ip next-hop 10.0.3.10
```

The ARM template sets as healtprobe message the TCP port 80. The csr1 and crs2 answer to the HTTP requests becasue the HTTP server is set UP in the cofiguration:
```
ip http server
```

## <a name="csr1 configuration"></a>1. snippet csr1 configuration
```console
hostname csr1
!
...
!
interface GigabitEthernet1
 ip address dhcp
 ip nat outside
 negotiation auto
 no mop enabled
 no mop sysid
!
interface GigabitEthernet2
 ip address dhcp
 negotiation auto
 no mop enabled
 no mop sysid
!
router bgp 65001
 bgp router-id interface GigabitEthernet2
 bgp log-neighbor-changes
 neighbor 10.0.5.10 remote-as 65010
 neighbor 10.0.5.10 ebgp-multihop 5
 neighbor 10.0.5.10 update-source GigabitEthernet2
 neighbor 10.0.5.11 remote-as 65010
 neighbor 10.0.5.11 ebgp-multihop 5
 neighbor 10.0.5.11 update-source GigabitEthernet2
 !
 address-family ipv4
  network 10.0.1.0 mask 255.255.255.0
  network 10.0.2.0 mask 255.255.255.0
  neighbor 10.0.5.10 activate
  neighbor 10.0.5.10 next-hop-self
  neighbor 10.0.5.10 soft-reconfiguration inbound
  neighbor 10.0.5.11 activate
  neighbor 10.0.5.11 next-hop-self
  neighbor 10.0.5.11 soft-reconfiguration inbound
 exit-address-family
!
...
ip http server
ip http banner
ip http secure-server
ip http banner-path Welcome
!
ip bgp-community new-format
ip route 0.0.0.0 0.0.0.0 10.0.1.1
ip route 10.0.3.0 255.255.255.0 10.0.2.1
ip route 10.0.5.0 255.255.255.0 10.0.2.1
!
line vty 0 4
 exec-timeout 25 0
 transport input ssh
...

```
## <a name="csr2 configuration"></a>2. snippet csr2 configuration

```console
hostname csr2
!
...
interface GigabitEthernet1
 ip address dhcp
 ip nat outside
 negotiation auto
 no mop enabled
 no mop sysid
!
interface GigabitEthernet2
 ip address dhcp
 negotiation auto
 no mop enabled
 no mop sysid
!
router bgp 65010
 bgp router-id interface GigabitEthernet2
 bgp log-neighbor-changes
 neighbor 10.0.2.10 remote-as 65001
 neighbor 10.0.2.10 ebgp-multihop 5
 neighbor 10.0.2.10 update-source GigabitEthernet2
 !
 address-family ipv4
  network 10.0.4.0 mask 255.255.255.0
  network 10.0.5.0 mask 255.255.255.0
  neighbor 10.0.2.10 activate
  neighbor 10.0.2.10 send-community
  neighbor 10.0.2.10 soft-reconfiguration inbound
  neighbor 10.0.2.10 route-map LB out
 exit-address-family
!
...
ip http server
ip http banner
ip http secure-server
ip http path welcome
!
ip bgp-community new-format
ip route 0.0.0.0 0.0.0.0 10.0.4.1
ip route 10.0.2.0 255.255.255.0 10.0.5.1
!
route-map LB permit 10
 set community 11111:22222
 set ip next-hop 10.0.3.10
!
line vty 0 4
 exec-timeout 25 0
 transport input ssh
....

```

## <a name="csr3 configuration"></a>3. snippet csr3 configuration

```console
hostname csr3
!
...
!
interface GigabitEthernet1
 ip address dhcp
 ip nat outside
 negotiation auto
 no mop enabled
 no mop sysid
!
interface GigabitEthernet2
 ip address dhcp
 negotiation auto
 no mop enabled
 no mop sysid
!
router bgp 65010
 bgp router-id interface GigabitEthernet2
 bgp log-neighbor-changes
 neighbor 10.0.2.10 remote-as 65001
 neighbor 10.0.2.10 ebgp-multihop 5
 neighbor 10.0.2.10 update-source GigabitEthernet2
 !
 address-family ipv4
  network 10.0.4.0 mask 255.255.255.0
  network 10.0.5.0 mask 255.255.255.0
  neighbor 10.0.2.10 activate
  neighbor 10.0.2.10 send-community
  neighbor 10.0.2.10 soft-reconfiguration inbound
  neighbor 10.0.2.10 route-map LB out
 exit-address-family
!
...
ip http server
ip http banner
ip http secure-server
ip http banner-path welcome
!
ip bgp-community new-format
ip route 0.0.0.0 0.0.0.0 10.0.4.1
ip route 10.0.2.0 255.255.255.0 10.0.5.1
!
route-map LB permit 10
 set community 11111:22222
 set ip next-hop 10.0.3.10
!
...
line vty 0 4
 exec-timeout 25 0
 transport input ssh
...

```
## <a name="BGP update message"></a>4. Check the next-hop IP in csr1

```console
csr1#show bgp ipv4 unicast 10.0.5.10
BGP routing table entry for 10.0.5.0/24, version 9
Paths: (1 available, best #1, table default, RIB-failure(17))
  Not advertised to any peer
  Refresh Epoch 1
  65010, (received & used)
    10.0.3.10 from 10.0.5.10 (10.0.5.10)
      Origin IGP, metric 0, localpref 100, valid, external, best
      rx pathid: 0, tx pathid: 0x0
      Updated on Nov 16 2021 10:48:10 UTC

csr1#show ip bgp 10.0.5.10
BGP routing table entry for 10.0.5.0/24, version 9
Paths: (1 available, best #1, table default, RIB-failure(17))
  Not advertised to any peer
  Refresh Epoch 1
  65010, (received & used)
    10.0.3.10 from 10.0.5.10 (10.0.5.10)
      Origin IGP, metric 0, localpref 100, valid, external, best
      rx pathid: 0, tx pathid: 0x0
      Updated on Nov 16 2021 10:48:10 UTC
```
The commands above show that next-hop IP to reach out the peer 10.0.5.10 is the frontend IP 10.0.3.10 of the load balancer.

## <a name="csr1 routing table"></a>5. Routing table of the csr1
```
csr1#show ip bgp
BGP table version is 9, local router ID is 10.0.2.10
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.0.1.0/24      0.0.0.0                  0         32768 i
 *>   10.0.2.0/24      0.0.0.0                  0         32768 i
 *    10.0.4.0/24      10.0.3.10                0             0 65010 i
 *>                    10.0.3.10                0             0 65010 i
 r    10.0.5.0/24      10.0.3.10                0             0 65010 i
 r>                    10.0.3.10                0             0 65010 i
```

## <a name="BGP update message"></a>6. Trigger the update BGP message

To see the message of debug on the vty session:
1. disable the console logging (**no logging console**)
2. activate the loggin in the terminal (**terminal monitor**)
3. to watch the update BGP messages use the command: **debug ip bgp updates**
4. to trigger the update BGP message clear the existing BGP message by command: **clear ip bgp \***

```
csr2#terminal monitor
csr2#conf t
Enter configuration commands, one per line.  End with CNTL/Z.
csr2(config)#no logging console
csr2(config)#exit
*Nov 16 10:46:47.305: %SYS-5-LOG_CONFIG_CHANGE: Console logging disabled
csr2#
*Nov 16 10:46:49.221: %SYS-5-CONFIG_I: Configured from console by edge on vty0
csr2#debug ip bgp updates
BGP updates debugging is on for address family: IPv4 Unicast
csr2#clear ip bgp *
csr2#
*Nov 16 10:47:30.973: %BGP-3-NOTIFICATION_MANY: sent to 1 sessions 6/4 (Administrative Reset) for all peers
*Nov 16 10:47:30.976: %BGP-5-ADJCHANGE: neighbor 10.0.2.10 Down User reset
*Nov 16 10:47:30.976: %BGP_SESSION-5-ADJCHANGE: neighbor 10.0.2.10 IPv4 Unicast topology base removed from session  User reset
*Nov 16 10:47:39.248: %BGP-5-ADJCHANGE: neighbor 10.0.2.10 Up
*Nov 16 10:47:39.248: BGP(0): 10.0.2.10 rcvd UPDATE w/ attr: nexthop 10.0.2.10, origin i, metric 0, merged path 65001, AS_PATH
*Nov 16 10:47:39.248: BGP(0): 10.0.2.10 rcvd 10.0.1.0/24
*Nov 16 10:47:39.248: BGP(0): 10.0.2.10 rcvd 10.0.2.0/24
*Nov 16 10:47:39.612: BGP(0): Revise route installing 1 of 1 routes for 10.0.1.0/24 -> 10.0.2.10(global) to main IP table
*Nov 16 10:47:39.612: BGP(0): Revise route installing 1 of 1 routes for 10.0.2.0/24 -> 10.0.2.10(global) to main IP table
*Nov 16 10:47:58.720: BGP(0): sourced route for 10.0.4.0/24 created
*Nov 16 10:47:58.720: BGP(0): sourced route for 10.0.4.0/24 path 0x7F521C2C1D88 id 0 gw 0.0.0.0 created (weight 32768)
*Nov 16 10:47:58.720: BGP(0): local route 10.0.4.0/24 added gw 0.0.0.0
*Nov 16 10:47:58.720: BGP(0): sourced route for 10.0.5.0/24 created
*Nov 16 10:47:58.720: BGP(0): sourced route for 10.0.5.0/24 path 0x7F521C2C1CF8 id 0 gw 0.0.0.0 created (weight 32768)
*Nov 16 10:47:58.720: BGP(0): local route 10.0.5.0/24 added gw 0.0.0.0
*Nov 16 10:47:58.726: BGP: topo global:IPv4 Unicast:base Remove_fwdroute for 10.0.4.0/24
*Nov 16 10:47:58.726: BGP: topo global:IPv4 Unicast:base Remove_fwdroute for 10.0.5.0/24
*Nov 16 10:48:10.333: BGP(0): 10.0.2.10 NEXT_HOP is set to 10.0.3.10 by policy for net 10.0.4.0/24,
*Nov 16 10:48:10.333: BGP(0): (base) 10.0.2.10 send UPDATE (format) 10.0.4.0/24, next 10.0.3.10, metric 0, path Local
*Nov 16 10:48:10.333: BGP(0): 10.0.2.10 NEXT_HOP is set to 10.0.3.10 by policy for net 10.0.5.0/24,
csr2#
```
The log messages shows that csr2 advertises the network 10.0.4.0/24 with next-hop IP: 10.0.3.10 (frontend IP of the LB). 


## <a name="check BGP communities in csr1"></a>7. check BGP communities in csr1

```console
csr1#show bgp 10.0.4.0/24
% Command accepted but obsolete, unreleased or unsupported; see documentation.
BGP routing table entry for 10.0.4.0/24, version 14
Paths: (2 available, best #2, table default)
  Advertised to update-groups:
     6
  Refresh Epoch 1
  65010, (received & used)
    10.0.3.10 from 10.0.5.11 (10.0.5.11)
      Origin IGP, metric 0, localpref 100, valid, external
      Community: 11111:22222
      rx pathid: 0, tx pathid: 0
      Updated on Nov 16 2021 21:06:30 UTC
  Refresh Epoch 1
  65010, (received & used)
    10.0.3.10 from 10.0.5.10 (10.0.5.10)
      Origin IGP, metric 0, localpref 100, valid, external, best
      Community: 11111:22222
      rx pathid: 0, tx pathid: 0x0
      Updated on Nov 16 2021 18:22:20 UTC

csr1#show bgp 10.0.5.0/24
% Command accepted but obsolete, unreleased or unsupported; see documentation.
BGP routing table entry for 10.0.5.0/24, version 15
Paths: (2 available, best #2, table default, RIB-failure(17))
  Advertised to update-groups:
     6
  Refresh Epoch 1
  65010, (received & used)
    10.0.3.10 from 10.0.5.11 (10.0.5.11)
      Origin IGP, metric 0, localpref 100, valid, external
      Community: 11111:22222
      rx pathid: 0, tx pathid: 0
      Updated on Nov 16 2021 21:06:30 UTC
  Refresh Epoch 1
  65010, (received & used)
    10.0.3.10 from 10.0.5.10 (10.0.5.10)
      Origin IGP, metric 0, localpref 100, valid, external, best
      Community: 11111:22222
      rx pathid: 0, tx pathid: 0x0
      Updated on Nov 16 2021 18:22:20 UTC

```

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"

<!--Link References-->

