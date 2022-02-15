<properties
pageTitle= 'Create a simple mesh network topology with Azure Virtual Network Manager'
description= "Create a simple mesh network topology with Azure Virtual Network Manager"
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

# Create a simple mesh network topology with Azure Virtual Network Manager
The network diagram shows a mesh topology between the vnets:

[![1]][1]

The mesh topology allows communications any-to-any.

<br>


**NOTE**: 
- the **networkManagerScopeAccesses** is set only to **"Connectivity"**; the ARM template does not use security admin rules
- the network manager is configured in mesh topology and it allows communications any-to-any.
- the network manager is scoped to a single Azure subscription
- the network groups use a static group membership


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

Deployment requires to run the the scripts in sequence:
- step 1: customize the values of variables in **init.json** 
- step 2: run the powershell script **01-vnets-vms.ps1** 
- step 3: run the powershell script **01-vnets-vms.ps1** 
- step 4: through Azure management portal, deploy the network connectivity configuration you have created in the Azure regions specified in the variables **"location1"**, **"location2"**, **"location3"**, **"location4"**. 


<br>

NOTE: to keep simple the configuration, all the vnets are deployed in the same Azure resource group

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"

<!--Link References-->

