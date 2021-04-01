<properties
pageTitle= 'spoke vnet in peering with two hub vnets and Azure route servers'
description= "spoke vnet in peering with two hub vnets and Azure route servers"
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
   ms.date="29/03/2021"
   ms.author="fabferri" />

# Spoke vnet in peering with two hub vnets and Azure route servers
 
The article describes the network configuration which diagram is shown below: 

[![1]][1]

Configuration is based on two hub vnets, vnet1 and vnet2, in peering with spoke vnet named vnet0.

Naming convention: **vnetX-subnetXY** where [**X** is the vnet number, **Y** is the subnet number]
* ExpressRoute circuit1 in Ashburn advertises through ExpressRoute private peering the network 10.2.13.0/25 to the ER Gateway1
* ExpressRoute circuit2 in Ashburn advertises through ExpressRoute private peering the network 10.2.20.0/25 to the ER Gateway2

* Two on-premises networks:
   * on-premises network 10.2.13.0/25 with a VM 10.2.13.10
   * on-premises network 10.2.20.0/25 with a VM 10.2.20.10

   The on-premises networks 10.2.13.0/25 and 10.2.20.0/25 can't communicate each other becasue are associated with two different VRFs.

* vnet1 (deployed in West US2) with address space 10.101.0.0/16 has:
   * ExpressRoute Gateway Standard (deployed in 10.101.5.0/24)
   * csr1 with two interfaces: 
      * one interface (nic0) for management purpose only (10.101.2.10)
      * one interface (nic1) to establish BGP peering with route servers rs1 and rs0
   * a test vm named vm14, connected to the subnet14 (10.101.4.10)
   * a route server in the subnet 10.101.1.0/24 with IPs: [10.101.1.4, 10.101.1.5] 

*	vnet2 (deployed in East US) with address space 10.102.0.0/16 has:
    * ExpressRoute Gateway Standard (deployed in 10.102.5.0/24)
    * csr2 with two interfaces:
      * one interface (nic0) for management purpose only (10.102.2.10)
      * one interface (nic1) to establish BGP peering with route servers (10.102.3.10)
    * a test vm named vm24, connected to the subnet14 (10.102.4.10)
    * route server in the "RouteServerSubnet"  10.102.1.0/24 with IPs: [10.102.1.4, 10.102.1.5] 

* vnet0 (deployed in East US) with address space [10.100.0.0/24, 10.200.0.0/24 ]has:
   * route server in the "RouteServerSubnet"  10.100.0.0/25 with IPs: [10.100.0.4, 10.100.0.5] 
   * vm02 in the subnet 10.100.0.128/25
   * vm03 in the subnet 10.200.0.128/25
   
   vnet0 is a spoke vnet and it is in peering with two hub vnets: vnet1 and vnet2.

* All the route servers are set with **AllowBranchToBranchTraffic** enabled.

* All the vnet peering have the same setup:
   * Traffic to remote virtual network: allow (default)
   * Traffic forwarded from remote virtual network: allow (default)
   * Virtual network gateway or Route Server: none (default)
* There is no UDR in all vnets.


**Files**:
| File name               | Description                                                       |
| ----------------------- | ----------------------------------------------------------------- |
| **01_vnets.json**       | deploy a VNets, ExpressRoute gateways, route server and VMs       |
| **01_vnets.ps1**        | powershell script to run **01_vnets.json**                        |
| **02_connections.json** | Create the Connections between the ExpressRoute Gateways and ExpressRoute Gateways    |
| **02_connections.ps1**  | powershell script to run **02_connections.json**               |
 
> **[!NOTE1]**
>
> Before spinning up the ARM template you should edit the file **01_vnets.ps1** and set:
> * your Azure subscription name in the variable **$subscriptionName**
> * the administrator username of the Azure VM in the variables **$adminUsername**
> * the administrator password of the Azure VM in the variables **$adminPassword**
>

> **[!NOTE2]**
>
> The full deployment is done in sequence: before run **01_vnets.json** and when completed run the second **02_connections.json** 
>

The ARM template  **rs.json** creates the Azure VNet, the route server and configure the BGP connection in route server an Ubuntu 20.04 VM.

## <a name="summary"></a>1. Communication between VMs 
 
 Communication between VMs:
* VMs (vm02, vm03) in spoke vnet (vnet0) can communicate with each VM in hub vnets 
* VMs (vm02, vm03) in spoke vnet (vnet0) can communicate with on-premises ASH-vm13 with transit through ER circuit1.
* VMs (vm02, vm03) in spoke vnet (vnet0) can communicate with on-premises ASH-vm20 with transit through ER circuit2.
* VMs in vnet1 (hub1) and VMs in vnet2 (hub2) can't communicate (traffic create a loop with packets discard due to TTL field reaching the zero).

[![2]][2]

There is no communications between VMs in vnet1 and vnet2:

[![3]][3]


## <a name="summary"></a>2. csr1 and csr2 configurations

