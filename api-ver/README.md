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

List of API versions supported in **northeurope** azure region to create Virtual Networks:
```powershell
((Get-AzResourceProvider -ProviderNamespace Microsoft.Network -Location northeurope).ResourceTypes | Where-Object ResourceTypeName -eq VirtualNetworks).ApiVersions

```

List of API versions supported in **northeurope** azure region to create Virtual Machines:
```powershell
((Get-AzResourceProvider -ProviderNamespace Microsoft.Compute -Location northeurope).ResourceTypes | Where-Object ResourceTypeName -eq VirtualMachines).ApiVersions
```

List of API versions supported in **northeurope** azure region to create Storage Accounts:
```powershell
((Get-AzResourceProvider -ProviderNamespace Microsoft.Storage -Location northeurope).ResourceTypes | Where-Object ResourceTypeName -eq StorageAccounts).ApiVersions
```

List of API versions supported in **uksouth** azure region to create Log Analytics workspaces:
```powershell
((Get-AzResourceProvider -ProviderNamespace "Microsoft.OperationalInsights" -Location uksouth).ResourceTypes | Where-Object ResourceTypeName -eq workspaces).ApiVersions
```

List of API versions supported in **westus2** Microsoft Container Service:
```
((Get-AzResourceProvider -ProviderNamespace Microsoft.ContainerService -Location westus2).ResourceTypes | Where-Object ResourceTypeName -eq managedClusters).apiversions
```
<!--Image References-->

<!--Link References-->

