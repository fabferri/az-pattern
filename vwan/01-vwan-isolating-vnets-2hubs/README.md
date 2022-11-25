<properties
pageTitle= 'Virtual WAN: simple configuration with isolating VNets'
description= "Virtual WAN: simple configuration with isolating VNets"
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
   ms.date="30/08/2021"
   ms.author="fabferri" />

# Virtual WAN: simple configuration with isolating VNets

The article walks through a virtual WAN configuration with spoke VNets connected to two virtual hubs hub1 and hub2. The configuration establishes a selective interconnection between spoke VNets. Only spoke VNets belonging to the same group can communicate each other. This configuration is known as **isolating VNets**. Below the network diagram:

[![1]][1]

The VNet1 and VNet3 are connected to the different virtual hubs and associated with the same routing table named **RT_RED**
<br>

The VNet2 and VNet4 are connected to the different hubs and associated with the same routing table named **RT_BLUE**
<br>
Comunications between VNets is shown in the table below:

|          | vnet1   | vnet2   | vnet3   | vnet4   |
| -------- | ------- | ------- | ------- | ------- |
|vnet1     | allow   | deny    | allow   |	deny   |
|vnet2     | deny    | allow   | deny    |	allow  |
|vnet3     | allow   | deny    | allow   |	deny   |
|vnet4     | deny    | allow   | deny    |	allow  |


The diagram below shows the selective communication between VNets:

[![2]][2]


## <a name="Routing in Virtual Hubs"></a>1. Routing in Virtual Hubs
Two routing tables are required to implement the configuration: **RT_RED** and **RT_BLUE**
<br>
The target configuration can be achieved with two different approaches: 
- connection with propagation to labels
- connection without propagation to labels

<br>

### <a name="with propagation to labels"></a>1.1 Virtual Network Connection with propagation to labels

[![3]][3]

vnet1 and vnet2 connections to the **hub1** <b><ins>with</ins></b> propagating to labels:

<pre>
Microsoft.Network/virtualHubs/<b>hub1</b>/hubVirtualNetworkConnections/<b>vnet1conn</b> 
associatedRouteTable: <b>RT_RED</b> 
propagatedRouteTables:
Propagating to labels: <b>red-lb</b>


Microsoft.Network/virtualHubs/<b>hub1</b>/hubVirtualNetworkConnections/<b>vnet2conn</b>
associatedRouteTable: <b>RT_BLUE</b>
propagatedRouteTables: 
Propagating to labels: <b>blue-lb</b>
</pre>

vnet3 and vnet4 connection to the **hub2** <b><ins>with</ins></b> propagating to labels:
<pre>
Microsoft.Network/virtualHubs/<b>hub2</b>/hubVirtualNetworkConnections/<b>vnet3conn</b> 
associatedRouteTable: <b>RT_RED</b> 
propagatedRouteTables:
Propagating to labels: <b>red-lb</b> 


Microsoft.Network/virtualHubs/<b>hub2</b>/hubVirtualNetworkConnections/<b>vnet4conn</b>
associatedRouteTable:  <b>RT_BLUE</b> 
propagatedRouteTables: 
Propagating to labels:  <b>blue-lb</b> 
</pre>


### <a name="without propagation to labels"></a>1.2 Virtual Network Connection without propagation to labels

[![4]][4]


vnet1 and vnet2 connections to the **hub1** <b><ins>without</ins></b> propagating to labels:
<pre>
Microsoft.Network/virtualHubs/<b>hub1</b>/hubVirtualNetworkConnections/<b>vnet1conn</b> 
associatedRouteTable: <b>RT_RED</b> 
propagatedRouteTables:{hub1: <b>RT_RED</b>
                       hub2: <b>RT_RED</b> }
Propagating to labels:


Microsoft.Network/virtualHubs/<b>hub1</b>/hubVirtualNetworkConnections/<b>vnet2_conn</b>
associatedRouteTable: <b>RT_BLUE</b>
propagatedRouteTables: {hub1: <b>RT_BLUE</b>
                        hub2: <b>RT_BLUE</b>}
Propagating to labels:
</pre>

vnet3 and vnet4 connections to the **hub2** <b><ins>without</ins></b> propagating to labels:
<pre>
Microsoft.Network/virtualHubs/hub2/hubVirtualNetworkConnections/vnet4conn
associatedRouteTable: <b>RT_RED</b> 
propagatedRouteTables:{hub1: <b>RT_RED</b>
                       hub2: <b>RT_RED</b> }
Propagating to labels:

