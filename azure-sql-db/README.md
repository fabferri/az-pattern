<properties
pageTitle= 'Azure ARM template and Azure powershell to deploy Azure SQL server with databases'
description= "Azure ARM template and Azure powershell to deploy Azure SQL server with databases"
documentationcenter: na
services="networking"
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
   ms.date="19/02/2020"
   ms.author="fabferri" />

## Azure ARM template and Azure powershell to deploy Azure SQL server with databases


| file                | Description                                                         |
| ------------------- |:--------------------------------------------------------------------|
| **sql-dbs.ps1**     | powershell script to deploy the Azure ARM template  **sql-dbs.json**|
| **sql-dbs.json**    | Azure ARM template to deploy the SQL server with databases          |
| **sql-dbs-pws.ps1** | powershell script to deploy the SQL server with databases           |

> *Note1*
> Before running **sql-dbs.ps1** set the input variables:
> $administratorLogin: name of the SQL administrator
> $administratorLoginPassword: password of the SQL server
> $subscriptionName : name of the Azure subscription
> $location         : name of the Azure region
> $rgName           : name of the Azure resource group
>

> *Note2*
> Before running **sql-dbs-pws.ps1** set the input variables:
> $administratorLogin: name of the SQL administrator
> $administratorLoginPassword: password of the SQL server
> $subscriptionName : name of the Azure subscription
> $location         : name of the Azure region
> $rgName           : name of the Azure resource group
>

The  **sql-dbs.json** and **sql-dbs-pws.ps1** are possibile alternative ways to make the same deployment; use one of them.

<!--Image References-->

<!--Link References-->

