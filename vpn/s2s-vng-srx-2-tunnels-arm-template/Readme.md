<properties
pageTitle= 'Two Site-to-Site IPsec tunnels between Azure VPN Gateway and Juniper vSRX'
description= "Two Site-to-Site IPsec tunnels between Azure VPN Gateway and Juniper vSRX"
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
   ms.date="28/11/2024"
   ms.review=""
   ms.author="fabferri" />

# Two Site-to-Site IPsec tunnels between Azure VPN Gateway and Juniper vSRX
The article walks you through  Site-to-Site IPsec tunnels between an Azure VPN Gateway in active-active mode and a Juniper vSRX <br>
The network diagram is shown below:

[![1]][1]

### Key Points:
- The virtual network **vnet1** and **vnet2** can be in same or different Azure regions
- In the **vnet1** is configured an Azure VPN Gateway route-based in active-standby mode. Two public IPs is associated with the VPN Gateway, one public IP for each VPN Gateway instance. The Azure VPN Gateway is configured with BGP and ASN 65001.
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
set interfaces st0 unit 0 family inet address <SRX_IP_SECURITY_TUNNEL1_INTERFACE>/32
set interfaces st0 unit 0 family inet mtu 1400
set interfaces st0 unit 1 family inet address <SRX_IP_SECURITY_TUNNEL2_INTERFACE>/32
set interfaces st0 unit 1 family inet mtu 1400
set interfaces lo0 unit 0 family inet address 172.16.0.101/32

# define the security zone an association of interfaces to security zones.
set security zones security-zone untrust interfaces ge-0/0/0.0 host-inbound-traffic system-services ike
set security zones security-zone untrust interfaces ge-0/0/0.0 host-inbound-traffic protocols bgp
set security zones security-zone untrust interfaces st0.0 host-inbound-traffic system-services ping
set security zones security-zone untrust interfaces st0.0 host-inbound-traffic protocols bgp
set security zones security-zone untrust interfaces st0.1 host-inbound-traffic system-services ping
set security zones security-zone untrust interfaces st0.1 host-inbound-traffic protocols bgp
set security zones security-zone untrust interfaces lo0.0 host-inbound-traffic system-services ping
set security zones security-zone untrust interfaces lo0.0 host-inbound-traffic protocols bgp

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


#PHASE 1
set security ike proposal VPN_AZURE_IKE_PROPOSAL authentication-method pre-shared-keys
set security ike proposal VPN_AZURE_IKE_PROPOSAL dh-group group2
set security ike proposal VPN_AZURE_IKE_PROPOSAL encryption-algorithm aes-256-cbc
set security ike proposal VPN_AZURE_IKE_PROPOSAL authentication-algorithm sha-256
set security ike proposal VPN_AZURE_IKE_PROPOSAL lifetime-seconds 28800
set security ike policy VPN_AZURE_IKE_POLICY mode main
set security ike policy VPN_AZURE_IKE_POLICY proposals VPN_AZURE_IKE_PROPOSAL
set security ike policy VPN_AZURE_IKE_POLICY pre-shared-key ascii-text <SHARED_SECRET>

set security ike gateway VPN_AZURE_IKE_GW1 ike-policy VPN_AZURE_IKE_POLICY
set security ike gateway VPN_AZURE_IKE_GW1 address <AZURE_VPN_GATEWAY_PUBLIC_IP1>
set security ike gateway VPN_AZURE_IKE_GW1 dead-peer-detection
set security ike gateway VPN_AZURE_IKE_GW1 local-identity inet <SRX_PUBLIC_IP_UNTRUSTED_INTERFACE>
set security ike gateway VPN_AZURE_IKE_GW1 remote-identity inet <AZURE_VPN_GATEWAY_PUBLIC_IP1>
set security ike gateway VPN_AZURE_IKE_GW1 external-interface ge-0/0/0.0
set security ike gateway VPN_AZURE_IKE_GW1 version v2-only

set security ike gateway VPN_AZURE_IKE_GW2 ike-policy VPN_AZURE_IKE_POLICY
set security ike gateway VPN_AZURE_IKE_GW2 address <AZURE_VPN_GATEWAY_PUBLIC_IP2>
set security ike gateway VPN_AZURE_IKE_GW2 dead-peer-detection
set security ike gateway VPN_AZURE_IKE_GW2 local-identity inet <SRX_PUBLIC_IP_UNTRUSTED_INTERFACE>
set security ike gateway VPN_AZURE_IKE_GW2 remote-identity inet <AZURE_VPN_GATEWAY_PUBLIC_IP2>
set security ike gateway VPN_AZURE_IKE_GW2 external-interface ge-0/0/0.0
set security ike gateway VPN_AZURE_IKE_GW2 version v2-only

