<properties
pageTitle= 'Overlay network between two VNets connected through IPSec by Juniper SRX'
description= "Overlay network between two VNets connected through IPsec by Juniper SRX"
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
   ms.date="30/07/2020"
   ms.author="fabferri" />

# Overlay network between two VNets connected through IPsec by Juniper SRX
Adoption of overlay network introduce in most of case complexities in setup and maintenance and it should be evaluated careful before using in production.
The article reports the ARM templates to create two Azure VNets, named vnet1 and vnet2. Each VNet is deployed with four subnets and a Juniper SRX with 4 NICs attached to each subnet.
Below is shown the network diagram.

[![1]][1]

The ARM template assigns:
- dynamic private IP address to the management interface 
- static private IP address to the other gigaEthernet interfaces

Inside the SRX, the IP addresses are associated with physical subinterfaces are all acquired via dhcp; the IP addresses of logical interfaces are statically assigned.

### **srx1**
|interface  |priv IP Address | assigmement inside srx |
|-----------|----------------|-------------|
|fxp0.0     |10.0.1.4/27     | vnet-dhcp   |
|ge-0/0/0.0 |10.0.1.50/27    | vnet-dhcp   |
|ge-0/0/1.0 |10.0.1.80/27    | vnet-dhcp   |
|ge-0/0/2.0 |10.0.1.120/27   | vnet-dhcp   |
|lo0.0      |172.16.1.1/32   |statically inside the srx config|
|st0.0      |192.168.1.1/30  |statically inside the srx config|

### **srx2**
|interface  |IP Address    | assigmement inside srx |
|-----------|--------------|-------------|
|fxp0.0     |10.0.2.4/27   | vnet-dhcp   |
|ge-0/0/0.0 |10.0.2.50/27  | vnet-dhcp   |
|ge-0/0/1.0 |10.0.2.80/27  | vnet-dhcp   |
|ge-0/0/2.0 |10.0.2.120/27 | vnet-dhcp   |
|lo0.0      |172.16.1.2/32 |statically inside the srx config|
|st0.0      |192.168.1.2/30|statically inside the srx config|

The configuration aims to establish a communication between the subnets in different VNets, through the same IPsec tunnel, with the following communications:
* [vnet1-subnet3] <-> [vnet2-subnet3]: allowed
* [vnet1-subnet4] <-> [vnet2-subnet4]: allowed
* [vnet1-subnet3] <-> [vnet1-subnet4]: deny
* [vnet2-subnet3] <-> [vnet2-subnet4]: deny
* [vnet1-subnet3] <-> [vnet2-subnet4]: deny

[![2]][2]

The desired implementation can be achieved in SRX with different routing instances.
A routing instance is a collection of routing tables, interfaces, and routing protocol parameters. Each routing instance consists of sets of the following:
* routing tables
* interfaces that belong to these routing tables

Junos supports different types of routing instances. In our setup, we use the VPN routing and forwarding (VRF) routing instance type for Layer 3 VPN. This routing instance type has a VPN routing table as well as a corresponding VPN forwarding table. For this instance type, there is a _one-to-one mapping between an interface and a routing instance_. Each VRF instance corresponds with a forwarding table. Routes on an interface go into the corresponding forwarding table. 

The interfaces are all still configured in the normal interface section, you just assign them to the specific routing-instance in the routing-instance section.  Within the routing-instance you also setup protocols and other "VRF" specific config you may need. 

In our setup two VRF routing instances are defined, named **blue-vrf** and **red-vrf**. To transport the VRF information between two SRXs is required the implementation of MPLS over IPsec.

Native support of MPLS over IPsec is not doable. Let's discuss why doesn't work.
A SRX device operate in two different modes: 
* **packet mode**. In packet mode, SRX processes the traffic on a per-packet basis. This is also known as stateless processing of traffic. 
* **flow mode**. In flow mode, SRX processes all traffic by analyzing the state or session of traffic. This is also called stateful processing of traffic. 

 IPsec is only supported with **flow mode** (which is default mode).  
 On SRX and J-Series MPLS can only be used in **packet mode**. 

