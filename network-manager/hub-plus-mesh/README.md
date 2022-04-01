<properties
pageTitle= 'Network topology in hub-spoke with spoke vnets in mesh through Azure Virtual Network Manager'
description= "Network topology in hub-spoke with spoke vnets in mesh through Azure Virtual Network Manager"
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

# Network topology in hub-spoke with spoke vnets in mesh through Azure Virtual Network Manager
The network diagram is shown below with vnets and network groups:

[![1]][1]

For reason of clarity, the network diagram with hub-spoke and mesh configurations is split up in different sketches: 

[![2]][2]

Three different configurations are deployed:
* netfg1: it is an hub-spoke network configuration
* netcfg2: it is a mesh topology created between two network groups, **grp6** and **grp7**
* netcfg3: it is a mesh topology create between the two network group, **grp8** and **grp9**

**NOTE**: 
- the **networkManagerScopeAccesses** is set only to **"Connectivity"**; the ARM template does not use <ins>security admin rules</ins>
- the network manager is scoped to a single Azure subscription
- the network groups use a static group membership 
- the connectivity configuration is set with Direct Connectivity (enable connectivity within network group) on all network groups
- the deployment has to run <ins>**without connectivity configurations in goal state**</ins>, to avoid one network configuration remove the setting created from other network configurations. **Without connectivity configurations in goal state**, the different network configurations will overlap.
- All the vnets are deployed in the same Azure resource group



## <a name="List of files"></a> List of files 

| file                    | description                                                        |       
| ----------------------- |:------------------------------------------------------------------ |
| **01-vnets-vms.json**   | ARM template to create vnets and VMs                               |
| **01-vnets-vms.ps1**    | powershell script to deploy the ARM template **01-vnets-vms.json** |
| **02-anm.json**         | ARM template to create network groups and  network connectivity configurations |
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
    "locationvnet1" : "westus2",
    "locationvnet2" : "westus2",
    "locationvnet3" : "westus2",
    "locationvnet4" : "westus2",
    "locationvnet5" : "westus2",
    "locationvnet6" : "westus2",
    "locationvnet7" : "westus2",
    "locationvnet8" : "westus2",
    "locationvnet9" : "westus2",
    "locationvnet10" : "westus2",
    "mngIP": "MANAGEMENT_PUBLIC_IP_ADDRESS_TO_CONNECT_IN_SSH_TO_THE_VMs",
    "RGTagExpireDate": "04/15/2022",
    "RGTagContact": "user1@contoso.com",
    "RGTagNinja": "user1",
    "RGTagUsage": "test azure network manager"
}
```
<br>

To make the deployment, run the scripts in sequence:
- step 1: customize the values of variables in **init.json** 
- step 2: run the powershell script **01-vnets-vms.ps1** 
- step 3: run the powershell script **02-anm.ps1** 
- step 4: through Azure management portal, deploy the network connectivity configurations in the target azure region


[![3]][3]

To connect in SSH to the VMs, you can get the public IP of the VMs by the powershell command:

```powershell
Get-AzPublicIpAddress -ResourceGroup $rgName | Select-Object Name,IpAddress
```


<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram"
[3]: ./media/network-diagram3.png "network diagram"

<!--Link References-->

