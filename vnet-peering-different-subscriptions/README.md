<properties
pageTitle= 'Azure VNets in peering in different Azure subscriptions'
description= "VNets peering between VNets in different Azure subscriptions"
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
   ms.date="08/04/2020"
   ms.author="fabferri" />

## Azure VNets peering between VNets in different Azure subscriptions

It is common create _VNet peering_ between VNets deployed in different Azure subscriptions.
The diagram below shows the configuration with two VNets called **vnet1** and **vnet2** connected by VNet peering.

* The **vnet1** is deployed in **Azure subscription1**
* The **vnet2** is deployed in **Azure subscription2**

Both of Azure subscriptions are associated with the same Azure Active Directory (AAD).

[![1]][1]


> [!NOTE]
> In the file **all-vnets.ps1** set the following variables:
>
> $subscriptionName1   : Azure subscription1
>
> $subscriptionName2   : Azure subscription2
>
> $location1           : Azure region to create vnet1
>
> $location2           : Azure region to create vnet2
>
> $resourceGrp1        : name of resource group to deploy vnet1 
>
> $resourceGrp2        : name of resource group to deploy vnet2
>
> $resourceGrpDeploy1  : name of deployment for the vnet1 
>
>
> $resourceGrpDeploy2  : name of the deployment of the vnet2
>
> $resourceGrpDeploy3  : name of the deployment for the peering with vnet2
>
> $resourceGrpDeploy4  : name of the deployment for the peering with vnet1
>
> $armTemplateFile1    : ARM template to create vnet1 
>
> $armTemplateFile2    : ARM template to create vnet2 
>
> $armTemplateFile3    : ARM template to configure VNet peering
>
> $vnet1Name           : name of the vnet1 in Azure subscription1
>
> $vnet2Name           : name of the vnet2 


<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"

<!--Link References-->

