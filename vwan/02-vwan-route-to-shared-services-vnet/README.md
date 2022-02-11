<properties
pageTitle= 'Virtual WAN: route to shared services VNet'
description= "Virtual WAN: route to shared services VNet"
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

# Virtual WAN: route to shared services VNet
This article describes a configuration with VNets connected to two virtual hub, hub1 and hub2.
The goal is to set up routes to access from VNets and branches to the **shared service VNet**, vnet1.
<br> 

Below the network diagram:

[![1]][1]

The configuration can be described with the following matrix of communications:
* the branch1 is connected with hub1 with site-to-site connection; the branch1 communicates with all the VNets and with the branch2
* the branch2 is connected with hub2 with site-to-site connection; the branch2 communicates with all the VNets and with the branch1
* vnet1 (shared service VNet) can communicate with all other VNets (vnet2, vnet3, vnet4) and with the branches (branch1 and branch2)
* vnet2 can communicate with vnet1 (shared service vnet) and with all the branches
* vnet3 can communicate with vnet1 (shared service vnet) and with all the branches
* vnet4 can communicate with vnet1 (shared service vnet) and with all the branches
* vnet2, vnet2,vnet4 are in isolation

[![2]][2]


<br>

A network diagram with more details is reported below:

[![3]][3]




## <a name="routing table association"></a>1. Connection <ins>with</ins> propagation to labels 
The network diagram below shows the association and propagation to labels **default**, **LBL_SHARED**:

[![4]][4]

<br>

The network diagram below shows more details in the association and propagation of connections in hub1 and hub2, with propagation to labels **default**, **LBL_SHARED**:
[![5]][5]
[![6]][6]

## <a name="routing table association"></a>2. Connection <ins>without</ins> propagation to labels 

Two routing tables are required to implement the configuration: **defaultRoutingTable** and **RT_SHARED**
* Isolated virtual networks (vnet2, vnet3,vnet4):
   * Associated route table: **RT_SHARED**
   * Propagated route table: **defaultRoutingTable**
* Shared services virtual network (vnet1):
   * Associated route table: **defaultRoutingTable**
   * Propagated route table: **defaultRoutingTable**, **RT_SHARED**  
* Branches (branch1 and branch2):
   * Associated route table: **defaultRoutingTable**
   * Propagating to route tables: **defaultRoutingTable**, **RT_SHARED**

The branches always must be associated to the **DefaultRoutingTable**.
All the VNets, except the shared services VNet, are associated with the **RT_SHARED**. This will imply that all these VNets (except the shared services VNet) will be able to reach destination based on the routes of **RT_SHARED** route table.

Based on the configuration described above:
- the Shared services virtual network (vnet1) propagates his network in the routing table **RT_SHARED**
- The branches (branch1, branch2) propagate their networks to the routing table **RT_SHARED**
then the **RT_SHARED** route table will learn routes from all branch connections and from the shared VNet (vnet1)

<br>

The network diagrams below shows the association and propagation of connections, without propagation to labels:


[![7]][7]

<br>

[![8]][8]

[![9]][9]

## <a name="Routing tables"></a>3. Routing tables in hub1
The branch1 advertises his network through BGP to the hub1 by AS 65010.
The network of the branch2 is advertised through BGP to the hub2 by AS 65011.
Each virtual hub advertised the learned routes to the peer hub through BGP by AS65520.

**routing tables in hub1**
| Name       | Provisioning State | Labels          | Associated connections | Propagating connections |
| ---------- | ------------------ | --------------- | ---------------------- | ----------------------- |
| Default    | Succeeded          | default         | 2                      | 3                       |
| RT\_Shared | Succeeded          | LBL\_RT\_SHARED | 1                      | 2                       |