If you convert the device to packet-mode (e.g.  configuring MPLS), you will not be able to configure IPsec VPN. That means you will not be able to use IPsec with MPLS at the same time. Hence you can only have one or the other. 
The issue can be overcome by generic routing encapsulation (GRE) over an IP Security (IPsec) tunnel.
In a GRE over IPsec tunnel, all of the routing traffic can be routed through because when the original packet is GRE encapsulated, it will have an IP header (as defined by the GRE tunnel, which is normally the tunnel interface IP addresses). The IPsec protocol can, therefore, understand the IP packet and so it can encapsulate the GRE packet to make it GRE over IPsec.

### **Note**
> To enable packet based forwarding (stateless), commit the following and reboot the SRX.
> ```console
> set security forwarding-options family mpls mode packet-based
> ```
>
> To enable flow based forwarding (statefull - the default), commit the following and reboot the SRX.  
> ```console
> set security forwarding-options family mpls mode flow-based
> ````
>
> then reboot the box: 
> ```console
> request system reboot
> ```

### **Note**
>
> To make GRE over IPsec: 
> - the IPsec tunnel needs to be route based 
>
> AND 
>
> - GRE endpoint and the IPsec endpoint cannot be the same to ensure that the GRE packets go over the IPsec tunnel.
>

## <a name="AzureDeployment"></a>1. List of files
|file           |description    | 
|---------------|---------------|
|**init.json**  |set paramenters values for the deployment of siteA and siteB| 
|**siteA.json** | ARM template to deploy siteA|
|**siteA.ps1**  | powershell script to run **siteA.json**|
|**siteB.json** | ARM template to deploy **siteB**|
|**siteB.ps1**  | powershell script to run **siteB.json**|
|**srx1-gen-config.ps1**| generate the configuration if srx1 in siteA|
|**srx2-gen-config.ps1**| generate the configuration if srx2 in siteB|
|**srx1-config.txt**| configuration file generated from the script **srx1-gen-config.ps1**|
|**srx2-config.txt**| configuration file generated from the script **srx2-gen-config.ps1**|

The pre-shared key (PSK) for the IPsec tunnel is defined in the variable **$presharedKey** in the scripts **srx1-gen-config.ps1**, **srx2-gen-config.ps1**
Before running those powershell scripts you might want to change the value of pre-shared key; please be sure that the variable **$presharedKey** has the same value in both scripts.

For production Juniper recommend Standard_D4s_v3 (max 2 NICs) or Standard_D8s_v3 (max 4 NICs) SKUs.
The ARM templates **siteA.json**, **siteB.json** deploy the SRXs with Standard_B4ms SKU (pretty cost effective) and it should be used _ONLY_ for testing purposes. The  Standard_B4ms supports max 4 NICs. 

## <a name="AzureDeployment"></a>2. How to run the deployment
### <a name="AzureDeployment"></a>2.1 Fill out the values in the file **init.json**
As first step, fill up the right variables values in the init.json file. The init.json file contains information on Azure subscription to deploy the two sites. Do not change the name of variables, but only change their values (assignment).

```json
{
 "siteA":{
   "subscriptionName": "NAME_OF_YOUR_AZURE_SUBSCRIPTION_TO_DEPLOY_SITEA",
   "adminUsername": "ADMINISTRATOR_USERNAME_SITEA",
   "adminPassword": "ADMINISTRATOR_PASSWORD_SITEA",
   "rgName": "NAME_RESOURCE_GROUP_SITEA",
   "location":"NAME_AZURE_REGION_SITEA",
   "srx1_vmName":"NAME_SRX_IN_SITEA"
 },
 "siteB":{
   "subscriptionName": "NAME_OF_YOUR_AZURE_SUBSCRIPTION_TO_DEPLOY_SITEB",
   "adminUsername": "ADMINISTRATOR_USERNAME_SITEB",
   "adminPassword": "ADMINISTRATOR_PASSWORD_SITEB",
   "rgName": "NAME_RESOURCE_GROUP_SITEB",
   "location":"NAME_AZURE_REGION_SITEB",
   "srx1_vmName":"NAME_SRX_IN_SITEB"
 }
}
```
if you do not set the value of the variables in init.json, your deployment will fail.

### <a name="AzureDeployment"></a>2.2 market terms and condition to run the srx image
Deployment of NVAs in Azure marketplace requires three mandatory parameters: "publisher", "offer", "sku", "version"
To find out the desired image run the powershell **getImages.ps1** and select the options.

[![3]][3]
[![4]][4]
[![5]][5]
[![6]][6]

The ARM template uses the following image:
  - "publisher" "juniper-networks"
  - "offer": "vsrx-next-generation-firewall"
  - "sku":  "vsrx-byol-azure-image"
  - "version": "latest"

Utilization of third-party software in azure marketplace requires approval of terms and condition. If you reference a product in ARM template without acceptance of terms and condition your deployment will fail with message:

```console
New-AzResourceGroupDeployment : 10:04:44 - Error: Code=MarketplacePurchaseEligibilityFailed; Message=Marketplace purchase eligibilty check returned errors.
```

To accept market terms and condition run the following command to check the specific image:

```powershell
 Get-AzMarketplaceTerms  -Publisher "juniper-networks" -Product "vsrx-next-generation-firewall-payg"  -Name "vsrx-azure-image-byol" 
