<properties
pageTitle= 'Site-to-site VPN between Azure VNets with overlapping of address space and remote networks statically configured'
description= "Site-to-site VPN between Azure VNets with overlapping of address space and remote networks statically configured"
documentationcenter: na
services="Azure VPN"
documentationCenter="na"
authors="fabferri"
manager=""
editor="fabferri"/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="na"
   ms.date="30/05/2022"
   ms.author="fabferri" />

# Site-to-site VPN between Azure VNets with overlapping of address space and remote networks statically configured
This post contains ARM templates to create site-to-site VPNs between three Azure VNet.
The network configuration is shown in the diagram:

[![1]][1]


* The ARM template creates three different VNets in three Azure regions (specified in the ARM template with parameters **location1, location2 and location3** ). 
* The Azure vnets vnet1, vnet2, vnet3 have all the same address space (vnets with networks in overlapping)
* In each gateway subnet is create an Azure VPN Gateway:
   * a **vpnGtw1** is created in a vnet1
   * a **vpnGtw2** is created in a vnet2
   * a **vpnGtw3** is created in a vnet3
* The Azure VPN gateways are all deployed in configuration active-active. 
* Two IPSec tunnels are established between vpnGtw1-vpnGtw2 
* Two IPSec tunnels are established between vpnGtw1-vpnGtw3 
* In each Azure VPN Gateway are configured static routes (in ARM is called local network) to forward the IP packets to the remote vnets. 
* To manage the overlapping of networks in the three vnets, the Azure VPN Gateway **vpnGtw1** is configured with NAT.
<br>


## <a name="List of files"></a>1. List of files

| file                 | description                                                        |       
| -------------------- |:------------------------------------------------------------------ |
| **init.json**        | Define a list of input variables required as input to **vpn1.json**,**vpn2.json** |
| **vpn1.json**        | ARM template to create vnets, VMs, vpn Gateways in each vnet       |
| **vpn1.ps1**         | powershell script to deploy the ARM template **vpn1.json**         |
| **vpn2.json**        | ARM template to configure the communication of the communication between vnet1-vnet2, vnet1-vnet3 |
| **vpn2.ps1**         | powershell script to deploy the ARM template **vpn2-caseA.json**   |
| **get-traffic-values.ps1** | powershell script fetch the values of byte in ingress/egress in the connections |

Before starting the deployment check the consistency of input variables into **init.json**.
Meaning of variables in the **init.json**:

```console
"subscriptionName": name of the Azure subscription
"ResourceGroupName": name of the resource group
"location1": Azure region to deploy the vnet1
"location2": Azure region to deploy the vnet2
"location3": Azure region to deploy the vnet3
"adminUsername": administrator username
"adminPassword": administrator password
"mngIP": public IP to connect in SSH to the VMs. It can be set with string empty if the SSH doesn't require restriction.
```

## <a name="NAT"></a>2. NAT in the Azure VPN Gateway vpnGtw1
The following diagrams show the vpnGtw1 NAT configurations:

[![2]][2]

[![3]][3]

List of local networks with the associated address space:
- **locNetgw1IP1-site2IP1** address space 100.0.2.0/24
- **locNetgw1IP2-site2IP2** address space 100.0.2.0/24
- **locNetgw1IP1-site3IP1** address space 100.0.3.0/24
- **locNetgw1IP2-site3IP2** address space 100.0.3.0/24
- **locNetgw2IP1-site2IP1** address space 100.0.1.0/24
- **locNetgw2IP2-site2IP2** address space 100.0.1.0/24
- **locNetgw3IP1-site2IP1** address space 100.0.1.0/24
- **locNetgw3IP2-site2IP2** address space 100.0.1.0/24

The above network diagrams show all details about the local networks and NAT rules associated with each Connection. The NAT rules in **vpnGw1** is shown below:

[![4]][4]


- IngressSNAT rule named **vpn1natIngressRule_tovpn2**: this rule translates the on-premises address space 10.0.1.0/24 to 100.0.2.0/24.
- IngressSNAT rule named **vpn1natIngressRule_tovpn2**: this rule translates the on-premises address space 10.0.1.0/24 to 100.0.3.0/24.
- EgressSNAT rule named **vpn1natEgressRule**: this rule translates the VNet address space 10.0.1.0/24 to 100.0.1.0/24.

