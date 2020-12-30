<properties
pageTitle= 'Azure ARM template to create multiple VNet-to-VNet with VPN Gateways'
description= "Azure ARM template to create multiple VNet to VNet with VPN Gateways"
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
   ms.date="19/07/2018"
   ms.author="fabferri" />

# How to create multiple VNet-to-VNet connection with two hub VNets
This ARM template creates multiple VNet-to-VNet connection by VPN Gateway. The intercommunication between VNets is based on IPsec tunnels.

The network configuration is reported in the diagram:

[![1]][1]

the ARM templates works with arrays:

* **vNetArray**: it is an array wih all VNets, inclusive of Gatewaysubnet, VPN gateway name, ASN and SKU of VPN Gateway
* **vpnConnectionArray**: includes the list of all connections. A single VNet2VNet is based on two connections:
    * connection for **vnet1-to-vnet2**
    * connection for **vnet2-to-vnet1**

> [!NOTE]
> you can increase the number of VNets changing the structure of the arrays: **vNetArray**, **vpnConnectionArray**
>

> [!Caveat]
> The ARM template might fail in the creation of connections. In this case you can easly fix it, removing the connection went in failure and than run again the same ARM template.
> 

Before deploying the ARM template you should:
* set the Azure subscription name in the file **vnet2vnet-vpn.ps1**
* set the administrator username (parameter **adminUsername**) and password (paramenter **adminPassword**) in the file **vnet2vnet-vpn.json**


<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"

<!--Link References-->

