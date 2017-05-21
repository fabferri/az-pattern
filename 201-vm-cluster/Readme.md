<properties
   pageTitle="Single ARM template to deploy a cluster of Azure VMs"
   description="ARM template to deploy a large number of Azure VMs attached to the same Virtual Network"
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
   ms.date="02/02/2016"
   ms.author="fabferri" />

# Deployment of a cluster of Azure VMs through a single ARM template

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Ffabferri%2Ffabrepo%2Fmaster%2FVMCluster201%2FdeployVMs.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>


Here an Azure Resource Manager (ARM) template to create a large number of Azure VMs attached to the same virtual Network (VNet).  

This template creates new storage accounts and VMs; the script allows to specify the number of .VHD stored in every storage account.

Below are the parameters that the template expects

| Name   | Description    |
|:--- |:---|
| storageAccountPrefix  | This is a unique prefix used for storage. |
| numberOfStorageAccounts  | The number of storage accounts to create. |
| numberOfInstancesPerAccount  | The number of VMs to create per storage account (<= 40 highly recommended). |
| adminUsername | The administrator user name. |
| adminPassword | The administrator password. |
| vmSize | the size of the VMs |
| imagePublisher | vendor of the OS |
| imageOffer | type of OS |
| imageSKU | Version of the OS |

##Known Issues and Limitations
- Based on the bandwidth limits for VHDs and storage accounts, it is highly recommended that you do not exceed 30 VMs per storage account.
