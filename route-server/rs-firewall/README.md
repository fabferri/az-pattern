<properties
pageTitle= 'Linux firewall for Internet-bound traffic and VNet with Azure Route Server'
description= "Linux firewall for Internet-bound traffic and VNet with Azure Route Server"
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
   ms.date="11/08/2021"
   ms.author="fabferri" />

## Linux firewall for Internet-bound traffic and VNet with Azure Route Server
The article describes a configuration with Azure Route Server and two NVAs, nva1 and nva2, configured for internet breakout traffic. 
<br>
An ARM template creates three vnets: vnet1, vnet2 and vnet3.
- in vnet1 is deployed an Azure Route Server and two NVAs: nva1 and nva2. The nva1 and nva2 run with uncomplicated firewall with NAT masquerading and quagga. Each NVA establishes a BGP peering with both of BGP IPs of the Route Server.
- vnet1 and vnet2 are connected through site-to-site VPN. Two IPsec tunnels are established between the Azure VPN gateways deployed with zonal gateways (SKU: **"VpnGw1AZ", "VpnGw2AZ", "VpnGw3AZ", "VpnGw4AZ", "VpnGw5AZ"**). Zonal VPN Gateways require public IP with Standard SKU and static assignment. 
- vnet1 and vnet3 are connected through vnet peering 

[![1]][1]

- Each NVA has two NICs: the first interface (eth0) is used as external interface to communicate with internet. The second interface (eth1) is used as internal interface to receive the traffic from the VMs. In each NVA is enabled the IP forwarding, to route the received traffic between eth0 and eth1. quagga is installed in to advertise the default route 0.0.0.0/0 from nva1 and nva2 to the Azure Route Server. The Azure Route Server receives the default route and pushes the routes learned to the VMs.
- to establish BGP peering, the Route Server presents two private IPs in the RouteServerSubnet: 10.0.1.68 and 10.0.1.69
- a UDR with default route to internet is applied to the subnet1, to avoid traffic loop with routing to/from internet (more details are described in routing paragraph).
- the VPN Gateways in vnet1 and vnet2 run in active-active configuration; each VPN Gateway has two public IPs. The IPsec tunnels are established between the public interface associate with the VPN Gateways, with BGP over IPsec:

[![2]][2]

<br>

| file                    | description                                                               |       
| ----------------------- |:------------------------------------------------------------------------- |
| **01-vnets-vms.json**   | ARM template to create three VNets, VMs and UDR applied to subnet1-vnet1  |
| **01-vnets-vms.ps1**    | powershell script to deploy the ARM template **vpn1.json**                |
| **02-s2s.json**         | ARM template to deploy site-so-site VPN with two IPsec tunnel between VPN Gateways in vnet1 and vnet2 |
| **02-s2s.ps1**          | powershell script to deploy the ARM template **02-s2s.json**              |
| **03-routeserver.json** | ARM template to deploy the Azure route server in vnet1 and setup the vnet peering between vnet1 and vnet3 |
| **03-routeserver.ps1**  | powershell script to deploy the ARM template **03-routeserver.json**      |
| **04-bastion.json**     | ARM template to deploy Azure Bastion in vnet1                             |
| **04-bastion.ps1**      | powershell script to deploy the ARM template **04-bastion.json**          |

In **02-s2s.json**, each ARM object **"Microsoft.Network/localNetworkGateways"** references a public IP of the remote VPN Gateway, the remote BGP peering address and the remote ASN.
<br>

The ARM template **03-routeserver.json** create the Azure Route Server in vnet1 and set the vnet peering between vnet1 and vnet3 with the following attributes:<br>

in vnet1:
```console
"allowVirtualNetworkAccess": true,
"allowForwardedTraffic": true,
"allowGatewayTransit": true,
"useRemoteGateways": false,
```
<br>

in vnet3:
```console
"allowVirtualNetworkAccess": true,
"allowForwardedTraffic": true,
"allowGatewayTransit": false,
"useRemoteGateways": true,
```
This setting is required to enable the propagation of vnet3 address space to the Azure Router Server.

