<properties
pageTitle= 'private service link'
description= "ARM template with private endpoints to communicate through private connection with Azure SQL and Azure storage account"
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
   ms.date="22/10/2019"
   ms.author="fabferri" />

## ARM template with private endpoints to communicate with Azure SQL and Azure storage account
The ARM template gives the capabilities to deploy an Azure VNet and create two private endpoints to get access to the Azure SQL Azure storage account. Two DNS private zones are deployed with integration in the VNet to access to the SQL and storage account through naming. The network diagram is shown below:


[![1]][1]

The ARM template creates a VNet with three subnets:
* the private endpoints are deployed in subnet1 
* the Azure VMs are deployed in subnet2
* the gateway subnet is used for deployment of Azure Gateway


> Note
> before running the powershell scripts customize the values of variables:
>
>   ADMINISTRATOR_USERNAME: administrator username of Azure SQL and Azure VMs
>   ADMINISTRATOR_PASSWORD: administrator password of Azure SQL and Azure VMs
>   
>   $subscriptionName: name of the Azure subscription
>
>   $location: name of the Azure region
>
>   $rgName: name of the Resource Group
>
> in the powershell **private-endpoints.ps1**
> 
In the diagram shown below the communication flows with private service link:

[![2]][2]



<!--Image References-->

[1]: ./media/network-diagram.png "network overview"
[2]: ./media/flows.png "communication flows with private endpoints"

<!--Link References-->

