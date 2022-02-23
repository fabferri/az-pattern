<properties
pageTitle= 'Create a secured hub and spoke network with Azure Network Manager'
description= "Create a secured hub and spoke network with Azure Network Manager"
documentationcenter: na
services=""
documentationCenter="na"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="na"
   ms.date="30/03/2022"
   ms.author="fabferri" />

# Create a secured hub and spoke network with Azure Network Manager
The goal of this article is to create a basic secure hub-spoke configuration. The network diagram is shown:

[![1]][1]


<br>
The allow/deny communications:
- communication between vnet1 and vnet2 is allowed
- communication between vnet3 and vnet4 is allowed
- communication between hub and all the spoke vnets (vnet1, vnet2, vne3, vnet4) is allowed
- communication between vnet1 and vnet3 is denied
- communication between vnet1 and vnet4 is denied
- communication between vnet2 and vnet3 is denied
- communication between vnet2 and vnet4 is denied
<br>



## <a name="List of files"></a>1. List of files 

| file                     | description                                                               |       
| ------------------------ |:------------------------------------------------------------------------- |
| **01-vnets-vms.json**    | ARM template to create hub and spoke vnets. in each VNet is created a VM  |
| **01-vnets-vms.ps1**     | powershell script to deploy the ARM template **01-vnets-vms.ps1**         |
| **02-anm.json**          | ARM template to create network manager, network group, connection configuration, security admin configuration |
| **02-anm.ps1**           | powershell script to deploy the ARM template **02-anm.json**              |

<br>
 
Before spinning up the powershell scripts, edit  **init.json** file to customize the values of variables.
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
    "RGTagExpireDate": "03/30/2022",
    "RGTagContact": "user1@contoso.com",
    "RGTagNinja": "user1",
    "RGTagUsage": "test azure network manager"
}
```

## <a name="Connectivity and Security Admin configuration"></a>2. Connectivity configuration and Security Admins configuration

Ther ARM template are two types of configurations: Connectivity configuration (named **netcfg**) and Security Admins configuration (**netcfg1**).
The security admin configuration contains a single rule connection. the security admin configuration is associated to the target network group **grp2**. 

<br>

The Connectivity **netcfg** configuration and Security Admins configuration **netcfg1** are shown in the diagram: 

[![2]][2]


Connectivity **netcfg** configuration and Security Admins configuration **netcfg1** are deployed in the Azure region westus2:
 
[![3]][3]

The ARM template define a single rule colletion containing more security admin rules:

[![4]][4]

A security rules can contain in _Source type_ and _Destination type_ a blocks of address in CIDR notation or a service tag. 
In the ARM template **02-anm.json** a security rule reference the tag **Storage** to allow access OUTBOUND to the storage accounts.

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram"
[3]: ./media/network-diagram3.png "network diagram"
[4]: ./media/network-diagram4.png "network diagram"

<!--Link References-->