<br>

The **04-bastion.json** facilitates the login to the VMs, when the default route table is applied to each VM.
<br>

> [!NOTE]
> Before spinning up the ARM templates you should:
> 1. edit the file **01-vnets-vms.json** and set the administrator _username_ and _password_ of the Azure VMs in the variables **$adminUsername**, **$adminPassword**
>
> 2. customize the values of variables stored in the **init.txt** file. Replace **YOUR_PUBLIC_IP** with the public IP used to access in SSH to the Azure VMs.
>

 
## <a name="Uncomplicated firewall"></a>1. Uncomplicated firewall configuration in the NVAs 

```
sed -i -e '$a\net.ipv4.ip_forward = 1' /etc/sysctl.conf
sysctl --system
sysctl net.ipv4.ip_forward
```
<br>

Add static route 10.0.1.64/27 to **/etc/netplan/50-cloud-init.yaml**:
```
network:
    ethernets:
        eth0:
            dhcp4: true
            dhcp4-overrides:
                route-metric: 100
            dhcp6: false
            match:
                driver: hv_netvsc
                macaddress: 00:0d:3a:96:4a:15
            set-name: eth0
        eth1:
            dhcp4: true
            dhcp4-overrides:
                route-metric: 200
            dhcp6: false
            match:
                driver: hv_netvsc
                macaddress: 00:0d:3a:42:00:81
            set-name: eth1
            routes:
              - to: 10.0.1.64/27
                via: 10.0.1.33
                metric: 10
    version: 2
```

Apply the new network config:
```
/usr/sbin/netplan apply
```

```
ufw default allow outgoing
ufw default deny incoming
ufw allow ssh
ufw show added
```

- Edit **/etc/ufw/sysctl.conf** file and uncomment: **net/ipv4/ip_forward=1**
- Edit the file **/etc/default/ufw** locate the **DEFAULT_FORWARD_POLICY** key, and change the value from **DROP** to **ACCEPT**
- Add to the **/etc/ufw/before.rules** file:

```
#NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]

# Forward traffic through eth0 - the public network interface
-A POSTROUTING -o eth0 -j MASQUERADE

# don't delete the 'COMMIT' line or these rules won't be processed
COMMIT
```

```
ufw enable
systemctl status ufw.service
ufw status numbered
```

## <a name="Uncomplicated firewall"></a>2. Configuration of quagga in nva1 and nva2
To install and configure quagga, run the bash scripts:
- **quagga1.sh** in nva1
- **quagga2.sh** in nva2

The bash scripts install quagga and establish two BGP peering with the route server endpoints:
- router server instance1-IP1: 10.0.1.68 
- router server instance1-IP1: 10.0.1.69
quagga advertises the default route 0.0.0.0/0 to the Azure Route Server.

<br>

## <a name="traffic capture"></a>3. Routing
To get the configuration working, the routing in the vnet1 needs to be properly orchestrated:
1. each NVA requires in OS routing table a default route (0.0.0.0/0) points out to the IP address of the gateway subnet (10.0.1.1) through the external interface (eth0). When an Azure VM is create with double NIC intefaces, a default route is automatically added to the system routing table, referencing the IP of the gateway through the primary interface. The default route should be then already in place, but it is good practice to verify it.
```console
root@nva1:~# ip -4 route
default via 10.0.1.1 dev eth0 proto dhcp src 10.0.1.10 metric 100
10.0.1.0/27 dev eth0 proto kernel scope link src 10.0.1.10
10.0.1.32/27 dev eth1 proto kernel scope link src 10.0.1.40
10.0.1.64/27 via 10.0.1.33 dev eth1 proto static metric 10 onlink
168.63.129.16 via 10.0.1.1 dev eth0 proto dhcp src 10.0.1.10 metric 100
169.254.169.254 via 10.0.1.1 dev eth0 proto dhcp src 10.0.1.10 metric 100
```
2. setting a static route to reach out the RouteServerSubnet. In our specific case a static route is added to the NVAs, to reach out the route server through the internal interface (eht1): <br> **0.0.1.64/27 via 10.0.1.33 dev eth1 proto static metric 10 onlink** <br> The presence of this route guarantee the pass of BGP peering between the NVAs and Azure Route server across the internal interface (eth1). 
3. in each NVA, check IP forwarding is enabled in each of NIC interfaces:
```powershell
(Get-AzNetworkInterface -ResourceGroupName $rgName -Name nva1-NIC1).EnableIPForwarding
(Get-AzNetworkInterface -ResourceGroupName $rgName -Name nva1-NIC2).EnableIPForwarding
```
4. UDR with the default route to internet is required to be applied to the subnet with external interface of the NVAs. <br> The network diagram below shows the presence of traffic loop <ins>without</ins> the UDR applied to subnet1:
[![3]][3]