```
if the outcome of previous command is not empty, accept the license:
```powershell
$agreementTerms=Get-AzMarketplaceTerms  -Publisher "juniper-networks" -Product "vsrx-next-generation-firewall"  -Name "vsrx-byol-azure-image"

 Set-AzMarketplaceTerms -Publisher "juniper-networks" -Product "vsrx-next-generation-firewall" -Name "vsrx-byol-azure-image" -Terms $agreementTerms -Accept
```
Through the Azure management portal enable the automatic deployment through powershell/ARM templates.
[![7]][7]
[![8]][8]

### <a name="AzureDeployment"></a>1.3 Run the powershell script siteA.ps1
The script **siteA.ps1** reads the file **init.json** and then deployes the ARM template **siteA.json**.
When completed the siteA will be running with vnet1, srx1, vm1a and vm1b.

[![9]][9]

### <a name="AzureDeployment"></a>1.4 Run the powershell script siteB.ps1
The script **siteB.ps1** reads the file **init.json** and then deploys the ARM template **siteB.json**.
When completed the siteB will be running with vnet2, srx2, vm2a and vm2b.

To speed up the deployment you can run the scripts siteA.ps1 and siteB.ps1 in parallel in two powershell sessions.

### <a name="AzureDeployment"></a>1.5 Run the script srx1-gen-config.ps1
The script **srx1-gen-config.ps1** generates a text file named **srx1-config.txt** 

The **srx1-config.txt** contains the Junos commands to setup the **srx1** in siteA.
Connect via SSH to the srx1 console and, in edit mode, paste the content of srx1-config.txt.

Run the Junos command **commit check** to check the consistency of configuration. If there is no error, proceed with the command **commit** to apply the configuration to the srx.


#### Note
The script **srx1-gen-config.ps1** collects the public IP addresses (local and remote) associated with the interface where IPsec tunnel has to be established. Below a snippet to get the public IPs associated with the SRXs:

```powershell
$rgLocal='NAME_OF_LOCAL_RESOURCE_GROUP'
$rgRemote='NAME_OF_REMOTE_RESOURCE_GROUP'
$nicNameLocal='NAME_OF_LOCAL_SRX'+'-ge-0-0-0'
$nicNameRemote='NAME_OF_REMOTE_SRX'+'-ge-0-0-0'

$ip_srx_Local=(Get-AzPublicIpAddress  -ResourceGroupName $rgLocal -Name $nicNameLocal).IpAddress
$ip_srx_Remote=(Get-AzPublicIpAddress  -ResourceGroupName $rgRemote -Name $nicNameRemote).IpAddress

