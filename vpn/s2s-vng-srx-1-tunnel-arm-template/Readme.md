<properties
pageTitle= 'Single Site-to-Site IPsec tunnel between Azure VPN Gateway and Juniper vSRX'
description= "Single Site-to-Site IPsec tunnel between Azure VPN Gateway and Juniper vSRX"
services="Azure VPN Gateway"
documentationCenter="https://github.com/fabferri"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="howto-Azure-examples"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="Azure VPN Gateway"
   ms.date="26/11/2024"
   ms.review=""
   ms.author="fabferri" />

# Single Site-to-Site IPsec tunnel between Azure VPN Gateway and Juniper vSRX
The article walks you through a Site-to-Site IPsec tunnel between an Azure VPN Gateway in active-standby mode and a Juniper vSRX <br>
The network diagram is shown below:

[![1]][1]

### Key Points:
- The virtual network **vnet1** and **vnet2** can be in same or different Azure regions
- In the **vnet1** is configured an Azure VPN Gateway route-based in active-standby mode. A single public IP is associated with the VPN Gateway. The Azure VPN Gateway is configured with BGP and ASN 65001
- In the **vnet2** is deployed a Juniper vSRX with three network interfaces: 
   - `srx-fxp0`: vSRX management interface to access in SSH to the vSRX. A public IP is associated with this interface.
   - `srx-ge-0-0-0`: vSRX untrusted interface. No publis IP is associated with this NIC.
   - `srx-ge-0-0-1`: vSRX trusted interface. A public IP is associated with this interface. the IPsec tunnel transits through this interface.
- The **vnet2** works as "simulation" of an on-premises network.  
- **vnet1** is create with two subnets
   - `subnet11`: subnet to host the vm1
   - `GatewaySubnet`: subnet reserved to the VPN Gateway
- vnet2 is create with multiple subnets
   - `subnet21`: subnet to host the vm2
   - `srx-mgt-subnet`: SRX management subnet
   - `srx-untrust-subnet`: SRX untrusted subnet
   - `srx-trust-subnet`: SRX trust subnet

The Site-to-Site VPN configuration diagram is shown:

[![2]][2]


## <a name="list of files"></a>1. File list

| File name                    | Description                                                                    |
| ---------------------------- | ------------------------------------------------------------------------------ |
| **init.json**                | define the value of input variables required for the full deployment           |
| **01-vpn.json**              | ARM template to deploy vnets, VPN Gateway                                      |
| **01-vpn.ps1**               | powershell script to deploy **01_vpn.json**                                    |
| **02-srx.json**              | ARM template to deploy a Juniper vSRX in the **vnet2**                         |
| **02-srx.ps1**               | powershell script to deploy **02-srx.json**                                    |
| **03-vpn.json**              | ARM template to create Local Network Gateway and VPN Connection                |
| **03-vpn.ps1**               | powershell script to deploy **03_vpn.json**                                    |
| **04-srx-config.ps1**        | powershell cript to generate the vSRX configuration                            |
| **05-vms.json**              | ARM template to deploy VMs in the **vnet1** and **vnet2**                      |
| **05-vms.ps1**               | powershell script to deploy **03_vpn.json**                                    |

Before running the deployment of Juniper vSRX you need to <ins>accept terms and conditions</ins> in Azure marketplace:
```console
az term accept --publisher <publisher> --product <offer> --plan <plan>
az term show --publisher "juniper-networks" --product "vsrx-next-generation-firewall-payg" --plan "vsrx-azure-image-byol"
az term accept --publisher "juniper-networks" --product "vsrx-next-generation-firewall-payg" --plan "vsrx-azure-image-byol"
```
if you do not accept terms and conditions the deployment of the Juniper vSRX will fail.

Run the deployment <ins>in sequence</ins>:
1. change/modify the value of input variables in the file **init.json**. 
2. run the powershell script **01-vpn.json**
3. run the powershell script **02-srx.ps1**
4. run the powershell script **03-vpn.ps1**
5. run the powershell script **04-srx-config.ps1**
5. run the powershell script **05-vms.ps1**

