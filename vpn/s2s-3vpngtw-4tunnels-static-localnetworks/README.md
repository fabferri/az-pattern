<properties
pageTitle= 'Site-to-site VPN between Azure VNets with remote networks statically configured'
description= "Site-to-site VPN between Azure VNets with remote networks statically configured"
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
   ms.date="26/05/2022"
   ms.author="fabferri" />

# Site-to-site VPN between Azure VNets with remote networks statically configured
This post contains ARM templates to create site-to-site VPNs between three Azure VNet.
The network configuration is shown in the diagram:

[![1]][1]



* The ARM template creates three different VNets in three Azure regions (specified in the ARM template with parameters **location1, location2, location3 and location4** ). 
* In each gateway subnet is create an Azure VPN Gateway:
   * a vpnGtw1 is created in a vnet1
   * a vpnGtw2 is created in a vnet2
   * a vpnGtw3 is created in a vnet3
* The Azure VPN gateways are all deployed in configuration active-active. 
* Two IPSec tunnels are established between vpnGtw1-vpnGtw2 
* Two IPSec tunnels are established between vpnGtw1-vpnGtw3 
* In each Azure VPN Gateway are configured static routes (in ARM is called local network) to forward the IP packets to the remote vnets. 
<br>

Two different cases are discussing:
1. CASE-A: configuration with communication only between vnet1-vnet2, vnet1-vnet3. Communication between vnet2-vnet3 is disabled  
2. CASE-B: configuration with communication between all the vnets: vnet1-vnet2, vnet1-vnet3, vnet2-vnet3

## <a name="List of files"></a>1. List of the files

| file                 | description                                                        |       
| -------------------- |:------------------------------------------------------------------ |
| **init.json**        | Define a list of input variables required as input to **vpn1.json**,**vpn2-caseA.json**,**vpn2-caseB.json** |
| **vpn1.json**        | ARM template to create vnets, VMs, vpn Gateways in each vnet       |
| **vpn1.ps1**         | powershell script to deploy the ARM template **vpn1.json**         |
| **vpn2-caseA.json**  | ARM template to configure the communication of the communication between vnet1-vnet2, vnet1-vnet3 (CASE-A) |
| **vpn2-caseA.ps1**   | powershell script to deploy the ARM template **vpn2-caseA.json**   |
| **vpn2-caseB.json**  | ARM template to configure the communication of the communication between vnet1-vnet2, vnet1-vnet3, vnet2-vnet3 (CASE-B) |
| **vpn2-caseB.ps1**   | powershell script to deploy the ARM template **vpn2-caseB.json**   |

## <a name="CASE-A"></a>2. CASE-A: communication only between vnet1-vnet2 and vnet1-vnet3
CASE-A requires the deployment in sequence of the following files:
- **init.json**: check the consistency of input variables, before starting the deployment
- **vpn1.json**: deployment of vnet1,vnet2,vnet3, each with own Azure VPN Gateway
- **vpn2-caseA.json**: deployment of local networks and Connections

Communication between vnets is shown in the diagram:
[![2]][2]

[![3]][3]

The details of the network configuration for the case-A are reported in the diagram below:

[![4]][4]

For the CASE-A the local network objects associated with the connections toward the vnet1 include ONLY the address space of the remote vnet1:
```json
{
            "type": "Microsoft.Network/localNetworkGateways",
            "name": "[variables('locNetgw2IP1-site1IP1')]",
            "apiVersion": "2020-06-01",
            "comments": "public IP of remote IPSec peer",
            "location": "[variables('location2')]",
            "dependsOn": [],
            "properties": {
                "gatewayIpAddress": "[reference(variables('gateway1PublicIP1Id'),'2017-10-01').ipAddress]",
                "localNetworkAddressSpace": {
                    "addressPrefixes": [
                        "[parameters('site1_localAddressPrefix')]"
                    ]
                }
            }
        },
        {
            "type": "Microsoft.Network/localNetworkGateways",
            "name": "[variables('locNetgw2IP2-site1IP2')]",
            "apiVersion": "2020-06-01",
            "comments": "public IP of remote IPSec peer",
            "location": "[variables('location2')]",
            "dependsOn": [],
            "properties": {
                "gatewayIpAddress": "[reference(variables('gateway1PublicIP2Id'),'2017-10-01').ipAddress]",
                "localNetworkAddressSpace": {
                    "addressPrefixes": [
                        "[parameters('site1_localAddressPrefix')]"
                    ]
                }
            }
        },
```
where: <br>
* parameters('site1_localAddressPrefix') is resolved into 10.0.1.0/24

The structure of local networks associated with the connection from vnet2 -> vnet1 doesn't contain in the **"localNetworkAddressSpace"** the address space of the vnet3.

In the CASE-A, we have the following effective routes:

Effective routes **vm1-nic**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.1.0/24      | Virtual network         |                     | |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 10.0.1.228          | |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 10.0.1.229          | |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 10.0.1.228          | |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 10.0.1.229          | |
| Default                 | Active | 0.0.0.0/0        | Internet                |                     | |
<br>

Effective routes **vm2-nic**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.2.0/24      | Virtual network         |                     | |
| Virtual network gateway | Active | 10.0.1.0/24      | Virtual network gateway | 10.0.2.228          | |
| Virtual network gateway | Active | 10.0.1.0/24      | Virtual network gateway | 10.0.2.229          | |
| Default                 | Active | 0.0.0.0/0        | Internet                |                     | |
<br>

