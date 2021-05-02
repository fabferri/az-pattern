<properties
pageTitle= 'dual-homed network with Azure Route Server and site-to-site VPNs'
description= "Spoke VNet with Azure Router Server in peering with NVAs in two hub VNets"
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
   ms.date="29/04/2021"
   ms.author="fabferri" />

# dual-homed network with Azure Route Server and site-to-site VPNs
 
The article describes the network configuration which diagram is shown below: 

[![1]][1]

Configuration is based on two hub vnets, **vnet1** and **vnet2** in peering with spoke vnet named **vnet0**.

The **vnet5** is connected to **vnet1** and **vnet2** through site-to-site IPsec tunnels. 

Naming convention for the subnets: **subnetXY** where [**X** is the vnet number, **Y** is the subnet number]

* vnet1 with address space network 10.101.0.0/16 is in peering with vnet0 and has a NVA (Cisco CSR). The Cisco CSR, named csr1 has two NICs: 
   * nic0 is connected to the subnet11, and it has an internal static IP address 10.101.1.10. The nic0 has also a public IP to establish IPsec tunnel with remote vnet5 and access to CSR by SSH. The nic0 (primary nic) of csr1 is associated in IOS XE with GigabitEthernet1.
   * nic1 is connected to the subnet12. The nic1 has a static IP address 10.101.2.10 and does not have any public IP. The csr1 establishes a BGP session with Router Server in vnet0 through the nic1. The nic1 of csr1 is associated in IOS XE with GigabitEthernet2.

* vnet2 with address space network 10.102.0.0/16 in peering with vnet0 and has a NVA (Cisco CSR). The Cisco CSR, named csr2 has two NICs: 
   * nic0 is connected to the subnet21, and it has an internal static IP address 10.102.1.10. The nic0 has also a public IP to establish IPsec tunnel with remote vnet5 and access to CSR by SSH. The nic0 (primary nic) of csr2 is associated in IOS XE with GigabitEthernet1.
   * nic1 is connected to the subnet22. The nic1 has a static IP address 10.102.2.10 and does not have any public IP. The csr2 establishes a BGP session with Router Server in vnet0 through the nic1. The nic1 of csr1 is associated in IOS XE with GigabitEthernet2.

* vnet5 with address space network 10.5.0.0/16 with an NVA (Cisco CSR). The Cisco CSR, named csr5 has two NICs: 
   * nic0 is connected to the subnet51, and it has an internal static IP address 10.5.1.10. The nic0 has also a public IP to establish an IPsec tunnel with remote vnet1 and IPsec tunnel with vnet2. The nic0 (primary nic) of csr5 is associated in IOS XE with GigabitEthernet1.
   * nic1 is connected to the subnet52. The nic1 has a static IP address 10.5.2.10 and does not have any public IP. The nic1 of csr5 is associated in IOS XE with GigabitEthernet2.

* vnet0 is the spoke vnet with address space [10.0.0.0/24,
10.0.1.0/24]; in the vnet0 is deployed a Route Server.
   * RouteServerSubnet has the address 10.0.0.0/25 
   * subnet01 has the address 10.0.1.0/25
   * subnet02 has the address 10.0.1.128/25

* All the vnet peering have the same setup:
   * Traffic to remote virtual network: allow (default)
   * Traffic forwarded from remote virtual network: allow (default)
   * Virtual network gateway or Route Server: none (default)
   * There is no UDR in all vnets.