The network diagram below shows the right effective routes when UDR applied to the subnet1:
[![4]][4]

5. NAT masquerade is activated in nva1 and nva2.

<br>

### <a name="effective routes"></a>3.1 Effective routes <ins>without</ins> advertisement of the default route to the route server

Routing table **vm1** without advertisement of default route from quagga to the route server:
|Source            |	    State|	Address Prefixes|	Next Hop Type  | Next Hop IP Address| User Defined Route Name|
| ---------------- | ----------- | ---------------- | ---------------- | ------------------ | ---------------------- |
|Default           |	   Active|	10.0.1.0/24     | Virtual network  |                   -|	-|
|Default           |	   Active|	10.0.3.0/24     | VNet peering     |	               -|	-|
|Virtual network gateway|  Active|	10.0.2.0/24     | Virtual network gateway|	10.0.1.228  |	-|
|Virtual network gateway|  Active|	10.0.2.0/24     | Virtual network gateway|	10.0.1.229  |	-|

<br>

Routing table **vm2** without advertisement of default route from quagga to the route server:
|Source            |	    State|	Address Prefixes|	Next Hop Type  | Next Hop IP Address| User Defined Route Name|
| ---------------- | ----------- | ---------------- | ---------------- | ------------------ | ---------------------- |
|Default	       |       Active|	10.0.2.0/24     |Virtual network   |	               -|	-|
|Virtual network gateway|  Active|	10.0.1.228/32	|Virtual network gateway|	10.0.2.228  |	-|
|Virtual network gateway|  Active|	10.0.1.228/32	|Virtual network gateway|	10.0.2.229  | 	-|
|Virtual network gateway|  Active|	10.0.1.229/32	|Virtual network gateway|	10.0.2.228  |	-|
|Virtual network gateway|  Active|	10.0.1.229/32	|Virtual network gateway|	10.0.2.229  |	-|
|Virtual network gateway|  Active|	10.0.1.0/24	    |Virtual network gateway|	10.0.2.228  |	-|
|Virtual network gateway|  Active|	10.0.1.0/24	    |Virtual network gateway|	10.0.2.229  |	-|
|Virtual network gateway|  Active|	10.0.3.0/24	    |Virtual network gateway|	10.0.2.228  |	-|
|Virtual network gateway|  Active|	10.0.3.0/24	    |Virtual network gateway|	10.0.2.229  |	-|
|Default	       |       Active|	0.0.0.0/0	    |Internet	       |                   -|	-|



### <a name="effective routes"></a>3.2 Effective routes <ins>with</ins> advertisement of the default route 0.0.0.0/0 to the route server

Routing table **vm3** with advertisement of default route 0.0.0.0/0 from quagga to the route server:
|Source            |	    State|	Address Prefixes|	Next Hop Type  | Next Hop IP Address| User Defined Route Name|
| ---------------- | ----------- | ---------------- | ---------------- | ------------------ | ---------------------- |
|Default           |	Active   | 10.0.3.0/24      |	Virtual network|	               -|	-|
|Default	       |    Active	 | 10.0.1.0/24	    |VNet peering      |	               -|	-|
|Virtual network gateway| Active | 10.0.2.0/24	    |Virtual network gateway|	10.0.1.228  |	-|
|Virtual network gateway| Active | 10.0.2.0/24	    |Virtual network gateway|	10.0.1.229  |	-|
|Virtual network gateway| Active | 0.0.0.0/0	    |Virtual network gateway|	10.0.1.40   |	-|
|Virtual network gateway| Active | 0.0.0.0/0	    |Virtual network gateway|	10.0.1.41   |	-|

