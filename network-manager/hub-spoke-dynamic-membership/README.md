<properties
pageTitle= 'Create a hub-spoke network topology with dynamic membership in Azure Virtual Network Manager'
description= "Create a hub-spoke network topology with dynamic membership in Azure Virtual Network Manager"
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
   ms.date="02/17/2022"
   ms.author="fabferri" />

# Create a hub-spoke network topology with dynamic membership in Azure Virtual Network Manager
In this article is described a simple hub-spoke topology with dynamic membership to the network groups. The network diagram is shown below:

[![1]][1]

<br>

The following communications are allow/denied:
|        | vnet1 | vnet2 | vnet3 | vnet4 | hub   |    
| ------ | ----- | ----- | ----- | ----- | ----- |
| vnet1  |   -   | allow | deny  | deny  | allow |
| vnet2  | allow |  -    | deny  | deny  | allow |
| vnet3  | deny  | deny  |   -   | allow | allow |
| vnet4  | deny  | deny  | allow |   -   | allow |
| hub    | allow | allow | allow | allow |   -   |


**NOTE**: 
- the **networkManagerScopeAccesses** is set only to **"Connectivity"**; the ARM template does not use security admin rules
- the network manager is configured in hub-spoke topology
- the network manager is scoped to a single Azure subscription
- five different VNets are created in different resource groups; each resource group has a specific tag 
- the network groups use dynamic membership; conditional statements are used to include in network group VNets deployed in Azure Resource Groups
- the connectivity configuration is configured with _enable connectivity within each network group_
- two network groups are defined named **grp1** and **grp2**
- the network group **grp1** with dynamic membership includes all the VNets for "PROD" environment
- the network group **grp2** with dynamic membership includes all the VNets for "TEST" environment

To dynamic membership for the network group **grp1** is established with the following structure:  
```console
"{ 
        \"allOf\": [
            {
                \"value\": \"[resourceGroup().Name]\", 
                \"contains\": \"PROD\" 
            }
        ]
}"
```

The string of dynamic membership can be along in single line, by the control character <b>\n</b> , but the format is less readable:

```json
"{ \n   \"allOf\": [\n   {\n    \"value\": \"[resourceGroup().Name]\", \n   \"contains\": \"PROD\" \n   }\n   ]\n  }"
```

The dynamic membership is shown in the Azure management portal as follow:

[![2]][2]

By the dynamic membership described, it is possible to include in dynamic membership all the VNets, in the Azure subscription, deployed in resource groups which name contains "PROD".

<br>

## <a name="List of files"></a> List of files 

| file                    | description                                                        |       
| ----------------------- |:------------------------------------------------------------------ |
| **01-vnets.json**       | ARM template to create 5 VNets in different resource groups        |
| **01-vnets.ps1**        | powershell script to deploy the ARM template **01-vnets.json**     |
| **02-vms.json**         | ARM template to create the VMs                                     |
| **02-vms.ps1**          | powershell script to deploy the ARM template **02-vms.json**       |
| **03-anm.json**         | ARM template to create network groups and a network connectivity configuration |
| **03-anm.ps1**          | powershell script to deploy the ARM template **03-anm.json**       |

<br>

Before spinning up the powershell scripts, **01-vnets-vms.ps1** and **02-anm.ps1**, you have to edit the file **init.json** and customize the values of variables:
The structure of **init.json** file is shown below:
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "subscriptionName": "NAME_AZURE_SUBSCRIPTION",
    "resourceGroupName": "anm",
    "resourceGroupNameHubVNet": "anm-SHARED",
    "resourceGroupNameVNet1": "anm-PROD",
    "resourceGroupNameVNet2": "anm-PROD",
    "resourceGroupNameVNet3": "anm-TEST",
    "resourceGroupNameVNet4": "anm-TEST",
    "location": "westus2",
    "locationhub": "westus2",
    "location1": "westus2",
    "location2": "westus2",
    "location3": "westus2",
    "location4": "westus2",
    "mngIP": "MANAGEMENT_PUBLIC_IP_ADDRESS_TO_CONNECT_IN_SSH_TO_THE_VMs",
    "RGTagExpireDate": "03/17/2022",
    "RGTagContact": "user1@contoso.com",
    "RGTagNinja": "user1",
    "RGTagUsage": "test azure network manager"
}
```
<br>

Deployment requires to run the scripts in sequence (respect the order of execution otherwise the scripts will fail):
- step 1: edit the **init.json** file to customize the values of variables  
- step 2: run the powershell script **01-vnets.ps1**; this creates the resource groups and VNets 
- step 3: run the powershell script **02-vms.ps1**; this creates the VMs in same resource groups of the related VNets.
- step 4: run the powershell script **03-anm.ps1** 
- step 5: deployment of the network connectivity configuration you have created in a specific Azure region through Azure management portal

<br>

Full network diagram inclusive of IP networks and VMs:

[![3]][3]


<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram"
[3]: ./media/network-diagram3.png "network diagram with IP networks"

<!--Link References-->

