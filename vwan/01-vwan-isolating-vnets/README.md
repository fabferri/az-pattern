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

## Virtual WAN: simple configuration with isolating VNets

The article reports a virtual WAN configuration with spoke VNets connected to two virtual hubs. The configuration establishes a selective interconnection between spoke VNets. Only spoke VNets belonging to the same group can communicate each other. This configuration is known as **isolating VNets**. Below the network diagram:

[![1]][1]

The VNet1 and VNet3 are connected to the different virtual hubs and associated with the same routing table named **red**
<br>

The vNet2 and VNet4 are connected to the different hubs and associated with the same routing table named **blue**
<br>
The allow communications:
- VNet1 and VNet3 can communicate
- VNet2 and VNet4 can communicate
<br>

The following communications are denied:
- VNet1 can't communicate with VNet2 
- VNet1 can't communicate with VNet4 
- VNet2 can't communicate with VNet3
- VNet3 can't communicate with VNet4
<br>

The diagram below shows the selective interconnections between VNets:

[![2]][2]


### <a name="List of files"></a>1. List of files 

| file                        | description                                                               |       
| --------------------------- |:------------------------------------------------------------------------- |
| **vwan-without-labels.json**| ARM template to create virtual WAN the virtual hubs, VNets, routing tables and connections between VNets and virtual hubs  |
| **vwan-without-labels.ps1** | powershell script to deploy the ARM template **vwan-without-labels.json** |
| **vwan-with-labels.json**   | ARM template to create virtual WAN the virtual hubs, VNets, routing tables and connections between VNets and virtual hubs. <br> The ARM template uses propagation with labels |
| **vwan-with-labels.ps1**    | powershell script to deploy the ARM template **vwan-with-labels.json**    |

<br>
 
