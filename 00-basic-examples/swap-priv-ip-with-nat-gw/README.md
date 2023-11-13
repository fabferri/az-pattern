<properties
pageTitle= 'how to swap a secondary private IP address between two Azure VMs'
description= "moving private secondary IPv4 address between two Azure Virtual Machines"
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
   ms.date="13/11/2023"
   ms.author="fabferri" />

## How to swap a secondary private IP address between two Azure VMs

The purpose of this article is to swap a secondary private IP address assigned to the NIC of the Azure VM to the NIC of another Azure VM connected to the same subnet. <br>
The diagram below shows the configuration:

[![1]][1]

* The **vm3** has a single NIC with private and public IP and it is used as jump box to connect to the **vm1** and **vm2**. <br>
* The **vm1** and **vm2** have a single NIC attached to the **subnet1**. <br>
* Both of VMs, **vm1** and **vm2**, are deployed without a public IP. <br>
* After the deployment only **vm1** has a primary and a secondary private IP assigned to the primary NIC. 
* The IP outbound connections to internet for **vm1** and **vm2** is managed by VNet NAT Gateway.<br>
The powershell script **swap-priv-ip.ps** makes the following actions: 
- collects information about the NIC of each VM
- in the VM having the secondary private IP, deallocate the secondary IP from the NIC
- associate the same public IP to the other VM 

The diagram below shows the private IP swap between the two VMs:

[![2]][2]


The powershell script **swap-priv-ip.ps1** can run multiple times, swapping the secondary private IP between the two VMs in turn. <br>
The powershell script **swap-priv-ip.ps1** writes the runtime operations of swapping IP between VMs in a log file, stored in the same local script folder.


## <a name="list of files"></a>1. File list

| File name            | Description                                                                             |
| -------------------- | --------------------------------------------------------------------------------------- |
| **vms.json**         | ARM template to deploy vnet and two VMs connected to the same subnet                    |
| **vms.ps1**          | powershell script to deploy **vms.json**                                                |
| **swap-priv-ip.ps1** | powershell script to swap the secondary private IP from **vm1** to **vm2** and from **vm2** to **vm1** |


> [!NOTE]
> Before spinning up the ARM template you should edit the file **vms.ps1** and set:
> * your Azure subscription name in the variable **$subscriptionName**
> * the administrator username **$adminUsername** and password of the Azure VMs **$adminPassword**
>
> 


`Tags: VNET NAT Gateway, secondary private IP, Azure VM` <br>
`date: 13-11-2023`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/swap-ip.png "swap secondary private IP between Azure VMs"

<!--Link References-->

