<properties
pageTitle= 'site-to-site VPN with NAT'
description= "site-to-site VPN with NAT"
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
   ms.date="30/08/2021"
   ms.author="fabferri" />

## Connection between two VNets through site-to-site VPN with NAT

The network diagram:

[![1]][1]

The Azure VPN Gateways run in active-passive configuration. A single IPSect tunnel is established between VPN Gateway1 and VPN Gateway2. 

<br>

NAT table in vpnGw1:
| Name | Type   | Mode       | Internal Mappings | External Mappings | Connection Associations |
| ---- | ------ | ---------- | ----------------- | ----------------- | ----------------------- |
| vnet | Static | EgressSnat | 10.0.0.0/24       | 100.0.1.0/24      | 1 Connection linked     |

<br>

NAT table in vpnGw2:
| Name   | Type   | Mode       | Internal Mappings | External Mappings | Connection Associations |
| ------ | ------ | ---------- | ----------------- | ----------------- | ----------------------- |
| branch | Static | EgressSnat | 10.0.2.0/24       | 100.0.2.0/24      | 1 Connection linked     |

<br>

## <a name="list of ARM templates and scripts"></a> List of ARM templates and powershell scripts
| file                     | description                                                               |       
| ------------------------ |:------------------------------------------------------------------------- |
| **vpn1.json**            | ARM template to create vnet1, VPNG Gateway1 and vm1 <br> vnet2, VPN Gateway2 and vm2 |
| **vpn1.ps1**             | powershell script to deploy the ARM template **vpn1.json**                |
| **vpn2.json**            | Create the local Network Gateways, connections between VPN Gateway1 and VPN Gateway 2, NAT rules  |
| **vpn2.ps1**             | powershell script to deploy the ARM template **vpn2.json**                |

<br>

**NOTE**
Before running, 
- set the name of the Azure Resource Group name in the file **init.txt**
- set the value of **ADMINISTRATOR_USERNAME** and **ADMINISTRATOR_PASSWORD** in the file **vpn1.ps1** 

Run in sequence: before **vpn1.json** and then only when completed run **vpn2.json**

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"


<!--Link References-->

