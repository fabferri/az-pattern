<properties
pageTitle= 'hub-spoke network topology with VPN Gateway in the hub vnet with Azure Virtual Network Manager'
description= "hub-spoke network topology with VPN Gateway in the hub vnet with Azure Virtual Network Manager"
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

# hub-spoke network topology with VPN Gateway in the hub vnet with Azure Virtual Network Manager
The netwrk diagram is shown:

[![1]][1]

<br>

The allow communications:
- vnet1 and vnet2  belong to the same network group **grp1** ; vnet1 and vnet2 can communicate with **Direct connection**
- vnet3 and vnet4  belong to the same network group **grp2** ; vnet3 and vnet4 can communicate with **Direct connection**
- the communications betwen different network groups are denied: vnet1 and vnet2 can't communicate with vnet3 and vnet4 
- hub vnet can communicate with all the spoke vnets (vnet1, vnet2, vne3, vnet4) and branch vnet 
- the VPN Gateway in the hub enables the communication with remote branch vnet

The screenshot below shows the setting of the **connectivity configuration** of the network manager:

[![2]][2]

<br>

Below the network diagram with IP networks assigned to the vnets and to the GatewaySubnets:

[![3]][3]

To use the VPN Gateway in the hub the connectivity configuration (**Microsoft.Network/networkManagers/connectivityConfigurations**) is defined with the **"useHubGateway"** sets to true.


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
 
Before spinning up the powershell scripts, you have to edit the file **init.json** to personalize the values of the input variables.
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

The network diagram reports the communications between vnets with transit across the site-to-site VPN:

[![4]][4]

## <a name="Effective routes in vm1"></a>2. Effective routing table in NIC of the vm1

| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.1.0/24      | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.0.0.0/24      | VNet peering            | \-                  | \-                      |
| Default                 | Active | 10.0.2.0/24      | ConnectedGroup          | \-                  | \-                      |
| Virtual network gateway | Active | 10.0.20.229/32   | Virtual network gateway | 10.0.0.228          | \-                      |
| Virtual network gateway | Active | 10.0.20.229/32   | Virtual network gateway | 10.0.0.229          | \-                      |
| Virtual network gateway | Active | 10.0.20.228/32   | Virtual network gateway | 10.0.0.228          | \-                      |
| Virtual network gateway | Active | 10.0.20.228/32   | Virtual network gateway | 10.0.0.229          | \-                      |
| Virtual network gateway | Active | 10.0.20.0/24     | Virtual network gateway | 10.0.0.228          | \-                      |
| Virtual network gateway | Active | 10.0.20.0/24     | Virtual network gateway | 10.0.0.229          | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |

## <a name="Effective routes in branch VM"></a>3. Effective routing table in NIC of the branchvm
The VM in branch receives the networks of hub and spoke vnets:

| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.20.0/24     | Virtual network         | \-                  | \-                      |
| Virtual network gateway | Active | 10.0.0.228/32    | Virtual network gateway | 10.0.20.228         | \-                      |
| Virtual network gateway | Active | 10.0.0.228/32    | Virtual network gateway | 10.0.20.229         | \-                      |
| Virtual network gateway | Active | 10.0.0.0/24      | Virtual network gateway | 10.0.20.228         | \-                      |
| Virtual network gateway | Active | 10.0.0.0/24      | Virtual network gateway | 10.0.20.229         | \-                      |
| Virtual network gateway | Active | 10.0.0.229/32    | Virtual network gateway | 10.0.20.228         | \-                      |
| Virtual network gateway | Active | 10.0.0.229/32    | Virtual network gateway | 10.0.20.229         | \-                      |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 10.0.20.228         | \-                      |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 10.0.20.229         | \-                      |
| Virtual network gateway | Active | 10.0.1.0/24      | Virtual network gateway | 10.0.20.228         | \-                      |
| Virtual network gateway | Active | 10.0.1.0/24      | Virtual network gateway | 10.0.20.229         | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 10.0.20.228         | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 10.0.20.229         | \-                      |
| Virtual network gateway | Active | 10.0.4.0/24      | Virtual network gateway | 10.0.20.228         | \-                      |
| Virtual network gateway | Active | 10.0.4.0/24      | Virtual network gateway | 10.0.20.229         | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |


<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram"
[3]: ./media/network-diagram3.png "network diagram"
[4]: ./media/network-diagram4.png "network diagram"

<!--Link References-->