if you run **03-vpn.ps1** before **02-srx.ps1**, the configuration will fail becasue the Local Network Gateway in Azure VPN Gateway requires the vSRX public IP of untrusted interface.
<br>

The configuration of vSRX is reported below:

```Console
# Set the IP addresses for vSRX Virtual Firewall interfaces.
set interfaces ge-0/0/0 unit 0 family inet address 10.200.0.5/27
set interfaces ge-0/0/1 unit 0 family inet address 10.200.0.50/27
set interfaces st0 unit 0 family inet address <SRX_IP_SECURITY_TUNNEL_INTERFACE>/32

# define the security zone an association of interfaces to security zones.
set security zones security-zone untrust interfaces ge-0/0/0.0 host-inbound-traffic system-services ike
set security zones security-zone untrust interfaces ge-0/0/0.0 host-inbound-traffic protocols bgp
set security zones security-zone untrust interfaces st0.0 host-inbound-traffic system-services ping
set security zones security-zone untrust interfaces st0.0 host-inbound-traffic protocols bgp

# Set up the trust security zone.
set security zones security-zone trust interfaces ge-0/0/1.0 host-inbound-traffic system-services all
set security zones security-zone trust interfaces ge-0/0/1.0 host-inbound-traffic protocols all

# Set security policy
set security policies from-zone trust to-zone trust policy default-permit match source-address any
set security policies from-zone trust to-zone trust policy default-permit match destination-address any
set security policies from-zone trust to-zone trust policy default-permit match application any
set security policies from-zone trust to-zone trust policy default-permit then permit

set security policies from-zone trust to-zone untrust policy default-permit match source-address any
set security policies from-zone trust to-zone untrust policy default-permit match destination-address any
set security policies from-zone trust to-zone untrust policy default-permit match application any
set security policies from-zone trust to-zone untrust policy default-permit then permit

set security policies from-zone untrust to-zone trust policy default-permit match source-address any
set security policies from-zone untrust to-zone trust policy default-permit match destination-address any
set security policies from-zone untrust to-zone trust policy default-permit match application any
set security policies from-zone untrust to-zone trust policy default-permit then permit


# PHASE 1 (IKE)
set security ike proposal VPN_AZURE_IKE_PROPOSAL authentication-method pre-shared-keys
set security ike proposal VPN_AZURE_IKE_PROPOSAL dh-group group2
set security ike proposal VPN_AZURE_IKE_PROPOSAL encryption-algorithm aes-256-cbc
set security ike proposal VPN_AZURE_IKE_PROPOSAL authentication-algorithm sha-256
set security ike proposal VPN_AZURE_IKE_PROPOSAL lifetime-seconds 28800
set security ike policy VPN_AZURE_IKE_POLICY mode main
set security ike policy VPN_AZURE_IKE_POLICY proposals VPN_AZURE_IKE_PROPOSAL
set security ike policy VPN_AZURE_IKE_POLICY pre-shared-key ascii-text <SHARED_SECRET>
set security ike gateway VPN_AZURE_IKE_GW ike-policy VPN_AZURE_IKE_POLICY
set security ike gateway VPN_AZURE_IKE_GW address <AZURE_VPN_GATEWAY_PUBLIC_IP>
set security ike gateway VPN_AZURE_IKE_GW dead-peer-detection
set security ike gateway VPN_AZURE_IKE_GW local-identity inet <SRX_PUBLIC_IP_UNTRUSTED_INTERFACE>
set security ike gateway VPN_AZURE_IKE_GW remote-identity inet <AZURE_VPN_GATEWAY_PUBLIC_IP>
set security ike gateway VPN_AZURE_IKE_GW external-interface ge-0/0/0.0
set security ike gateway VPN_AZURE_IKE_GW version v2-only

# PHASE 2
set security ipsec proposal VPN_AZURE_IPSEC_PROPOSAL protocol esp
set security ipsec proposal VPN_AZURE_IPSEC_PROPOSAL authentication-algorithm hmac-sha1-96
set security ipsec proposal VPN_AZURE_IPSEC_PROPOSAL encryption-algorithm aes-256-cbc
set security ipsec proposal VPN_AZURE_IPSEC_PROPOSAL lifetime-seconds 28800
set security ipsec policy VPN_AZURE_IPSEC_POLICY proposals VPN_AZURE_IPSEC_PROPOSAL
set security ipsec vpn VPN_AZURE bind-interface st0.0
set security ipsec vpn VPN_AZURE ike gateway VPN_AZURE_IKE_GW
set security ipsec vpn VPN_AZURE ike ipsec-policy VPN_AZURE_IPSEC_POLICY
set security ipsec vpn VPN_AZURE establish-tunnels immediately


# Configure routing
set routing-instances siteA-vr1 instance-type virtual-router
set routing-instances siteA-vr1 interface ge-0/0/0.0
set routing-instances siteA-vr1 interface ge-0/0/1.0
set routing-instances siteA-vr1 interface st0.0

# Routing Configurations to Reach remote BGP/tunnel ip
set routing-instances siteA-vr1 routing-options static route 10.100.0.126/32 next-hop st0.0
set routing-instances siteA-vr1 routing-options static route 10.200.0.96/27 next-hop 10.200.0.33
set routing-instances siteA-vr1 routing-options static route 0.0.0.0/0 next-hop 10.200.0.1


# Configure routing policy to reditribute direct connect networks and static routes. 
# The name of routing policy in case is "send-direct" 
set policy-options policy-statement send-direct term 1 from protocol direct
set policy-options policy-statement send-direct term 1 then accept
set policy-options policy-statement send-direct term 2 from protocol static
set policy-options policy-statement send-direct term 2 from route-filter 10.200.0.96/27 orlonger
set policy-options policy-statement send-direct term 2 then accept


# BGP Configurations
set routing-instances siteA-vr1 routing-options autonomous-system <SRX_BGP_ASN>
set routing-instances siteA-vr1 routing-options router-id <SRX_IP_SECURITY_TUNNEL_INTERFACE>
set routing-instances siteA-vr1 protocols bgp group azure type external
set routing-instances siteA-vr1 protocols bgp group azure multihop ttl 50
set routing-instances siteA-vr1 protocols bgp group azure export send-direct

set routing-instances siteA-vr1 protocols bgp group azure peer-as <AZURE_VPN_GW_BGP_ASN>
set routing-instances siteA-vr1 protocols bgp group azure neighbor <AZURE_VPN_GW_BGP_IP_ADDRESS>
set routing-instances siteA-vr1 protocols bgp local-address <SRX_IP_SECURITY_TUNNEL_INTERFACE>

```

