<properties
pageTitle= 'Azure route server in BGP peering with FRR'
description= "Azure route server in BGP peering with FRR"
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

## Azure route server in BGP peering with FRR

The Azure route server allows to create BGP peering with NVA.
The article shows a simple configuration with an Azure Virtual Network (VNet), an Azure route server in  **"RouteServerSubnet"** and an Ubuntu VM with Free Range Routing (FRR) deployed and configured by cloud-init. 


The network diagram is reported below:

[![1]][1]


**Files:**
| File name           |Description                                                |
| ------------------- |---------------------------------------------------------- |
| **rs.json**         | deploy a VNet, the route server and configure the BGP connection in route server an Ubuntu 22.04 VM |
| **rs.ps1**          | powershell script to run **rs.json**                      |
| **cloud-init.txt**  | cloud-init file to automatically install and setup FRR    |
| **init.json**       | input variables                                           |



## <a name="FRR"></a>1. default Inbound and Outbound policy in FRR 
In contrast to OpenBGPD, in FRR you have to configure Inbound and Outbound path policies in order FRR will accept and send inbound and outbound updates for the advertised routes. This is visulaized by the command:
<br>
```
show ip bgp neighbor
...
Inbound updates discarded due to missing policy
Outbound updates discarded due to missing policy
...
```

To setup an inbound and outbound policy use the route-map:
```
address-family ipv4 unicast
   neighbor <ip-address> route-map map-name {in | out}
```


## <a name="FRR"></a>2. cloud-init file to install and setup FRR

```yaml
#cloud-config
package_update: true
packages:
   - frr
write_files:
  - path: /opt/frr.conf
    owner: frr:frr
    content: |
      !
      frr defaults traditional
      hostname vm1
      no ipv6 forwarding
      service integrated-vtysh-config
      !
      ip route 10.0.1.0/24 10.10.4.1
      ip route 10.0.2.0/24 10.10.4.1
      ip route 10.0.3.0/24 10.10.4.1
      ip route 10.10.1.0/24 10.10.4.1
      !
      router bgp 65001
      bgp router-id 10.10.4.10
      neighbor 10.10.1.4 remote-as 65515
      neighbor 10.10.1.5 remote-as 65515
      !
      address-family ipv4 unicast
       network 10.0.1.0/24
       network 10.0.2.0/24
       network 10.0.3.0/24
       neighbor 10.10.1.4 soft-reconfiguration inbound
       neighbor 10.10.1.4 route-map BGP_IN in
       neighbor 10.10.1.4 route-map BGP_OUT out
       neighbor 10.10.1.5 soft-reconfiguration inbound
       neighbor 10.10.1.5 route-map BGP_IN in
       neighbor 10.10.1.5 route-map BGP_OUT out
      exit-address-family
      exit
      !
      ip prefix-list BGP_OUT seq 10 permit 0.0.0.0/0 le 32
      ip prefix-list BGP_IN seq 10 permit 0.0.0.0/0 le 32
      !
      route-map BGP_OUT permit 10
       match ip address prefix-list BGP_OUT
      exit
      !
      route-map BGP_IN permit 10
       match ip address prefix-list BGP_IN
      exit
      !
runcmd:
  # Enable IP forward
  - [ sed, -i, -e, '$a\net.ipv4.ip_forward = 1', /etc/sysctl.conf]
  # Apply kernel parameters
  - [ sysctl, --system ]
  - [ sed, -i, -e, 's/^bgpd=no/bgpd=yes/', /etc/frr/daemons]
  - cat /opt/frr.conf >> /etc/frr/frr.conf
  - [ systemctl, enable, frr.service ]
  - [ systemctl, restart, frr.service ]

```

## <a name="FRR"></a>3. Network prefixes learned and advertised in route server
```powershell
Get-AzRouteServerPeerLearnedRoute -ResourceGroupName test-rs -RouteServerName test-srv1 -PeerName bgp-conn1 | ft

LocalAddress Network     NextHop    SourcePeer Origin AsPath Weight
------------ -------     -------    ---------- ------ ------ ------
10.10.1.5    10.0.1.0/24 10.10.4.10 10.10.4.10 EBgp   65001   32768
10.10.1.5    10.0.3.0/24 10.10.4.10 10.10.4.10 EBgp   65001   32768
10.10.1.5    10.0.2.0/24 10.10.4.10 10.10.4.10 EBgp   65001   32768
10.10.1.4    10.0.1.0/24 10.10.4.10 10.10.4.10 EBgp   65001   32768
10.10.1.4    10.0.3.0/24 10.10.4.10 10.10.4.10 EBgp   65001   32768
10.10.1.4    10.0.2.0/24 10.10.4.10 10.10.4.10 EBgp   65001   32768

Get-AzRouteServerPeerAdvertisedRoute -ResourceGroupName test-rs -RouteServerName test-srv1 -PeerName bgp-conn1 | ft

LocalAddress Network      NextHop   SourcePeer Origin AsPath Weight
------------ -------      -------   ---------- ------ ------ ------
10.10.1.5    10.10.0.0/16 10.10.1.5            Igp    65515       0
10.10.1.4    10.10.0.0/16 10.10.1.4            Igp    65515       0
```


## <a name="ping the Azure Route Server"></a>4. Test TCP connectivity with Azure Route Server
In vm1 install hping3:

```bash
sudo apt update
sudo apt install -y hping3
hping3 --version
```

```
# initiate a classic TCP SYN Scan
# –S sets the syn flag in the TCP header
# -c 5 sets the count as 5
# –p 179 crafts the TCP segment with the destination port as TCP
#
root@vm1:~# hping3 -S 10.10.1.4 -p 179 -c 5
HPING 10.10.1.4 (eth0 10.10.1.4): S set, 40 headers + 0 data bytes
len=46 ip=10.10.1.4 ttl=128 DF id=47195 sport=179 flags=SA seq=0 win=65392 rtt=4.3 ms
len=46 ip=10.10.1.4 ttl=128 DF id=47196 sport=179 flags=SA seq=1 win=65392 rtt=4.1 ms
len=46 ip=10.10.1.4 ttl=128 DF id=47197 sport=179 flags=SA seq=2 win=65392 rtt=3.8 ms
len=46 ip=10.10.1.4 ttl=128 DF id=47198 sport=179 flags=SA seq=3 win=65392 rtt=3.7 ms
len=46 ip=10.10.1.4 ttl=128 DF id=47199 sport=179 flags=SA seq=4 win=65392 rtt=3.6 ms

--- 10.10.1.4 hping statistic ---
5 packets transmitted, 5 packets received, 0% packet loss
round-trip min/avg/max = 3.6/3.9/4.3 ms

root@vm1:~# hping3 -S 10.10.1.5 -p 179 -c 3
HPING 10.10.1.5 (eth0 10.10.1.5): S set, 40 headers + 0 data bytes
len=46 ip=10.10.1.5 ttl=128 DF id=39341 sport=179 flags=SA seq=0 win=65392 rtt=6.7 ms
len=46 ip=10.10.1.5 ttl=128 DF id=39342 sport=179 flags=SA seq=1 win=65392 rtt=6.6 ms
len=46 ip=10.10.1.5 ttl=128 DF id=39343 sport=179 flags=SA seq=2 win=65392 rtt=6.4 ms

--- 10.10.1.5 hping statistic ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 6.4/6.6/6.7 ms

```
The Route server private IPs (10.10.1.4, 10.10.1.5) answer to TCP SYN messages.


`Tags: virtual datacenter, hub-spoke` <br>
`version date: 10-08-22`
`version date: 22-08-23`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"

<!--Link References-->