Routing table **vm1** with advertisement of default route 0.0.0.0/0 from quagga to the route server:
|Source            |	    State|	Address Prefixes|	Next Hop Type  | Next Hop IP Address| User Defined Route Name|
| ---------------- | ----------- | ---------------- | ---------------- | ------------------ | ---------------------- |
|Default	       | Active	     | 10.0.1.0/24	    | Virtual network  |	               -|	-|
|Default	       | Active	     | 10.0.3.0/24	    | VNet peering     |	               -|	-|
|Virtual network gateway| Active |	10.0.2.0/24	    | Virtual network gateway|	10.0.1.228  |	-|
|Virtual network gateway| Active |	10.0.2.0/24	    | Virtual network gateway|	10.0.1.229  |	-|
|Virtual network gateway| Active |	0.0.0.0/0	    | Virtual network gateway|	10.0.1.40   |	-|
|Virtual network gateway| Active |	0.0.0.0/0	    | Virtual network gateway|	10.0.1.41   |	-|

**The current release of the Azure VPN Gateway does not propagate the default route 0.0.0.0/0 to the remote VPN peer. The missing presence of default route in the vnet2 does not allow to Azure vm2 to use nva1 and nva2 in vnet1 for internet breakout.** 

Routing table **nva1-NIC1** with advertisement of default route 0.0.0.0/0 from quagga to the route server:
|Source            |	    State|	Address Prefixes|	Next Hop Type  | Next Hop IP Address| User Defined Route Name|
| ---------------- | ----------- | ---------------- | ---------------- | ------------------ | ---------------------- |
|Default	       | Active	     | 10.0.1.0/24      | Virtual network  |                  -	|-|
|Default	       | Active	     | 10.0.3.0/24	    | VNet peering     |                  -	|-|
|Virtual network gateway |Active | 10.0.2.0/24	    | Virtual network gateway|	10.0.1.228  |-|
|Virtual network gateway |Active | 10.0.2.0/24	    | Virtual network gateway|	10.0.1.229  |-|
|Virtual network gateway |Invalid| 0.0.0.0/0	    | Virtual network gateway|	10.0.1.40	|-|
|Virtual network gateway |Invalid| 0.0.0.0/0	    | Virtual network gateway|	10.0.1.41	|-|
|User	           |Active	     | 0.0.0.0/0	    | Internet	             |             -| default|

Routing table **nva1-NIC2** with advertisement of default route 0.0.0.0/0 from quagga to the route server:
|Source            |	    State|	Address Prefixes|	Next Hop Type  | Next Hop IP Address| User Defined Route Name|
| ---------------- | ----------- | ---------------- | ---------------- | ------------------ | ---------------------- |
|Default	       | Active	     | 10.0.1.0/24	    | Virtual network  |	              -	| -|
|Default	       | Active	     | 10.0.3.0/24	    | VNet peering	   |                  -	| -|
|Virtual network gateway| Active |	10.0.2.0/24	    | Virtual network gateway|	10.0.1.228  | -|
|Virtual network gateway| Active |	10.0.2.0/24	    | Virtual network gateway|	10.0.1.229  | -|
|Virtual network gateway| Active |	0.0.0.0/0	    | Virtual network gateway|	10.0.1.40   | -|
|Virtual network gateway| Active |	0.0.0.0/0	    | Virtual network gateway|	10.0.1.41   | -|

<br>

