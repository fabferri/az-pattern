<properties
pageTitle= 'Azure Virtual Network Manager with Dynamic Membership in a Hub-Spoke Network Topology'
description= "Azure Virtual Network Manager with Dynamic Membership in a Hub-Spoke Network Topology"
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

# Azure Virtual Network Manager with Dynamic Membership in a Hub-Spoke Network Topology
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

<br>

The dynamic membership to the network groups is based on two criteria:
- tag assigned to the VNets

AND 

- the presence of specific word in VNet name

<br>

[![2]][2]

**NOTE**: 
- the **networkManagerScopeAccesses** is set only to **"Connectivity"**; the ARM template does not use security admin rules
- the network manager is configured in hub-spoke topology
- the network manager is scoped to a single Azure subscription
- five different VNets are created in different resource groups; each resource group has a specific tag but tags is not used to create dynamic membership  
- the network groups use dynamic membership with conditional statements based on vnet tag and vnet naming
- the connectivity configuration is configured with _enable connectivity within each network group_
- two network groups are defined named **grp1** and **grp2**
- the network group **grp1** is based on dynamic membership. The network group includes all the VNets containing the word "PROD" in the vnet name AND in vnet tag "Environment"  
- the network group **grp2** is based on dynamic membership. the network group includes all the VNets containing the word "DEV" in the vnet name AND in vnet tag "Environment"  

To dynamic membership for the network group **grp1** has the following structure:  
```json
"policyRule": {
    "if": {
        "allof": [
            {
                "field": "type",
                "equals": "Microsoft.Network/virtualNetworks"
            },
            {
                "field": "tags[Environment]",
                "contains": "PROD"
            },
            {
                "field": "Name",
                "contains": "PROD"
            }
        ]
    },
    "then": {
        "effect": "addToNetworkGroup",
        "details": {
            "networkGroupId": "[parameters('networkGroupId')]"
        }
    }
}
```
where:
```json
"networkGroupId": "[resourceId(subscription().subscriptionId, parameters('resourceGroupName'), 'Microsoft.Network/networkManagers/networkGroups', parameters('networkManagerName'),parameters('networkGroup1Name'))]"
```


To dynamic membership for the network group **grp2** has the following structure:  
```json
"policyRule": {
    "if": {
        "allof": [
            {
                "field": "type",
                "equals": "Microsoft.Network/virtualNetworks"
            },
            {
                "field": "tags[Environment]",
                "contains": "DEV"
            },
            {
                "field": "Name",
                "contains": "DEV"
            }
        ]
    },
    "then": {
        "effect": "addToNetworkGroup",
        "details": {
            "networkGroupId": "[parameters('networkGroupId')]"
        }
    }
}
```
where:
```json
"networkGroupId": "[resourceId(subscription().subscriptionId, parameters('resourceGroupName'), 'Microsoft.Network/networkManagers/networkGroups', parameters('networkManagerName'),parameters('networkGroup2Name'))]"
```

<br>

## <a name="List of files"></a> List of files 

| file                    | description                                                          |       
| ----------------------- |:-------------------------------------------------------------------- |
| **01-vnets.json**       | ARM template to create five VNets in different resource groups  and one Azure VM in each vnet |
| **01-vnets.ps1**        | powershell script to deploy the ARM template **01-vnets.json**                                |
| **03-anm.json**         | ARM template to create network groups and a network connectivity configuration                |
| **03-anm.ps1**          | powershell script to deploy the ARM template **03-anm.json**         |
| **deployment.ps1**      | powershell using REST API to deploy the Azure Virtual Network Manager configuration |
| **deployment-deleting.ps1** | powershell using REST API to delete the deployment of the Azure Virtual Network Manager configuration |

<br>

Before spinning up the powershell scripts (**01-vnets-vms.ps1**, **02-anm.ps1**, **03-anm.ps1**) you have to edit and customize the values of variables in the file **init.json**:
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "subscriptionName": "NAME_AZURE_SUBSCRIPTION",
    "resourceGroupName": "RESOURCE_GROUP_NAME_NETWORK_MANAGER",
    "resourceGroupNameHubVNet": "RESOURCE_GROUP_NAME_HUB_VNET",
    "resourceGroupNameVNet1": "RESOURCE_GROUP_NAME_HUB_vnet1",
    "resourceGroupNameVNet2": "RESOURCE_GROUP_NAME_HUB_vnet2",
    "resourceGroupNameVNet3": "RESOURCE_GROUP_NAME_HUB_vnet3",
    "resourceGroupNameVNet4": "RESOURCE_GROUP_NAME_HUB_vnet4",
    "location": "AZURE_REGION_NETWORK_MANAGER",
    "locationhub": "AZURE_REGION_HUB_VNET",
    "location1": "AZURE_REGION_vnet1",
    "location2": "AZURE_REGION_vnet2",
    "location3": "AZURE_REGION_vnet3",
    "location4":"AZURE_REGION_vnet4"
}
```
<br>

Deployment requires to run the scripts in sequence (respect the order of execution otherwise the scripts will fail):
- step 1: edit the **init.json** file to customize the values of variables  
- step 2: run the powershell script **01-vnets.ps1**; this creates the resource groups and VNets 
- step 3: run the powershell script **02-anm.ps1** 
- step 4: deployment of the network connectivity configuration you have created in a specific Azure region through Azure management portal or through the powershell **deployment.ps1**


`Tags: Azure Virtual Network Manager` <br>
`date: 06-05-2024` <br>

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram"

<!--Link References-->