#PHASE 2
set security ipsec proposal VPN_AZURE_IPSEC_PROPOSAL protocol esp
set security ipsec proposal VPN_AZURE_IPSEC_PROPOSAL authentication-algorithm hmac-sha1-96
set security ipsec proposal VPN_AZURE_IPSEC_PROPOSAL encryption-algorithm aes-256-cbc
set security ipsec proposal VPN_AZURE_IPSEC_PROPOSAL lifetime-seconds 28800
set security ipsec policy VPN_AZURE_IPSEC_POLICY proposals VPN_AZURE_IPSEC_PROPOSAL

set security ipsec vpn VPN_AZURE1 bind-interface st0.0
set security ipsec vpn VPN_AZURE1 ike gateway VPN_AZURE_IKE_GW1
set security ipsec vpn VPN_AZURE1 ike ipsec-policy VPN_AZURE_IPSEC_POLICY
set security ipsec vpn VPN_AZURE1 establish-tunnels immediately

set security ipsec vpn VPN_AZURE2 bind-interface st0.1
set security ipsec vpn VPN_AZURE2 ike gateway VPN_AZURE_IKE_GW2
set security ipsec vpn VPN_AZURE2 ike ipsec-policy VPN_AZURE_IPSEC_POLICY
set security ipsec vpn VPN_AZURE2 establish-tunnels immediately

# Configure routing
set routing-instances siteA-vr1 instance-type virtual-router
set routing-instances siteA-vr1 interface ge-0/0/0.0
set routing-instances siteA-vr1 interface ge-0/0/1.0
set routing-instances siteA-vr1 interface st0.0
set routing-instances siteA-vr1 interface st0.1
set routing-instances siteA-vr1 interface lo0.0

# Routing Configurations to Reach remote BGP/tunnel ip
set routing-instances siteA-vr1 routing-options static route 10.100.0.4/32 next-hop st0.0
set routing-instances siteA-vr1 routing-options static route 10.100.0.5/32 next-hop st0.1
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
set routing-instances siteA-vr1 routing-options router-id 172.16.0.101
set routing-instances siteA-vr1 protocols bgp group azure type external
set routing-instances siteA-vr1 protocols bgp group azure multihop ttl 50
set routing-instances siteA-vr1 protocols bgp group azure export send-direct

set routing-instances siteA-vr1 protocols bgp group azure peer-as <AZURE_VPN_GW_BGP_ASN>
set routing-instances siteA-vr1 protocols bgp group azure neighbor <AZURE_VPN_GW_BGP_IP1_ADDRESS>
set routing-instances siteA-vr1 protocols bgp local-address <SRX_IP_SECURITY_TUNNEL_INTERFACE1>

set routing-instances siteA-vr1 protocols bgp group azure peer-as <AZURE_VPN_GW_BGP_ASN>
set routing-instances siteA-vr1 protocols bgp group azure neighbor <AZURE_VPN_GW_BGP_IP2_ADDRESS>
set routing-instances siteA-vr1 protocols bgp local-address <SRX_IP_SECURITY_TUNNEL_INTERFACE2>

```

In vSRX configuration the variables are shown between bracket `<>` to distringuish the variables to replace.  
- `st0.0`: SRX security tunnel interface. A secure tunnel interface (st0) is an internal interface that is used by route-based VPNs to route cleartext traffic to an IPsec VPN tunnel.
- `ge-0/0/0.0`: vSRX untrusted interface
- `<SRX_IP_SECURITY_TUNNEL_INTERFACE1>`: it is the IP address of the security tunnel interface in vSRX. In our configuration the value is 172.16.0.1
- - `<SRX_IP_SECURITY_TUNNEL_INTERFACE2>`: it is the IP address of the security tunnel interface in vSRX. In our configuration the value is 172.16.0.2
- `<SRX_BGP_ASN>`: ASN of the vSRX. In our configuration the value is 65002
- `<SRX_PUBLIC_IP_UNTRUSTED_INTERFACE>`: it is the IP address of the untrusted NIC in the vSRX
- `<AZURE_VPN_GATEWAY_PUBLIC_IP1>`: it is the public IP of the VPN Gateway instance_0
- `<AZURE_VPN_GATEWAY_PUBLIC_IP2>`: it is the public IP of the VPN Gateway instance_1
- `<AZURE_VPN_GW_BGP_IP1_ADDRESS>`: it is the BGP IP address in the Azure VPN Gateway instance_0. In our configuration the value is 10.100.0.4
- `<AZURE_VPN_GW_BGP_IP2_ADDRESS>`: it is the BGP IP address in the Azure VPN Gateway instance_1. In our configuration the value is 10.100.0.5
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
show bgp neighbor 10.100.0.4
show bgp neighbor 10.100.0.5
show route advertising-protocol bgp 10.100.0.4 table siteA-vr1
show route receive-protocol bgp 10.100.0.4 table siteA-vr1
show route advertising-protocol bgp 10.100.0.5 table siteA-vr1
show route receive-protocol bgp 10.100.0.5 table siteA-vr1
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
user@srx# deactivate security ike gateway VPN_AZURE_IKE_GW1
user@srx# deactivate security ipsec vpn VPN_AZURE1
user@srx# commit
```
or/and:
```
user@srx# deactivate security ike gateway VPN_AZURE_IKE_GW1
user@srx# deactivate security ipsec vpn VPN_AZURE1
user@srx# commit
```
## <a name="SRX commands"></a>3. Checking the Site-to-Site VPN status in Azure management portal
Local Network Gateway1 in Azure VPN Gateway:
[![3]][3]