Effective routes **vm3-nic**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.3.0/24      | Virtual network         |                     | |
| Virtual network gateway | Active | 10.0.1.0/24      | Virtual network gateway | 10.0.3.228          | |
| Virtual network gateway | Active | 10.0.1.0/24      | Virtual network gateway | 10.0.3.229          | |
| Default                 | Active | 0.0.0.0/0        | Internet                |                     | |

10.0.1.228, 10.0.1.229 are the internal IP address of the VPN Gateway1 in vnet1
10.0.2.228, 10.0.2.229 are the internal IP address of the VPN Gateway2 in vnet2
10.0.3.228, 10.0.3.229 are the internal IP address of the VPN Gateway3 in vnet3

## <a name="CASE-B"></a>3. CASE-B: communication between vnet1-vnet2, vnet1-vnet3, vnet2-vnet3
CASE-B requires the deployment in sequence of the following files:
- **init.json**: check the consistency of input variables, before starting the deployment
- **vpn1.json**: deployment of vnet1,vnet2,vnet3, each with own Azure VPN Gateway
- **vpn2-caseA.json**: deployment of local networks and Connections

Communication between vnets is shown in the diagram:
[![5]][5]

[![6]][6]



The details of the network configuration for the case-B are reported in the diagram below:

[![7]][7]

For the CASE-B, the local networks associated with the two connections from vnet2 -> vnet1 include the address space of the remote vnet1 but also the address space of remote vnet3:
```json
{
            "type": "Microsoft.Network/localNetworkGateways",
            "name": "[variables('locNetgw2IP1-site1IP1')]",
            "apiVersion": "2020-06-01",
            "comments": "public IP of remote IPSec peer",
            "location": "[variables('location2')]",
            "dependsOn": [],
            "properties": {
                "gatewayIpAddress": "[reference(variables('gateway1PublicIP1Id'),'2017-10-01').ipAddress]",
                "localNetworkAddressSpace": {
                    "addressPrefixes": [
                        "[parameters('site1_localAddressPrefix')]",
                        "[parameters('site3_localAddressPrefix')]"
                    ]
                }
            }
        },
        {
            "type": "Microsoft.Network/localNetworkGateways",
            "name": "[variables('locNetgw2IP2-site1IP2')]",
            "apiVersion": "2020-06-01",
            "comments": "public IP of remote IPSec peer",
            "location": "[variables('location2')]",
            "dependsOn": [],
            "properties": {
                "gatewayIpAddress": "[reference(variables('gateway1PublicIP2Id'),'2017-10-01').ipAddress]",
                "localNetworkAddressSpace": {
                    "addressPrefixes": [
                        "[parameters('site1_localAddressPrefix')]",
                        "[parameters('site3_localAddressPrefix')]"
                    ]
                }
            }
        },
```
where: <br>
* parameters('site1_localAddressPrefix') is resolved into 10.0.1.0/24
* parameters('site3_localAddressPrefix') is resolved into 10.0.3.0/24

In the CASE-B we have the following effective routes:
Effective routes **vm1-nic**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.1.0/24      | Virtual network         |                     | |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 10.0.1.228          | |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 10.0.1.229          | |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 10.0.1.228          | |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 10.0.1.229          | |
| Default                 | Active | 0.0.0.0/0        | Internet                |                     | |

<br>

Effective routes **vm2-nic**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.2.0/24      | Virtual network         |                     | |
| Virtual network gateway | Active | 10.0.1.0/24      | Virtual network gateway | 10.0.2.228          | |
| Virtual network gateway | Active | 10.0.1.0/24      | Virtual network gateway | 10.0.2.229          | |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 10.0.2.228          | |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 10.0.2.229          | |
| Default                 | Active | 0.0.0.0/0        | Internet                |                     | |
<br>

Effective routes **vm3-nic**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.3.0/24      | Virtual network         |                     | |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 10.0.3.228          | |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 10.0.3.229          | |
| Virtual network gateway | Active | 10.0.1.0/24      | Virtual network gateway | 10.0.3.228          | |
| Virtual network gateway | Active | 10.0.1.0/24      | Virtual network gateway | 10.0.3.229          | |
| Default                 | Active | 0.0.0.0/0        | Internet                |                     | |

10.0.1.228, 10.0.1.229 are the internal IP address of the VPN Gateway1 in vnet1
10.0.2.228, 10.0.2.229 are the internal IP address of the VPN Gateway2 in vnet2
10.0.3.228, 10.0.3.229 are the internal IP address of the VPN Gateway3 in vnet3

## <a name="vpn2.json"></a>4. Note: **Reference an existing public IP in ARM template**
The **vpn2-caseA.json** and **vpn2-caseB.json** reference the existing public IPs of VPN gateways. As reported in the official Microsoft documentation, **reference an existing resource (or one not defined in the same template), a full resourceId must be supplied to the reference() function**

In the AM template **vpn2-caseA.json** to get the existing public IP of the VPN Gateway: 
```json
reference(variables('gateway1PublicIP1Id'),'2017-10-01').ipAddress**
```




<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram - overview" 
[2]: ./media/vnets-communications-caseA.png "communication between vnets in CASE-A"
[3]: ./media/network-diagram-caseA.png "network diagram CASE-A"
[4]: ./media/network-diagram-caseA-details.png "network diagram with implementation details for the CASE-A"
[5]: ./media/vnets-communications-caseB.png "communication between vnets in CASE-B"
[6]: ./media/network-diagram-caseB.png "network diagram CASE-B"
[7]: ./media/network-diagram-caseB-details.png "network diagram with implementation details for the CASE-B"
<!--Link References-->

