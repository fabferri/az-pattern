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
   ms.tgt_pltfrm="azure"
   ms.workload="na"
   ms.date="30/08/2021"
   ms.author="fabferri" />

# Create a simple hub-spoke network topology with Azure Virtual Network Manager
The network diagram is shown below:

[![1]][1]


<br>
Allow communications:
- vnet1 and vnet2 can communicate and are in the same network group
- vnet3 and vnet4 can communicate and are in the same network group
- hub vnet can communicate with all the spoke vnets (vnet1, vnet2, vne3, vnet4)
<br>

The following communications are denied:
- vnet1 can't communicate with vnet3 
- vnet1 can't communicate with vnet4
- vnet2 can't communicate with vnet3 
- vnet2 can't communicate with vnet4

**NOTE**: 
- the **networkManagerScopeAccesses** is set only to **"Connectivity"**; the ARM template does not use security admin rules
- the network manager is configured in hub-spoke topology
- the network manager is scoped to a single Azure subscription
- the network groups use a static group membership 
- the connectivity configuration is configured with enable connectivity within each network group


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
    "locationhub" : "westus2",
    "location1" : "westus2",
    "location2" : "westus2",
    "location3" : "westus2",
    "location4" : "westus2",
    "mngIP": "MANAGEMENT_PUBLIC_IP_ADDRESS_TO_CONNECT_IN_SSH_TO_THE_VMs",
    "RGTagExpireDate": "02/15/2022",
    "RGTagContact": "user1@contoso.com",
    "RGTagNinja": "user1",
    "RGTagUsage": "test azure network manager"
}
```
<br>

Deployment requires to run the scripts in sequence:
- step 1: edit the file **init.json** to customize the values of variables
- step 2: run the powershell script **01-vnets-vms.ps1** 
- step 3: run the powershell script **01-vnets-vms.ps1** 
- step 4: through Azure management portal, deploy the network connectivity configuration you have created in a specific Azure region 


[![2]][2]

<br>

NOTE: to keep simple the configuration, all the vnets are deployed in the same Azure resource group

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram"

<!--Link References-->