VPN Connection1 in Azure VPN Gateway:
[![4]][4]

BGP peers in Azure VPN Gateway:
[![5]][5]

Learnt routes via BGP in Azure VPN Gateway:
[![6]][6]

## <a name="effective route tables"></a>4. Effective route tables in Azure VMs

Effective route table in **vm1-NIC**:
```powershell
 Get-AzEffectiveRouteTable -NetworkInterfaceName vm1-NIC -ResourceGroupName $rgName  | Select-Object -Property Source,State,AddressPrefix,NextHopType,NextHopIpAddress | ft

Source                State  AddressPrefix    NextHopType           NextHopIpAddress
------                -----  -------------    -----------           ----------------
Default               Active {10.100.0.0/24}   VnetLocal             {}
VirtualNetworkGateway Active {172.16.0.1/32}   VirtualNetworkGateway {10.100.0.4, 10.100.0.5}
VirtualNetworkGateway Active {10.200.0.96/27}  VirtualNetworkGateway {10.100.0.4, 10.100.0.5}
VirtualNetworkGateway Active {10.200.0.32/27}  VirtualNetworkGateway {10.100.0.4, 10.100.0.5}
VirtualNetworkGateway Active {172.16.0.101/32} VirtualNetworkGateway {10.100.0.4, 10.100.0.5}
VirtualNetworkGateway Active {10.200.0.0/27}   VirtualNetworkGateway {10.100.0.4, 10.100.0.5}
Default               Active {0.0.0.0/0}       Internet              {}
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



## <a name="Annex"></a>6. Annex

### <a name="SRX commands"></a>6.1 Display of SRX commands

```
user@srx> show security ike security-associations
Index   State  Initiator cookie  Responder cookie  Mode           Remote Address
449436  UP     f76bd4b42661324d  4538a3a1541272b6  IKEv2          <VPN_GW_PUBLIC_IP1>
449437  UP     8304210f5524b570  5ac659cfc15cf372  IKEv2          <VPN_GW_PUBLIC_IP2>

user@srx> show security ipsec security-associations
  Total active tunnels: 2     Total Ipsec sas: 2
  ID    Algorithm       SPI      Life:sec/kb  Mon lsys Port  Gateway
  <131073 ESP:aes-cbc-256/sha1 b573b6f8 28749/ unlim - root 4500 <VPN_GW_PUBLIC_IP1>
  >131073 ESP:aes-cbc-256/sha1 cb1ccf1e 28749/ unlim - root 4500 <VPN_GW_PUBLIC_IP1>
  <131074 ESP:aes-cbc-256/sha1 686ec666 28771/ unlim - root 4500 <VPN_GW_PUBLIC_IP2>
  >131074 ESP:aes-cbc-256/sha1 86cdf4c2 28771/ unlim - root 4500 <VPN_GW_PUBLIC_IP2>

user@srx> show bgp summary
Threading mode: BGP I/O
Default eBGP mode: advertise - accept, receive - accept
Groups: 1 Peers: 2 Down peers: 0
Peer                     AS      InPkt     OutPkt    OutQ   Flaps Last Up/Dwn State|#Active/Received/Accepted/Damped...
10.100.0.4            65001        375        364       0       0     2:42:44 Establ
  siteA-vr1.inet.0: 1/1/1/0
10.100.0.5            65001        372        363       0       0     2:42:40 Establ
  siteA-vr1.inet.0: 0/1/1/0

user@srx> show bgp group azure summary
Group        Type       Peers     Established    Active/Received/Accepted/Damped
azure        External   2         2
  siteA-vr1.inet.0 : 1/2/2/0


user@srx> show route advertising-protocol bgp 10.100.0.4 table siteA-vr1

