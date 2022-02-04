<properties
pageTitle= 'Virtual WAN: traffic branches to VNets with transit through an NVA'
description= "Virtual WAN: traffic branches to VNets with transit through an NVA"
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

## Virtual WAN: traffic branches to VNets with transit through an NVA

The article describes a virtual WAN configuration with spoke VNets (vnet1, vnet2, vnet3, vnet4) and two branches (branch1, brnach2) connected in site-to-site VPN to the virtual hub1. In vnet1 is deployed an NVA (vm1). Below the network diagram:

[![1]][1]

**Design**
* Virtual networks to branches (V2B) traffic is routed through the virtual appliace (NVA)
* VNet to VNet (V2V) traffic doesn't transit through NVA
* Branch to branch (B2B) traffic doesn't transit through NVA

### Setup
* the connection to **vnet1** is associated with routing table **RT_NVA** and propagated to the hub routing tables **RT_VNET**,**defaultRouteTable** 
* che connection to **vnet2** is associated with routing table **RT_VNET** and propagated to the hub routing table **RT_VNET**,**RT_NVA**
* the connection to **vnet3** is associated with routing table **RT_VNET** and propagated to the hub routing table **RT_VNET**,**RT_NVA**
* the connection to **vnet4** is associated with routing table **RT_VNET** and propagated to the hub routing table **RT_VNET**,**RT_NVA**

| Routing Configuration of  vnet1conn     || 
| -------------------- |:---------------- | 
| associatedRouteTable | RT_NVA           | 
| propagatedRouteTable | default, RT_VNET | 
<br>

| Routing Configuration of vnetconn2, vnetconn3, vnetconn4 || 
| -------------------- |:---------------- | 
| associatedRouteTable | RT_VNET          | 
| propagatedRouteTable | RT_VNET, RT_NVA  | 
<br>

| Routing Configuration of VPN connections || 
| -------------------- |:---------------- | 
| associatedRouteTable | defaultRouteTable| 
| propagatedRouteTable | defaultRouteTable, RT_NVA | 
<br>

The routing table **RT_NVA**, **RT_VNET**, **defaultRouteTable** do not communicate. To establish a communication are required static routes in each routing table:

* Static routes configured on NVA VNet Connection **vnet1conn**:

| Route name  | Destination type | Destination Prefix | Next Hop  |
| ----------- |:---------------- | ------------------ | --------- |
| RT_V2B1     | CIDR             | 192.168.1.0/24     |10.1.0.4   |
| RT_V2B2     | CIDR             | 192.168.1.0/24     |10.1.0.4   |
| RT_B2V      | CIDR             | 10.0.0.0/16        |10.1.0.4   |
<br>

* static routes added to the routing table **RT_VNET**:

| Route name  | Destination type | Destination Prefix | Next Hop     |
| ----------- |:---------------- | ------------------ | ------------ |
| RT_V2B      | CIDR             | 192.168.0.0/16     |vnet1conn     |

<br>

* static routes added to the routing table **defaultRouteTable**:

| Route name  | Destination type | Destination Prefix | Next Hop     |
| ----------- |:---------------- | ------------------ | ------------ |
| RT_B2V      | CIDR             | 10.0.0.0/16        |vnet1conn     |

<br>

The diagram shows the routing tables and connections:

[![2]][2]


### <a name="List of files"></a>1. List of files 

| file                        | description                                                    |       
| ---------------------- |:------------------------------------------------------------------- |
| **init.json**          | file with the value of variables used across the ARM templates      |
| **00-keyvault.json**   | Keyvault to store username and password to access to the VMs        |
| **00-keyvault.ps1**    | powershell script to deploy the ARM template **00-keyvault.json**   |
| **01-vwan.json**       | ARM template to create virtual WAN the virtual hub, VNets, routing tables, connections between VNets and virtual hubs and VMs |
| **01-vwan.ps1**        | powershell script to deploy the ARM template **01-vwan.json**        |
| **02-vpn.json**        | ARM template to create branch1 and branch2                           |
| **02-vpn.ps1**         | powershell script to deploy the ARM template **02-vpn.json**         |
| **03-vwan-site.json**  | ARM template to create sites connection and site link with branch1 and branch2  |
| **03-vwan-site.ps1**   | powershell script to deploy the ARM template **03-vwan-site.json**   |
<br>
 
Before spinning up the powershell scripts, you should edit the file **init.json** and customize the values of variables in use across all the ARM templates.

<br>

Meaning of the variables:
- **subscriptionName**: Azure subscription name
- **ResourceGroupName**: name of the resouce group
- **keyVaultName**: name of the keyvault used to store administrator username and administrator password of the VMs
- **keyVaultAccessPoliciesObjectId**: AAD_OBJECT_ID (i.e. AAD username object Id) to access to keyvault secrets
- **vwanName**: name of the virtual WAN
- **hub1location**: Azure region of the virtual hub1
- **hub1Name**: name of the virtual hub1
- **branch1location**: branch1 name
- **branch2location**: branch2 name
- **ResourceGroupNameBranch**: name of the resource group of where are deployed the branch1 and branch2 (it can be the same of **ResourceGroupName** if you want to deploy branch1 and branch2 in the same resource group of vWAN) 
- **sharedKey**: shared dkey of site-to-site VPN 
- **mngIP**: public IP used to connect to the Azure VMs in SSH
- **adminUsername**: administrator username of the Azure VMs
- **adminPassword**: administrator password of the Azure VMs
- **RGTagExpireDate**: tag assigned to the resource group. It is used to track the expiration date of the deployment in testing.
- **RGTagContact**: tag assigned to the resource group. It is used to email to the owner of th deployment
- **RGTagNinja**: alias of the user
- **RGTagUsage**: short description of the deployment purpose


<br>





<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram"


<!--Link References-->

