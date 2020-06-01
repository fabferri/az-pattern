<properties
   pageTitle="ARM template to deploy a cluster of Azure VMs"
   description="ARM template to create a cluster of Azure VMs connected to the same Virtual Network"
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
   ms.date="02/05/2020"
   ms.author="fabferri" />

# Cluster of Azure VMs through ARM template

Here an ARM (Azure Resource Manager) template to create a cluster of Azure VMs attached to the same Virtual Network (VNet).  

List of files:

| Name                  | Description                                                  |
|:--------------------- |:-------------------------------------------------------------|
| **multiple-vms.ps1**  | powershell script to depoy  multiple-vms.json                |
| **multiple-vms.json** | ARM template to deploye a cluster of Azure VMs               |
| **address.ps1**       | powershell script to run the address.json                    |
| **address.json**      | simple ARM template to deploy only VNet and NICs-without VMs |


> **NOTE**
> Before running **multiple-vms.ps1** set the values of following variables:
> ##   $adminUsername    : administrator username
> ##   $adminPassword    : adminsitrator password
> ##   $subscriptionName : name of the Azure subscription
> ##   $location         : Azure region when deployed the resource group
> ##   $rgName           : resource group name
>

##Known Issues and Limitations
- deployment works with max 250 VMs. Scale up at higher number of VMs requires a review of static IP assigment of private IP.