**Files**:
| File name                | Description                                                          |
| ------------------------ | :------------------------------------------------------------------- |
| **az-deployment.json**   | deploy VNets, Route Server, NSG, UDRs, Cisco CSR and VMs             |
| **az-deployment.ps1**    | powershell script to deploy the ARM template **az-deployment.json**  |
| **LegalAgreementMarketplace.ps1** | powershell script to accept the legal agreement to run the Cisco CSR in the Azure subscription   |
| **get-csr-images.ps1**   | powershell script to fetch the cisco CSR images from the Azure marketplace |
| **rs0-fetch-routes.ps1** | it featches routes (learned and advertised) from the Azure Route Server in vnet0 |
| **csr-1st-step-configs** | this folder contains the powershell scripts **generate-csr1-config.ps1**, **generate-csr2-config.ps1**, **generate-csr5-config.ps1** to generate the inial configuration of the **csr1**, **csr2**, **csr5**. <br> The scripts generate the text files **csr1-config.txt, csr2-config.txt, csr5-config.txt** with CSR config.  |
| **csr-2nd-step-config**  | CSR configuration snippets: create BGP peering between **csr1** and RS, **csr2** and RS, add AS PATH prepending in peering between **csr5** and **csr2** | 
| **csr-full-configs**     | folder with the final CSRs configurations  |

> **[!NOTE1]**
> Before spinning up the ARM template you should edit the file **az-deployment.ps1** and set:
> * your Azure subscription name in the variable **$subscriptionName**
> * the administrator username of the Azure VM in the variables **$adminUsername**
> * the administrator password of the Azure VM in the variables **$adminPassword**
> * the management IP address **$mngIP** to connect in SSH to the CSRs and VMs



## <a name="summary"></a>1. BGP session through IPSec tunnels
The csr1 and csr2 have a site-to-site IPsec tunnel with csr5. The IPsec tunnels are established through tunnel interfaces tunnel0 and tunnel1, as shown in the diagram below.

[![2]][2]


To check the status of IPSec sessions in **csr5**:
```console
csr5#show crypto session
Crypto session current status

Interface: Tunnel0
Profile: az-PROFILE1
Session status: UP-ACTIVE
Peer: 52.252.1.174 port 4500
  Session ID: 2
  IKEv2 SA: local 10.5.1.10/4500 remote 52.252.1.174/4500 Active
  IPSEC FLOW: permit ip 0.0.0.0/0.0.0.0 0.0.0.0/0.0.0.0
        Active SAs: 2, origin: crypto map

Interface: Tunnel1
Profile: az-PROFILE2
Session status: UP-ACTIVE
Peer: 13.73.145.44 port 4500
  Session ID: 3
  IKEv2 SA: local 10.5.1.10/4500 remote 13.73.145.44/4500 Active
  IPSEC FLOW: permit ip 0.0.0.0/0.0.0.0 0.0.0.0/0.0.0.0
        Active SAs: 2, origin: crypto map
```

Each CSR has:
* a loopback interface used to establish a BGP session over the IPsec tunnel.
* a static route to point to the remote loopback interface through the local tunnel interface

## <a name="summary"></a>2. BGP route tables with csr1 and csr2 <ins>NOT</ins> in peering with Azure Route server
To create a deterministic path from vnet5 to vnet0, the **csr5** applies AS prepending in BGP peering with **csr2**:
```console
route-map PREPEND permit 10
  set as-path prepend 65005

router bgp 65005
  address-family ipv4
    neighbor 192.168.0.2 route-map PREPEND out
```
In presence of AS PATH prepending, from the vnet5 the preferred path to reach out the vnet0 will be through the **csr1**.

Below the BGP routing tables (with **csr1** and **csr2** <ins>not</ins> in peering with Azure Route Server):
```console
csr5#show ip bgp
BGP table version is 16, local router ID is 192.168.0.5
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.5.1.0/24      0.0.0.0                  0         32768 i
 *>   10.5.2.0/24      0.0.0.0                  0         32768 i
 *>   10.5.3.0/24      10.5.2.1                 0         32768 i
 *>   10.101.1.0/24    192.168.0.1              0             0 65001 i
 *>   10.101.2.0/24    192.168.0.1              0             0 65001 i
 *>   10.101.3.0/24    192.168.0.1              0             0 65001 i
 *>   10.102.1.0/24    192.168.0.2              0             0 65002 i
 *>   10.102.2.0/24    192.168.0.2              0             0 65002 i
 *>   10.102.3.0/24    192.168.0.2              0             0 65002 i
```

