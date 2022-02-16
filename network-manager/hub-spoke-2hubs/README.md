<properties
pageTitle= 'hub-spoke network topology with Azure Virtual Network Manager with spoke vnets connected to two hubs '
description= "hub-spoke network topology with Azure Virtual Network Manager with spoke vnets connected to two hubs"
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

# hub-spoke network topology with Azure Virtual Network Manager with spoke vnets connected to two hubs
The network diagram is shown below:

[![1]][1]

<br>

Allow communications:
- vnet1 and vnet2 can communicate and are in the same network group **grp1**
- vnet3 and vnet4 can communicate and are in the same network group **grp2**
- hub1 vnet can communicate with all the spoke vnets (vnet1, vnet2, vne3, vnet4)
- hub2 vnet can communicate with all the spoke vnets (vnet1, vnet2, vne3, vnet4)
<br>

The following communications are denied:
- hub1 vnet can't communicate with hub2 vnet 
- vnet1 can't communicate with vnet3
- vnet1 can't communicate with vnet4
- vnet2 can't communicate with vnet3 
- vnet2 can't communicate with vnet4

**NOTE**: 
- the **networkManagerScopeAccesses** is set only to **"Connectivity"**; the ARM template does not use security admin rules
- the network manager is configured in hub-spoke topology, with two hubs: hub1 and hub2
- the network manager is scoped to a single Azure subscription
- the network groups **gr1** and **gr2** use a static group membership 
- the connectivity configurations are configured with enable connectivity within each network group
- two connectivity configurations are in use to establish the communication with hub1 and hub2. The two connectivity configurations in hub-spoke topology use the same network groups **grp1** and **grp2**

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
    "locationhub1" : "westus2",
    "locationhub2" : "westus2",
    "location1" : "westus2",
    "location2" : "westus2",
    "location3" : "westus2",
    "location4" : "westus2",
    "mngIP": "MANAGEMENT_PUBLIC_IP_ADDRESS_TO_CONNECT_IN_SSH_TO_THE_VM",
    "RGTagExpireDate": "02/15/2022",
    "RGTagContact": "user1@contoso.com",
    "RGTagNinja": "user1",
    "RGTagUsage": "test azure network manager"
}
```
<br>

Deployment requires to run the the scripts in sequence:
- step 1: customize the values of variables in **init.json** 
- step 2: run the powershell script **01-vnets-vms.ps1** 
- step 3: run the powershell script **01-vnets-vms.ps1** 
- step 4: through Azure management portal, deploy the network connectivity configuration you have created in a specific Azure region 

NOTE: to simplify the configuration, all the vnets are deployed in the same Azure resource group.

<br>
The network diagram below shows the address space assigned to each vnets and VMs:

[![2]][2]

<br>


<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram"

<!--Link References-->