In vSRX configuration the variables are shown between bracket `<>` for an easy reading.  
- `st0.0`: SRX security tunnel interface. A secure tunnel interface (st0) is an internal interface that is used by route-based VPNs to route cleartext traffic to an IPsec VPN tunnel.
- `ge-0/0/0.0`: vSRX untrusted interface
- `<SRX_IP_SECURITY_TUNNEL_INTERFACE>`: it is the IP address of the security tunnel in vSRX. In our configuration the value is 172.16.0.1
- `<SRX_BGP_ASN>`: ASN of the vSRX. In our configuration the value is 65002
- `<SRX_PUBLIC_IP_UNTRUSTED_INTERFACE>`: it is the IP address of the untrusted NIC in the vSRX
- `<AZURE_VPN_GW_BGP_IP_ADDRESS>`: it is the BGP IP address in the Azure VPN Gateway. In our configuration the value is 10.100.0.126
- `<AZURE_VPN_GW_BGP_ASN>`: ASN of the Azure VPN Gateway. in our configuration the value is 65001
- `<SHARED_SECRET>`: it is the shared secret between the vSRX and the Azure VPN Gateway

The vSRX configuration with variables is useful to create a manual configuration of the vSRX; in this case replace the value of variables with the actual values.

## <a name="SRX commands"></a>2. SRX commands to verify the IPsec tunnel and routing

