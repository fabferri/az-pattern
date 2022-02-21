<properties
pageTitle= 'Large hub-spoke network topology with Azure Virtual Network Manager'
description= "Large hub-spoke network topology with Azure Virtual Network Manager"
documentationcenter: na
services="Virtual Network Manager"
documentationCenter="na"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="na"
   ms.date="30/03/2022"
   ms.author="fabferri" />

# Large hub-spoke network topology with Azure Virtual Network Manager
The article propose a hub-spoke configuration with large number of spoke VNets connected to the same hub. The network diagram is shown below:

[![1]][1]

<br>

The allow communications:
- hub vnet can communicate with all the spoke VNets
- Spoke VNets inside the same same network group can communicate each other
- communications between spoke VNets beloging to different network groups are denied

<br>



## <a name="List of files"></a>1. List of files 

| file              | description                                                               |       
| ----------------- |:------------------------------------------------------------------------- |
| **01-vnets.json** | ARM template to create hubvnet and spoke VNets                            |
| **01-vnets.ps1**  | powershell script to deploy the ARM template **01-vnets.json**            |
| **02-vms.json**   | ARM template to create few VMs in specific VNets                          |
| **02-vms.ps1**    | powershell script to deploy the ARM template **02-vms.json**              |
| **03-anm.json**   | ARM template to create Network Manager, the network groups and the connectivity configuration |
| **03-anm.ps1**    | powershell script to deploy the ARM template **03-anm.json**              |

<br>
 
Before spinning up the powershell scripts, you have to edit the file **init.json** to personalize the values of the input variables.
The structure of **init.json** file is shown below:
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "subscriptionName": "NAME_AZURE_SUBSCRIPTION",
    "ResourceGroupName": "NAME_RESOURCE_GROUP",
    "resourceGroupName": "large-vnet1",
    "resourceGroupNameVNets": "large-vnet1",
    "location" : "westus2",
    "locationhub" : "westus2",
    "locationspokes": "westus2",
    "numSpokes" : "NUMBER_SPOKE_VNETs",
    "mngIP": "MANAGEMENT_PUBLIC_IP_ADDRESS_TO_CONNECT_IN_SSH_TO_THE_VMs",
    "RGTagExpireDate": "02/15/2022",
    "RGTagContact": "user1@contoso.com",
    "RGTagNinja": "user1",
    "RGTagUsage": "test azure network manager"
}
```

**NOTE**
- **"numSpokes"** is an integer value specifies the total number of spoke VNet. Azure virtual Network Manager is in preview; a hub in a hub-and-spoke topology can be peered up to 250 spokes. The "numSpokes" can't be higher than 249.
- The spoke VNets are create by resource iteration; for reason of simplicity to each spoke vnet is assigned a network /24.
- the address space of spoke vnets are carved by interation with function module 256:
```json
"[concat(string(variables('firstOctet')),'.', string( add(variables('secondOctet'),div(copyIndex(),256)) ),'.', string(add(variables('thirdOctet'),mod(copyIndex(),256))), '.0/24' )]"
```
The first Octet and second octet have the fix values:
```console
"firstOctet": 10,
"secondOctet": 0,
```
- the third octet start with value 0 and increse in the interations.
- the ARM template **03-anm.json** creates network groups, each with 5 spoke VNets. A different criteria of partition of VNets in the network group can be used, but requires to adjust the ARM template
- the ARM template **02-vms.json** creates few VMs in existing VNets. This ARM template is not mandatory and it is required only if VMs are requested in specific VNets. The value of variable **vnet1Idx**, **vnet2Idx**, **vnet3Idx** specificy in which VNet the VMs need to be deployed. the values f these variable needs to be lower of max equal to the  **"numSpokes"** 



[![2]][2]

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram with IP networks"


<!--Link References-->

