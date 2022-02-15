<properties
pageTitle= 'Create a simple hub-spoke network topology with Azure Virtual Network Manager'
description= "Create a simple hub-spoke network topology with Azure Virtual Network Manager"
documentationcenter: na
services="Azure Virtual Network Manager"
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
   ms.date="30/08/2021"
   ms.author="fabferri" />

# Create a simple hub-spoke network topology with Azure Virtual Network Manager
The network diagram is shown below:

[![1]][1]


<br>
Allow communications:
- vnet1 and vnet2 can communicate and are in the same network group 1
- vnet3 and vnet4 can communicate and are in the same network group 2
- vnet5 and vnet6 can communicate and are in the same network group 3
- vnet7 and vnet8 can communicate and are in the same network group 4
- hub vnet can communicate with all the spoke vnets (vnet1, vnet2, vne3, vnet4, vnet5, vnet6, vnet7)
<br>

The following communications are allow/denied:
| vnet   | vnet1 | vnet2 | vnet3 | vnet4 | vnet5 | vnet6 | vnet7 | vnet8 |       
| ------ | ----- | ----- | ----- | ----- | ----- | ------| ------| ----- |
| vnet1  |   -   | allow | deny  | deny  | deny  | deny  | deny  | deny  |
| vnet2  | allow |  -    | deny  | deny  | deny  | deny  | deny  | deny  |
| vnet3  | deny  | deny  |   -   | allow | deny  | deny  | deny  | deny  |
| vnet4  | deny  | deny  | deny  |   -   | allow | deny  | deny  | deny  |
| vnet5  | deny  | deny  | deny  | deny  |   -   | allow | deny  | deny  |
| vnet6  | deny  | deny  | deny  | deny  | deny  |   -   | allow | deny  |
| vnet7  | deny  | deny  | deny  | deny  | deny  | deny  |   -   | allow |
| vnet8  | deny  | deny  | deny  | deny  | deny  | deny  | allow |   -   |

**NOTE**: 
- the **networkManagerScopeAccesses** is set only to **"Connectivity"**; the ARM template does not use <ins>security admin rules</ins>
- the network manager is configured in hub-spoke topology
- the network manager is scoped to a single Azure subscription
- the network groups use a static group membership 
- the connectivity configuration is set with Direct Connectivity (enable connectivity within network group) on all network groups



## <a name="List of files"></a> List of files 

| file                    | description                                                        |       
| ----------------------- |:------------------------------------------------------------------ |
| **01-vnets-vms.json**   | ARM template to create vnets and VMs                               |
| **01-vnets-vms.ps1**    | powershell script to deploy the ARM template **01-vnets-vms.json** |
| **02-anm.json**         | ARM template to create network groups and a network connectivity configuration |
| **02-anm.ps1**          | powershell script to deploy the ARM template **02-anm.json**       |

<br>

Before spinning up the powershell scripts, **01-vnets-vms.ps1** and **02-anm.ps1**, you have to edit the file **init.json** and customize the values of variables:
The structure of **init.json** file is shown below:
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "subscriptionName": "NAME_AZURE_SUBSCRIPTION",
    "ResourceGroupName": "NAME_RESOURCE_GROUP",
    "location" : "westus2",
    "locationhubvnet" : "westus2",
    "locationvnet1" : "westus",
    "locationvnet2" : "westus2",
    "locationvnet3" : "westus",
    "locationvnet4" : "westus2",
    "locationvnet5" : "westus",
    "locationvnet6" : "westus2",
    "locationvnet7" : "westus",
    "locationvnet8" : "westus2",
    "mngIP": "MANAGEMENT_PUBLIC_IP_ADDRESS_TO_CONNECT_IN_SSH_TO_THE_VMs",
    "RGTagExpireDate": "02/15/2022",
    "RGTagContact": "user1@contoso.com",
    "RGTagNinja": "user1",
    "RGTagUsage": "test azure network manager"
}
```
<br>

Deployment requires to run the scripts in sequence:
- step 1: customize the values of variables in **init.json** 
- step 2: run the powershell script **01-vnets-vms.ps1** 
- step 3: run the powershell script **01-vnets-vms.ps1** 
- step 4: through Azure management portal, deploy the network connectivity configuration you have created in the Azure regions defined in "locationhubvnet", "locationvnet1", "locationvnet2","locationvnet3", "locationvnet4", "locationvnet5", "locationvnet6" ,"locationvnet7", "locationvnet8"

[![2]][2]

[![3]][3]

NOTE: to keep simple the configuration, all the vnets are deployed in the same Azure resource group


<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram"
[3]: ./media/network-diagram3.png "network diagram"

<!--Link References-->

