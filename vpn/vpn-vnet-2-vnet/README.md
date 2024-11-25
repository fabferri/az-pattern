<properties
pageTitle= 'Multiple VNet-to-VNet connections with VPN Gateways in a partial mesh configuration'
description= "Multiple VNet-to-VNet connections with VPN Gateways in a partial mesh configuration"
services="Azure VPN Gateway"
documentationCenter="[na](https://github.com/fabferri)"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="Azure VPN Gateway"
   ms.date="25/11/2025"
   ms.author="fabferri" />

# Multiple VNet-to-VNet connections with VPN Gateways in a Partial Mesh configuration
This ARM template creates multiple VNet-to-VNet connections using VPN Gateways. The intercommunication between VNets is based on IPsec tunnels. <br>
The network configuration is illustrated in the diagram:

[![1]][1]

## Key Points:
- the Azure VPN Gateway vpnGtw1 is created in vnet1 and configured in active-active mode, with BGP enabled
- each VPN Gateway has a different ASN
- each VPN Gateway re-advertised the network learnt from other a VPN Gateway to the other VPN Gateway; in this way there is a full mesh of communication between all the vnets. 
- the vnet1 and vnet2 work as hub vnet: the traffic between vnet3,vnet4,vnet5,vnet6,vnet7 pass through the vnet1 and vnet2
- vnet1 adn vnet2 are connected by vnet-to-vnet connections
- The ARM templates works with arrays:
   - **vNetArray**: it is an array wih all VNets, inclusive of GatewaySubnet, VPN gateway name, ASN and SKU of VPN Gateway
   - **vpnConnectionArray**: includes the list of all connections. For example, a single VNet-to-VNet is based on two connections:
       - connection for **vnet1-to-vnet2**
       - connection for **vnet2-to-vnet1**

> [!NOTE]
>
> - You can increase the number of VNets changing the structure of the arrays: **vNetArray**, **vpnConnectionArray**
> - If the ARM template fails to create connections due to contention from creating multiple parallel connections on the same gateway, remove the failed connections and then rerun the ARM template.
> 

Before deploying the ARM template customize the value of your variables in the **init.txt** file:
`subscriptionName` = AZURE_SUBSCRIPTION_NAME <br>
`ResourceGroupName` = RESOURCE_GROUP_NAME <br>
`location1` = AZURE_REGION_1 <br>
`location2` = AZURE_REGION_2 <br>
`location3` = AZURE_REGION_3 <br>
`location4` = AZURE_REGION_4 <br>
`location5` = AZURE_REGION_5 <br>
`location6` = AZURE_REGION_6 <br>
`location7` = AZURE_REGION_7 <br>
`adminUsername` = ADMINISTRATOR_USERNAME <br>
`adminPassword` = ADMINISTRATOR_PASSWORD <br>


### Effetive route tables in the vm1:

[![2]][2]

### Effetive route tables in the vm2:

[![3]][3]

### Effetive route tables in the vm3:

[![4]][4]

### Effetive route tables in the vm4:

[![5]][5]

## NOTE
The recommended configuration for interconnecting VNets is to use VNet peering. VNet peering allows for scaling up throughput and removes the bandwidth cap and maximum packet per second limit associated with VPN Gateways.

`Tags: Azure VPN, Site-to-Site VPN` <br>
`date: 25/11/2024` <br>
`date: 19/07/2018` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/effective-routes-vm1-nic.png "effetive route table vm1-nic"
[3]: ./media/effective-routes-vm2-nic.png "effetive route table vm2-nic"
[4]: ./media/effective-routes-vm3-nic.png "effetive route table vm3-nic"
[5]: ./media/effective-routes-vm4-nic.png "effetive route table vm4-nic"
<!--Link References-->

