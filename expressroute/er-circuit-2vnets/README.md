<properties
pageTitle= 'ARM template to create 2 Azure VNets connected to an ExpressRoute circuit in different Azure subscription'
description= "ARM template to create 2 VNets connected to an ExpressRoute circuit in different Azure subscription"
documentationcenter: github
services="ExpressRoute"
documentationCenter="na"
authors="fabferri"
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="ExpressRoute"
   ms.date="29/09/2019"
   ms.author="fabferri" />

## ARM template to create two Azure VNets connected to an ExpressRoute circuit in different Azure subscription
The ARM template to create two Azure VNets in two different regions, each with an ExpressRoute Gateway. 
To run successful the ARM template is required a pre-existing ExpressRoute circuit deployed in a different Azure subscription. Two authetication codes are generated in the ExpressRoute circuit, to allow to establish two connections.

The network diagram is shown below:

[![1]][1]


> > [!NOTE]
> Before spinning up the ARM template you should change the following in the file **2VNets-1ERcircuit.json**: <br>
> variable **$subscriptionName**:  name of your Azure subscription  <br>
> variable **$adminUsername**: username of administrator of the Azure VMs <br>
> variable **$adminPassword**: password of the administrator of the Azure VMs <br>
>
> 
> Before spinning up the ARM template you should change the following in the file **2VNets-1ERcircuit.ps1**: <vr>
> parameter **azureRegion1**:  name of Azure region where is deployed the Azure VNet1 <br>
> parameter **azureRegion2**:  name of Azure region where is deployed the Azure VNet2 <br>
> **authorizationKey**:  authorization Key associated with the Expressroute circuit. Each Azure VNet requires a specific autorization key; you can't use the same authorization key to join more then one VNet to the same ExpressRoute circuit. <br>
> **erCircuitId**: ExpressRoute circuit Id. The structure of Expressroute circuit Id is: **"/subscriptions/<subscription_ID>/resourceGroups/<resourceGroup_Name>/providers/Microsoft.Network/expressRouteCircuits/<ER_circuit_Name>"**
> 


`Tags: ExpressRoute`<br>
`date: 10-08-22`

<!--Image References-->
[1]: ./media/network-diagram.png "network diagram"
<!--Link References-->