Routes advertised from Route Server:
```
LocalAddress Network     NextHop   SourcePeer Origin AsPath            Weight
------------ -------     -------   ---------- ------ ------            ------
10.0.1.68    10.0.1.0/24 10.0.1.68            Igp    65515                  0
10.0.1.68    10.0.2.0/24 10.0.1.68            Igp    65515-65001-65002      0
10.0.1.68    10.0.3.0/24 10.0.1.68            Igp    65515                  0
10.0.1.69    10.0.1.0/24 10.0.1.69            Igp    65515                  0
10.0.1.69    10.0.2.0/24 10.0.1.69            Igp    65515-65001-65002      0
10.0.1.69    10.0.3.0/24 10.0.1.69            Igp    65515                  0
```
<br>

Routes learned in Route Server:
```
LocalAddress Network   NextHop   SourcePeer Origin AsPath Weight
------------ -------   -------   ---------- ------ ------ ------
10.0.1.68    0.0.0.0/0 10.0.1.40 10.0.1.40  EBgp   65010   32768
10.0.1.69    0.0.0.0/0 10.0.1.40 10.0.1.40  EBgp   65010   32768
```

<br>

## <a name="traffic capture"></a>4. Check the traffic passing across NVAs
To check the traffic going to or from vm3 and passing across nva1 and nva2:
```
tcpdump -n -i eth1 host 10.0.3.10 and not host <IP1> and not host <IP2>
```
The agent installed linux VM communicates in HTTPS with the Microsoft public endpoints; IP1 and IP2 are microsoft management public endpoints to be excluded from the capture.

<br>

## <a name="quagga configuration"></a>5. ANNEX: quagga configuration in nva1
```console
nva1# show run
Building configuration...

Current configuration:
!
!
interface eth0
!
interface eth1
!
interface lo
!
router bgp 65010
 bgp router-id 10.0.1.40
 network 0.0.0.0/0
 neighbor 10.0.1.68 remote-as 65515
 neighbor 10.0.1.68 soft-reconfiguration inbound
 neighbor 10.0.1.69 remote-as 65515
 neighbor 10.0.1.69 soft-reconfiguration inbound
!
 address-family ipv6
 exit-address-family
 exit
!
ip forwarding
!
line vty
!
end
```

```
nva1# show ip route
Codes: K - kernel route, C - connected, S - static, R - RIP,
       O - OSPF, I - IS-IS, B - BGP, P - PIM, A - Babel, N - NHRP,
       > - selected route, * - FIB route

K>* 0.0.0.0/0 via 10.0.1.1, eth0, src 10.0.1.10
C>* 10.0.1.0/27 is directly connected, eth0
C>* 10.0.1.32/27 is directly connected, eth1
K>* 10.0.1.64/27 via 10.0.1.33, eth1
C>* 127.0.0.0/8 is directly connected, lo
K>* 168.63.129.16/32 via 10.0.1.1, eth0, src 10.0.1.10
K>* 169.254.169.254/32 via 10.0.1.1, eth0, src 10.0.1.10


nva1# show ip bgp
BGP table version is 0, local router ID is 10.0.1.40
Status codes: s suppressed, d damped, h history, * valid, > best, = multipath,
              i internal, r RIB-failure, S Stale, R Removed
Origin codes: i - IGP, e - EGP, ? - incomplete

   Network          Next Hop            Metric LocPrf Weight Path
*> 0.0.0.0          0.0.0.0                  0         32768 i
   10.0.1.0/24      10.0.1.68                              0 65515 i
                    10.0.1.69                              0 65515 i
   10.0.2.0/24      10.0.1.68                              0 65515 65001 65002 i
                    10.0.1.69                              0 65515 65001 65002 i
   10.0.3.0/24      10.0.1.68                              0 65515 i
                    10.0.1.69                              0 65515 i

Displayed  4 out of 7 total prefixes
```


<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/network-diagram2.png "BGP peering over IPSec tunnels"
[3]: ./media/effective-routes1.png "presence of loop due to missing UDR in subnet1"
[4]: ./media/effective-routes2.png "correct routing with UDR"
<!--Link References-->

