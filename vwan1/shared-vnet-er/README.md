<properties
pageTitle= 'Virtual WAN: communication of a shared vnet with isolating vnets and branch'
description= "Virtual WAN: communication of a shared vnet with isolating vnets and branch"
documentationcenter: na
services=""
documentationCenter="github repository"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service = "configuration-example-Azure Virtual WAN"
   ms.devlang = "na"
   ms.topic = "article"
   ms.tgt_pltfrm = "Azure"
   ms.workload = "Virtual WAN"
   ms.date = "02/02/2023"
   ms.author="fabferri" />

## Virtual WAN: communication of a shared vnet with isolating vnets and branch
The article describes a simple virtual WAN configuration with:
* shared vnet, named  **nvavnet**, able to communicate with  two isolated spoke VNets **spoke1**, **spoke2** 
* shared **nvavnet** able to communicate with the on-premises network through the ExpressRoute circuit

The network diagram is shown below:

[![1]][1]


### Routing setup

|Routing configuration of **nvavnet**  connection   ||   
| -------------------- |:-------------------------- | 
| associatedRouteTable | **RT_SHARED**              | 
| propagatedRouteTable | **default**, **RT_SPOKE**  | 

<br>

|Routing configuration of **spoke1** connection  ||
| -------------------- |:----------------------- | 
| associatedRouteTable | **RT_SPOKE**            | 
| propagatedRouteTable | **RT_SHARED**           | 
<br>

|Routing configuration of **spoke2** connection  ||
| -------------------- |:----------------------- | 
| associatedRouteTable | **RT_SPOKE**            | 
| propagatedRouteTable | **RT_SHARED**           | 

<br>

|Routing configuration of ExpressRoute connection   ||
| -------------------- |:-------------------------- | 
| associatedRouteTable | **default**                | 
| propagatedRouteTable | **default**, **RT_SHARED** | 

<br>



The diagram shows the communications between vnets and between shared vnet and on-premises:

[![2]][2]

|                      | communication   |
| -------------------- |:--------------- | 
| spoke1 - spoke2      | **deny**        | 
| spoke1 - nvavnet     | **allow**       | 
| spoke1 - on-premises | **deny**        | 
| spoke2 - nvavnet     | **allow**       |
| spoke2 - on-premsies | **deny**        |
| nvavnet - on-premises| **allow**       |

### <a name="List of files"></a>1. List of files 

| file                   | description                                                         |       
| ---------------------- |:------------------------------------------------------------------- |
| **init.json**          | file with the value of variables used across the ARM templates      |
| **01-vwan.json**       | ARM template to create virtual WAN the virtual hub, VNets, routing tables, connections between VNets and virtual hubs and VMs |
| **01-vwan.ps1**        | powershell script to deploy the ARM template **01-vwan.json**       |
| **02-er-connection.json** | ARM template an ExpressRoute connection                          |
| **02-vpn.ps1**         | powershell script to deploy the ARM template ***02-er-connection.json**        |

<br>
 
Before spinning up the powershell scripts, you should edit the file **init.json** and customize the values of input variables in use across all the ARM templates.

<br>

Meaning of the variables in **init.json**:
```json
{
    "subscriptionName": "AZURE_SUBSCRIPTION_NAME_WHERE_DEPLOY_THE_VIRTUAL_WAN_AND_VNETs",
    "ResourceGroupName": "RESOURCE_GROUP_NAME_WHERE_DEPLOY_THE_VIRTUAL_WAN_AND_VNETs",
    "vwanName": "NAME_OF_THE_VIRTUAL_WAN",
    "hub1location": "AZURE_REGION_VIRTUAL_WAN",
    "hub1Name": "NAME_OF_THE_VIRTUAL_HUB",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "ercircuitSubcriptionId": "AZURE_SUBSCRIPTION_ID_WHERE_IS_DEPLOYED_THE_EXPRESSROUTE_CIRCUIT",
    "ercircuitResourceGroup": "RESOUCE_GROUP_NAME_WHERE_IS_DEPLOYED_THE_EXPRESSROUTE_CIRCUIT",
    "erCircuitName": "EXPRESSROUTE_CIRCUIT_NAME",
    "erAuthorizationKey": "EXPRESSROUTE_AUTHORIZATION_KEY"
}
```
<br>


`Tags: Virtual WAN, vWAN` <br>
`Testing date: 02-02-23`

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "communication between vnets and between shared vnet and on-premises"

<!--Link References-->