In order to verify that the IPsec tunnel is up between the vSRX and the Azure VPN gateway:
```console
show security ike security-associations
show security ipsec security-associations
```
or to get more accurate information by:
```console
show security ike security-association detail
show security ipsec security-associations detail
```

Commands to verify the routing in vSRX:
```console 
show bgp summary
show bgp group azure summary
show bgp neighbor 10.100.0.126
show route advertising-protocol bgp 10.100.0.126 table siteA-vr1
show route receive-protocol bgp 10.100.0.126 table siteA-vr1
show route 
```
Command to activate/deactivate the Site-to-Site tunnel:
```console
# To Deactivate the Site-to-Site VPN tunnel:
user@srx# deactivate security ike gateway <gatewayname>
user@srx# deactivate security ipsec vpn <vpn name>
user@srx# commit

# To Activate the Site-to-Site VPN tunnel:
user@srx# activate security ike gateway <gatewayname>
user@srx# activate security ipsec vpn <vpn name>
user@srx# commit
```

In our specific case:
```
user@srx# deactivate security ike gateway VPN_AZURE_IKE_GW
user@srx# deactivate security ipsec vpn VPN_AZURE
user@srx# commit
```

## <a name="SRX commands"></a>3. Checking the Site-to-Site VPN status in Azure management portal
Local Network Gateway in Azure VPN Gateway:
[![3]][3]

VPN Connection in Azure VPN Gateway:
[![4]][4]

BGP peers in Azure VPN Gateway:
[![5]][5]


## <a name="effective route tables"></a>4. Effective route tables in Azure VMs

Effective route table in **vm1-NIC**:
```powershell
 Get-AzEffectiveRouteTable -NetworkInterfaceName vm1-NIC -ResourceGroupName $rgName  | Select-Object -Property Source,State,AddressPrefix,NextHopType,NextHopIpAddress | ft

Source                State  AddressPrefix    NextHopType           NextHopIpAddress
------                -----  -------------    -----------           ----------------
Default               Active {10.100.0.0/24}  VnetLocal             {}
VirtualNetworkGateway Active {172.16.0.1/32}  VirtualNetworkGateway {<VPN_GW_PUBLIC_IP>}
VirtualNetworkGateway Active {10.200.0.0/27}  VirtualNetworkGateway {<VPN_GW_PUBLIC_IP>}
VirtualNetworkGateway Active {10.200.0.32/27} VirtualNetworkGateway {<VPN_GW_PUBLIC_IP>}
VirtualNetworkGateway Active {10.200.0.96/27} VirtualNetworkGateway {<VPN_GW_PUBLIC_IP>}
Default               Active {0.0.0.0/0}      Internet              {}
```

Effective route table in **vm2-NIC**:
```powershell
 Get-AzEffectiveRouteTable -NetworkInterfaceName vm2-NIC -ResourceGroupName $rgName  | Select-Object -Property Source,State,AddressPrefix,NextHopType,NextHopIpAddress | ft

Source  State  AddressPrefix    NextHopType      NextHopIpAddress
------  -----  -------------    -----------      ----------------
Default Active {10.200.0.0/24}  VnetLocal        {}
Default Active {0.0.0.0/0}      Internet         {}
User    Active {10.100.0.0/24}  VirtualAppliance {10.200.0.50}
```


## <a name="Troubleshooting"></a>5. How to configure syslog to display VPN status messages in vSRX
VPN status messages are written to the daemon facility at the "info" level. If your configuration is using the default system syslog configuration, which is "critical," the "info" VPN status messages will not be captured and viewable with show system syslog .