Write-Host "IP Local....: "$ip_srx_Local -ForegroundColor Yellow
Write-Host "IP Remote...: "$ip_srx_Remote -ForegroundColor Yellow
``` 
The above powershell snippet is integrated inside **srx1-gen-config.ps1**.

### <a name="AzureDeployment"></a>1.5 Run the script srx2-gen-config.ps1
The script **srx2-gen-config.ps1** generates a text file named **srx2-config.txt** 

The **srx2-config.txt** contains the Junos commands to setup the **srx2** in siteB. Connect via SSH to the srx2 console and, in edit mode, paste the content of srx2-config.txt.

Run the Junos command **commit check** to check the consistency of configuration. If there is no error, proceed with the command **commit** to apply the configuration to the srx.

#### Note: srx management interface
By default,  the management Ethernet interface (usually fxp0) provides the out-of-band management network for the device. There is no clear separation between either out-of-band management traffic and in-band protocol control traffic, that is, user traffic at the routing-instance or routing-table level. Instead, all traffic is handled through the default routing instance (inet.0 table).
In our configuration we move the fxp0 management interfaces in a nondefault virtual routing and forwarding (VRF) instance, the **mgmt_junos** routing instance. 
```console
set routing-instances mgmt_junos description "management routing instance"
set system management-instance
```
The name of the dedicated management instance is reserved and hardcoded as mgmt_junos. Once the mgmt_junos routing instance is deployed, management traffic no longer shares a routing table (that is, the default inet.0 table) with other control or protocol traffic in the system.Tables for the mgmt_junos table are set up for inet and inet6 and marked as private tables. The management interface fxp0 is moved to the mgmt_junos routing table. At the point where you commit the configuration, if you are using SSH, the connection to the device will be dropped and you will have to re-establish it (likewise our case).

After you configure this management routing instance, management traffic no longer has to share a routing table (that is, the default inet.0 table) with other control or protocol traffic in the system. This improves security and makes it easier to use the management interface to troubleshoot.



## <a name="AzureDeployment"></a>2. Check post srx configurations
After application of configurations to srx1 and srx2, we can execute few checks.

```
device: srx1, subinterface: ge-0/0/0.0, public IP associated with the subinterface: 13.68.202.166
device: srx2, subinterface: ge-0/0/0.0, public IP associated with the subinterface: 13.68.203.192
```

```console
srx1> show security ike security-associations
Index   State  Initiator cookie  Responder cookie  Mode           Remote Address
8107851 UP     fb41ebf0d6974d16  8d80f0886faa2492  IKEv2          13.68.203.192

srx1> show security ipsec security-associations
  Total active tunnels: 1     Total Ipsec sas: 1
  ID    Algorithm       SPI      Life:sec/kb  Mon lsys Port  Gateway
  <131073 ESP:aes-cbc-256/sha1 18bdd9c9 2882/ unlim - root 4500 13.68.203.192
  >131073 ESP:aes-cbc-256/sha1 66f9ccb0 2882/ unlim - root 4500 13.68.203.192
```

```console
srx2> show security ike security-associations
Index   State  Initiator cookie  Responder cookie  Mode           Remote Address
6878435 UP     fb41ebf0d6974d16  8d80f0886faa2492  IKEv2          13.68.202.166


srx2> show security ipsec security-associations
  Total active tunnels: 1     Total Ipsec sas: 1
  ID    Algorithm       SPI      Life:sec/kb  Mon lsys Port  Gateway
  <131073 ESP:aes-cbc-256/sha1 66f9ccb0 2818/ unlim - root 4500 13.68.202.166
  >131073 ESP:aes-cbc-256/sha1 18bdd9c9 2818/ unlim - root 4500 13.68.202.166
```

Verify that the GRE interface is up:
```console
srx1> show interfaces gr-0/0/0 terse
Interface               Admin Link Proto    Local                 Remote
gr-0/0/0                up    up
gr-0/0/0.0              up    up   inet     172.16.255.1/30
                                   mpls
```

Verify that the route for the destination network is reachable through the GRE tunnel:
```console
srx1> show route 172.16.255.2

