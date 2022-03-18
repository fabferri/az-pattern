<properties
pageTitle= 'Azure Virtual Network Manager in hub-spoke topology with dynamic membership and security admin config'
description= "Azure Virtual Network Manager in hub-spoke topology with Dynamic membership and security admin config"
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
   ms.date="30/08/2021"
   ms.author="fabferri" />

# Azure Virtual Network Manager in hub-spoke topology with Dynamic membership and security admin config
The network diagram is shown:

[![1]][1]

<br>

The network connectivity is described in brief:
- vnet1 and vnet2  are in the same network group **grp1** ; vnet1 and vnet2 can communicate with **Direct Connectivity**
- vnet3 and vnet4  are in the same network group **grp2** ; vnet3 and vnet4 can communicate with **Direct Connectivity**
- the communications between different network groups are denied: vnet1 and vnet2 can't communicate with vnet3 and vnet4 
- hub vnet can communicate with all the spoke vnets (vnet1, vnet2, vne3, vnet4) 
- the network group **grp1** use the hub as a gateway that allows to the communication across the VPN Gateways between vnet1 <-> branch vnet, vnet2 <-> branch vnet
- the network group **grp2** use the hub as a gateway that allows to the communication across the VPN Gateways between vnet3 <-> branch vnet, vnet4 <-> branch vnet

The screenshot shows the setting of the **connectivity configuration** of the network manager in Azure Network Management portal:

[![2]][2]

<br>

A network diagram inclusive of IP addresses is shown below:

[![3]][3]

To use the VPN Gateway in the hub the connectivity configuration (**Microsoft.Network/networkManagers/connectivityConfigurations**) is defined in the ARM template with the **"useHubGateway"** sets to true.

[![4]][4]

The network diagram reports the communications between vnets with transit across the site-to-site VPN:

[![5]][5]

A visual representation of the full configuration deployed by ARM template with **connectivity configuration** and **security admin configuration** is reported below. To keep simple the security admin configuration is only applied only to **grp2**:

[![6]][6]

After the deployment with ARM template, the  **configuration configuration** and **security admin configuration** required to be deployed in one of more Azure regions:

[![7]][7]

The ARM template creates a single security admin configuration with one rule collection:

[![8]][8]

The policy specified in the rule collection of the security admin rule **seccfg1** deny some traffic:

[![9]][9]


[![10]][10]

## <a name="List of files"></a>1. List of files 

| file              | description                                                               |       
| ----------------- |:------------------------------------------------------------------------- |
| **00-vpn.json**   | ARM template to create hubvnet and branch vnet with the VPN Gateways in the gateway subnets|
| **00-vpn.ps1**    | powershell script to deploy the ARM template **00-vpn.json**              |
| **01-vpn.json**   | ARM template to create the connections in VPN Gateway1 and VPN Gateway2   |
| **01-vpn.ps1**    | powershell script to deploy the ARM template **01-vpn.jso**               |
| **02-vnets-vms.json** | ARM template to create vnets and VMs                                  |
| **02-vnets-vms.ps1**  | powershell script to deploy the ARM template **02-vnets-vms.json**    |
| **03-anm.json**       | ARM template to create Network Manager, the network groups and the connectivity configuration |
| **03-anm.ps1**    | powershell script to deploy the ARM template **03-anm.json**              |

<br>
 
Before spinning up the powershell scripts, you have to edit the file **init.json** you should customize the values of the input variables.
The structure of **init.json** file is shown below:
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "subscriptionName": "NAME_AZURE_SUBSCRIPTION",
    "ResourceGroupName": "NAME_RESOURCE_GROUP",
    "location" : "westus2",
    "locationhub" : "westus2",
    "locationbranch" : "westus2",
    "location1" : "westus2",
    "location2" : "westus2",
    "location3" : "westus2",
    "location4" : "westus2",
    "mngIP": "MANAGEMENT_PUBLIC_IP_ADDRESS_TO_CONNECT_IN_SSH_TO_THE_VM",
    "RGTagExpireDate": "09/30/2021",
    "RGTagContact": "user1@contoso.com",
    "RGTagNinja": "user1",
    "RGTagUsage": "test azure Virtual Network Manager"
}
```
<br>


<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram"
[3]: ./media/network-diagram3.png "network diagram"
[4]: ./media/network-diagram4.png "network diagram"
[5]: ./media/network-diagram5.png "network diagram"
[6]: ./media/network-diagram6.png "network diagram"
[7]: ./media/network-diagram7.png "network diagram"
[8]: ./media/network-diagram8.png "network diagram"
[9]: ./media/network-diagram9.png "network diagram"
[10]: ./media/network-diagram10.png "network diagram"
<!--Link References-->