Before spinning up the powershell scripts, **vwan-without-labels.ps1** and **vwan-with-labels.ps1**, you should edit the file **init.json** and customize the values:
The structure of **init.json** file is shown below:
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "subscriptionName": "AzureDemo",
    "ResourceGroupName": "vwan1-grp",
    "hub1_location": "northcentralus",
    "hub2_location": "northcentralus",
    "locationBranch1": "northcentralus",
    "locationBranch2": "northcentralus",
    "hub1Name": "hub1",
    "hub2Name": "hub2",
    "mngIP": "MANAGEMENT_PUBLIC_IP_ADDRESS",
    "RGTagExpireDate": "09/30/2021",
    "RGTagContact": "user1@contoso.com",
    "RGTagNinja": "user1",
    "RGTagUsage": "vWAN-basic configuration with isolating VNets"
}
```
<br>

Meaning of the variables:
- **adminUsername**: administrator username of the Azure VMs
- **adminPassword**: administrator password of the Azure VMs
- **subscriptionName**: Azure subscription name
- **ResourceGroupName**: name of the resouce group
- **hub1_location**: Azure region of the virtual hub1
- **hub2_location**: Azure region of the virtual hub2
- **hub1Name**: name of the virtual hub1
- **hub2Name**: name of the virtual hub2
- **mngIP**: public IP used to connect to the Azure VMs in SSH
- **RGTagExpireDate**: tag assigned to the resource group. It is used to track the expiration date of the deployment in testing.
- **RGTagContact**: tag assigned to the resource group. It is used to email to the owner of th deployment
- **RGTagNinja**: alias of the user
- **RGTagUsage**: short description of the deployment purpose


<br>

### <a name="routing table association"></a>2. Virtual Hubs Routing Tables
Two routing tables are required to implement the configuration: **red** and **blue**
* virtual networks vnet1, vnet3:
   * Associated route table: **red**
   * Propagated route table: **red**
* virtual networks vnet2, vnet4:
   * Associated route table: **blue**
   * Propagated route table: **blue**  

Target configuration can be achieved with two different approach: 
- without propagation to labels
- with propagation to labels

### <a name="without propagation to labels"></a>3. Virtual Network Connection without propagation to labels

[![3]][3]


Connection of vnet1 and vnet2 to the **hub1** without propagating to labels:
<pre>
Microsoft.Network/virtualHubs/<b>hub1</b>/hubVirtualNetworkConnections/<font color='red'><b>vnet1_conn</b></font> 
associatedRouteTable: <font color='red'><b>red</b></font> 
propagatedRouteTables:{hub1-> <font color='red'><b>red</b></font>
                       hub2-> <font color='red'><b>red</b></font> }
Propagating to labels:


Microsoft.Network/virtualHubs/<b>hub1</b>/hubVirtualNetworkConnections/<font color='blue'><b>vnet2_conn</b></font>
associatedRouteTable: <font color='blue'>blue</font>
propagatedRouteTables: {hub1 -> <font color='blue'><b>blue</b></font>
                        hub2 -> <font color='blue'><b>blue</b></font> }
Propagating to labels:
</pre>

Connection of vnet3 and vnet4 to the **hub2** without propagating to labels:
<pre>
Microsoft.Network/virtualHubs/<b>hub2</b>/hubVirtualNetworkConnections/<font color='red'><b>vnet3_conn</b></font> 
associatedRouteTable: <font color='red'><b>red</b></font> 
propagatedRouteTables:{hub1-> <font color='red'><b>red</b></font>
                       hub2-> <font color='red'><b>red</b></font> }
Propagating to labels:


Microsoft.Network/virtualHubs/<b>hub2</b>/hubVirtualNetworkConnections/<font color='blue'><b>vnet4_conn</b></font>
associatedRouteTable: <font color='blue'><b>blue</b></font>
propagatedRouteTables: {hub1 -> <font color='blue'><b>blue</b></font>
                        hub2 -> <font color='blue'><b>blue</b></font> }
Propagating to labels:
</pre>

<br>


Routing table <font color='red'><b>red</b></font> in virtual <b>hub1</b>:<br>
Microsoft.Network/virtualHubs/<b>hub1</b>/hubRouteTables/<font color='red'><b>red</b></font>

|Prefix 	    |Next Hop Type              |   Next Hop       | Origin 	    |AS path    |
| ------------- | ------------------------- | ---------------- | -------------- | --------- |
|10.0.1.0/24	|Virtual Network Connection	|vnet1_connection  |vnet1_connection|	        |
|10.0.3.0/24	|Remote Hub	                |hub2	           |hub2	        |65520-65520|

<br>
Routing table <font color='blue'><b>blue</b></font> in virtual <b>hub1</b>: <br>
Microsoft.Network/virtualHubs/<b>hub1</b>/hubRouteTables/<font color='blue'><b>blue</b></font>

|Prefix 	    |Next Hop Type              |   Next Hop       | Origin 	    |AS path    |
| ------------- | ------------------------- | ---------------- | -------------- | --------- |
|10.0.2.0/24	|Virtual Network Connection	|vnet2_connection  |vnet2_connection|	        |
|10.0.4.0/24	|Remote Hub	                |hub2	           |hub2	        |65520-65520|


<br>
Routing table <font color='red'><b>red</b></font> in virtual <b>hub2</b>:<br>
Microsoft.Network/virtualHubs/<b>hub2</b>/hubRouteTables/<font color='red'><b>red</b></font>

|Prefix 	    |Next Hop Type              |   Next Hop       | Origin 	    |AS path    |
| ------------- | ------------------------- | ---------------- | -------------- | --------- |
|10.0.1.0/24	|Remote Hub              	|hub1              |hub1            |65520-65520|
|10.0.3.0/24	|Virtual Network Connection	|vnet3_connection  |vnet3_connection|           |


<br>
Routing table <font color='blue'><b>blue</b></font> in virtual <b>hub2</b>: <br>
Microsoft.Network/virtualHubs/<b>hub2</b>/hubRouteTables/<font color='blue'><b>blue</b></font>

|Prefix 	    |Next Hop Type              |   Next Hop       | Origin 	    |AS path    |
| ------------- | ------------------------- | ---------------- | -------------- | --------- |
|10.0.2.0/24	|Remote Hub	                |hub1              |hub1            |65520-65520|
|10.0.4.0/24	|Virtual Network Connection	|vnet4_connection  |vnet4_connection|           |


### <a name="with propagation to labels"></a>4. Virtual Network Connection with propagation to labels

Connection of vnet1 and vnet2 to the **hub1** without propagating to labels:

<pre>
Microsoft.Network/virtualHubs/<b>hub1</b>/hubVirtualNetworkConnections/<font color='red'><b>vnet1_conn</b></font> 
associatedRouteTable: <font color='red'><b>red</b></font> 
propagatedRouteTables:{hub1-> <font color='red'><b>red</b></font> }
Propagating to labels: <font color='red'><b>lbl-red</b></font>


Microsoft.Network/virtualHubs/<b>hub1</b>/hubVirtualNetworkConnections/<font color='blue'><b>vnet2_conn</b></font>
associatedRouteTable: <font color='blue'>blue</font>
propagatedRouteTables: {hub1 -> <font color='blue'><b>blue</b></font> }
Propagating to labels: <font color='blue'><b>lbl-blue</b></font>
</pre>

Connection of vnet3 and vnet4 to the **hub2** without propagating to labels:
<pre>
Microsoft.Network/virtualHubs/<b>hub2</b>/hubVirtualNetworkConnections/<font color='red'><b>vnet3_conn</b></font> 
associatedRouteTable: <font color='red'><b>red</b></font> 
propagatedRouteTables:{ hub2-> <font color='red'><b>red</b></font> }
Propagating to labels: <font color='red'><b>lbl-red</b></font> 


Microsoft.Network/virtualHubs/<b>hub2</b>/hubVirtualNetworkConnections/<font color='blue'><b>vnet4_conn</b></font>
associatedRouteTable: <font color='blue'><b>blue</b></font>
propagatedRouteTables: { hub2 -> <font color='blue'><b>blue</b></font> }
Propagating to labels:  <font color='red'><b>lbl-blue</b></font> 
</pre>



<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram"
[3]: ./media/network-diagram3.png "network diagram"

<!--Link References-->