inet.0: 11 destinations, 12 routes (11 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

172.16.255.0/30    *[Direct/0] 00:34:43
                    >  via gr-0/0/0.0
                    [OSPF/10] 00:34:42, metric 1
                    >  via gr-0/0/0.0

mgmt_junos.inet.0: 3 destinations, 3 routes (3 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

0.0.0.0/0          *[Access-internal/12] 00:34:46, metric 0
                    >  to 10.0.1.1 via fxp0.0
```
```
srx1> show ospf route
Topology default Route Table:

Prefix             Path  Route      NH       Metric NextHop       Nexthop
                   Type  Type       Type            Interface     Address/LSP
172.16.1.2         Intra Router     IP            1 gr-0/0/0.0
172.16.1.1/32      Intra Network    IP            0 lo0.0
172.16.1.2/32      Intra Network    IP            1 gr-0/0/0.0
172.16.255.0/30    Intra Network    IP            1 gr-0/0/0.0
```
```console
srx2> show ospf route
Topology default Route Table:

Prefix             Path  Route      NH       Metric NextHop       Nexthop
                   Type  Type       Type            Interface     Address/LSP
172.16.1.1         Intra Router     IP            1 gr-0/0/0.0
172.16.1.1/32      Intra Network    IP            1 gr-0/0/0.0
172.16.1.2/32      Intra Network    IP            0 lo0.0
172.16.255.0/30    Intra Network    IP            1 gr-0/0/0.0
```
```console
srx1> show ldp route
Destination                            Next-hop intf/lsp/table  Next-hop address
 0.0.0.0/0                             ge-0/0/0.0               10.0.1.33
 10.0.1.32/27                          ge-0/0/0.0
 10.0.1.50/32
 172.16.1.1/32                         lo0.0
 172.16.1.2/32                         gr-0/0/0.0
 172.16.255.0/30                       gr-0/0/0.0
 172.16.255.1/32
 192.168.1.0/30                        st0.0
 192.168.1.1/32
 224.0.0.5/32
```

```console
srx1> show ldp session
  Address                           State       Connection  Hold time  Adv. Mode
172.16.1.2                          Operational Open          20         DU
```

Network prefixes received from the remote BGP peer 172.16.1.2:
```console
srx1> show route receive-protocol bgp 172.16.1.2

inet.0: 11 destinations, 12 routes (11 active, 0 holddown, 0 hidden)

inet.3: 1 destinations, 1 routes (1 active, 0 holddown, 0 hidden)

mgmt_junos.inet.0: 3 destinations, 3 routes (3 active, 0 holddown, 0 hidden)

blue-vrf.inet.0: 3 destinations, 3 routes (3 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
* 10.0.2.64/27            172.16.1.2                   100        I

red-vrf.inet.0: 3 destinations, 3 routes (3 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
* 10.0.2.96/27            172.16.1.2                   100        I

mpls.0: 8 destinations, 8 routes (8 active, 0 holddown, 0 hidden)

bgp.l3vpn.0: 2 destinations, 2 routes (2 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
  10:10:10.0.2.64/27
*                         172.16.1.2                   100        I
  20:20:10.0.2.96/27
*                         172.16.1.2                   100        I

inet6.0: 1 destinations, 1 routes (1 active, 0 holddown, 0 hidden)

blue-vrf.inet6.0: 1 destinations, 1 routes (1 active, 0 holddown, 0 hidden)

red-vrf.inet6.0: 1 destinations, 1 routes (1 active, 0 holddown, 0 hidden)
```

Network prefixes advertised to the remote BGP peer 172.16.1.2
```console
srx1> show route advertising-protocol bgp 172.16.1.2

blue-vrf.inet.0: 3 destinations, 3 routes (3 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
* 10.0.1.64/27            Self                         100        I

red-vrf.inet.0: 3 destinations, 3 routes (3 active, 0 holddown, 0 hidden)
  Prefix                  Nexthop              MED     Lclpref    AS path
* 10.0.1.96/27            Self                         100        I
```


```console
srx1> ping routing-instance blue-vrf 10.0.2.80 source 10.0.1.80
PING 10.0.2.80 (10.0.2.80): 56 data bytes
64 bytes from 10.0.2.80: icmp_seq=0 ttl=64 time=3.276 ms
```
```console
srx1> ping routing-instance red-vrf 10.0.2.120 source 10.0.1.120
PING 10.0.2.120 (10.0.2.120): 56 data bytes
64 bytes from 10.0.2.120: icmp_seq=0 ttl=64 time=3.282 ms
```

```console
srx1> show bgp group IBGP summary
Group        Type       Peers     Established    Active/Received/Accepted/Damped
IBGP         Internal   1         1
  bgp.l3vpn.0      : 2/2/2/0
  bgp.l3vpn.2      : 0/0/0/0
  blue-vrf.inet.0  : 1/1/1/0
  inet.0           : 0/0/0/0
  inet.2           : 0/0/0/0
  red-vrf.inet.0   : 1/1/1/0
```
```console
srx1> show route table blue-vrf.inet.0

blue-vrf.inet.0: 3 destinations, 3 routes (3 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

10.0.1.64/27       *[Direct/0] 02:17:56
                    >  via ge-0/0/1.0
10.0.1.80/32       *[Local/0] 02:17:56
                       Local via ge-0/0/1.0
10.0.2.64/27       *[BGP/170] 00:32:24, localpref 100, from 172.16.1.2
                      AS path: I, validation-state: unverified
                    >  via gr-0/0/0.0, Push 16

srx1> show route table red-vrf.inet.0

red-vrf.inet.0: 3 destinations, 3 routes (3 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

10.0.1.96/27       *[Direct/0] 02:19:14
                    >  via ge-0/0/2.0
10.0.1.120/32      *[Local/0] 02:19:14
                       Local via ge-0/0/2.0
10.0.2.96/27       *[BGP/170] 00:33:42, localpref 100, from 172.16.1.2
                      AS path: I, validation-state: unverified
                    >  via gr-0/0/0.0, Push 17

srx1> show route table bgp.l3vpn.0

bgp.l3vpn.0: 2 destinations, 2 routes (2 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

10:10:10.0.2.64/27
                   *[BGP/170] 00:35:09, localpref 100, from 172.16.1.2
                      AS path: I, validation-state: unverified
                    >  via gr-0/0/0.0, Push 16
20:20:10.0.2.96/27
                   *[BGP/170] 00:35:09, localpref 100, from 172.16.1.2
                      AS path: I, validation-state: unverified
                    >  via gr-0/0/0.0, Push 17
```

All routing tables:
```console
srx1> show route

inet.0: 11 destinations, 12 routes (11 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

0.0.0.0/0          *[Static/5] 02:22:15
                    >  to 10.0.1.33 via ge-0/0/0.0
10.0.1.32/27       *[Direct/0] 02:22:15
                    >  via ge-0/0/0.0
10.0.1.50/32       *[Local/0] 02:22:15
                       Local via ge-0/0/0.0
172.16.1.1/32      *[Direct/0] 02:22:26
                    >  via lo0.0
172.16.1.2/32      *[OSPF/10] 00:37:45, metric 1
                    >  via gr-0/0/0.0
172.16.255.0/30    *[Direct/0] 02:22:15
                    >  via gr-0/0/0.0
                    [OSPF/10] 02:22:14, metric 1
                    >  via gr-0/0/0.0
172.16.255.1/32    *[Local/0] 02:22:15
                       Local via gr-0/0/0.0
192.168.1.0/30     *[Direct/0] 00:37:49
                    >  via st0.0
192.168.1.1/32     *[Local/0] 00:37:49
                       Local via st0.0
224.0.0.2/32       *[LDP/9] 02:22:26, metric 1
                       MultiRecv
224.0.0.5/32       *[OSPF/10] 02:22:26, metric 1
                       MultiRecv

inet.3: 1 destinations, 1 routes (1 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

172.16.1.2/32      *[LDP/9] 00:37:43, metric 1
                    >  via gr-0/0/0.0

mgmt_junos.inet.0: 3 destinations, 3 routes (3 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

0.0.0.0/0          *[Access-internal/12] 02:22:18, metric 0
                    >  to 10.0.1.1 via fxp0.0
10.0.1.0/27        *[Direct/0] 02:22:19
                    >  via fxp0.0
10.0.1.4/32        *[Local/0] 02:22:19
                       Local via fxp0.0

blue-vrf.inet.0: 3 destinations, 3 routes (3 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

10.0.1.64/27       *[Direct/0] 02:22:19
                    >  via ge-0/0/1.0
10.0.1.80/32       *[Local/0] 02:22:19
                       Local via ge-0/0/1.0
10.0.2.64/27       *[BGP/170] 00:36:47, localpref 100, from 172.16.1.2
                      AS path: I, validation-state: unverified
                    >  via gr-0/0/0.0, Push 16

red-vrf.inet.0: 3 destinations, 3 routes (3 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

10.0.1.96/27       *[Direct/0] 02:22:19
                    >  via ge-0/0/2.0
10.0.1.120/32      *[Local/0] 02:22:19
                       Local via ge-0/0/2.0
10.0.2.96/27       *[BGP/170] 00:36:47, localpref 100, from 172.16.1.2
                      AS path: I, validation-state: unverified
                    >  via gr-0/0/0.0, Push 17

mpls.0: 8 destinations, 8 routes (8 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

0                  *[MPLS/0] 02:22:26, metric 1
                       Receive
1                  *[MPLS/0] 02:22:26, metric 1
                       Receive
2                  *[MPLS/0] 02:22:26, metric 1
                       Receive
13                 *[MPLS/0] 02:22:26, metric 1
                       Receive
16                 *[VPN/0] 02:22:26
                    >  via lsi.0 (blue-vrf), Pop
17                 *[VPN/0] 02:22:26
                    >  via lsi.1 (red-vrf), Pop
299792             *[LDP/9] 00:37:43, metric 1
                    >  via gr-0/0/0.0, Pop
299792(S=0)        *[LDP/9] 00:37:43, metric 1
                    >  via gr-0/0/0.0, Pop

bgp.l3vpn.0: 2 destinations, 2 routes (2 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

10:10:10.0.2.64/27
                   *[BGP/170] 00:36:47, localpref 100, from 172.16.1.2
                      AS path: I, validation-state: unverified
                    >  via gr-0/0/0.0, Push 16
20:20:10.0.2.96/27
                   *[BGP/170] 00:36:47, localpref 100, from 172.16.1.2
                      AS path: I, validation-state: unverified
                    >  via gr-0/0/0.0, Push 17

inet6.0: 1 destinations, 1 routes (1 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

ff02::2/128        *[INET6/0] 02:31:00
                       MultiRecv

blue-vrf.inet6.0: 1 destinations, 1 routes (1 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

ff02::2/128        *[INET6/0] 02:22:26
                       MultiRecv

red-vrf.inet6.0: 1 destinations, 1 routes (1 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

ff02::2/128        *[INET6/0] 02:22:26
                       MultiRecv
```

```console
[@vm1a ~]$ ping  10.0.2.70
PING 10.0.2.70 (10.0.2.70) 56(84) bytes of data.
64 bytes from 10.0.2.70: icmp_seq=1 ttl=62 time=3.54 ms
...

[vm1a ~]$ ping  10.0.2.100
PING 10.0.2.100 (10.0.2.100) 56(84) bytes of data.
From 10.0.1.80 icmp_seq=1 Destination Net Unreachable
From 10.0.1.80 icmp_seq=2 Destination Net Unreachable

[@vm1b ~]$ ping 10.0.2.100
PING 10.0.2.100 (10.0.2.100) 56(84) bytes of data.
64 bytes from 10.0.2.100: icmp_seq=1 ttl=62 time=3.47 ms

[@vm1b ~]$ ping 10.0.2.70
PING 10.0.2.70 (10.0.2.70) 56(84) bytes of data.
From 10.0.1.120 icmp_seq=1 Destination Net Unreachable
From 10.0.1.120 icmp_seq=2 Destination Net Unreachable

```

## <a name="Juniper"></a>1. Annex1: basic Juniper info
### <a name="Juniper"></a>1.1 Security policy
A security policy is a set of statements that controls traffic from a specified source to a specified destination using a specified service. 
A policy permits, denies, or tunnels specified types of traffic <ins>**unidirectionally**</ins> between two points.
Each security policy consists of:
* a unique name for the policy,
* a _from-zone_ and a _to-zone_,
* a set of match criteria defining the conditions that must be satisfied (based on a source IP address, destination IP address, and application)
* a set of actions to be performed in case of a match—permit or deny
* a set of source VRF names (not used in our case)
* a set of destination VRF names (not used in our case)

### <a name="Juniper"></a>1.2 Zone
A security zone is a collection of one or more network segments requiring the regulation of inbound and outbound traffic through policies.
By default, interfaces are in the null zone. 
The interfaces will not pass traffic until they have been assigned to a zone.



### <a name="Juniper"></a>1.4 How to configure syslog to display VPN status messages
Reference: [How to configure syslog to display VPN status messages](https://kb.juniper.net/InfoCenter/index?page=content&id=KB10097)

Troubleshooting a VPN in status down or not active can be done through VPN logs.
VPN status messages are logged in syslog. The default syslog level does not display these VPN status.
We proceed to configure a new syslog file called **kmd-logs** which matches on the uppercase text:  **KMD** with daemon set to info.
Note that KMD has to be uppercase. 

```console
set system syslog file kmd-logs daemon info
set system syslog file kmd-logs match KMD
commit
```
The file kmd-logs in written to the /var/log directory. View the VPN status messages with the command **show log kmd-logs**: 
```
srx1> show log kmd-logs
Aug  3 10:18:01  srx1 kmd[14162]: Config download: Processed 4 - 5 messages
Aug  3 10:18:01  srx1 kmd[14162]: Config download time: 0 seconds
Aug  3 10:18:01  srx1 kmd[14162]: KMD_VPN_DOWN_ALARM_USER: VPN ipsec-vpn-1 from 13.68.203.192 is down. Local-ip: 10.0.1.50, gateway name: gtw-A, vpn name: ipsec-vpn-1, tunnel-id: 131073, local tunnel-if: st0.0, remote tunnel-ip: 2.1.168.192, Local IKE-ID: 13.68.202.166, Remote IKE-ID: 13.68.203.192, AAA username: Not-Applicable, VR id: 0, Traffic-selector: , Traffic-selector local ID: ipv4_subnet(any:0,[0..7]=0.0.0.0/0), Traffic-selector remote ID: ipv4_subnet(any:0,[0..7]=0.0.0.0/0), SA Type: Static, Reason: Tunnel configuration is deleted. Corresponding IKE/IPSec SAs are deleted
Aug  3 10:18:44  srx1 kmd[14162]: Config download: Processed 5 - 6 messages
Aug  3 10:18:44  srx1 kmd[14162]: Config download time: 0 seconds
Aug  3 10:18:44  srx1 kmd[14162]: KMD_PM_SA_ESTABLISHED: Local gateway: 10.0.1.50, Remote gateway: 13.68.203.192, Local ID: ipv4_subnet(any:0,[0..7]=0.0.0.0/0), Remote ID: ipv4_subnet(any:0,[0..7]=0.0.0.0/0), Direction: inbound, SPI: 0x190695fe, AUX-SPI: 0, Mode: Tunnel, Type: dynamic, Traffic-selector:  FC Name:
Aug  3 10:18:44  srx1 kmd[14162]: KMD_PM_SA_ESTABLISHED: Local gateway: 10.0.1.50, Remote gateway: 13.68.203.192, Local ID: ipv4_subnet(any:0,[0..7]=0.0.0.0/0), Remote ID: ipv4_subnet(any:0,[0..7]=0.0.0.0/0), Direction: outbound, SPI: 0x60555011, AUX-SPI: 0, Mode: Tunnel, Type: dynamic, Traffic-selector:  FC Name:
Aug  3 10:18:44  srx1 kmd[14162]: KMD_VPN_UP_ALARM_USER: VPN ipsec-vpn-1 from 13.68.203.192 is up. Local-ip: 10.0.1.50, gateway name: gtw-A, vpn name: ipsec-vpn-1, tunnel-id: 131073, local tunnel-if: st0.0, remote tunnel-ip: 2.1.168.192, Local IKE-ID: ^MDʦ, Remote IKE-ID: 13.68.203.192, AAA username: Not-Applicable, VR id: 0, Traffic-selector: , Traffic-selector local ID: ipv4_subnet(any:0,[0..7]=0.0.0.0/0), Traffic-selector remote ID: ipv4_subnet(any:0,[0..7]=0.0.0.0/0), SA Type: Static
Aug  3 10:18:44  srx1 kmd[14162]: IKE negotiation successfully completed. IKE Version: 2, VPN: ipsec-vpn-1 Gateway: gtw-A, Local: 10.0.1.50/4500, Remote: 13.68.203.192/4500, Local IKE-ID: 13.68.202.166, Remote IKE-ID: 13.68.203.192, VR-ID: 0, Role: Initiator

```

### <a name="Juniper"></a>1.5 deactivate and reactivate VPN tunnel on SRX
To deactivate:
```console
srx#deactivate security ike gateway <gatewayname>
srx#deactivate security ipsec vpn <vpn name>
srx#commit
```
To activate:
```console
srx#activate security ike gateway <gatewayname>
srx#activate security ipsec vpn <vpn name>
srx#commit
```

Deactivation and activation commands can be used to generate VPN logs.

## <a name="Juniper"></a>2. REFERENCE

[Example: Configuring MPLS over GRE with IPsec Fragmentation and Reassembly](https://www.juniper.net/documentation/en_US/junos/topics/example/vpls-over-gre-ipsec.html)

https://www.juniper.net/documentation/en_US/release-independent/nce/information-products/pathway-pages/nce/nce-140-srx-for-mpls-over-IPSec-1500byte-mtu-configuring.pdf

<!--Image References-->
[1]: ./media/network-diagram.png  "network diagram"
[2]: ./media/vrf-communication.png "communication between vrf"
[3]: ./media/srx-marketplace-01.png "srx Azure marketplace"
[4]: ./media/srx-marketplace-02.png "srx Azure marketplace"
[5]: ./media/srx-marketplace-03.png "srx Azure marketplace"
[6]: ./media/srx-marketplace-04.png "srx Azure marketplace"
[7]: ./media/srx-marketplace-05.png "srx -enable automatic deployment"
[8]: ./media/srx-marketplace-06.png "srx -enable automatic deployment"
[9]: ./media/deployment.png "site deployment"
<!--Link References-->