siteA-vr1.inet.0: 12 destinations, 13 routes (12 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
* 10.200.0.0/27           Self                                    I
* 10.200.0.32/27          Self                                    I
* 10.200.0.96/27          Self                                    I
* 172.16.0.101/32         Self                                    I

user@srx> show route receive-protocol bgp 10.100.0.4 table siteA-vr1

siteA-vr1.inet.0: 12 destinations, 13 routes (12 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
* 10.100.0.0/24           10.100.0.4                              65001 I

user@srx> show route advertising-protocol bgp 10.100.0.5 table siteA-vr1

siteA-vr1.inet.0: 12 destinations, 13 routes (12 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
* 10.200.0.0/27           Self                                    I
* 10.200.0.32/27          Self                                    I
* 10.200.0.96/27          Self                                    I
* 172.16.0.101/32         Self                                    I

user@srx> show route receive-protocol bgp 10.100.0.5 table siteA-vr1

siteA-vr1.inet.0: 12 destinations, 13 routes (12 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
  10.100.0.0/24           10.100.0.5                              65001 I

```
### <a name="SRX security policies"></a>6.2 SRX security policies
SRX security policies are rules that determine how traffic is handled as it passes through the firewall. They define what traffic is allowed or denied between different security zones.

**Key Components of Security Policies** <br>
<ins>Zones</ins>: Security zones are logical segments of the network. Policies are applied between these zones (e.g., from the "trust" zone to the "untrust" zone).
<ins>Match Criteria</ins>: These are conditions that traffic must meet for the policy to apply. They include:
   - **Source Address**: The IP address or address set from which the traffic originates.
   - **Destination Address**: The IP address or address set to which the traffic is destined.
   - **Application**: The type of application or service (e.g., HTTP, FTP) the traffic is using.<br>

<ins>Actions</ins>: The actions specify what to do with the traffic that matches the criteria. Common actions include:<br>
   - **Permit**: Allow the traffic.
   - **Deny**: Block the traffic.
   - **Reject**: Block the traffic and send an error message to the source.

<ins>Logging and Counting</ins>: Policies can be configured to log traffic that matches the criteria or to count the number of matches.

### <a name="SRX commands"></a>6.3 Useful SRX commands
- user@srx> `show config | display set` _display the active configuration_
- user@host# `show | compare` _it shows the changes in candidate configuration which are not yet applied to the device_
- user@host# `show | compare` _is actually the same as_ `show | compare rollback 0`, _which means to compare current candidate configuration with the last active configuration (rollback 0)._ 
- user@host# `show config | compare rollback <number> ` _the current configuration is compared to previous configuration <number>_
- user@host# `show | compare rollback 1` _diplay the difference between the current candidate configuration and the archived configuration from one commit ago_

After you have rolled back the configuration, you must use the commit command to activate the configuration: <br>
user@host# `rollback <number>` <br>
user@host# `commit`

- user@srx# `rollback 0` _discard all changes_
- user@srx# `roolback ?` _visualize the list the previous configurations_

- user@srx> `show system commit` _it provides the rollback number of the configuration file to use in the next command_
- user@srx> `show system rollback compare <rollback#1> <rollback#2>` _compare two rollback configurations_

### <a name="Reference"></a>6.4 Reference

[How to configure a Site to Site BGP Route based VPN between Juniper SRX and Microsoft Azure](https://supportportal.juniper.net/s/article/How-to-configure-a-Site-to-Site-BGP-Route-based-VPN-between-Juniper-SRX-and-Microsoft-Azure)

[Configure an IPsec VPN Between a vSRX Virtual Firewall and Virtual Network Gateway in Microsoft Azure](https://www.juniper.net/documentation/us/en/software/vsrx/vsrx-consolidated-deployment-guide/vsrx-azure/topics/example/security-vsrx-example-azure-VPN-VNETS.html)

[SRX: How to configure syslog to display VPN status messages](https://supportportal.juniper.net/s/article/SRX-How-to-configure-syslog-to-display-VPN-status-messages)

<br>



`Tags: Azure VPN, Site-to-Site VPN, Site-to-Site IPsec tunnels, Juniper SRX` <br>
`date: 28-11-2024` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/configuration-diagram.png "Site-to-Site configuration diagram"
[3]: ./media/vpn-gw-local-network1.png "Local Network Gateway1 in Azure VPN Gateway"
[4]: ./media/vpn-gw-local-network2.png "Local Network Gateway2 in Azure VPN Gateway"
[5]: ./media/vpn-gw-bgp.png "BGP peers in Azure VPN Gateway"
[6]: ./media/vpn-gw-lerned-routes.png "BGP learnt routes in Azure VPN Gateway"

<!--Link References-->