**csr1 configuration:**
```console
ip route  10.101.1.0 255.255.255.0 GigabitEthernet2 10.101.3.1
ip route  10.101.4.0 255.255.255.0 GigabitEthernet2 10.101.3.1
ip route  10.100.0.0 255.255.255.0 GigabitEthernet2 10.101.3.1
router bgp 65001
  bgp log-neighbor-changes
  neighbor 10.101.1.4 remote-as 65515
  neighbor 10.101.1.4 ebgp-multihop 3    
  neighbor 10.101.1.5 remote-as 65515
  neighbor 10.101.1.5 ebgp-multihop 3
  neighbor 10.100.0.4 remote-as 65515
  neighbor 10.100.0.4 ebgp-multihop 3  
  neighbor 10.100.0.5 remote-as 65515
  neighbor 10.100.0.5 ebgp-multihop 3  
 address-family ipv4 
  network 10.101.3.0 mask 255.255.255.0
  network 10.101.4.0 mask 255.255.255.0  
  neighbor 10.101.1.4 activate
  neighbor 10.101.1.4 as-override
  neighbor 10.101.1.4 next-hop-self
  neighbor 10.101.1.4 soft-reconfiguration inbound
  neighbor 10.101.1.5 activate
  neighbor 10.101.1.5 as-override
  neighbor 10.101.1.5 next-hop-self
  neighbor 10.101.1.5 soft-reconfiguration inbound
  neighbor 10.100.0.4 activate
  neighbor 10.100.0.4 as-override
  neighbor 10.100.0.4 next-hop-self
  neighbor 10.100.0.4 soft-reconfiguration inbound
  neighbor 10.100.0.5 activate
  neighbor 10.100.0.5 as-override
  neighbor 10.100.0.5 next-hop-self
  neighbor 10.100.0.5 soft-reconfiguration inbound
 exit-address-family
!
!
line vty 0 4
 exec-timeout 25 0
exit
```


**csr2 configuration:**
```console
ip route  10.102.1.0 255.255.255.0 GigabitEthernet2 10.102.3.1
ip route  10.102.4.0 255.255.255.0 GigabitEthernet2 10.102.3.1
ip route  10.100.0.0 255.255.255.0 GigabitEthernet2 10.102.3.1
router bgp 65002
  bgp log-neighbor-changes
  neighbor 10.102.1.4 remote-as 65515
  neighbor 10.102.1.4 ebgp-multihop 3    
  neighbor 10.102.1.5 remote-as 65515
  neighbor 10.102.1.5 ebgp-multihop 3
  neighbor 10.100.0.4 remote-as 65515
  neighbor 10.100.0.4 ebgp-multihop 3  
  neighbor 10.100.0.5 remote-as 65515
  neighbor 10.100.0.5 ebgp-multihop 3  
 address-family ipv4 
  network 10.102.3.0 mask 255.255.255.0
  network 10.102.4.0 mask 255.255.255.0  
  neighbor 10.102.1.4 activate
  neighbor 10.102.1.4 as-override
  neighbor 10.102.1.4 next-hop-self
  neighbor 10.102.1.4 soft-reconfiguration inbound
  neighbor 10.102.1.5 activate
  neighbor 10.102.1.5 as-override
  neighbor 10.102.1.5 next-hop-self
  neighbor 10.102.1.5 soft-reconfiguration inbound
  neighbor 10.100.0.4 activate
  neighbor 10.100.0.4 as-override
  neighbor 10.100.0.4 next-hop-self
  neighbor 10.100.0.4 soft-reconfiguration inbound
  neighbor 10.100.0.5 activate
  neighbor 10.100.0.5 as-override
  neighbor 10.100.0.5 next-hop-self
  neighbor 10.100.0.5 soft-reconfiguration inbound
 exit-address-family
!
!
line vty 0 4
 exec-timeout 25 0
exit
```

* The nic0 of CSR is associated with GigabitEthernet1. This interface is used only for management purpose (connection to the CSR in SSH).
* The nic1 of CSR is associated with GigabitEthernet2

The purpose of static routes in the CSRs is to define the nic1 interface as routing interface for the vnet. The BGP sessions between the CSR and route servers pass through the nic1. 


## <a name="routing"></a>3. Routing considerations
The BGP sessions between each CSRs and the route servers are external BGP sessions (eBGP).
The loop prevention in eBGP is done by verifying the AS number in the AS Path. If the receiving router sees its own AS number in the AS Path of the received BGP packet, the packet is dropped. The receiving router assumes that the packet was originated from its own AS and has reached the same place from where it originated initially.
 
In such a scenario, routing updates from a csr1 to rs1 will be dropped when the update is coming from a remote rs0.
To overcome the blocker, AS-override function causes to replace the AS number of originating router with the AS number of the sending BGP router. 
**as-override** works if you have the peer AS in the AS path of a prefix you are advertising to the peer. For example, let assume the AS of the BGP peer is 65001. If 65001 appears in the AS path of an outgoing prefix update, it will replace that AS in the path with the local router's AS. **as-override** does not arbitrarily override AS paths.
A router will look at the AS PATH of a prefix, if any ASNs in the path match the remote-as of the neighbor, it will replace all of those with its own ASN.
In cisco CSR the command is 
```console
neighbor <ip-address-peer> as-override 
```
and can only be executed under the VPNv4 address-family.
In our network configuration, the CSRs are both in the mid of communication with two different route servers. The **as-override** is than required in each BGP peering with the route server.

[![4]][4]

## <a name="routing tables"></a>4. Logs

