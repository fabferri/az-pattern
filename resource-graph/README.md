<properties
pageTitle= 'Azure Resource Graph queries'
description= "Azure Resource Graph queries"
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
   ms.date="22/05/2021"
   ms.author="fabferri" />

# Azure Resource Graph queries in powershell
Define the global variable with the name of the Azure subscription:

```powershell
$subscriptionName='AzureDev'
```

List of resources in a specific Azure subscription:
```powershell
$subscriptionId= (Get-AzSubscription -SubscriptionName $subscriptionName).Id
Search-AzGraph -Subscription $subscriptionId -Query 'Resources | project name, type | limit 40'
```

List of VMs with properties:
```powershell
$subscriptionId= (Get-AzSubscription -SubscriptionName $subscriptionName).Id
Search-AzGraph -Subscription $subscriptionId -Query "where type =~ 'Microsoft.Compute/virtualMachines' "
```
List of VMs name and location, ordered by name:
```powershell
$subscriptionId= (Get-AzSubscription -SubscriptionName $subscriptionName).Id
Search-AzGraph -Subscription $subscriptionId -Query "Resources | project name, location, type| where type =~ 'Microsoft.Compute/virtualMachines' | order by name desc"
```
List of VMs by name, resource group, location, VM SKU:
```powershell
$subscriptionId= (Get-AzSubscription -SubscriptionName $subscriptionName).Id
Search-AzGraph -Subscription $subscriptionId -Query "Resources | where type =~ 'Microsoft.Compute/virtualMachines' | project name,  resourceGroup, location, tostring(properties.hardwareProfile.vmSize)"
```

Count OS disk type (Linux, Windows) :
```powershell
$subscriptionId= (Get-AzSubscription -SubscriptionName $subscriptionName).Id
Search-AzGraph -Subscription $subscriptionId -Query "where type =~ 'Microsoft.Compute/virtualMachines' | summarize count() by tostring(properties.storageProfile.osDisk.osType)"
```
List of VMs running and deallocated:
```powershell
$subscriptionId= (Get-AzSubscription -SubscriptionName $subscriptionName).Id
Search-AzGraph -Subscription $subscriptionId -Query "where type =~ 'Microsoft.Compute/virtualMachines' | project name , tostring(properties.extended.instanceView.powerState.displayStatus)" 

```
List of VMs running and deallocated with OS type:
```powershell
$subscriptionId= (Get-AzSubscription -SubscriptionName $subscriptionName).Id
Search-AzGraph -Subscription $subscriptionId -Query "where type =~ 'Microsoft.Compute/virtualMachines' | project name , tostring(properties.extended.instanceView.powerState.displayStatus), tostring(properties.storageProfile.osDisk.osType), location" 

```

Count number of VMs by SKU:
```powershell
$subscriptionId= (Get-AzSubscription -SubscriptionName $subscriptionName).Id
Search-AzGraph -Subscription $subscriptionId -Query "where type =~ 'Microsoft.Compute/virtualMachines' | project SKU = tostring(properties.hardwareProfile.vmSize)| summarize count() by SKU"
```

List of publis IPs:
```powershell
# List all the Public IP Addresses:
Search-AzGraph -Subscription $subscriptionId  -Query "where type contains 'publicIPAddresses' and isnotempty(properties.ipAddress) | project properties.ipAddress"
```
<!--Image References-->



<!--Link References-->

