<properties
pageTitle= '101 Azure ARM template to create multiple VNets and VMs in different Azure regions'
description= "simple Azure ARM template to create multiple VNets and VMs in different Azure regions"
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
   ms.date="20/07/2018"
   ms.author="fabferri" />

# Azure ARM template to create multiple VNets and VMs in different Azure regions
This ARM template creates multiple VNets in different Azure regions.
The ARM template use loops to created VNets, IPs, NICs, VMs.

* The parameter **vNetCount** define how many VNets are created
* The array **azureRegion** defines the list of Azure regions where the VNet will be deployed. The array can contain multiple times the same Azure region. The ARM template uses the Azure region in sequence:
 * first element of the array **azureRegion[0]** is assigned to the virtual network vnet-01
 * second element of the array **azureRegion[1]** is assigned to the virtual network vnet-02
 * ...
* A module function manage the assignment of Azure region, and supports the case with total number of VNets higher than the number of Azure regions.
* The ARM template creates for every VNet a small Azure CentOS VM with private static IP address

The network diagram is reported below:

[![1]][1]


Before spinning up the ARM template you should:
* set the Azure subscription name in the file **101-multiple-vnets-vms.ps1**
* set the administrator username and password in the file **101-multiple-vnets-vms.json**

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"

<!--Link References-->

