<properties
pageTitle='Site-to-Site IPsec tunnels in dual stack with IPv4 and IPv6 between Azure VPN Gateway and Cisco Catalyst'
description="Site-to-Site IPsec tunnels in IPv4 and IPv6 between Azure VPN Gateway and Cisco Catalyst"
services="Azure VPN Gateway"
documentationCenter="https://github.com/fabferri"
authors="fabferri"
editor="fabferri" />

<tags
   ms.service="howto-Azure-examples"
   ms.devlang="ARM template"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="Azure VPN Gateway"
   ms.date="23/07/2025"
   ms.review=""
   ms.author="fabferri" />

# Site-to-Site IPsec tunnels in dual stack with IPv4 and IPv6 between Azure VPN Gateway and Cisco Catalyst

The article walks you through Site-to-Site IPsec tunnels between an Azure VPN Gateway in active-active mode and a Cisco Catalyst 8000v. The IPsec tunnels are configured to transport IPv4 and IPv6 inner traffic. Tunnel IPv6 inner traffic refers to IPv6 packets encapsulated within IPv4 packets to enable their transmission across networks that only support IPv4 routing. <br>
The network diagram is shown below:

[![1]][1]

## Key Points

- The virtual networks **vnet1** and **vnet2** can reside in the same or different Azure regions.
- **vnet1** is configured with an Azure VPN Gateway in route-based, active-active mode. Two public IP addresses are associated with the gateway—one for each instance. The VPN Gateway uses static routing (BGP is not enabled).
- **vnet1** contains two subnets:
  - subnet1: Hosts the virtual machine vm1.
  - GatewaySubnet: Reserved for the VPN Gateway.
- In vnet2, a Cisco Catalyst device is deployed with three network interfaces:
  - **cat-eth1-nic**: Primary interface (GigabitEthernet1) used for SSH access. A public IP named **cat-eth1-nic** is associated with this interface.
  - **cat-eth2-nic**: Interface used to establish an IPsec tunnel with VPN Gateway instance 0. It has a public IP named **cat-eth2-nic**.
  - **cat-eth3-nic**: Interface used to establish an IPsec tunnel with VPN Gateway instance 1. It has a public IP named **cat-eth3-nic**.
- vnet2 simulates an on-premises network environment.
- two UDRs **RT-app-subnet**, **RT-subnet-eth1** are required to route the traffic from the **vm2** in vnet2 to the **vm1** in vnet1


The Site-to-Site VPN configuration diagram is shown below:

[![2]][2]

The two Local Network Gateway **localNetGw1**, **localNetGw2** reference the public IP assigned to the interface **cat-eth2-nic** and **cat-eth3-nic**.

## 1. File list

| File name                    | Description                                                                    |
| ---------------------------- | ------------------------------------------------------------------------------ |
| **init.json**                | define the value of input variables required for the full deployment           |
| **01-catalyst.json**         | ARM template to deploy vnet2, Catalyst and UDRs                                |
| **01-catalyst.ps1**          | powershell script to deploy **01-catalyst.json**                               |
| **02-azvng.json**            | ARM template to deploy the VPN Gateway in the **vnet1**                        |
| **02-azvng.ps1**             | powershell script to deploy **02-azvng.json**                                  |
| **03-catalyst-gen-config.ps1** |powershell script to generate the configuration of Catalyst. The configuration is created in the script folder |

The init.json file has the following structure:
```json
{
    "subscriptionName": "NAME_SUBSCRIPTION",
    "rgName": "NAME_RESOURCE_GROUP",
    "location": "AZURE_LOCATION",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "catalystName": "cat",
    "sharedKey": "SHARED_SECRET_IPsecTunnels",
    "gatewayName": "NAME_VPN_-_GATEWAY"
}
```

Run the deployment <ins>in sequence</ins>:

1. change/modify the value of input variables in the file **init.json**.
1. run the powershell script **01-catalyst.ps1**
1. run the powershell script **02-azvng.ps1**
1. run the powershell script **03-catalyst-gen-config.ps1**

if you run **02-azvng.ps1** before **01-catalyst.ps1**, the configuration will fail becasue the Local Network Gateway in Azure VPN Gateway requires the Catalyst public IPs **cat-eth2-pip** and **cat-eth3-pip**.