### <a name="routing tables"></a>4.1 route server rs0 in spoke vnet
```powershell
$rgName = "ASH-Cust13-2"   
$vrName = "rs0" 
$peer1Name = "bgpconn-nva1"
$peer2Name = "bgpconn-nva2"
Get-AzVirtualRouterPeerLearnedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name -WarningAction Ignore | ft

LocalAddress Network       NextHop     SourcePeer  Origin AsPath                              Weight
------------ -------       -------     ----------  ------ ------                              ------
10.100.0.4   10.2.13.0/25  10.101.3.10 10.101.3.10 EBgp   65001-65001-12076-65021              32768
10.100.0.4   10.100.0.0/24 10.101.3.10 10.101.3.10 EBgp   65001-65001                          32768
10.100.0.4   10.101.0.0/16 10.101.3.10 10.101.3.10 EBgp   65001-65001                          32768
10.100.0.4   10.200.0.0/24 10.101.3.10 10.101.3.10 EBgp   65001-65001                          32768
10.100.0.4   10.101.3.0/24 10.101.3.10 10.101.3.10 EBgp   65001                                32768
10.100.0.4   10.101.4.0/24 10.101.3.10 10.101.3.10 EBgp   65001                                32768
10.100.0.4   10.2.20.0/25  10.101.3.10 10.101.3.10 EBgp   65001-65001-65002-65002-12076-65021  32768
10.100.0.4   10.102.0.0/16 10.101.3.10 10.101.3.10 EBgp   65001-65001-65002-65002              32768
10.100.0.4   10.102.3.0/24 10.101.3.10 10.101.3.10 EBgp   65001-65001-65002                    32768
10.100.0.4   10.102.4.0/24 10.101.3.10 10.101.3.10 EBgp   65001-65001-65002                    32768
10.100.0.5   10.2.13.0/25  10.101.3.10 10.101.3.10 EBgp   65001-65001-12076-65021              32768
10.100.0.5   10.100.0.0/24 10.101.3.10 10.101.3.10 EBgp   65001-65001                          32768
10.100.0.5   10.101.0.0/16 10.101.3.10 10.101.3.10 EBgp   65001-65001                          32768
10.100.0.5   10.200.0.0/24 10.101.3.10 10.101.3.10 EBgp   65001-65001                          32768
10.100.0.5   10.101.3.0/24 10.101.3.10 10.101.3.10 EBgp   65001                                32768
10.100.0.5   10.101.4.0/24 10.101.3.10 10.101.3.10 EBgp   65001                                32768
10.100.0.5   10.2.20.0/25  10.101.3.10 10.101.3.10 EBgp   65001-65001-65002-65002-12076-65021  32768
10.100.0.5   10.102.0.0/16 10.101.3.10 10.101.3.10 EBgp   65001-65001-65002-65002              32768
10.100.0.5   10.102.3.0/24 10.101.3.10 10.101.3.10 EBgp   65001-65001-65002                    32768
10.100.0.5   10.102.4.0/24 10.101.3.10 10.101.3.10 EBgp   65001-65001-65002                    32768


Get-AzVirtualRouterPeerLearnedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer2Name -WarningAction Ignore | ft

LocalAddress Network       NextHop     SourcePeer  Origin AsPath                              Weight
------------ -------       -------     ----------  ------ ------                              ------
10.100.0.4   10.2.13.0/25  10.102.3.10 10.102.3.10 EBgp   65002-65002-65001-65001-12076-65021  32768
10.100.0.4   10.2.20.0/25  10.102.3.10 10.102.3.10 EBgp   65002-65002-12076-65021              32768
10.100.0.4   10.100.0.0/24 10.102.3.10 10.102.3.10 EBgp   65002-65002                          32768
10.100.0.4   10.102.0.0/16 10.102.3.10 10.102.3.10 EBgp   65002-65002                          32768
10.100.0.4   10.200.0.0/24 10.102.3.10 10.102.3.10 EBgp   65002-65002                          32768
10.100.0.4   10.101.0.0/16 10.102.3.10 10.102.3.10 EBgp   65002-65002-65001-65001              32768
10.100.0.4   10.101.3.0/24 10.102.3.10 10.102.3.10 EBgp   65002-65002-65001                    32768
10.100.0.4   10.101.4.0/24 10.102.3.10 10.102.3.10 EBgp   65002-65002-65001                    32768
10.100.0.4   10.102.3.0/24 10.102.3.10 10.102.3.10 EBgp   65002                                32768
10.100.0.4   10.102.4.0/24 10.102.3.10 10.102.3.10 EBgp   65002                                32768
10.100.0.5   10.2.13.0/25  10.102.3.10 10.102.3.10 EBgp   65002-65002-65001-65001-12076-65021  32768
10.100.0.5   10.2.20.0/25  10.102.3.10 10.102.3.10 EBgp   65002-65002-12076-65021              32768
10.100.0.5   10.100.0.0/24 10.102.3.10 10.102.3.10 EBgp   65002-65002                          32768
10.100.0.5   10.102.0.0/16 10.102.3.10 10.102.3.10 EBgp   65002-65002                          32768
10.100.0.5   10.200.0.0/24 10.102.3.10 10.102.3.10 EBgp   65002-65002                          32768
10.100.0.5   10.101.0.0/16 10.102.3.10 10.102.3.10 EBgp   65002-65002-65001-65001              32768
10.100.0.5   10.101.3.0/24 10.102.3.10 10.102.3.10 EBgp   65002-65002-65001                    32768
10.100.0.5   10.101.4.0/24 10.102.3.10 10.102.3.10 EBgp   65002-65002-65001                    32768
10.100.0.5   10.102.3.0/24 10.102.3.10 10.102.3.10 EBgp   65002                                32768
10.100.0.5   10.102.4.0/24 10.102.3.10 10.102.3.10 EBgp   65002                                32768

```
The route server rs0 learns from csr1 the following networks:
* **10.2.13.0/25  AS PATH={ 65001-65001-12076-65021 }** - The AS 65001 is present two times due to as-override set in csr1
* **10.101.0.0/16 AS PATH={ 65001-65001 }** - The AS 65001 is present two times due to as-override set in csr1
* **10.101.3.0/24 AS PATH={ 65001 }** - The AS 65001 is present one times becasue is advertised straight from csr1
* **10.101.4.0/24 AS PATH={ 65001 }** - The AS 65001 is present one times becasue is advertised straight from csr1