Microsoft.Network/virtualHubs/hub2/hubVirtualNetworkConnections/vnet4conn
associatedRouteTable: <b>RT_BLUE</b>
propagatedRouteTables: {hub1: <b>RT_BLUE</b>
                        hub2: <b>RT_BLUE</b> }
Propagating to labels:
</pre>

<br>

## <a name="effective routes in virtual hubs"></a>2. Effective routes in the virtual hubs

Routing table <b>RT_RED</b> in virtual <b>hub1</b>: <br>
Microsoft.Network/virtualHubs/hub1/hubRouteTables/RT_RED

|Prefix 	 |Next Hop Type              |   Next Hop       | Origin 	     |AS path    |
| ---------- | ------------------------- | ---------------- | -------------- | --------- |
|10.0.1.0/24 |Virtual Network Connection |vnet1conn         |vnet1conn       |	         |
|10.0.3.0/24 |Remote Hub	             |hub2	            |hub2	         |65520-65520|

<br>
Routing table <b>RT_BLUE</b> in virtual <b>hub1</b>: <br>
Microsoft.Network/virtualHubs/<b>hub1</b>/hubRouteTables/<b>RT_BLUE</b>

|Prefix 	 |Next Hop Type              |   Next Hop       | Origin    	 |AS path    |
| ---------- | ------------------------- | ---------------- | -------------- | --------- |
|10.0.2.0/24 |Virtual Network Connection |vnet2conn         |vnet2conn       |	         |
|10.0.4.0/24 |Remote Hub	             |hub2	            |hub2	         |65520-65520|


<br>
Routing table <b>RT_RED</b> in virtual <b>hub2</b>:<br>
Microsoft.Network/virtualHubs/<b>hub2</b>/hubRouteTables/<b>RT_RED</b>

|Prefix 	 |Next Hop Type              |   Next Hop       | Origin 	     |AS path    |
| ---------- | ------------------------- | ---------------- | -------------- | --------- |
|10.0.1.0/24 |Remote Hub              	 |hub1              |hub1            |65520-65520|
|10.0.3.0/24 |Virtual Network Connection |vnet3conn         |vnet3conn       |           |


<br>
Routing table <b>RT_BLUE</b> in virtual <b>hub2</b>: <br>
Microsoft.Network/virtualHubs/<b>hub2</b>/hubRouteTables/<b>RT_BLUE</b>

|Prefix 	 |Next Hop Type              |   Next Hop       | Origin 	     |AS path    |
| ---------- | ------------------------- | ---------------- | -------------- | --------- |
|10.0.2.0/24 |Remote Hub	             |hub1              |hub1            |65520-65520|
|10.0.4.0/24 |Virtual Network Connection |vnet4conn         |vnet4conn       |           |


## <a name="List of files"></a>3. List of files 

| file                        | description                                                               |       
| --------------------------- |:------------------------------------------------------------------------- |
| **vwan-without-labels.json**| ARM template to create virtual WAN the virtual hubs, VNets, routing tables and connections between VNets and virtual hubs  |
| **vwan-without-labels.ps1** | powershell script to deploy the ARM template **vwan-without-labels.json** |
| **vwan-with-labels.json**   | ARM template to create virtual WAN the virtual hubs, VNets, routing tables and connections between VNets and virtual hubs. <br> The ARM template uses propagation with labels |
| **vwan-with-labels.ps1**    | powershell script to deploy the ARM template **vwan-with-labels.json**    |

<br>
 
Before spinning up the powershell scripts, **vwan-without-labels.ps1** and **vwan-with-labels.ps1**, you have to edit the file **init.json** and customize the values of variables:
The structure of **init.json** file is shown below:
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "subscriptionName": "NAME_AZURE_SUBSCRIPTION",
    "ResourceGroupName": "NAME_RESOURCE_GROUP",
    "hub1location": "northcentralus",
    "hub2location": "northcentralus",
    "locationBranch1": "northcentralus",
    "locationBranch2": "northcentralus",
    "hub1Name": "NAME_hub1",
    "hub2Name": "NAME_hub2",
    "mngIP": "MANAGEMENT_PUBLIC_IP_ADDRESS_TO_CONNECT_IN_SSH_TO_THE_VM"
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
- **hub1Name**: name of the virtual hub1
- **hub2Name**: name of the virtual hub2
- **mngIP**: public IP used to connect to the Azure VMs in SSH. By default is set to empty string.

<br>

`Tags: vWAN, Azre Virtual WAN, ARM templates` <br>
`testing date: 10-08-22`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram"
[3]: ./media/network-diagram3.png "network diagram"
[4]: ./media/network-diagram4.png "network diagram"

<!--Link References-->