>
> [!NOTE]
>
> Site-to-site in dual stack, IPv4 and IPv6 inner traffic, is currently in preview. To see in the Azure management portal the IPv6 use the flight link: [az-IPv6-management portal](https://aka.ms/vpnipv6portal)
> 

## 2. How to accept the terms and condition to spin up a Cisco Catalyst

To deploy a Catalyst is required the acceptance of license and condition in Azure marketplace. <br>
AZ CLI offers some useful command to make the work: https://learn.microsoft.com/cli/azure/vm/image/terms?view=azure-cli-latest

`az vm image terms accept --offer {offer} --plan {plan} --publisher {publisher}` <br>

set the subscription: `az account set --subscription "Hybrid-PM-Demo-1"` <br>
show the current subscription: `az account show` <br>
get the full list of images: `az vm image list --all --publisher cisco --offer cisco-c8000v-byol` <br>
get the list of skus: `az vm image list --all --publisher cisco --offer cisco-c8000v-byol --query '[].{sku:sku}'` <br>
get sku and urn: `az vm image list --all --publisher cisco --offer cisco-c8000v-byol --query '[].{sku:sku,urn:urn}'` <br>
`az vm image list --all --publisher cisco --offer cisco-c8000v-byol --sku 17_15_01a-byol --query '[0].urn'` <br>

Accept Azure Marketplace image terms so that the image can be used to create VMs: <br>
`az vm image terms accept --urn cisco:cisco-c8000v-byol:17_15_01a-byol:17.15.0120240903` <br>

Verification that legal has been fulfilled: <br>
`az vm image terms show --urn cisco:cisco-c8000v-byol:17_15_01a-byol:17.15.0120240903` <br>

Acceptance of the terms and conditions is linked to the subscription and required only once per release. If the release changes, the terms and conditions must be accepted again.

## 3. Enable license in the Cisco Catalyst 8000v 

The first step after bootstrapping the Catalyst is to enable the IPsec license in configuration mode:

```console
catalyst(config)# license boot level network-advantage addon dna-advantage
catalyst# write
catalyst# reload
```

## 4. Cisco Catalyst configuration to trasport IPv6 inner traffic

The interfaces IPv6 address of the Catalyst are configured through DHCP. In IPv6, the default gateway is not assigned via DHCPv6. Instead, it is learned through Router Advertisements (RA) sent by routers on the local link. This is by design and aligns with the IPv6 protocol standards. <br>
The current setup of the Catalyst runs **Cisco IOS XE Software, Version 17.16.01a** <br>
The documentation [Security for VPNs with IPsec Configuration Guide](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/sec_conn_vpnips/configuration/xe-16-11/sec-sec-for-vpns-w-ipsec-xe-16-11-book/sec-ipsec-virt-tunnl.html) outlines support for a configuration in which an IPsec tunnel is established over a Virtual Tunnel Interface (VTI) using a <ins>dual-overlay network</ins>. The command **tunnel mode ipsec dual-overlay** enables the transport of IPv6 inner traffic across the tunnel interface.

The script **03-catalyst-gen-config.ps1** automatically generates  the site-to-site tunnels configuration for the Catalyst. Below is reported the configuration, with includes variables in PowerShell style (prefixed with $).

Variables VPN Gateway:

- `$pubIP_RemoteGtw0`: VPN GTW-public IPv4 address assigned to the VPN Gateway-instance_0
- `$pubIP_RemoteGtw1`: VPN GTW-public IPv4 address assigned to the VPN Gateway-instance_1
- `$remoteVnetAddressSpaceIPv4`: IPv4 address space of the remote vnet1
- `$remoteVnetAddressSpaceIPv6`: IPv6 address space of the remote vnet1
- `$ip_Tunnel0`: Catalyst-IPv4 address of the tunnel0 interface
- `$ip_Tunnel1`: Catalyst-IPv4 address of the tunnel1 interface
- `$priv_eth2IP`: Catalyst-IPv4 private network prefix assigned to the eth2 NIC
- `$priv_eth3IP`: Catalyst-IPv4 private network prefix assigned to the eth3 NIC
- `$mask_eth2`: Catalyst-IPv4 subnet mask assigned to the eth2 NIC
- `$mask_eth3`: Catalyst-IPv4 subnet mask assigned to the eth3 NIC
- `$defaultGwEth1Subnet`:Catalyst-IPv4 default gateway of the subnet attached to the eth1 NIC
- `$defaultGwEth2Subnet`: Catalyst-IPv4 default gateway of the subnet attached to the eth2 NIC
- `$defaultGwEth3Subnet`: Catalyst-IPv4 default gateway of the subnet attached to the eth3 NIC
- `$internalSubnetIPv4`: Catalyst-IPv4 app-subnet in vnet2
- `$internalSubnetMaskIPv4`: Catalyst-IPv4 subnet mask of the app-subnet in vnet2
- `$internalSubnetIPv6`: Catalyst-IPv6 address of the app-subnet in vnet2
- `$internalSubnetMaskIPv6`: Catalyst-IPv6 subnet mask of the app-subnet in vnet2
- `$defaultGwEth1SubnetIPv6`: Catalyst-IPv6 default gateway of the subnet attached to the eth1 NIC

```Console
!
ipv6 unicast-routing
!
interface GigabitEthernet1
 ip address dhcp
 ip nat outside
 negotiation auto
 ipv6 address dhcp
 ipv6 enable
 ipv6 nd autoconfig default-route
 no mop enabled
 no mop sysid
!
interface GigabitEthernet2
 ip address dhcp
 negotiation auto
 ipv6 address dhcp
 ipv6 enable
 ipv6 nd autoconfig default-route
 no mop enabled
 no mop sysid
 no shut
!
interface GigabitEthernet3
 ip address dhcp
 negotiation auto
 ipv6 address dhcp
 ipv6 enable
 ipv6 nd autoconfig default-route
 no mop enabled
 no mop sysid
 no shut
!
!
crypto ikev2 proposal az-PROPOSAL
 encryption aes-gcm-256 aes-gcm-128
 prf sha384 sha256
 group 14
!
crypto ikev2 policy az-POLICY
 proposal az-PROPOSAL
!
crypto ikev2 keyring az-KEYRING1
 peer az-gw-instance0
  address $pubIP_RemoteGtw0
  pre-shared-key $psk1
!
!
crypto ikev2 keyring az-KEYRING2
 peer az-gw-instance1
  address $pubIP_RemoteGtw1
  pre-shared-key $psk2
 !
crypto ikev2 profile az-PROFILE1
 match address local $priv_eth2IP
 match identity remote address $pubIP_RemoteGtw0 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local az-KEYRING1
 dpd 40 2 on-demand
!
crypto ikev2 profile az-PROFILE2
 match address local $priv_eth3IP
 match identity remote address $pubIP_RemoteGtw1 255.255.255.255
 authentication remote pre-share
 authentication local pre-share
 keyring local az-KEYRING2
 dpd 40 2 on-demand
!
crypto ipsec transform-set az-TRANSFORMSET esp-gcm 256
 mode tunnel
!
crypto ipsec profile az-IPSEC-PROFILE1
 set transform-set az-TRANSFORMSET
 set ikev2-profile az-PROFILE1
!
crypto ipsec profile az-IPSEC-PROFILE2
 set transform-set az-TRANSFORMSET
 set ikev2-profile az-PROFILE2
!
interface Tunnel0
 ip address $ip_Tunnel0 255.255.255.255
 ipv6 enable
 ip tcp adjust-mss 1350
 tunnel source $priv_eth2IP
 tunnel mode ipsec dual-overlay
 tunnel destination $pubIP_RemoteGtw0
 tunnel protection ipsec profile az-IPSEC-PROFILE1
!
interface Tunnel1
 ip address $ip_Tunnel1 255.255.255.255
 ipv6 enable
 ip tcp adjust-mss 1350
 tunnel source $priv_eth3IP
 tunnel mode ipsec dual-overlay
 tunnel destination $pubIP_RemoteGtw1
 tunnel protection ipsec profile az-IPSEC-PROFILE2
!
! route set by ARM template
ip route $remoteVnetAddressSpaceIPv4 Tunnel0
ip route $remoteVnetAddressSpaceIPv4 Tunnel1
ip route $pubIP_RemoteGtw0 255.255.255.255 $defaultGwEth2Subnet
ip route $pubIP_RemoteGtw1 255.255.255.255 $defaultGwEth3Subnet
ip route $internalSubnetIPv4 $internalSubnetMaskIPv4 $defaultGwEth1Subnet
ipv6 route $internalSubnetIPv6$internalSubnetMaskIPv6 $defaultGwEth1SubnetIPv6
ipv6 route $remoteVnetAddressSpaceIPv6 Tunnel0
ipv6 route $remoteVnetAddressSpaceIPv6 Tunnel1
!
!
line vty 0 4
 exec-timeout 10 0
exit
```

The Catalyst configuration with variables is useful to create a manual configuration by replacement the value of variables with the actual values. <br>
In IPv6, the Neighbor Discovery Protocol (ND) is used for address resolution, neighbor discovery, and router discovery. Router Advertisements (RA) are part of ND and are sent by routers to inform hosts about network prefixes, default gateways, and other configuration parameters. When a host uses SLAAC to obtain an IPv6 address, it learns the network prefix from the RA messages. However, the RA also contains information about the default gateway. The **ipv6 nd autoconfig default-route** command ensures that the router itself learns the default route from the RA, allowing it to forward traffic to other networks.

>
> [!NOTE]
>
> **no mop enabled** command in Cisco IOS disables the Maintenance Operation Protocol (MOP) on an interface. MOP is an older protocol that is enabled by default on Ethernet interfaces and is rarely needed. Disabling it enhances security by preventing potential misuse of MOP for unauthorized access.
>

## 5. Catalyst commands to verify the IPsec tunnel and routing

After completion of Catalyst configuration check the IP addreses assigne dto the GigaEthernet interfaces:

```console
cat#show ip interface brief
Interface              IP-Address      OK? Method Status                Protocol
GigabitEthernet1       10.2.0.4        YES DHCP   up                    up
GigabitEthernet2       10.2.0.36       YES DHCP   up                    up
GigabitEthernet3       10.2.0.68       YES DHCP   up                    up
Tunnel0                172.168.0.1     YES manual up                    up
Tunnel1                172.168.0.2     YES manual up                    up
VirtualPortGroup0      192.168.35.101  YES NVRAM  up                    up


cat#show ipv6 interface brief
GigabitEthernet1       [up/up]
    FE80::6245:BDFF:FEFC:2150
    2001:DB8:2:1::4
GigabitEthernet2       [up/up]
    FE80::6245:BDFF:FEFC:2A01
    2001:DB8:2:2::4
GigabitEthernet3       [up/up]
    FE80::6245:BDFF:FEFC:2299
    2001:DB8:2:3::4
Tunnel0                [up/up]
    FE80::21E:F6FF:FEFE:EE00
Tunnel1                [up/up]
    FE80::21E:F6FF:FEFE:EE00
VirtualPortGroup0      [up/up]
    unassigned
```

In order to verify that the IPsec tunnel is up between the Catalyst and the Azure VPN gateway:

```console
show crypto session 
show crypto ikev2 session
show crypto ipsec sa
show crypto ipsec sa interface tunnel0
show crypto ipsec sa interface tunnel1
```

In the Catalyst ping in IPv4 and IPv6 the vm1:

```text
cat#ping 10.1.0.4 source 10.2.0.4
cat#ping 10.1.0.4 source 10.2.0.36
cat#ping 10.1.0.4 source 10.2.0.68

cat#ping ipv6 2001:db8:1:1::4 source 2001:DB8:2:1::4
cat#ping ipv6 2001:db8:1:1::4 source 2001:db8:2:2::4
cat#ping ipv6 2001:db8:1:1::4 source 2001:db8:2:3::4
```

Commands to verify the IPv4 routing in the Catalyst:

```text
cat#show ip route
Codes: L - local, C - connected, S - static, R - RIP, M - mobile, B - BGP
       D - EIGRP, EX - EIGRP external, O - OSPF, IA - OSPF inter area
       N1 - OSPF NSSA external type 1, N2 - OSPF NSSA external type 2
       E1 - OSPF external type 1, E2 - OSPF external type 2, m - OMP
       n - NAT, Ni - NAT inside, No - NAT outside, Nd - NAT DIA
       i - IS-IS, su - IS-IS summary, L1 - IS-IS level-1, L2 - IS-IS level-2
       ia - IS-IS inter area, * - candidate default, U - per-user static route
       H - NHRP, G - NHRP registered, g - NHRP registration summary
       o - ODR, P - periodic downloaded static route, l - LISP
       a - application route
       + - replicated route, % - next hop override, p - overrides from PfR
       & - replicated local route overrides by connected

Gateway of last resort is 10.2.0.1 to network 0.0.0.0

S*    0.0.0.0/0 [1/0] via 10.2.0.1
      10.0.0.0/8 is variably subnetted, 8 subnets, 3 masks
S        10.1.0.0/24 is directly connected, Tunnel0
                     is directly connected, Tunnel1
C        10.2.0.0/27 is directly connected, GigabitEthernet1
L        10.2.0.4/32 is directly connected, GigabitEthernet1
C        10.2.0.32/27 is directly connected, GigabitEthernet2
L        10.2.0.36/32 is directly connected, GigabitEthernet2
C        10.2.0.64/27 is directly connected, GigabitEthernet3
L        10.2.0.68/32 is directly connected, GigabitEthernet3
S        10.2.0.96/27 [1/0] via 10.2.0.1
      131.145.0.0/32 is subnetted, 1 subnets
S        131.145.40.113 [1/0] via 10.2.0.65
      168.63.0.0/32 is subnetted, 1 subnets
S        168.63.129.16 [254/0] via 10.2.0.1
      169.254.0.0/32 is subnetted, 1 subnets
S        169.254.169.254 [254/0] via 10.2.0.1
      172.168.0.0/32 is subnetted, 2 subnets
C        172.168.0.1 is directly connected, Tunnel0
C        172.168.0.2 is directly connected, Tunnel1
      172.187.0.0/32 is subnetted, 1 subnets
S        172.187.117.24 [1/0] via 10.2.0.33

```

Commands to verify the IPv6 routing in the Catalyst:

```text
cat#show ipv6 route
IPv6 Routing Table - default - 6 entries
Codes: C - Connected, L - Local, S - Static, U - Per-user Static route
       B - BGP, R - RIP, H - NHRP, HG - NHRP registered
       Hg - NHRP registration summary, HE - NHRP External, I1 - ISIS L1
       I2 - ISIS L2, IA - ISIS interarea, IS - ISIS summary, D - EIGRP
       EX - EIGRP external, ND - ND Default, NDp - ND Prefix, DCE - Destination
       NDr - Redirect, RL - RPL, O - OSPF Intra, OI - OSPF Inter
       OE1 - OSPF ext 1, OE2 - OSPF ext 2, ON1 - OSPF NSSA ext 1
       ON2 - OSPF NSSA ext 2, la - LISP alt, lr - LISP site-registrations
       ld - LISP dyn-eid, lA - LISP away, le - LISP extranet-policy
       lp - LISP publications, ls - LISP destinations-summary, a - Application
       m - OMP
ND  ::/0 [2/0]
     via FE80::1234:5678:9ABC, GigabitEthernet1
     via FE80::1234:5678:9ABC, GigabitEthernet3
     via FE80::1234:5678:9ABC, GigabitEthernet2
S   2001:DB8:1::/48 [1/0]
     via Tunnel1, directly connected
     via Tunnel0, directly connected
LC  2001:DB8:2:1::4/128 [0/0]
     via GigabitEthernet1, receive
LC  2001:DB8:2:2::4/128 [0/0]
     via GigabitEthernet2, receive
LC  2001:DB8:2:3::4/128 [0/0]
     via GigabitEthernet3, receive
L   FF00::/8 [0/0]
     via Null0, receive
```

This command clears all Security Associations (SAs), which forces the device to renegotiate the IPsec tunnel:

```Console
clear crypto sa
```

If you want to target a specific peer or tunnel, you can use:

```Console
clear crypto sa peer <peer-ip-address>
```

## 6. Checking the Site-to-Site VPN status in Azure management portal

Local Network Gateways in Azure VPN Gateway:
[![3]][3]

[![4]][4]

VPN Connection1 in Azure VPN Gateway:
[![5]][5]

## 7. traffic capture in vm1 and vm2

Capture ipv6 ICMP: `tcpdump -i eth0 -n -qq ip6 proto 58`

```text
vm1:~# tcpdump -i eth0 -n -qq ip6 net 2001:db8:2::/48
vm2:~# ping -6 2001:db8:1:1::4
```

To check the web site with looback interface: `curl -6 [::1]` <br>
Generate IPv6 HTTP traffic from vm2 to vm1:

```text
vm1:~# curl -6 http://[2001:db8:2:4::4]
vm2:~# curl -6 http://[2001:db8:1:1::4]
```

## 8. Effective route tables in Azure VMs

Effective route table in **vm1-NIC**:
```powershell
 Get-AzEffectiveRouteTable -NetworkInterfaceName vm1-NIC -ResourceGroupName $rgName  | Select-Object -Property Source,State,AddressPrefix,NextHopType,NextHopIpAddress | ft

Source                State  AddressPrefix     NextHopType           NextHopIpAddress
------                -----  -------------     -----------           ----------------
Default               Active {10.1.0.0/24}     VnetLocal             {}
VirtualNetworkGateway Active {10.2.0.0/24}     VirtualNetworkGateway {10.1.0.228, 10.1.0.229}
Default               Active {0.0.0.0/0}       Internet              {}
Default               Active {2001:db8:1::/48} VnetLocal             {}
VirtualNetworkGateway Active {2001:db8:2::/48} VirtualNetworkGateway {10.1.0.228, 10.1.0.229}
Default               Active {::/0}            Internet              {}
```

Effective route table in **vm2-NIC**:
```powershell
 Get-AzEffectiveRouteTable -NetworkInterfaceName vm2-NIC -ResourceGroupName $rgName  | Select-Object -Property Source,State,AddressPrefix,NextHopType,NextHopIpAddress | ft

Source  State  AddressPrefix     NextHopType      NextHopIpAddress
------  -----  -------------     -----------      ----------------
Default Active {10.2.0.0/24}     VnetLocal        {}
Default Active {0.0.0.0/0}       Internet         {}
User    Active {10.1.0.0/24}     VirtualAppliance {10.2.0.4}
Default Active {2001:db8:2::/48} VnetLocal        {}
Default Active {::/0}            Internet         {}
User    Active {2001:db8:1::/48} VirtualAppliance {2001:db8:2:1::4}
```

## 9. IPv6 link-local

IPv6 generates a link-local address for each interface. These link-local addresses are also used by routing protocols like RIPng, EIGRP, OSPFv3, etc, as the next-hop addresses. To change a Cisco router's IPv6 link-local address, you can use the ipv6 address link-local-address link-local command within the interface configuration mode. This allows you to manually specify a link-local address, rather than relying on the automatically generated EUI-64 based address.

```text
router(config-if)# ipv6 address 2001:db8:2:5::4 link-local
```

Specifies a link-local address on the interface to be used instead of the link-local address that is automatically configured when IPv6 is enabled on the interface. This command enables IPv6 processing on the interface.
Automatically configures an IPv6 link-local address on the interface, and enables the interface for IPv6 processing. The link-local address can only be used to communicate with nodes on the same link.

## 10. Reference

[Security for VPNs with IPsec Configuration Guide](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/sec_conn_vpnips/configuration/xe-16-11/sec-sec-for-vpns-w-ipsec-xe-16-11-book/sec-ipsec-virt-tunnl.html)

<br>


`Tags: Azure VPN, Site-to-Site VPN, Site-to-Site IPsec tunnels, IPv6` <br>
`date: 23-07-2025` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/site-to-site.png "Site-to-Site configuration diagram"
[3]: ./media/local-network-gateway1.png "Local Network Gateway1 in Azure VPN Gateway"
[4]: ./media/local-network-gateway2.png "Local Network Gateway2 in Azure VPN Gateway"
[5]: ./media/connection1.png "connection1"


<!--Link References-->
