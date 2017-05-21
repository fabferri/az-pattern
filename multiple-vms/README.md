<properties
   pageTitle="Azure Resource Manager template to create multiple custom VMs"
   description="Azure Resource Manager template to create multiple custom VMs"
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
   ms.workload="AzureVMs"
   ms.date="30/01/2017"
   ms.author="fabferri" />

# Azure Resource Manager template to create multiple custom VMs.


**the Azure Resource Manager (ARM) template use an array to specify number and type Azure VMs; here the structure of the array:**

1. "**vmNamePrefix**"  : hostname of the VM
2. "**dnsNamePubIP**"  : public DNS  prefix associated to the VM
3. "**nicName**"       : name of NIC connected to the VM
4. "**vmSize**"        : size of the VM
5. "**imagePublisher**": specify the publisher of the image (OpenLogic, Canonical, MicrosoftWindowsServer, etc.)
6. "**imageOffer**"    : specify the publisher offer (CentOS, UbuntuServer, WindowsServer, etc.)
7. "**OSVersion**"     : specify the OS version (e.g. 7.1 for CentOS, 15.04 for UbuntuServer, etc. )
8. "**dataDiskSize**"  : size of the datadisk attached to the VM


### Caveats
1. The ARM template use a unique storage account to deploy all the VMs.
   This is acceptable for dev & test and for small number of VMs.
   For large number of VMs, to avoid throttling in the storage account it is recommended to modify the template and create multiple storage accounts. 
2. All the VMs have OS disk and datadisk in the same storage account. In production is recommend to split up the deployment in different Azure storage accounts.