```console
csr1#show ip bgp
BGP table version is 16, local router ID is 192.168.0.1
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.5.1.0/24      192.168.0.5              0             0 65005 i
 *>   10.5.2.0/24      192.168.0.5              0             0 65005 i
 *>   10.5.3.0/24      192.168.0.5              0             0 65005 i
 *>   10.101.1.0/24    0.0.0.0                  0         32768 i
 *>   10.101.2.0/24    0.0.0.0                  0         32768 i
 *>   10.101.3.0/24    10.101.2.1               0         32768 i
 *>   10.102.1.0/24    192.168.0.5                            0 65005 65002 i
 *>   10.102.2.0/24    192.168.0.5                            0 65005 65002 i
 *>   10.102.3.0/24    192.168.0.5                            0 65005 65002 i
```

```console
csr2#show ip bgp
BGP table version is 10, local router ID is 192.168.0.2
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.5.1.0/24      192.168.0.5              0             0 65005 65005 i
 *>   10.5.2.0/24      192.168.0.5              0             0 65005 65005 i
 *>   10.5.3.0/24      192.168.0.5              0             0 65005 65005 i
 *>   10.101.1.0/24    192.168.0.5                            0 65005 65005 65001 i
 *>   10.101.2.0/24    192.168.0.5                            0 65005 65005 65001 i
 *>   10.101.3.0/24    192.168.0.5                            0 65005 65005 65001 i
 *>   10.102.1.0/24    0.0.0.0                  0         32768 i
 *>   10.102.2.0/24    0.0.0.0                  0         32768 i
 *>   10.102.3.0/24    10.102.2.1               0         32768 i
```

## <a name="summary"></a>3. BGP route tables with csr1 and csr2 in peering with Azure Route server
The diagram shown the BGP peering between CSRs and between CSRs and Azure Route Server:
* csr1 is in BGP peering with Azure Route Server in vnet0 and in BGP peering with csr5
* csr2 is in BGP peering with Azure Route Server in vnet0 and in BGP peering with csr5

[![3]][3]

Configuration snippet in csr1 to create BGP peering with Azure Route server:
```console
router bgp 65001
 neighbor 10.0.0.4 remote-as 65515
 neighbor 10.0.0.4 ebgp-multihop 3
 neighbor 10.0.0.4 update-source GigabitEthernet2
 neighbor 10.0.0.5 remote-as 65515
 neighbor 10.0.0.5 ebgp-multihop 3
 neighbor 10.0.0.5 update-source GigabitEthernet2
 !
 address-family ipv4
  neighbor 10.0.0.4 activate
  neighbor 10.0.0.4 next-hop-self
  neighbor 10.0.0.4 soft-reconfiguration inbound
  neighbor 10.0.0.5 activate
  neighbor 10.0.0.5 next-hop-self
  neighbor 10.0.0.5 soft-reconfiguration inbound
 exit-address-family

ip route 10.0.0.4 255.255.255.255  10.101.2.1
ip route 10.0.0.5 255.255.255.255  10.101.2.1
```


Configuration snippet in csr2 to create BGP peering with Azure Route server:
```console
router bgp 65002
 neighbor 10.0.0.4 remote-as 65515
 neighbor 10.0.0.4 ebgp-multihop 3
 neighbor 10.0.0.4 update-source GigabitEthernet2
 neighbor 10.0.0.5 remote-as 65515
 neighbor 10.0.0.5 ebgp-multihop 3
 neighbor 10.0.0.5 update-source GigabitEthernet2
 !
 address-family ipv4
  neighbor 10.0.0.4 activate
  neighbor 10.0.0.4 next-hop-self
  neighbor 10.0.0.4 soft-reconfiguration inbound
  neighbor 10.0.0.5 activate
  neighbor 10.0.0.5 next-hop-self
  neighbor 10.0.0.5 soft-reconfiguration inbound
 exit-address-family

ip route 10.0.0.4 255.255.255.255  10.102.2.1
ip route 10.0.0.5 255.255.255.255  10.102.2.1
```