The route server rs0 learns from csr2 the following networks:
* **10.2.20.0/25  AS PATH={ 65002-65002-12076-65021 }** - The AS 65002 is present two times due to as-override set in csr2
* **10.102.0.0/16 AS PATH={ 65002-65002 }** - The AS 65001 is present two times due to as-override set in csr2
* **10.102.3.0/24 AS PATH={ 65002 }** - The AS 65001 is present one times becasue is advertised straight from csr2
* **10.102.4.0/24 AS PATH={ 65002 }** - The AS 65001 is present one times becasue is advertised straight from csr2

```powershell
$rgName = "ASH-Cust13-2"   
$vrName = "rs0" 
$peer1Name = "bgpconn-nva1"
$peer2Name = "bgpconn-nva2"
Get-AzVirtualRouterPeerAdvertisedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name -WarningAction Ignore | ft

LocalAddress Network       NextHop    SourcePeer Origin AsPath                        Weight
------------ -------       -------    ---------- ------ ------                        ------
10.100.0.4   10.100.0.0/24 10.100.0.4            Igp    65515                              0
10.100.0.4   10.200.0.0/24 10.100.0.4            Igp    65515                              0
10.100.0.4   10.2.20.0/25  10.100.0.4            Igp    65515-65002-65002-12076-65021      0
10.100.0.4   10.102.0.0/16 10.100.0.4            Igp    65515-65002-65002                  0
10.100.0.4   10.102.3.0/24 10.100.0.4            Igp    65515-65002                        0
10.100.0.4   10.102.4.0/24 10.100.0.4            Igp    65515-65002                        0
10.100.0.5   10.100.0.0/24 10.100.0.5            Igp    65515                              0
10.100.0.5   10.200.0.0/24 10.100.0.5            Igp    65515                              0
10.100.0.5   10.2.20.0/25  10.100.0.5            Igp    65515-65002-65002-12076-65021      0
10.100.0.5   10.102.0.0/16 10.100.0.5            Igp    65515-65002-65002                  0
10.100.0.5   10.102.3.0/24 10.100.0.5            Igp    65515-65002                        0
10.100.0.5   10.102.4.0/24 10.100.0.5            Igp    65515-65002                        0

Get-AzVirtualRouterPeerAdvertisedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer2Name -WarningAction Ignore | ft

LocalAddress Network       NextHop    SourcePeer Origin AsPath                        Weight
------------ -------       -------    ---------- ------ ------                        ------
10.100.0.4   10.100.0.0/24 10.100.0.4            Igp    65515                              0
10.100.0.4   10.200.0.0/24 10.100.0.4            Igp    65515                              0
10.100.0.4   10.2.13.0/25  10.100.0.4            Igp    65515-65001-65001-12076-65021      0
10.100.0.4   10.101.0.0/16 10.100.0.4            Igp    65515-65001-65001                  0
10.100.0.4   10.101.3.0/24 10.100.0.4            Igp    65515-65001                        0
10.100.0.4   10.101.4.0/24 10.100.0.4            Igp    65515-65001                        0
10.100.0.5   10.100.0.0/24 10.100.0.5            Igp    65515                              0
10.100.0.5   10.200.0.0/24 10.100.0.5            Igp    65515                              0
10.100.0.5   10.2.13.0/25  10.100.0.5            Igp    65515-65001-65001-12076-65021      0
10.100.0.5   10.101.0.0/16 10.100.0.5            Igp    65515-65001-65001                  0
10.100.0.5   10.101.3.0/24 10.100.0.5            Igp    65515-65001                        0
10.100.0.5   10.101.4.0/24 10.100.0.5            Igp    65515-65001                        0
```

