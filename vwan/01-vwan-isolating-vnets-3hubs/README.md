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

# Virtual WAN: configuration with isolating VNets

The article walks through a virtual WAN configuration with spoke VNets connected to three virtual hubs hub1, hub2 and hub3. The configuration establishes a selective interconnection between spoke VNets. The connection to vnet5 (**vnet5conn**) is propagated to . This configuration is known as **isolating VNets**. Below the network diagram:

[![1]][1]


## <a name="design"></a>1. Design
The goal is to establish the folling communication:
- **vnet1** can communicate with **vnet3** and **vnet5**
- **vnet2** can communicate with **vnet4** and **vnet5**
- **vnet5** can communicate with **vnet1**,**vnet2**,**vnet3** and **vnet4**

[![2]][2]


## <a name="implementation"></a>1. Implementation
- In the virtual hub1 are defined the routing tables **RT1_RED**, **RT1_BLUE**
- In the virtual hub2 are defined the routing tables **RT2_RED**, **RT2_BLUE**
- In the virtual hub3 is defined the routing tables **RT3_BLUERED**
- the connection hub1 to the vnet1 **vnet1conn** is propagated to the label **red-lb** 
- the connection hub1 to the vnet2 **vnet2conn** is propagated to the label **blue-lb** 
- the connection hub2 to the vnet3 **vnet3conn** is propagated to the label **red-lb** 
- the connection hub2 to the vnet4 **vnet4conn** is propagated to the label **blue-lb** 
- the connection hub3 to the vnet5 **vnet5conn** is propagated to the label **red-lb**, **blue-lb** 
<br>


[![3]][3]

## <a name="Effective routes in hub3"></a>2. Effective routes in RT3_BLUERED 

| Prefix      | Next Hop Type              | Next Hop  | Origin    | AS path     |
| ----------- | -------------------------- | --------- | --------- | ----------- |
| 10.0.5.0/24 | Virtual Network Connection | vnet5conn | vnet5conn |             |
| 10.0.1.0/24 | Remote Hub                 | hub1      | hub1      | 65520-65520 |
| 10.0.2.0/24 | Remote Hub                 | hub1      | hub1      | 65520-65520 |
| 10.0.3.0/24 | Remote Hub                 | hub2      | hub2      | 65520-65520 |
| 10.0.4.0/24 | Remote Hub                 | hub2      | hub2      | 65520-65520 |

## <a name="List of files"></a>3. List of files 

| file                         | description                                                                   |       
| ---------------------------- |:----------------------------------------------------------------------------- |
| **vwan-isolating-vnets.json**| ARM template to create virtual WAN hubs, routing tables and connections between VNets and virtual hubs         |
| **vwan-isolating-vnets.ps1** | powershell script to deploy the ARM template **vwan-isolating-vnets.json**    |
| **init.json**                | values of variables used in the ARM template  **vwan-isolating-vnets.json**   |

<br>
 
Before spinning up the powershell scripts, **vwan-isolating-vnets.json**, you have to edit the file **init.json** and customize the values of variables:
The structure of **init.json** file is shown below:
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "subscriptionName": "NAME_AZURE_SUBSCRIPTION",
    "ResourceGroupName": "NAME_RESOURCE_GROUP",
    "hub1location": "AZURE_LOCATION_HUB1",
    "hub2location": "AZURE_LOCATION_HUB2",
    "hub3location": "AZURE_LOCATION_HUB3",
    "hub1Name": "NAME_Virtual_hub1",
    "hub2Name": "NAME_Virtual_hub2",
    "hub3Name": "NAME_Virtual_hub2",
    "mngIP": "MANAGEMENT_PUBLIC_IP_ADDRESS_TO_CONNECT_IN_SSH_TO_THE_VM",
    "RGTagExpireDate": "09/30/2021",
    "RGTagContact": "user1@contoso.com",
    "RGTagNinja": "user1",
    "RGTagUsage": "vWAN-basic configuration with isolating VNets"
}
```
<br>

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram"
[3]: ./media/network-diagram3.png "network diagram"

<!--Link References-->

