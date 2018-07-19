---
title: 'Azure ARM template to create multiple VNet-to-VNet with VPN Gateways'
description: simple ARM template to create multiple VNet to VNet with VPN Gateways
documentationcenter: na
services: Azure routing
author:  fabferri
manager:
editor: ''
tags: azure-service-management

ms.assetid:
ms.service: VNet-to-VNet
ms.devlang: na
ms.topic: article
ms.tgt_pltfrm: na
ms.workload: infrastructure-services
ms.date: 07/19/2018
ms.author: fabferri

---

# Azure ARM template to create multiple VNet-to-VNet with VPN Gateways
This ARM template create a deployment with multiple VNets and with VNet-to-VNet intercommunication by VPN Gateway.
the VNet intercommunication create IPsec tunnels between VNets.

The network configuration is reported in the diagram:

[![1]][1]

the ARM templates works with arrays:

* **vNetArray**: it is an array wih all VNets, inclusive of Gatewaysubnet, VPN gateway name, ASN and SKU of VPN Gateway
* **vpnConnectionArray**: includes the list of all connections. Every VNet-2-VNet have two connections:
 *connection for vnet1-to -> vnet2*
 *connection for vnet2-to -> vnet1*
 Every connection have an element in the array.

> [!NOTE1]
> you can increase the number of VNets changing the structure of the arrays: **vNetArray**, **vpnConnectionArray**
> 

> [!NOTE2]
> The ARM template might fail in the creation of connections. In this case you can easly fix it, removing the connection went in failure and than run again the same ARM template.
> 

Before deploying the ARM template you should:
* set the Azure subscription name in the file **vnet2vnet-vpn.ps1**
* set the administrator username (parameter **adminUsername**) and password (paramenter **adminPassword**) in the file **vnet2vnet-vpn.json**



<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"


<!--Link References-->