**defaultRouteTable in hub1**
| Prefix         | Next Hop Type              | Next Hop       | Origin         | AS path           |
| -------------- | -------------------------- | -------------- | -------------- | ----------------- |
| 192.168.1.0/24 | VPN\_S2S\_Gateway          | hub1\_S2SvpnGW | hub1\_S2SvpnGW | 65010             |
| 10.0.2.0/24    | Virtual Network Connection | vnet2\_conn    | vnet2\_conn    |                   |
| 10.0.1.0/24    | Virtual Network Connection | vnet1\_conn    | vnet1\_conn    |                   |
| 192.168.2.0/24 | Remote Hub                 | hub2           | hub2           | 65520-65520-65011 |
| 10.0.3.0/24    | Remote Hub                 | hub2           | hub2           | 65520-65520       |
| 10.0.4.0/24    | Remote Hub                 | hub2           | hub2           | 65520-65520       |

<br>

**RT_SHARED in hub1**
| Prefix         | Next Hop Type              | Next Hop       | Origin         | AS path           |
| -------------- | -------------------------- | -------------- | -------------- | ----------------- |
| 192.168.1.0/24 | VPN\_S2S\_Gateway          | hub1\_S2SvpnGW | hub1\_S2SvpnGW | 65010             |
| 10.0.1.0/24    | Virtual Network Connection | vnet1\_conn    | vnet1\_conn    |                   |
| 192.168.2.0/24 | Remote Hub                 | hub2           | hub2           | 65520-65520-65011 |
<br>

## <a name="Routing tables"></a>4. Routing tables in hub2

**Routing tables in hub2**
| Name       | Provisioning State | Labels          | Associated connections | Propagating connections |
| ---------- | ------------------ | --------------- | ---------------------- | ----------------------- |
| Default    | Succeeded          | default         | 1                      | 3                       |
| RT\_Shared | Succeeded          | LBL\_RT\_SHARED | 2                      | 1                       |
<br>

**DefaultRouteTable in hub2**
| Prefix         | Next Hop Type              | Next Hop       | Origin         | AS path           |
| -------------- | -------------------------- | -------------- | -------------- | ----------------- |
| 192.168.2.0/24 | VPN\_S2S\_Gateway          | hub2\_S2SvpnGW | hub2\_S2SvpnGW | 65011             |
| 10.0.3.0/24    | Virtual Network Connection | vnet3\_conn    | vnet3\_conn    |                   |
| 10.0.4.0/24    | Virtual Network Connection | vnet4\_conn    | vnet4\_conn    |                   |
| 192.168.1.0/24 | Remote Hub                 | hub1           | hub1           | 65520-65520-65010 |
| 10.0.1.0/24    | Remote Hub                 | hub1           | hub1           | 65520-65520       |
| 10.0.2.0/24    | Remote Hub                 | hub1           | hub1           | 65520-65520       |



## <a name="list of ARM templates and scripts"></a>5. List of ARM templates and powershell scripts
The full deployment can be executed by ARM templates and scripts are stored in two different folders:
* folder: **without-propagation-to-labels**. This folder contains a list of script and ARM templates; the connections are created <ins>without propagation to labels </ins>. Each connection requires a propagation to routing tables in hub1 and hub2.
* folder: **propagation-to-labels**. This folder uses <ins>propagation to labels</ins> to simply the propagation of connections.

<br>

To create the deployment, use all the scripts in **without-propagation-to-labels** folder OR as alternative option the scripts in the folder **propagation-to-labels**.   

| file                        | description                                                               |       
| --------------------------- |:------------------------------------------------------------------------- |
| **01-vwan.json**            | ARM template to create virtual WAN the virtual hubs, VNets, routing tables and connections between VNets and virtual hubs  |
| **01-vwan.ps1**             | powershell script to deploy the ARM template **01-vwan.json**             |
| **02-vpn.json**             | ARM template to create the remote branch1<br> The ARM template create the vnet, VPN gateway and VM in the branch1 and branch2 |
| **02-vpn.ps1**              | powershell script to deploy the ARM template **02-vpn.json**              |
| **03-vwan-site.json**       | create in the hub1 a site-to-site connection to the branch1 and site-to-site connection to the branch2  |
| **03-vwan-site.ps1**        | powershell script to deploy the ARM template **03-vwan-site.json**        |
| **init.json**               | it contains a list of input variables. <br>All the powershell scripts read the init.json to assign the variables values|