### <a name="routing tables"></a>4.2 route server rs1 in hub vnet1
```powershell
$rgName = "ASH-Cust13-2"   
$vrName = "rs1" 
$peer1Name = "bgpconn-nva1"
Get-AzVirtualRouterPeerLearnedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name -WarningAction Ignore | ft

LocalAddress Network       NextHop     SourcePeer  Origin AsPath                              Weight
------------ -------       -------     ----------  ------ ------                              ------
10.101.1.4   10.2.13.0/25  10.101.3.10 10.101.3.10 EBgp   65001-65001-12076-65021              32768
10.101.1.4   10.100.0.0/24 10.101.3.10 10.101.3.10 EBgp   65001-65001                          32768
10.101.1.4   10.101.0.0/16 10.101.3.10 10.101.3.10 EBgp   65001-65001                          32768
10.101.1.4   10.200.0.0/24 10.101.3.10 10.101.3.10 EBgp   65001-65001                          32768
10.101.1.4   10.101.3.0/24 10.101.3.10 10.101.3.10 EBgp   65001                                32768
10.101.1.4   10.101.4.0/24 10.101.3.10 10.101.3.10 EBgp   65001                                32768
10.101.1.4   10.2.20.0/25  10.101.3.10 10.101.3.10 EBgp   65001-65001-65002-65002-12076-65021  32768
10.101.1.4   10.102.0.0/16 10.101.3.10 10.101.3.10 EBgp   65001-65001-65002-65002              32768
10.101.1.4   10.102.3.0/24 10.101.3.10 10.101.3.10 EBgp   65001-65001-65002                    32768
10.101.1.4   10.102.4.0/24 10.101.3.10 10.101.3.10 EBgp   65001-65001-65002                    32768
10.101.1.5   10.2.13.0/25  10.101.3.10 10.101.3.10 EBgp   65001-65001-12076-65021              32768
10.101.1.5   10.100.0.0/24 10.101.3.10 10.101.3.10 EBgp   65001-65001                          32768
10.101.1.5   10.101.0.0/16 10.101.3.10 10.101.3.10 EBgp   65001-65001                          32768
10.101.1.5   10.200.0.0/24 10.101.3.10 10.101.3.10 EBgp   65001-65001                          32768
10.101.1.5   10.101.3.0/24 10.101.3.10 10.101.3.10 EBgp   65001                                32768
10.101.1.5   10.101.4.0/24 10.101.3.10 10.101.3.10 EBgp   65001                                32768
10.101.1.5   10.2.20.0/25  10.101.3.10 10.101.3.10 EBgp   65001-65001-65002-65002-12076-65021  32768
10.101.1.5   10.102.0.0/16 10.101.3.10 10.101.3.10 EBgp   65001-65001-65002-65002              32768
10.101.1.5   10.102.3.0/24 10.101.3.10 10.101.3.10 EBgp   65001-65001-65002                    32768
10.101.1.5   10.102.4.0/24 10.101.3.10 10.101.3.10 EBgp   65001-65001-65002                    32768

Get-AzVirtualRouterPeerAdvertisedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name -WarningAction Ignore | ft

LocalAddress Network       NextHop    SourcePeer Origin AsPath            Weight
------------ -------       -------    ---------- ------ ------            ------
10.101.1.4   10.101.0.0/16 10.101.1.4            Igp    65515                  0
10.101.1.4   10.2.13.0/25  10.101.1.4            Igp    65515-12076-65021      0
10.101.1.5   10.101.0.0/16 10.101.1.5            Igp    65515                  0
10.101.1.5   10.2.13.0/25  10.101.1.5            Igp    65515-12076-65021      0
```
### <a name="routing tables"></a>4.3 route server rs2 in hub vnet2
```powershell
$rgName = "ASH-Cust13-2"   
$vrName = "rs2" 
$peer1Name = "bgpconn-nva2"
Get-AzVirtualRouterPeerLearnedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name -WarningAction Ignore | ft

LocalAddress Network       NextHop     SourcePeer  Origin AsPath                              Weight
------------ -------       -------     ----------  ------ ------                              ------
10.102.1.4   10.2.13.0/25  10.102.3.10 10.102.3.10 EBgp   65002-65002-65001-65001-12076-65021  32768
10.102.1.4   10.2.20.0/25  10.102.3.10 10.102.3.10 EBgp   65002-65002-12076-65021              32768
10.102.1.4   10.100.0.0/24 10.102.3.10 10.102.3.10 EBgp   65002-65002                          32768
10.102.1.4   10.102.0.0/16 10.102.3.10 10.102.3.10 EBgp   65002-65002                          32768
10.102.1.4   10.200.0.0/24 10.102.3.10 10.102.3.10 EBgp   65002-65002                          32768
10.102.1.4   10.101.0.0/16 10.102.3.10 10.102.3.10 EBgp   65002-65002-65001-65001              32768
10.102.1.4   10.101.3.0/24 10.102.3.10 10.102.3.10 EBgp   65002-65002-65001                    32768
10.102.1.4   10.101.4.0/24 10.102.3.10 10.102.3.10 EBgp   65002-65002-65001                    32768
10.102.1.4   10.102.3.0/24 10.102.3.10 10.102.3.10 EBgp   65002                                32768
10.102.1.4   10.102.4.0/24 10.102.3.10 10.102.3.10 EBgp   65002                                32768
10.102.1.5   10.2.13.0/25  10.102.3.10 10.102.3.10 EBgp   65002-65002-65001-65001-12076-65021  32768
10.102.1.5   10.2.20.0/25  10.102.3.10 10.102.3.10 EBgp   65002-65002-12076-65021              32768
10.102.1.5   10.100.0.0/24 10.102.3.10 10.102.3.10 EBgp   65002-65002                          32768
10.102.1.5   10.102.0.0/16 10.102.3.10 10.102.3.10 EBgp   65002-65002                          32768
10.102.1.5   10.200.0.0/24 10.102.3.10 10.102.3.10 EBgp   65002-65002                          32768
10.102.1.5   10.101.0.0/16 10.102.3.10 10.102.3.10 EBgp   65002-65002-65001-65001              32768
10.102.1.5   10.101.3.0/24 10.102.3.10 10.102.3.10 EBgp   65002-65002-65001                    32768
10.102.1.5   10.101.4.0/24 10.102.3.10 10.102.3.10 EBgp   65002-65002-65001                    32768
10.102.1.5   10.102.3.0/24 10.102.3.10 10.102.3.10 EBgp   65002                                32768
10.102.1.5   10.102.4.0/24 10.102.3.10 10.102.3.10 EBgp   65002                                32768

Get-AzVirtualRouterPeerAdvertisedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name -WarningAction Ignore | ft

LocalAddress Network       NextHop    SourcePeer Origin AsPath            Weight
------------ -------       -------    ---------- ------ ------            ------
10.102.1.4   10.102.0.0/16 10.102.1.4            Igp    65515                  0
10.102.1.4   10.2.20.0/25  10.102.1.4            Igp    65515-12076-65021      0
10.102.1.5   10.102.0.0/16 10.102.1.5            Igp    65515                  0
10.102.1.5   10.2.20.0/25  10.102.1.5            Igp    65515-12076-65021      0
```