Therefore, perform these steps in vSRX to capture the "info" VPN status messages.
```console
srx (config)# set system syslog file kmd-logs daemon info
srx (config)# set system syslog file kmd-logs match KMD
srx (config)# commit
srx > show log kmd-logs
```
`show log kmd-logs`: view the VPN status messages

an example of logs with successful site-to-site IPsec tunnel:
```
Nov 28 11:24:02  srx kmd[13696]: KMD_PM_SA_ESTABLISHED: Local gateway: 10.200.0.5, Remote gateway: <VPN_GW_PUBLIC_IP>, Local ID: ipv4_subnet(any:0,[0..7]=0.0.0.0/0), Remote ID: ipv4_subnet(any:0,[0..7]=0.0.0.0/0), Direction: inbound, SPI: 0x9cc87ce6, AUX-SPI: 0, Mode: Tunnel, Type: dynamic, Traffic-selector:  FC Name:
Nov 28 11:24:02  srx kmd[13696]: KMD_PM_SA_ESTABLISHED: Local gateway: 10.200.0.5, Remote gateway: <VPN_GW_PUBLIC_IP>, Local ID: ipv4_subnet(any:0,[0..7]=0.0.0.0/0), Remote ID: ipv4_subnet(any:0,[0..7]=0.0.0.0/0), Direction: outbound, SPI: 0x3bb47cb4, AUX-SPI: 0, Mode: Tunnel, Type: dynamic, Traffic-selector:  FC Name:
Nov 28 11:24:02  srx kmd[13696]: KMD_VPN_UP_ALARM_USER: VPN VPN_AZURE from <VPN_GW_PUBLIC_IP> is up. Local-ip: 10.200.0.5, gateway name: VPN_AZURE_IKE_GW, vpn name: VPN_AZURE, tunnel-id: 131073, local tunnel-if: st0.0, remote tunnel-ip: Not-Available, Local IKE-ID: U�Ҭ, Remote IKE-ID: <VPN_GW_PUBLIC_IP>, AAA username: Not-Applicable, VR id: 4, Traffic-selector: , Traffic-selector local ID: ipv4_subnet(any:0,[0..7]=0.0.0.0/0), Traffic-selector remote ID: ipv4_subnet(any:0,[0..7]=0.0.0.0/0), SA Type: Static
Nov 28 11:24:02  srx kmd[13696]: IKE negotiation successfully completed. IKE Version: 2, VPN: VPN_AZURE Gateway: VPN_AZURE_IKE_GW, Local: 10.200.0.5/4500, Remote: <VPN_GW_PUBLIC_IP>/4500, Local IKE-ID: <SRX_UNTRUSTED_PUBIP>, Remote IKE-ID: <VPN_GW_PUBLIC_IP>, VR-ID: 4, Role: Initiator
Nov 28 11:24:02  srx kmd[13696]: KMD_PM_SA_ESTABLISHED: Local gateway: 10.200.0.5, Remote gateway: <VPN_GW_PUBLIC_IP>, Local ID: ipv4_subnet(any:0,[0..7]=0.0.0.0/0), Remote ID: ipv4_subnet(any:0,[0..7]=0.0.0.0/0), Direction: inbound, SPI: 0x11090e53, AUX-SPI: 0, Mode: Tunnel, Type: dynamic, Traffic-selector:  FC Name:
Nov 28 11:24:02  srx kmd[13696]: KMD_PM_SA_ESTABLISHED: Local gateway: 10.200.0.5, Remote gateway: <VPN_GW_PUBLIC_IP>, Local ID: ipv4_subnet(any:0,[0..7]=0.0.0.0/0), Remote ID: ipv4_subnet(any:0,[0..7]=0.0.0.0/0), Direction: outbound, SPI: 0xaf8ed566, AUX-SPI: 0, Mode: Tunnel, Type: dynamic, Traffic-selector:  FC Name:
Nov 28 11:24:02  srx kmd[13696]: IKE negotiation successfully completed. IKE Version: 2, VPN: VPN_AZURE Gateway: VPN_AZURE_IKE_GW, Local: 10.200.0.5/4500, Remote: <VPN_GW_PUBLIC_IP>/4500, Local IKE-ID: <SRX_UNTRUSTED_PUBIP>, Remote IKE-ID: <VPN_GW_PUBLIC_IP>, VR-ID: 4, Role: Responder
```