Before spinning up the powershell scripts, you should edit the file **init.json** and customize the values:
The structure of **init.json** file is shown below:
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "subscriptionName": "AzureDemo",
    "ResourceGroupName": "rg-wan1",
    "hub1location": "westus2",
    "hub2location": "westus2",
    "branch1location": "westus2",
    "branch2location": "westus2",
    "hub1Name": "hub1",
    "hub2Name": "hub2",
    "sharedKey": "VPN_SHARED_SECRET",
    "mngIP": "MANAGEMENT_PUBLIC_IP_ADDRESS",
    "RGTagExpireDate": "09/30/2021",
    "RGTagContact": "user1@contoso.com",
    "RGTagNinja": "user1",
    "RGTagUsage": "vWAN: route to shared services VNet"
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
- **RGTagExpireDate**: tag assigned to the resource group. It is used to track the expiration date of the deployment in testing.
- **RGTagContact**: tag assigned to the resource group. It is used to email to the owner of the deployment
- **RGTagNinja**: alias of the user
- **RGTagUsage**: short description of the deployment purpose

The file **init.json** guarantees a consistency by assignment of same values of input parameters across all the ARM templates.
<br>

## <a name="how to run the deployment"></a>6. How to run the deployment
Deployment needs to be carried out in sequence:
- _1st step_: customize the values in **init.json**
- _2nd step_: run the script **01-vwan.ps1**
- _3rd step_: run the script **02-vpn.ps1**
- _4th step_: run the script **03-vwan-site.ps1**

## <a name="example of connection with propagation to labels"></a>7. ARM template snippets with propagation of connection to labels
Connection for the vnet1 with propagation to the labels **LBL_RT_SHARED**, **default**
```json
{
   "type": "Microsoft.Network/virtualHubs/hubVirtualNetworkConnections",
   "name": "hub1/vnet1conn",
   "apiVersion": "2021-02-01",
   "dependsOn": [
         "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', variables('hub1Name'), 'defaultRouteTable')]",
         "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', variables('hub1Name'), 'RT_SHARED')]",
   ],
   "properties": {
      "routingConfiguration": {
            "associatedRouteTable": {
               "id": "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables','hub1', 'defaultRouteTable')]"
            },
            "propagatedRouteTables": {
               "ids": [],
               "labels": [
                     "LBL_RT_SHARED",
                     "default"
               ]
            }
         },
         "remoteVirtualNetwork": {
            "id": "[resourceId('Microsoft.Network/virtualNetworks', 'vnet1')]"
         }
   }
}
```

Connection for the vnet4 with propagation to the label **default**:
```json
{
   "type": "Microsoft.Network/virtualHubs/hubVirtualNetworkConnections",
   "apiVersion": "2021-02-01",
   "name": "hub2/vnet4conn",
   "dependsOn": [
         "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', 'hub2', 'defaultRouteTable')]",
         "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', 'hub2', 'RT_SHARED')]",
   ],
   "properties": {
         "routingConfiguration": {
            "associatedRouteTable": {
               "id": "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', 'hub2', 'RT_SHARED')]"
            },
            "propagatedRouteTables": {
               "ids": [],
               "labels": [
                     "default"
               ]
            }
         },
         "remoteVirtualNetwork": {
            "id": "[resourceId('Microsoft.Network/virtualNetworks', 'vnet4'))]"
         }
   }
}
```

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "communications"
[3]: ./media/network-diagram3.png "network diagram"
[4]: ./media/network-diagram4.png "network diagram"
[5]: ./media/network-diagram5.png "network diagram"
[6]: ./media/network-diagram6.png "routing tables"
[7]: ./media/network-diagram7.png "routing tables"
[8]: ./media/network-diagram8.png "routing tables"
[9]: ./media/network-diagram9.png "routing tables"

<!--Link References-->