In the diagram, each connection resource has the following rules:
- Connection **gtw1IP1-to-gtw2IP1** (vnet1-to-vnet2):
   * IngressSNAT rule **vpn1natIngressRule_tovpn2**
   * EgressSNAT rule **vpn1natEgressRule**

- Connection **gtw1IP2-to-gtw2IP2** (vnet1-to-vnet2):
   * IngressSNAT rule **vpn1natIngressRule_tovpn2**
   * EgressSNAT rule **vpn1natEgressRule**

- Connection **gtw1IP1-to-gtw3IP1** (vnet1-to-vnet3):
   * IngressSNAT rule **vpn1natIngressRule_tovpn3**
   * EgressSNAT rule **vpn1natEgressRule**

- Connection **gtw1IP2-to-gtw3IP2** (vnet1-to-vnet3):
   * IngressSNAT rule **vpn1natIngressRule_tovpn3**
   * EgressSNAT rule **vpn1natEgressRule**

Based on the NAT rules associated with the connections we have the address translation:
| Network        | Origin      | Translated  |      
| -------------- |:----------- |:----------- |
| **vnet1**      | 10.0.1.0/24 | 100.0.1.0/24|
| **vnet2**      | 10.0.1.0/24 | 100.0.2.0/24|
| **vnet3**      | 10.0.1.0/24 | 100.0.3.0/24|

The diagram below shows an IP packet from vnet2 to vnet1, and from the vnet1 to the vnet2, before and after the translation:

[![5]][5]


## <a name="Azure VMs effective routes"></a>3. Azure VMs effective routes 
The VMs have the following effective routes :

Effective routes **vm1-nic**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.1.0/24      | Virtual network         |                     |                         |
| Virtual network gateway | Active | 100.0.2.0/24     | Virtual network gateway | 10.0.1.228          |                         |
| Virtual network gateway | Active | 100.0.2.0/24     | Virtual network gateway | 10.0.1.229          |                         |
| Virtual network gateway | Active | 100.0.3.0/24     | Virtual network gateway | 10.0.1.228          |                         |
| Virtual network gateway | Active | 100.0.3.0/24     | Virtual network gateway | 10.0.1.229          |                         |
| Default                 | Active | 0.0.0.0/0        | Internet                |                     |                         |

<br>

Effective routes **vm2-nic**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.1.0/24      | Virtual network         |                     | |
| Virtual network gateway | Active | 100.0.1.0/24     | Virtual network gateway | 10.0.1.228          | |
| Virtual network gateway | Active | 100.0.1.0/24     | Virtual network gateway | 10.0.1.229          | |
| Default                 | Active | 0.0.0.0/0        | Internet                |                     | |
<br>

Effective routes **vm3-nic**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.1.0/24      | Virtual network         |                     | |
| Virtual network gateway | Active | 100.0.1.0/24     | Virtual network gateway | 10.0.1.228          | |
| Virtual network gateway | Active | 100.0.1.0/24     | Virtual network gateway | 10.0.1.229          | |
| Default                 | Active | 0.0.0.0/0        | Internet                |                     | |



## <a name="vpn2.json"></a>4. Note: Reference an existing public IP in ARM template
The **vpn2.json** references the existing public IPs of VPN gateways. As reported in the official Microsoft documentation, **reference an existing resource (or one not defined in the same template), a full resourceId must be supplied to the reference() function**

In the AM template **vpn2.json** to get the existing public IP of the VPN Gateway is used: 
```json
reference(variables('gateway1PublicIP1Id'),'2017-10-01').ipAddress
```


`Tags: Azure VPN, site-to-site, NAT`

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram - overview" 
[2]: ./media/network-diagram2.png "site-to-site VPN between vnet1 and vnet2"
[3]: ./media/network-diagram3.png "site-to-site VPN between vnet1 and vnet3"
[4]: ./media/nat.png "NAT rules in vpnGw1"
[5]: ./media/nat-rules.png "NAT rules in vpnGw1"

<!--Link References-->