## <a name="Annex"></a>6. Annex

### <a name="SRX commands"></a>6.1 Display of SRX commands

```
user@srx> show security ike security-associations
Index   State  Initiator cookie  Responder cookie  Mode           Remote Address
4455313 UP     8ad90d3f1da3fca7  fc379e53525410ce  IKEv2          <VPN_GW_PUBLIC_IP>

user@srx> show security ipsec security-associations
  Total active tunnels: 1     Total Ipsec sas: 1
  ID    Algorithm       SPI      Life:sec/kb  Mon lsys Port  Gateway
  <131073 ESP:aes-cbc-256/sha1 62bdd781 20842/ unlim - root 4500 <VPN_GW_PUBLIC_IP>
  >131073 ESP:aes-cbc-256/sha1 31a611e6 20842/ unlim - root 4500 <VPN_GW_PUBLIC_IP>

user@srx> show bgp summary
Threading mode: BGP I/O
Default eBGP mode: advertise - accept, receive - accept
Groups: 1 Peers: 1 Down peers: 0
Peer                     AS      InPkt     OutPkt    OutQ   Flaps Last Up/Dwn State|#Active/Received/Accepted/Damped...
10.100.0.126          65001        967        945       0       0     7:03:19 Establ
  siteA-vr1.inet.0: 1/1/1/0

user@srx> show bgp group azure summary
Group        Type       Peers     Established    Active/Received/Accepted/Damped
azure        External   1         1
  siteA-vr1.inet.0 : 1/1/1/0

user@srx> show bgp neighbor 10.100.0.126
Peer: 10.100.0.126+59918 AS 65001 Local: 172.16.0.1+179 AS 65002
  Group: azure                 Routing-Instance: siteA-vr1
  Forwarding routing-instance: siteA-vr1
  Type: External    State: Established    Flags: <Sync InboundConvergencePending>
  Last State: OpenConfirm   Last Event: RecvKeepAlive
  Last Error: None
  Export: [ send-direct ]
  Options: <Multihop LocalAddress Ttl PeerAS Refresh>
  Options: <GracefulShutdownRcv>
  Local Address: 172.16.0.1 Holdtime: 90 Preference: 170
  Graceful Shutdown Receiver local-preference: 0
  Number of flaps: 0
  Receive eBGP Origin Validation community: Reject
  Peer ID: 10.100.0.126    Local ID: 172.16.0.1        Active Holdtime: 90
  Keepalive Interval: 30         Group index: 0    Peer index: 0    SNMP index: 0
  I/O Session Thread: bgpio-0 State: Enabled
  BFD: disabled, down
  NLRI for restart configured on peer: inet-unicast
  NLRI advertised by peer: inet-unicast inet6-unicast
  NLRI for this session: inet-unicast
  Peer supports Refresh capability (2)
  Stale routes from peer are kept for: 300
  Restart time requested by this peer: 120
  NLRI that peer supports restart for: inet-unicast inet6-unicast
  NLRI peer can save forwarding state: inet-unicast inet6-unicast
  NLRI that restart is negotiated for: inet-unicast
  NLRI of all end-of-rib markers sent: inet-unicast
  Peer does not support LLGR Restarter or Receiver functionality
  Peer supports 4 byte AS extension (peer-as 65001)
  Peer does not support Addpath
  Table siteA-vr1.inet.0 Bit: 20000
    RIB State: BGP restart is complete
    RIB State: VPN restart is complete
    Send state: in sync
    Active prefixes:              1
    Received prefixes:            1
    Accepted prefixes:            1
    Suppressed due to damping:    0
    Advertised prefixes:          3
  Last traffic (seconds): Received 2    Sent 21   Checked 25474
  Input messages:  Total 970    Updates 1       Refreshes 0     Octets 18502
  Output messages: Total 948    Updates 1       Refreshes 0     Octets 18055
  Output Queue[1]: 0            (siteA-vr1.inet.0, inet-unicast)

user@srx> show route advertising-protocol bgp 10.100.0.126 table siteA-vr1

siteA-vr1.inet.0: 9 destinations, 9 routes (9 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
* 10.200.0.0/27           Self                                    I
* 10.200.0.32/27          Self                                    I
* 10.200.0.96/27          Self                                    I


edge@srx> show route receive-protocol bgp 10.100.0.126 table siteA-vr1

siteA-vr1.inet.0: 9 destinations, 9 routes (9 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
* 10.100.0.0/24           10.100.0.126                            65001 I


edge@srx> show route

inet.0: 3 destinations, 3 routes (3 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

0.0.0.0/0          *[Access-internal/12] 10:23:19, metric 0
                    >  to 10.200.0.65 via fxp0.0
10.200.0.64/27     *[Direct/0] 10:23:19
                    >  via fxp0.0
10.200.0.68/32     *[Local/0] 10:23:19
                       Local via fxp0.0

siteA-vr1.inet.0: 9 destinations, 9 routes (9 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

0.0.0.0/0          *[Static/5] 09:24:20
                    >  to 10.200.0.1 via ge-0/0/0.0
10.100.0.0/24      *[BGP/170] 07:08:45, localpref 100, from 10.100.0.126
                      AS path: 65001 I, validation-state: unverified
                    >  via st0.0
10.100.0.126/32    *[Static/5] 09:24:19
                    >  via st0.0
10.200.0.0/27      *[Direct/0] 09:24:20
                    >  via ge-0/0/0.0
10.200.0.5/32      *[Local/0] 09:24:20
                       Local via ge-0/0/0.0
10.200.0.32/27     *[Direct/0] 09:24:20
                    >  via ge-0/0/1.0
10.200.0.50/32     *[Local/0] 09:24:20
                       Local via ge-0/0/1.0
10.200.0.96/27     *[Static/5] 09:24:20
                    >  to 10.200.0.33 via ge-0/0/1.0
172.16.0.1/32      *[Local/0] 09:24:19
                       Local via st0.0

inet6.0: 1 destinations, 1 routes (1 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

ff02::2/128        *[INET6/0] 10:22:56
                       MultiRecv

```

