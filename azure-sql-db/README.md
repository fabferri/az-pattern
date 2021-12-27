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

>> *Note1*
>
>  Input variables in **sql-dbs.ps1**:
>
> $administratorLogin: name of the SQL administrator
>
> $administratorLoginPassword: password of the SQL server
>
> $subscriptionName : name of the Azure subscription
>
> $location         : name of the Azure region
>
> $rgName           : name of the Azure resource group
>

>> *Note2*
>
>  Input variables in **sql-dbs-pws.ps1**:
>
> $administratorLogin: name of the SQL administrator
>
> $administratorLoginPassword: password of the SQL server
>
> $subscriptionName : name of the Azure subscription
>
> $location         : name of the Azure region
>
> $rgName           : name of the Azure resource group
>
<br>

You can use two possibile alternative way to run the deployment:  **sql-dbs.json** OR **sql-dbs-pws.ps1** 

<br>

Use one of them.

<!--Image References-->

<!--Link References-->

