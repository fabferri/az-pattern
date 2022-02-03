<properties
pageTitle= 'Virtual WAN: VNet to VNet with transit through Azure firewall'
description= "Virtual WAN: V2V with transit through Azure firewall"
documentationcenter: na
services=""
documentationCenter="github repository"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service = "configuration-Example-Azure-Virtual WAN"
   ms.devlang = "na"
   ms.topic = "article"
   ms.tgt_pltfrm = "Azure"
   ms.workload = "Virtual WAN"
   ms.date = "03/02/2022"
   ms.author="fabferri" />

## Virtual WAN: VNet to VNet (V2V) with transit through Azure firewall

The article describes a virtual WAN configuration with spoke VNets connected to a Secure Virtual Hub (Virtual Hub with Azure firewall). The configuration establishes a selective communication between spoke VNets vnet1,vnet2, vnet3 across the Azure firewall. Below the network diagram:

[![1]][1]

**Design**
* **vnet1** is associated with routing table **RT_VNET1** and propagated to the hub routing table **RT_VNET1**
* **vnet2** is associated with routing table **RT_VNET1** and propagated to the hub routing table **RT_VNET2**
* **vnet3** is associated with routing table **RT_VNET3** and propagated to the hub routing table **RT_VNET3**
<br>

The routing table **RT_VNET1**, **RT_VNET2**, **RT_VNET3** do not communicate. To establish a communication are required static routes in each routing table:

* static routes added to the routing table **RT_VNET1**:

| Route name  | Destination type | Destination Prefix | Next Hop     |
| ----------- |:---------------- | ------------------ | ------------ |
| RT_2vnet2   | CIDR             | 10.0.2.0/24        |azfirewall Id |
| RT_2vnet3   | CIDR             | 10.0.3.0/24        |azfirewall Id |
<br>

* static routes added to the routing table **RT_VNET2**:

| Route name  | Destination type | Destination Prefix | Next Hop     |
| ----------- |:---------------- | ------------------ | ------------ |
| RT_2vnet1   | CIDR             | 10.0.1.0/24        |azfirewall Id |
| RT_2vnet3   | CIDR             | 10.0.3.0/24        |azfirewall Id |
<br>

* static routes added to the routing table **RT_VNET3**:

| Route name  | Destination type | Destination Prefix | Next Hop     |
| ----------- |:---------------- | ------------------ | ------------ |
| RT_2vnet1   | CIDR             | 10.0.1.0/24        |azfirewall Id |
| RT_2vnet2   | CIDR             | 10.0.2.0/24        |azfirewall Id |
<br>

The diagram shows the routing tables and connections:

[![2]][2]


### <a name="List of files"></a>1. List of files 

| file                        | description                                                               |       
| --------------------------- |:------------------------------------------------------------------------- |
| **vwan-firewall.json**      | ARM template to create virtual WAN the virtual hub, VNets, routing tables, connections between VNets and virtual hubs and Azure firewall |
| **vwan-firewall.json**      | powershell script to deploy the ARM template **vwan-firewall.json**         |
| **init.json**               | file with the value of variables used in the template **vwan-firewall.json**|


<br>
 
Before spinning up the powershell scripts, **vwan-without-labels.ps1** and **vwan-with-labels.ps1**, you should edit the file **init.json** and customize the values:
The structure of **init.json** file is shown below:
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "subscriptionName": "AzureDemo",
    "ResourceGroupName": "vwan1-grp",
    "hub1location": "westus2",
    "vwanName": "vwan3",
    "hub1Name": "hub1",
    "mngIP": "MANAGEMENT_PUBLIC_IP_ADDRESS",
    "RGTagExpireDate": "04/29/2022",
    "RGTagContact": "user1@contoso.com",
    "RGTagNinja": "user1",
    "RGTagUsage": "test vWAN: V2V with transit through azure firewall"
}
```
<br>

Meaning of the variables:
- **adminUsername**: administrator username of the Azure VMs
- **adminPassword**: administrator password of the Azure VMs
- **subscriptionName**: Azure subscription name
- **ResourceGroupName**: name of the resouce group
- **vwanName**: name of the virtual WAN
- **hub1location**: Azure region of the virtual hub1
- **hub1Name**: name of the virtual hub1
- **mngIP**: public IP used to connect to the Azure VMs in SSH
- **RGTagExpireDate**: tag assigned to the resource group. It is used to track the expiration date of the deployment in testing.
- **RGTagContact**: tag assigned to the resource group. It is used to email to the owner of th deployment
- **RGTagNinja**: alias of the user
- **RGTagUsage**: short description of the deployment purpose


<br>





<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram"


<!--Link References-->