### <a name="Reference"></a>6.2 Reference

[How to configure a Site to Site BGP Route based VPN between Juniper SRX and Microsoft Azure](https://supportportal.juniper.net/s/article/How-to-configure-a-Site-to-Site-BGP-Route-based-VPN-between-Juniper-SRX-and-Microsoft-Azure)

[Configure an IPsec VPN Between a vSRX Virtual Firewall and Virtual Network Gateway in Microsoft Azure](https://www.juniper.net/documentation/us/en/software/vsrx/vsrx-consolidated-deployment-guide/vsrx-azure/topics/example/security-vsrx-example-azure-VPN-VNETS.html)

[SRX: How to configure syslog to display VPN status messages](https://supportportal.juniper.net/s/article/SRX-How-to-configure-syslog-to-display-VPN-status-messages)

<br>



`Tags: Azure VPN, Site-to-Site VPN, Juniper SRX` <br>
`date: 26-11-2024` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/configuration-diagram.png "Site-to-Site configuration diagram"
[3]: ./media/vpn-gw-local-network.png "Local Network Gateway in Azure VPN Gateway"
[4]: ./media/vpn-gw-connection.png "VPN Connection in Azure VPN Gateway"
[5]: ./media/vpn-gw-bgp.png "BGP peers in Azure VPN Gateway"

<!--Link References-->
