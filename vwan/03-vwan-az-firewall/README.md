<properties
pageTitle= 'Virtual WAN: firewall - custom traffic transit'
description= "Virtual WAN: firewall - custom traffic transit"
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
   ms.date="03/09/2021"
   ms.author="fabferri" />

# Virtual WAN: firewall - custom traffic transit
This article describes a configuration with two virtual hubs with NVAs in spoke VNets. Below the network diagram:

[![1]][1]

Only the hub1 is a secure hub, with Azure firewall. The hub2 does not have an Azure firewall.
<br>
Let's set the goal of the configuration:
- traffic between spoke VNets (vnet1, vnet2, vnet3, vnet4) does directly and do not traverse the Azure firewall
- traffic between the vnet1 and vnet2 and internet goes through Azure firewall
- traffic between the vnet1 and vnet2 and branch1 goes through Azure firewall,
- traffic between the vnet1 and vnet2 and network on-premises through ExpressRoute circuit goes through the Azure firewall
- branch1 and branch2 can communicate directly without transit through Azure firewall
- branch1 and branch2 can communicate directly with on-premises through ExpressRoute and do not pass across the Azure firewall

[![2]][2]

<br>

[![3]][3]

Implementation requires two routing tables configured as follows:
- Virtual networks:
   - Associated route table: **RT_VNET**
   - Propagating to route tables: **RT_VNET**
- Branches (site-to-site VPN and ExpressRoute):
    - Associated route table: **defaultRouteTable**
    - Propagating to route tables: **defaultRouteTable**
- few static routes are required in the routing tables **RT_VNET** and **defaultRouteTable**  to activate the vnets-branches flows across the Azure firewall


<br>
Below the network diagram across-the-board:

[![4]][4]

<br>


## <a name="routing table association"></a>1. Connections and associations in the virtual hubs 

The network diagram below shows the connections with associations:
[![5]][5]



# <a name="routing table association"></a>2. Static routes in the routing tables of the hub1
VPN, ExpressRoute, and User VPN connections are collectively called Branches. The route tables **RT_VNET** and **defaultRoutingTable** are isolated. Branches are associated and propagating to the **defaultRoutingTable**. Branches do not propagate to **RT_VNET** route table. 

<br>

This ensures the VNet-to-Branch traffic flow via the Azure Firewall are necessary static routes in the routing tables **RT_VNET** and **defaultRoutingTable** of the hub1:

[![6]][6]

Static routes in the **RT_VNET** of the hub1:

| Dest Addr        | Nexthop          | description                   |      
| ---------------- |:--------------- | ----------------------------- |
| 192.168.1.0/24   | fw1_ResourceID  | route to reach out the branch1|
| 10.2.12.0/25     | fw1_ResourceID  | route to on-premises network across ExpressRoute |
| 0.0.0.0/0        | fw1_ResourceID  | defautl route to internet |

Static routes in the **defaultRoutingTable** of the hub1:

| Dest Addr        | Nexthop          | description            |      
| ---------------- |:---------------- | ---------------------- |
| 10.0.1.0/24      | fw1_ResourceID   | route to the vnet1     |
| 10.0.2.0/24      | fw1_ResourceID   | route to the vnet1     |




## <a name="routing table association"></a>3. Connections and routing tables in the hub1  

Routing tables and connections in hub1:
[![7]][7]

## <a name="routing table association"></a>4. Connections and routing tables in the hub2  
[![8]][8]

<br>


## <a name="List of files"></a>2. List of ARM templates and scripts

| file                        | description                                                                |       
| --------------------------- |:-------------------------------------------------------------------------- |
| **01-vwan.json**            | ARM template to create virtual WAN the virtual hubs, VNets, routing table and connections between VNets and virtual hubs  |
| **01-vwan.ps1**             | powershell script to deploy the ARM template **01-vwan.json**              |
| **02-vpn.json**             | ARM template to create the branch1 and branch2<br> The ARM template create  vnet, VPN gateway and one VM in each branch. |
| **02-vpn.ps1**              | powershell script to deploy the ARM template **02-vpn.json**               |
| **03-vwan-site.json**       | create in the hub1 a site-to-site connections with the branch1 and <br> in the hub2 a site-to-site connection with the branch2 |
| **03-vwan-site.ps1**        | powershell script to deploy the ARM template **03-vwan-site.json**         |
| **04-er.json**              | create in the hub1 a ExpressRoute connections in hub1                      |
| **04-er.ps1**               | powershell script to deploy the ARM template **04-er.json**                |