```console
csr1#show ip bgp
BGP table version is 35, local router ID is 192.168.0.1
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *    10.0.0.0/24      192.168.0.5                            0 65005 65002 65515 i
 *                     10.0.0.5                               0 65515 i
 *>                    10.0.0.4                               0 65515 i
 *    10.0.1.0/24      192.168.0.5                            0 65005 65002 65515 i
 *                     10.0.0.5                               0 65515 i
 *>                    10.0.0.4                               0 65515 i
 *>   10.5.1.0/24      192.168.0.5              0             0 65005 i
 *>   10.5.2.0/24      192.168.0.5              0             0 65005 i
 *>   10.5.3.0/24      192.168.0.5              0             0 65005 i
 *>   10.101.1.0/24    0.0.0.0                  0         32768 i
 *>   10.101.2.0/24    0.0.0.0                  0         32768 i
 *>   10.101.3.0/24    10.101.2.1               0         32768 i
 *    10.102.1.0/24    192.168.0.5                            0 65005 65002 i
 *                     10.0.0.5                               0 65515 65002 i
 *>                    10.0.0.4                               0 65515 65002 i
 *    10.102.2.0/24    192.168.0.5                            0 65005 65002 i
 *                     10.0.0.5                               0 65515 65002 i
 *>                    10.0.0.4                               0 65515 65002 i
 *    10.102.3.0/24    192.168.0.5                            0 65005 65002 i
 *                     10.0.0.5                               0 65515 65002 i
 *>                    10.0.0.4                               0 65515 65002 i
```

```console
csr2#show ip bgp
BGP table version is 25, local router ID is 192.168.0.2
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *    10.0.0.0/24      10.0.0.5                               0 65515 i
 *>                    10.0.0.4                               0 65515 i
 *    10.0.1.0/24      10.0.0.5                               0 65515 i
 *>                    10.0.0.4                               0 65515 i
 *    10.5.1.0/24      10.0.0.4                               0 65515 65001 65005 i
 *                     10.0.0.5                               0 65515 65001 65005 i
 *>                    192.168.0.5              0             0 65005 65005 i
 *    10.5.2.0/24      10.0.0.4                               0 65515 65001 65005 i
 *                     10.0.0.5                               0 65515 65001 65005 i
 *>                    192.168.0.5              0             0 65005 65005 i
 *    10.5.3.0/24      10.0.0.4                               0 65515 65001 65005 i
 *                     10.0.0.5                               0 65515 65001 65005 i
 *>                    192.168.0.5              0             0 65005 65005 i
 *    10.101.1.0/24    192.168.0.5                            0 65005 65005 65001 i
 *                     10.0.0.5                               0 65515 65001 i
 *>                    10.0.0.4                               0 65515 65001 i
 *    10.101.2.0/24    192.168.0.5                            0 65005 65005 65001 i
 *                     10.0.0.5                               0 65515 65001 i
 *>                    10.0.0.4                               0 65515 65001 i
 *    10.101.3.0/24    192.168.0.5                            0 65005 65005 65001 i
 *                     10.0.0.5                               0 65515 65001 i
 *>                    10.0.0.4                               0 65515 65001 i
 *>   10.102.1.0/24    0.0.0.0                  0         32768 i
 *>   10.102.2.0/24    0.0.0.0                  0         32768 i
 *>   10.102.3.0/24    10.102.2.1               0         32768 i
```