### <a name="routing tables"></a>4.4 csr1 routing tables
```console
ASH-Cust13-csr1#show ip bgp neighbors 10.100.0.4 routes
BGP table version is 11, local router ID is 10.101.3.10
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.2.20.0/25     10.100.0.4                             0 65515 65002 65002 12076 65021 i
 r>   10.100.0.0/24    10.100.0.4                             0 65515 i
 *>   10.102.0.0/16    10.100.0.4                             0 65515 65002 65002 i
 *>   10.102.3.0/24    10.100.0.4                             0 65515 65002 i
 *>   10.102.4.0/24    10.100.0.4                             0 65515 65002 i
 *>   10.200.0.0/24    10.100.0.4                             0 65515 i

Total number of prefixes 6


ASH-Cust13-csr1#show ip bgp neighbors 10.100.0.4 advertised-routes
BGP table version is 11, local router ID is 10.101.3.10
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.2.13.0/25     10.101.1.4                             0 65515 12076 65021 i
 *>   10.2.20.0/25     10.100.0.4                             0 65515 65002 65002 12076 65021 i
 r>   10.100.0.0/24    10.100.0.4                             0 65515 i
 *>   10.101.0.0/16    10.101.1.4                             0 65515 i
 *>   10.101.3.0/24    0.0.0.0                  0         32768 i
 *>   10.101.4.0/24    10.101.3.1               0         32768 i
 *>   10.102.0.0/16    10.100.0.4                             0 65515 65002 65002 i
 *>   10.102.3.0/24    10.100.0.4                             0 65515 65002 i
 *>   10.102.4.0/24    10.100.0.4                             0 65515 65002 i
 *>   10.200.0.0/24    10.100.0.4                             0 65515 i

Total number of prefixes 10
```

```console
ASH-Cust13-csr1#show ip bgp neighbors 10.101.1.4 routes
BGP table version is 11, local router ID is 10.101.3.10
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.2.13.0/25     10.101.1.4                             0 65515 12076 65021 i
 *>   10.101.0.0/16    10.101.1.4                             0 65515 i

Total number of prefixes 2

ASH-Cust13-csr1#show ip bgp neighbors 10.101.1.4 advertised-routes
BGP table version is 11, local router ID is 10.101.3.10
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.2.13.0/25     10.101.1.4                             0 65515 12076 65021 i
 *>   10.2.20.0/25     10.100.0.4                             0 65515 65002 65002 12076 65021 i
 r>   10.100.0.0/24    10.100.0.4                             0 65515 i
 *>   10.101.0.0/16    10.101.1.4                             0 65515 i
 *>   10.101.3.0/24    0.0.0.0                  0         32768 i
 *>   10.101.4.0/24    10.101.3.1               0         32768 i
 *>   10.102.0.0/16    10.100.0.4                             0 65515 65002 65002 i
 *>   10.102.3.0/24    10.100.0.4                             0 65515 65002 i
 *>   10.102.4.0/24    10.100.0.4                             0 65515 65002 i
 *>   10.200.0.0/24    10.100.0.4                             0 65515 i

Total number of prefixes 10

```
### <a name="routing tables"></a>4.5 csr2 routing tables

```console
ASH-Cust13-csr2#show ip bgp neighbors 10.100.0.4 routes
BGP table version is 11, local router ID is 10.102.3.10
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.2.13.0/25     10.100.0.4                             0 65515 65001 65001 12076 65021 i
 r>   10.100.0.0/24    10.100.0.4                             0 65515 i
 *>   10.101.0.0/16    10.100.0.4                             0 65515 65001 65001 i
 *>   10.101.3.0/24    10.100.0.4                             0 65515 65001 i
 *>   10.101.4.0/24    10.100.0.4                             0 65515 65001 i
 *>   10.200.0.0/24    10.100.0.4                             0 65515 i

Total number of prefixes 6

ASH-Cust13-csr2#show ip bgp neighbors 10.100.0.4 advertised-routes
BGP table version is 11, local router ID is 10.102.3.10
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.2.13.0/25     10.100.0.4                             0 65515 65001 65001 12076 65021 i
 *>   10.2.20.0/25     10.102.1.4                             0 65515 12076 65021 i
 r>   10.100.0.0/24    10.100.0.4                             0 65515 i
 *>   10.101.0.0/16    10.100.0.4                             0 65515 65001 65001 i
 *>   10.101.3.0/24    10.100.0.4                             0 65515 65001 i
 *>   10.101.4.0/24    10.100.0.4                             0 65515 65001 i
 *>   10.102.0.0/16    10.102.1.4                             0 65515 i
 *>   10.102.3.0/24    0.0.0.0                  0         32768 i
 *>   10.102.4.0/24    10.102.3.1               0         32768 i
 *>   10.200.0.0/24    10.100.0.4                             0 65515 i

Total number of prefixes 10

```
The csr2 leanrs from on-premises the network 10.2.20.0/25 through ER circuit2:
```console
ASH-Cust13-csr2#show ip bgp neighbors 10.102.1.4 routes
BGP table version is 11, local router ID is 10.102.3.10
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.2.20.0/25     10.102.1.4                             0 65515 12076 65021 i
 *>   10.102.0.0/16    10.102.1.4                             0 65515 i

Total number of prefixes 2

ASH-Cust13-csr2#show ip bgp neighbors 10.102.1.4 advertised-routes
BGP table version is 11, local router ID is 10.102.3.10
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.2.13.0/25     10.100.0.4                             0 65515 65001 65001 12076 65021 i
 *>   10.2.20.0/25     10.102.1.4                             0 65515 12076 65021 i
 r>   10.100.0.0/24    10.100.0.4                             0 65515 i
 *>   10.101.0.0/16    10.100.0.4                             0 65515 65001 65001 i
 *>   10.101.3.0/24    10.100.0.4                             0 65515 65001 i
 *>   10.101.4.0/24    10.100.0.4                             0 65515 65001 i
 *>   10.102.0.0/16    10.102.1.4                             0 65515 i
 *>   10.102.3.0/24    0.0.0.0                  0         32768 i
 *>   10.102.4.0/24    10.102.3.1               0         32768 i
 *>   10.200.0.0/24    10.100.0.4                             0 65515 i

Total number of prefixes 10
```


