<properties
pageTitle= 'vnet peering with transit across load balancer in HA'
description= "vnet peering with transit across load balancer in HA"
documentationcenter: na
services="Azure vnet, Azure load balancer"
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
   ms.date="01/06/2022"
   ms.author="fabferri" />

# VNet peering with transit across load balancer in HA
The network configuration is shown in the diagram:

[![1]][1]


## <a name="List of files"></a>1. List of files

| file                 | description                                                        |       
| -------------------- |:------------------------------------------------------------------ |
| **init.json**        | Define a list of input variables required as input to **az.json**  |
| **az.json**          | ARM template to create vnets, VMs, vpn Gateways in each vnet       |
| **az.ps1**           | powershell script to deploy the ARM template **az.json**           |

Before starting the deployment check the consistency of input variables into **init.json** 




<!--Image References-->

[1]: ./media/network-diagram.png "network diagram - overview" 


<!--Link References-->

