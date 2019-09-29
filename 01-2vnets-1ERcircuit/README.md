<properties
pageTitle= 'ARM template to create 2 Azure VNets connected to an ExpressRoute circuit in different Azure subscription'
description= "ARM template to create 2 VNets connected to an ExpressRoute circuit in different Azure subscription"
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
   ms.date="29/09/2019"
   ms.author="fabferri" />

## ARM template to create two Azure VNets connected to an ExpressRoute circuit in different Azure subscription
The ARM template to create two Azure VNets in two different regions, each with an ExpressRoute Gateway. 
To run successful the ARM template is required a pre-existing ExpressRoute circuit deployed in a different Azure subscription. Two authetication codes are generated in the ExpressRoute circuit, to allow to establish two connections.

The network diagram is shown below:

[![1]][1]


> [!NOTE1]
> Before spinning up the ARM template you should change the following in the file **2VNets-1ERcircuit.json**:
> * variable **$subscriptionName**:  name of your Azure subscription
> * variable **$adminUsername**: username of administrator of the Azure VMs
> * variable **$adminPassword**: password of the administrator of the Azure VMs

> [!NOTE2]
> Before spinning up the ARM template you should change the following in the file **2VNets-1ERcircuit.ps1**:
> * parameter **azureRegion1**:  name of Azure region wher eis deployed the Azure VNet1
> * parameter **azureRegion2**:  name of Azure region wher eis deployed the Azure VNet2
> * **authorizationKey**:  authorization Key associated with the Expressroute circuit. Each Azure VNet requires a specific autorization key; you can't use the same authorization key to join more then one VNet to the same ExpressRoute circuit.
> * **erCircuitId**: ExpressRoute circuit Id. The structure of Expressroute circuit Id is: **"/subscriptions/<subscription_ID>/resourceGroups/<resourceGroup_Name>/providers/Microsoft.Network/expressRouteCircuits/<ER_circuit_Name>"**
> 


<!--Image References-->
[1]: ./media/network-diagram.png "network diagram"
<!--Link References-->