### <a name="routing tables"></a>4.6 effetive routing table in the Azure VMs
Below the effetive routing table appliedto the nic of the VMs.
To keep the logs more readble, the networks with _nexthopeType_ set to **None** are not reported in the printout.


Effective routes csr1 in vnet1:
```powershell
Get-AzEffectiveRouteTable -ResourceGroupName ASH-Cust13-2 -NetworkInterfaceName ASH-Cust13-csr1-nic1 | select-object -Property Source,AddressPrefix,nextHoptype,nextHopIpAddress

Source                AddressPrefix    NextHopType           NextHopIpAddress
------                -------------    -----------           ----------------
Default               {10.101.0.0/16}  VnetLocal             {}              
VirtualNetworkGateway {10.2.13.0/25}   VirtualNetworkGateway {10.3.129.67}   
VirtualNetworkGateway {10.102.4.0/24}  VirtualNetworkGateway {10.101.3.10}   
VirtualNetworkGateway {10.102.0.0/16}  VirtualNetworkGateway {10.101.3.10}   
VirtualNetworkGateway {10.102.3.0/24}  VirtualNetworkGateway {10.101.3.10}   
VirtualNetworkGateway {10.2.20.0/25}   VirtualNetworkGateway {10.101.3.10}   
Default               {0.0.0.0/0}      Internet              {}          
Default               {10.100.0.0/24}  VNetGlobalPeering     {}              
Default               {10.200.0.0/24}  VNetGlobalPeering     {}            
```

Effective routes csr2 in vnet2:
```powershell
Get-AzEffectiveRouteTable -ResourceGroupName ASH-Cust13-2 -NetworkInterfaceName ASH-Cust13-csr2-nic1 | select-object -Property Source,AddressPrefix,nextHoptype,nextHopIpAddress

Source                AddressPrefix    NextHopType           NextHopIpAddress
------                -------------    -----------           ----------------
Default               {10.102.0.0/16}  VnetLocal             {}              
Default               {10.100.0.0/24}  VNetPeering           {}              
Default               {10.200.0.0/24}  VNetPeering           {}              
VirtualNetworkGateway {10.2.20.0/25}   VirtualNetworkGateway {10.2.146.14}   
VirtualNetworkGateway {10.101.4.0/24}  VirtualNetworkGateway {10.102.3.10}   
VirtualNetworkGateway {10.101.0.0/16}  VirtualNetworkGateway {10.102.3.10}   
VirtualNetworkGateway {10.101.3.0/24}  VirtualNetworkGateway {10.102.3.10}   
VirtualNetworkGateway {10.2.13.0/25}   VirtualNetworkGateway {10.102.3.10}   
Default               {0.0.0.0/0}      Internet              {}              
```

Effective routes vm02 in vnet0:
```powershell
Get-AzEffectiveRouteTable -ResourceGroupName ASH-Cust13-2 -NetworkInterfaceName ASH-Cust13-vm02-NIC | select-object -Property Source,AddressPrefix,nextHoptype,nextHopIpAddress

Source                AddressPrefix    NextHopType           NextHopIpAddress
------                -------------    -----------           ----------------
Default               {10.100.0.0/24}  VnetLocal             {}              
Default               {10.200.0.0/24}  VnetLocal             {}              
Default               {10.102.0.0/16}  VNetPeering           {}              
VirtualNetworkGateway {10.2.20.0/25}   VirtualNetworkGateway {10.102.3.10}   
VirtualNetworkGateway {10.2.13.0/25}   VirtualNetworkGateway {10.101.3.10}   
Default               {0.0.0.0/0}      Internet              {}                     
Default               {10.101.0.0/16}  VNetGlobalPeering     {}  
```