```console
csr5#show ip bgp
BGP table version is 15, local router ID is 192.168.0.5
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *    10.0.0.0/24      192.168.0.1                            0 65001 65515 i
 *>                    192.168.0.2                            0 65002 65515 i
 *    10.0.1.0/24      192.168.0.1                            0 65001 65515 i
 *>                    192.168.0.2                            0 65002 65515 i
 *>   10.5.1.0/24      0.0.0.0                  0         32768 i
 *>   10.5.2.0/24      0.0.0.0                  0         32768 i
 *>   10.5.3.0/24      10.5.2.1                 0         32768 i
 *>   10.101.1.0/24    192.168.0.1              0             0 65001 i
 *                     192.168.0.2                            0 65002 65515 65001 i
 *>   10.101.2.0/24    192.168.0.1              0             0 65001 i
 *                     192.168.0.2                            0 65002 65515 65001 i
 *>   10.101.3.0/24    192.168.0.1              0             0 65001 i
 *                     192.168.0.2                            0 65002 65515 65001 i
 *    10.102.1.0/24    192.168.0.1                            0 65001 65515 65002 i
 *>                    192.168.0.2              0             0 65002 i
 *    10.102.2.0/24    192.168.0.1                            0 65001 65515 65002 i
 *>                    192.168.0.2              0             0 65002 i
 *    10.102.3.0/24    192.168.0.1                            0 65001 65515 65002 i
 *>                    192.168.0.2              0             0 65002 i
```
Below a diagram shows the preferred path from vnet5 to reach out the vnet0.

[![4]][4]

The vnet0 has two effective path to reach out the vnet5:
* primary path (with shorter AS path length) through vnet1
* a backup path (with longer AS path length) through vnet2

In case the BGP peering between the **csr5** and **csr1** should be down, the path from vnet5 to vnet0 will be through the vnet2:

[![5]][5]


There is no intercommunication between the VMs in vnet1 and vnet2:

[![6]][6]

```
user1@vm12:~$ ping 10.102.3.10
PING 10.102.3.10 (10.102.3.10) 56(84) bytes of data.
From 10.101.2.10 icmp_seq=2 Time to live exceeded
From 10.101.2.10 icmp_seq=3 Time to live exceeded

user1@vm13:~$ ping 10.102.3.10
PING 10.102.3.10 (10.102.3.10) 56(84) bytes of data.
From 10.101.2.10 icmp_seq=1 Time to live exceeded
From 10.101.2.10 icmp_seq=2 Time to live exceeded

```

# <a name="routing tables"></a>4. ANNEX2: Logs