<br>

Before spinning up the powershell scripts, you should edit the file **init.json** and customize the values:
The structure of **init.json** file is shown below:
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "subscriptionName": "AzureDemo",
    "ResourceGroupName": "vwan1-grp",
    "hub1location": "westus2",
    "hub2location": "westus2",
    "branch1location": "westus2",
    "branch2location": "westus2",
    "hub1Name": "hub1",
    "hub2Name": "hub2",
    "sharedKey": "SHARED_SECRET_SITE_TO_SITE_VPN",
    "mngIP": "PUBLIC_MANAGEMENT_IP_TO_CONNECT_TO_THE_VMs",
    "ercircuitId": "/subscriptions/SUBSCRIPTION_ID/resourceGroups/RESOURCE_GROUP_NAME/providers/Microsoft.Network/expressRouteCircuits/EXPRESSROUTE_CIRCUIT_NAME",
    "authorizationKey": "818120f0-f6bd-4a8d-9739-d65eecd7f182",
    "er1AddressPrefix": "10.2.12.0/25",
    "RGTagExpireDate": "09/30/2021",
    "RGTagContact": "user1@contoso.com",
    "RGTagNinja": "user1",
    "RGTagUsage": "vWAN: route through NVAs in BGP peering with the hubs"
}
```
<br>

Meaning of the variables:
- **adminUsername**: administrator username of the Azure VMs
- **adminPassword**: administrator password of the Azure VMs
- **subscriptionName**: Azure subscription name
- **ResourceGroupName**: name of the resource group
- **hub1location**: Azure region of the virtual hub1
- **hub2location**: Azure region of the virtual hub2
- **branch1location**: Azure region to deploy the branch1
- **branch2location**: Azure region to deploy the branch2
- **hub1Name**: name of the virtual hub1
- **hub2Name**: name of the virtual hub2
- **sharedKey**: VPN shared secret
- **mngIP**: public IP used to connect to the Azure VMs in SSH
- **ercircuitId**: ExpressRoute circuit Id
- **authorizationKey**: Authorization key associated to the ExpressRoute circuit
- **er1AddressPrefix**: on-premises network advertised to the ExpressRoute circuit
- **RGTagExpireDate**: tag assigned to the resource group. It is used to track the expiration date of the deployment in testing
- **RGTagContact**: tag assigned to the resource group. It is used to email to the owner of the deployment
- **RGTagNinja**: alias of the user
- **RGTagUsage**: short description of the deployment purpose

The file **init.json** guarantees a consistency of input parameters across all the ARM templates.
<br>

**NOTE**
The ARM template **04-er.json** reference the existing Expressroute circuit through the ExpressRoute circuit ID and the authorization key.
<br>
The variable **ercircuitId** in **init.json** file has the following format:
```console
/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP_NAME>/providers/Microsoft.Network/expressRouteCircuits/<EXPRESSROUTE_CIRCUIT_NAME>
```

<br>
## <a name="how to run the deployment"></a>3. How to run the deployment
Deployment needs to be carried out in sequence:
- _1st step_: customize the values in **init.json**
- _2nd step_: run the script **01-vwan.ps1**. The runtime is 1 hour and 5 minutes (_estimated time_).
- _3rd step_: run the script **02-vpn.ps1**. The runtime is 20 minutes (_estimated time_).
- _4rd step_: run the script **03-vwan-site.ps1**. the runtime is 5 minutes (_estimated time_).
- _5th step_: run the script **04-er.json**. The runtime is 30 minutes (_estimated time_).


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

<!--Link References-->