Effective routes vm14 in vnet1:
```powershell
Get-AzEffectiveRouteTable -ResourceGroupName ASH-Cust13-2 -NetworkInterfaceName ASH-Cust13-vm14-NIC  | select-object -Property Source,AddressPrefix,nextHoptype,nextHopIpAddress

Source                AddressPrefix    NextHopType           NextHopIpAddress
------                -------------    -----------           ----------------
Default               {10.101.0.0/16}  VnetLocal             {}              
VirtualNetworkGateway {10.2.13.0/25}   VirtualNetworkGateway {10.3.129.67}   
VirtualNetworkGateway {10.102.4.0/24}  VirtualNetworkGateway {10.101.3.10}   
VirtualNetworkGateway {10.102.0.0/16}  VirtualNetworkGateway {10.101.3.10}   
VirtualNetworkGateway {10.102.3.0/24}  VirtualNetworkGateway {10.101.3.10}   
VirtualNetworkGateway {10.2.20.0/25}   VirtualNetworkGateway {10.101.3.10}   
Default               {0.0.0.0/0}      Internet              {}                      
Default               {10.100.0.0/24}  VNetGlobalPeering     {}              
Default               {10.200.0.0/24}  VNetGlobalPeering     {} 
```

Effective routes vm24 in vnet2:
```powershell
Get-AzEffectiveRouteTable -ResourceGroupName ASH-Cust13-2 -NetworkInterfaceName ASH-Cust13-vm24-NIC  | select-object -Property Source,AddressPrefix,nextHoptype,nextHopIpAddress

Source                AddressPrefix    NextHopType           NextHopIpAddress
------                -------------    -----------           ----------------
Default               {10.102.0.0/16}  VnetLocal             {}              
Default               {10.100.0.0/24}  VNetPeering           {}              
Default               {10.200.0.0/24}  VNetPeering           {}              
VirtualNetworkGateway {10.2.20.0/25}   VirtualNetworkGateway {10.2.146.14}   
VirtualNetworkGateway {10.101.4.0/24}  VirtualNetworkGateway {10.102.3.10}   
VirtualNetworkGateway {10.101.0.0/16}  VirtualNetworkGateway {10.102.3.10}   
VirtualNetworkGateway {10.101.3.0/24}  VirtualNetworkGateway {10.102.3.10}   
VirtualNetworkGateway {10.2.13.0/25}   VirtualNetworkGateway {10.102.3.10}   
Default               {0.0.0.0/0}      Internet              {}               
```

### <a name="routing tables"></a>4.7 edge routers routing tables
Network prefixes learned from the ExpressRoute circuit1:
```console
ASH-ASR#show ip bgp vpnv4 vrf 20 neighbor 192.168.20.18 routes
BGP table version is 15104250, local router ID is 192.168.0.0
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 65021:20 (default for vrf 20)
 *>   10.100.0.0/24    192.168.20.18                          0 12076 i
 *>   10.101.0.0/16    192.168.20.18                          0 12076 i
 *>   10.101.3.0/24    192.168.20.18                          0 12076 i
 *>   10.101.4.0/24    192.168.20.18                          0 12076 i
 *>   10.102.0.0/16    192.168.20.18                          0 12076 i
 *>   10.102.3.0/24    192.168.20.18                          0 12076 i
 *>   10.102.4.0/24    192.168.20.18                          0 12076 i
 *>   10.200.0.0/24    192.168.20.18                          0 12076 i

Total number of prefixes 8 
```
Network prefixes learned from the ExpressRoute circuit2:
```console
ASH-ASR#show ip bgp vpnv4 vrf 13 neighbor 192.168.13.18 routes
BGP table version is 15104250, local router ID is 192.168.0.0
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 65021:13 (default for vrf 13)
 *>   10.100.0.0/24    192.168.13.18                          0 12076 i
 *>   10.101.0.0/16    192.168.13.18                          0 12076 i
 *>   10.101.3.0/24    192.168.13.18                          0 12076 i
 *>   10.101.4.0/24    192.168.13.18                          0 12076 i
 *>   10.102.0.0/16    192.168.13.18                          0 12076 i
 *>   10.102.3.0/24    192.168.13.18                          0 12076 i
 *>   10.102.4.0/24    192.168.13.18                          0 12076 i
 *>   10.200.0.0/24    192.168.13.18                          0 12076 i

Total number of prefixes 8 
```

### <a name="ANNEX"></a>5. ANNEX
When multiple deployments and deletion of nva from Azure marketplace are applied in short period of time, the operations might casue a failure with following error message:  

```powershell
New-AzResourceGroupDeployment : 16:59:35 - The deployment 'vnets' failed with error(s). Showing 3 out of 5 error(s).
Status Message: The resource 'ASH-Cust13-csr2' with the id 'Microsoft.Compute/virtualMachines/ASH-Cust13-csr2' has a previous order being canceled. Please try 
after some time or create resource with different name.  (Code:ResourcePurchaseCanceling)
Status Message: The resource 'ASH-Cust13-csr1' with the id 'Microsoft.Compute/virtualMachines/ASH-Cust13-csr1' has a previous order being canceled. Please try 
after some time or create resource with different name.  (Code:ResourcePurchaseCanceling)
Status Message: The operation failed due to following errors: 'One or more operations failed'. (Code: OperationFailureErrors)
CorrelationId: 4d3ea82c-acbe-4f5b-aa22-b34fe8a5038b
At C:\Users\fabferri\Desktop\Charley-VR-2021-03-with-2ERcircuits-03\01_vnets.ps1:49 char:1
+ New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupNa ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [New-AzResourceGroupDeployment], Exception
    + FullyQualifiedErrorId : Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.NewAzureResourceGroupDeploymentCmdlet
```
To fix the issue, the name of nva has to be different from previous deployment. Assignment of different name of the VM allows to overcome the blocker.

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/communications1.png "communication between VMs"
[3]: ./media/communications2.png "communication between VMs"
[4]: ./media/routing.png "routing"

<!--Link References-->

