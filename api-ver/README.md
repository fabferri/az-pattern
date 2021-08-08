<properties
pageTitle= 'List of ARM API'
description= "List of ARM API"
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
   ms.date="08/08/2021"
   ms.author="fabferri" />

# List of ARM API
Powershell script to get the list of ARM API in a specific location.

<br>

To get the full list of network resources in a specific location, i.e. 'eastus':

```powershell
((Get-AzResourceProvider -ProviderNamespace Microsoft.Network -Location 'eastus').ResourceTypes)
```

<br>
List of network resources without specificy a region:

```powershell
((Get-AzResourceProvider -ProviderNamespace Microsoft.Network ).ResourceTypes)

```
<br>

List of network resources name:

```powershell
((Get-AzResourceProvider -ProviderNamespace Microsoft.Network ).ResourceTypes).ResourceTypeName
```

<!--Image References-->

<!--Link References-->

