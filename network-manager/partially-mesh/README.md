<properties
pageTitle= 'Virtual networks in partially mesh topology with Azure Virtual Network Manager'
description= "Virtual networks in partially mesh topology with Azure Virtual Network Manager"
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
   ms.date="02/16/2022"
   ms.author="fabferri" />

# Virtual networks in partially mesh topology with Azure Virtual Network Manager
The network diagram is shown below:

[![1]][1]

<br>

The allow/denied communication want aim, it is summarized in the table:

|        | vnet1 | vnet2 | vnet3 | vnet4 | hub0  | hub1  | hub2 |       
| ------ | ----- | ----- | ----- | ----- | ----- | ------| ------|
| vnet1  |   -   | allow | deny  | deny  | allow | allow | allow |
| vnet2  | allow |  -    | deny  | deny  | allow | allow | allow |
| vnet3  | deny  | deny  |   -   | allow | allow | allow | allow |
| vnet4  | deny  | deny  | allow |   -   | allow | allow | allow |
| hub0   | allow | allow | allow | allow |   -   | allow | allow |
| hub1   | allow | allow | allow | allow | allow |   -   | deny  |
| hub2   | allow | allow | allow | allow | allow | deny  |   -   |

The implementation can be achieved in different ways. This article describes one possible solution:
- the **networkManagerScopeAccesses** is set only to **"Connectivity"**; the ARM template does not use **_security admin rules_**
- the network manager is scoped to a single Azure subscription
- all the network groups **gr1**,  **gr2**, **gr3** and **gr4** use a static group membership 
- vnet1 and vnet2 are in the network group **grp1** and in the network group **grp3**
- vnet3 and vnet4 are in the same network group **grp2** and in the network group **grp4**
- all the VNets [hub1, hub2, vnet1, vnet2, vnet3 and vnet4] are in the network group **grp0**
- three different connectivity configurations **netcfg1**, **netcfg2** and **netcfg3** are used
- the connectivity configurations **netcfg1** creates a topology hub-spoke with the **hub1** and includes the network groups **grp1** and **grp2**
- the connectivity configurations **netcfg2** creates a topology hub-spoke with the **hub2** and includes the network groups **grp3** and **grp4**
- the connectivity configurations **netcfg3** creates a topology hub-spoke with the **hub0** and includes the network groups **grp0**
- the connectivity configuration **netcfg1**, **netcfg2**  are configured <ins>with</ins> **"enable connectivity within each network group"**
- the connectivity configuration **netcfg3** is configured <ins>without</ins> **"enable connectivity within each network group"**
- deployment of those three connectivity configurations **netcfg1**, **netcfg2** and **netcfg2** provide a viable way to achieve the wished topology  

<br>

The composition of network groups are shown with diagram: 

[![2]][2]

The connectivity configurations are shown:

[![3]][3]
[![4]][4]
[![5]][5]



The network diagram inclusive of IP networks and VMs:

[![6]][6]

## <a name="List of files"></a> List of files 

| file                    | description                                                        |       
| ----------------------- |:------------------------------------------------------------------ |
| **01-vnets-vms.json**   | ARM template to create VNets and VMs                               |
| **01-vnets-vms.ps1**    | powershell script to deploy the ARM template **01-vnets-vms.json** |
| **02-anm.json**         | ARM template to create network groups and network connectivity configurations |
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
    "location": "westus2",
    "locationhub0": "westus2",
    "locationhub1": "westus2",
    "locationhub2": "westus2",
    "location1": "westus2",
    "location2": "westus2",
    "location3": "westus2",
    "location4": "westus2",
    "mngIP": "MANAGEMENT_PUBLIC_IP_ADDRESS_TO_CONNECT_IN_SSH_TO_THE_VMs",
    "RGTagExpireDate": "02/15/2022",
    "RGTagContact": "user1@contoso.com",
    "RGTagNinja": "user1",
    "RGTagUsage": "test azure network manager"
}
```
<br>

Deployment requires to run the scripts in sequence:
- step 1: customize the values of the variables in **init.json** 
- step 2: run the powershell script **01-vnets-vms.ps1** 
- step 3: run the powershell script **01-vnets-vms.ps1** 
- step 4: through Azure management portal, deploy the network connectivity configurations you have created in the target Azure regions 

NOTE: to simplify the configuration, all the VNets are deployed in the same Azure resource group.

<br>

Below some screenshots related to the deployment:

[![7]][7]

[![8]][8]

[![9]][9]





<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "network groups"
[3]: ./media/network-diagram3.png "connectivity configuration1"
[4]: ./media/network-diagram4.png "connectivity configuration2"
[5]: ./media/network-diagram5.png "connectivity configuration3"
[6]: ./media/network-diagram6.png "network diagram inclusive of IP networks and VMs"
[7]: ./media/network-diagram7.png "network groups"
[8]: ./media/network-diagram8.png "connectivity configurations"
[9]: ./media/network-diagram9.png "deployments"
<!--Link References-->