### <a name="routing tables"></a>4.1 Routing tables in Azure Route Server (spoke vnet)
```powershell
$subscriptionName = "AzDev1"  
$rgName = "rs03"   
$vrName = "rs01" 
$peer1Name = "bgpconn-nva1"
$peer2Name = "bgpconn-nva2"

Get-AzVirtualRouterPeerLearnedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name -WarningAction Ignore | ft

LocalAddress Network       NextHop     SourcePeer  Origin AsPath      Weight
------------ -------       -------     ----------  ------ ------      ------
10.0.0.4     10.5.3.0/24   10.101.2.10 10.101.2.10 EBgp   65001-65005  32768
10.0.0.4     10.5.2.0/24   10.101.2.10 10.101.2.10 EBgp   65001-65005  32768
10.0.0.4     10.5.1.0/24   10.101.2.10 10.101.2.10 EBgp   65001-65005  32768
10.0.0.4     10.101.1.0/24 10.101.2.10 10.101.2.10 EBgp   65001        32768
10.0.0.4     10.101.2.0/24 10.101.2.10 10.101.2.10 EBgp   65001        32768
10.0.0.4     10.101.3.0/24 10.101.2.10 10.101.2.10 EBgp   65001        32768
10.0.0.5     10.5.3.0/24   10.101.2.10 10.101.2.10 EBgp   65001-65005  32768
10.0.0.5     10.5.2.0/24   10.101.2.10 10.101.2.10 EBgp   65001-65005  32768
10.0.0.5     10.5.1.0/24   10.101.2.10 10.101.2.10 EBgp   65001-65005  32768
10.0.0.5     10.101.1.0/24 10.101.2.10 10.101.2.10 EBgp   65001        32768
10.0.0.5     10.101.2.0/24 10.101.2.10 10.101.2.10 EBgp   65001        32768
10.0.0.5     10.101.3.0/24 10.101.2.10 10.101.2.10 EBgp   65001        32768

Get-AzVirtualRouterPeerLearnedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer2Name -WarningAction Ignore | ft

LocalAddress Network       NextHop     SourcePeer  Origin AsPath            Weight
------------ -------       -------     ----------  ------ ------            ------
10.0.0.4     10.5.1.0/24   10.102.2.10 10.102.2.10 EBgp   65002-65005-65005  32768
10.0.0.4     10.5.2.0/24   10.102.2.10 10.102.2.10 EBgp   65002-65005-65005  32768
10.0.0.4     10.5.3.0/24   10.102.2.10 10.102.2.10 EBgp   65002-65005-65005  32768
10.0.0.4     10.102.1.0/24 10.102.2.10 10.102.2.10 EBgp   65002              32768
10.0.0.4     10.102.2.0/24 10.102.2.10 10.102.2.10 EBgp   65002              32768
10.0.0.4     10.102.3.0/24 10.102.2.10 10.102.2.10 EBgp   65002              32768
10.0.0.5     10.5.1.0/24   10.102.2.10 10.102.2.10 EBgp   65002-65005-65005  32768
10.0.0.5     10.5.2.0/24   10.102.2.10 10.102.2.10 EBgp   65002-65005-65005  32768
10.0.0.5     10.5.3.0/24   10.102.2.10 10.102.2.10 EBgp   65002-65005-65005  32768
10.0.0.5     10.102.1.0/24 10.102.2.10 10.102.2.10 EBgp   65002              32768
10.0.0.5     10.102.2.0/24 10.102.2.10 10.102.2.10 EBgp   65002              32768
10.0.0.5     10.102.3.0/24 10.102.2.10 10.102.2.10 EBgp   65002              32768

Get-AzVirtualRouterPeerAdvertisedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name -WarningAction Ignore | ft

LocalAddress Network       NextHop  SourcePeer Origin AsPath      Weight
------------ -------       -------  ---------- ------ ------      ------
10.0.0.4     10.0.0.0/24   10.0.0.4            Igp    65515            0
10.0.0.4     10.0.1.0/24   10.0.0.4            Igp    65515            0
10.0.0.4     10.102.1.0/24 10.0.0.4            Igp    65515-65002      0
10.0.0.4     10.102.2.0/24 10.0.0.4            Igp    65515-65002      0
10.0.0.4     10.102.3.0/24 10.0.0.4            Igp    65515-65002      0
10.0.0.5     10.0.0.0/24   10.0.0.5            Igp    65515            0
10.0.0.5     10.0.1.0/24   10.0.0.5            Igp    65515            0
10.0.0.5     10.102.1.0/24 10.0.0.5            Igp    65515-65002      0
10.0.0.5     10.102.2.0/24 10.0.0.5            Igp    65515-65002      0
10.0.0.5     10.102.3.0/24 10.0.0.5            Igp    65515-65002      0

Get-AzVirtualRouterPeerAdvertisedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer2Name -WarningAction Ignore | ft

LocalAddress Network       NextHop  SourcePeer Origin AsPath            Weight
------------ -------       -------  ---------- ------ ------            ------
10.0.0.4     10.0.0.0/24   10.0.0.4            Igp    65515                  0
10.0.0.4     10.0.1.0/24   10.0.0.4            Igp    65515                  0
10.0.0.4     10.5.3.0/24   10.0.0.4            Igp    65515-65001-65005      0
10.0.0.4     10.5.2.0/24   10.0.0.4            Igp    65515-65001-65005      0
10.0.0.4     10.5.1.0/24   10.0.0.4            Igp    65515-65001-65005      0
10.0.0.4     10.101.1.0/24 10.0.0.4            Igp    65515-65001            0
10.0.0.4     10.101.2.0/24 10.0.0.4            Igp    65515-65001            0
10.0.0.4     10.101.3.0/24 10.0.0.4            Igp    65515-65001            0
10.0.0.5     10.0.0.0/24   10.0.0.5            Igp    65515                  0
10.0.0.5     10.0.1.0/24   10.0.0.5            Igp    65515                  0
10.0.0.5     10.5.3.0/24   10.0.0.5            Igp    65515-65001-65005      0
10.0.0.5     10.5.2.0/24   10.0.0.5            Igp    65515-65001-65005      0
10.0.0.5     10.5.1.0/24   10.0.0.5            Igp    65515-65001-65005      0
10.0.0.5     10.101.1.0/24 10.0.0.5            Igp    65515-65001            0
10.0.0.5     10.101.2.0/24 10.0.0.5            Igp    65515-65001            0
10.0.0.5     10.101.3.0/24 10.0.0.5            Igp    65515-65001            0

```
The route server rs0 learns from csr1 the following networks:
* **10.5.1.0/24 AS PATH={ 65001-65005 }** 
* **10.5.2.0/24 AS PATH={ 65001-65005 }** 
* **10.5.3.0/24 AS PATH={ 65001-65005 }** 

