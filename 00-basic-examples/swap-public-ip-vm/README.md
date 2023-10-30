<properties
pageTitle= 'how to swap a public IPv4 between two Azure VMs'
description= "Moving public IPv4 between two Azure Virtual Machines"
documentationcenter: na
services="Azure VM"
documentationCenter="github"
authors="fabferri"
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="na"
   ms.date="29/10/2023"
   ms.author="fabferri" />

## How to swap a public IPv4 between two Azure VMs

The purpose of this article is to swap the public IP assigned to the primary NIC of the Azure VM to the primary NIC of another Azure VM connected to the same subnet. <br>
The diagram below shows the configuration:

[![1]][1]


After the deployment only **vm1** has a public IP assigned to the primary NIC. the **vm2** is deployed without a public IP.<br>
The powershell script **swap.ps1** makes the following actions: 
- collects information about the NIC of each VM
- in the VM having the public IP, deallocate the public IP from the NIC
- associate the same public IP to the other VM 



[![2]][2]


The powershell script **swap.ps1** can run multiple times, swapping the public IP between the two VMs in turn. <br>
The powershell script **swap.ps1** writes the runtime operations of swapping IP between VMs in a log file, stored in the same script folder.


## <a name="list of files"></a>1. File list

| File name          | Description                                                                             |
| ------------------ | --------------------------------------------------------------------------------------- |
| **vms.json**       | ARM template to deploy vnet and two VMs connected to the same subnet                    |
| **vms.ps1**        | powershell script to deploy **vms.json**                                                |
| **swap.ps1**       | powershell script to swap the public IP from **vm1** to **vm2** and from **vm2** to **vm1** |


> [!NOTE]
> Before spinning up the ARM template you should edit the file **vms.ps1** and set:
> * your Azure subscription name in the variable **$subscriptionName**
> * the administrator username **$adminUsername** and password of the Azure VMs **$adminPassword**
>
> 


`Tags: public IP, Azure VM` <br>
`date: 30-10-2023`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/swap-ip.png "swap public IP between Azure VMs"

<!--Link References-->