The route server rs0 learns from csr2 the following networks:
* **10.5.1.0/24 AS PATH={ 65002-65005-65005 }**  
* **10.5.2.0/24 AS PATH={ 65002-65005-65005 }** 
* **10.5.3.0/24 AS PATH={ 65002-65005-65005 }** 
AS PATH prepending is applied to BGP peering with csr2, then AS 65005 is present two times in the path 


### <a name="routing tables"></a>4.6 effetive routing table in the Azure VMs
Below the effective routing table applied to the nic of the VMs.
To keep the logs more readable, the networks with _nexthopeType_ set to **None** are not reported in the printout.


Effective routes in vm02:
```powershell
Get-AzEffectiveRouteTable -ResourceGroupName rs03 -NetworkInterfaceName vm02-NIC | select-object -Property Source,AddressPrefix,nextHoptype,nextHopIpAddress

Source                AddressPrefix    NextHopType           NextHopIpAddress
------                -------------    -----------           ----------------
Default               {10.0.0.0/24}    VnetLocal             {}              
Default               {10.0.1.0/24}    VnetLocal             {}              
VirtualNetworkGateway {10.5.3.0/24}    VirtualNetworkGateway {10.101.2.10}   
VirtualNetworkGateway {10.5.2.0/24}    VirtualNetworkGateway {10.101.2.10}   
VirtualNetworkGateway {10.5.1.0/24}    VirtualNetworkGateway {10.101.2.10}   
Default               {0.0.0.0/0}      Internet              {}                    
Default               {10.102.0.0/16}  VNetGlobalPeering     {}              
Default               {10.101.0.0/16}  VNetGlobalPeering     {}    
```

Effective routes in vm13:
```powershell
Get-AzEffectiveRouteTable -ResourceGroupName rs03 -NetworkInterfaceName vm13-NIC | select-object -Property Source,AddressPrefix,nextHoptype,nextHopIpAddress

Source  AddressPrefix    NextHopType       NextHopIpAddress
------  -------------    -----------       ----------------
Default {10.101.0.0/16}  VnetLocal         {}              
Default {0.0.0.0/0}      Internet          {}                  
User    {10.0.0.0/8}     VirtualAppliance  {10.101.2.10}   
Default {10.0.0.0/24}    VNetGlobalPeering {}              
Default {10.0.1.0/24}    VNetGlobalPeering {}    


```

Effective routes in vm53:
```powershell
Get-AzEffectiveRouteTable -ResourceGroupName rs03 -NetworkInterfaceName vm53-NIC | select-object -Property Source,AddressPrefix,nextHoptype,nextHopIpAddress

Source                AddressPrefix    NextHopType           NextHopIpAddress
------                -------------    -----------           ----------------
Default {10.5.0.0/16}    VnetLocal        {}              
Default {0.0.0.0/0}      Internet         {}              
User    {10.0.0.0/8}     VirtualAppliance {10.5.2.10}     
```




<!--Image References-->
[1]: ./media/01.png "network diagram"
[2]: ./media/02.png "communication between VMs"
[3]: ./media/03.png "BGP peering with Azure Route Server"
[4]: ./media/04.png "preferred path between vnet0-vnet5"
[5]: ./media/05.png "backup path between vnet0-vnet5"
[6]: ./media/06.png "missing intercommunication betwen vnet1 and vnet2"

<!--Link References-->

