<properties
pageTitle= 'Site-to-Site VPN between Azure VPN Gateways with transit through an ExpressRoute circuit'
description= "Site-to-Site VPN between Azure VPN Gateways with transit through an ExpressRoute circuit"
documentationcenter: na
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
   ms.date="22/11/2023"
   ms.author="fabferri" />

# Site-to-Site VPN between Azure VPN Gateways with transit through ExpressRoute private peering
This post discusses how to create a Site-to-Site VPN tunnels between two Azure VPN Gateways with transit through an ExpressRoute private peering. <br>
The Site-to-Site VPN tunnels are established between the private IPs of the VPN Gateways. <br>
The diagram illustrates the network configuration:

[![1]][1]

The following network diagram shows data traffic flow:

[![2]][2]

Communication between **vnet1** and **vnet2** occurs through the backend interfaces of the MSEE routers. <br>
The traffic does not pass through the MSEE routers front interfaces connected to the customer's edge routers, a process commonly referred to _hairpinning_.

## Key Points:
- The Azure VPN Gateway **vpnGtw1** is created in **vnet1** and configured in active-active mode
- The Azure VPN Gateway **vpnGtw2** is created in **vnet2** and configured in active-active mode
- Two Site-to-Site IPSec tunnels are established between **vpnGtw1** and **vpnGtw2** through private IP addresses
- To enable Site-to-Site tunnels through the private IPs of the VPN Gateway, the following settings are required:
   - resource type: **Microsoft.Network/virtualNetworkGateways**, setting required: **"enablePrivateIpAddress": true**
   - resource type: **Microsoft.Network/connections**, setting required: **"useLocalAzureIpAddress": true**
- ExpressRoute Gateway **ergw1** is deployed in **vnet1**
- ExpressRoute Gateway **ergw2** is deployed in **vnet1**
- To enable the routing between vnet1 and vnet2 through ExpressRoute private peering the following setting is required in ExpressRoute Gateway:
   - resource type: **Microsoft.Network/virtualNetworkGateways**, setting required: **"allowRemoteVnetTraffic": true** <br>
   This setting is shown in the Azure management portal:
   [![3]][3]
- To enable the transit of Site-to-Site tunnels through the private IP address the following property is required in VPN Connections:
   - Resource type: **Microsoft.Network/connections**, setting required: **"useLocalAzureIpAddress": true** <br>
   This setting is shown in the Azure management portal:
   [![4]][4]   
- A UDR is applied to the **subnet1** in **vnet1** to force the traffic going in the remote **vnet2** to transit through the VPN Gateway **vpnGw1**
- A UDR is applied to the **subnet2** in **vnet2** to force the traffic going to the remove **vnet1** to transit through the VPN Gateway **vpnGw2**
- If there are multiple User-Defined Routes (UDRs) with the same destination, only one route will be applied while the others will be ignored. The selection of the applied route can be somewhat random, so it's important to avoid conflicting routes to ensure predictable routing behaviour. In this setup, the UDR entry with the destination network address space of the remote VNet has a next-hop of one of the private IP addresses of the VPN Gateway. The VPN Gateway in active-active mode has two private IPs, but only one of them can be used in the UDR.  

The network diagram with the two Site-to-Site IPsec tunnels:

[![5]][5]

The network diagram with UDRs is depicted below:
 
[![6]][6]

The presence of UDRs overrides the routing in the system routing table. UDRs applied to subnet1 and subnet2 are necessary; without them, traffic will bypass the VPN Gateway and pass only through the ExpressRoute Gateways. In this configuration, traffic between subnet1 and subnet2 transits through a single IPsec tunnel.

## Files Description
- `init.txt`: it contains a variables used as input of the ARM templates. The powershell script **01_vpn1.ps1** and **02_vpn2.ps1** read the input variables from the **init.txt**. 
- `01_vpn1.json`: ARM template creates the vnet1, vnet2, vpngw1, vpgw2, vm1 and vm2
- `01_vpn1.json`: powershell script to run the ARM template **01_vpn1.json** 
- `02_vpn2.json`: ARM template to create local networks and connections for the vpngw1 and vpngw2
- `02_vpn2.ps1`: powershell script to run the ARM template **02_vpn2.json** 
- `03_er-gws.json`: This ARM template creates the ExpressRoute Gateways ergw1 in vnet1 and ergw2 in vnet2, and subsequently deploys the connections to the ExpressRoute circuit.
- `03_er-gws.ps1`: powershell script to run the ARM template **03_er-gws.json** 
- `collect-priv-ip.json`: ARM template to collect private IP addresses and BGP IP addresses of the vpngw1 and vpngw2. The ARM template do not make any deployment
- `collect-priv-ip.ps1`: powershell script to run the ARM template **collect-priv-ip.json**

The powershell scripts **01_vpn1.ps1**, **02_vpn2.ps1** and **03_er-gws.json** needs to be run in sequence. 

> [!NOTE]
>
> Before deploying the ARM template, set the variable value in the `init.txt` file:
> subscriptionName = AZURE_SUBSCRIPTION_NAME <br>
> ResourceGroupName = RESOURCE_GROUP_NAME <br>
> location1 = AZURE_REGION_VNET1 <br>
> location2 = AZURE_REGION_VNET2 <br>
> adminUsername = ADMINISTRATOR_USERNAME <br>
> adminPassword = ADMINISTRATOR_PASSWORD <br>
> erGateway1Name = EXPRESSROUTE_GATEWAY_NAME_IN_VNET1 <br>
> erGateway2Name = EXPRESSROUTE_GATEWAY_NAME_IN_VNET2 <br>
> erSubscriptionId = AZURE_SUBSCRIPTION_ID_EXPRESSROUTE_CIRCUIT <br>
> erResourceGroup = RESOURCE_GROUP_NAME_EXPRESSROUTE_CIRCUIT <br>
> erCircuitName = EXPRESSROUTE_CIRCUIT_NAME <br>
> erCircuitAuthorizationKey1 = AUTHORIZATION_CODE_1_TO_CONNECT_TO_EXPRESSROUTE_CIRCUIT <br>
> erCircuitAuthorizationKey2 = AUTHORIZATION_CODE_2_TO_CONNECT_TO_EXPRESSROUTE_CIRCUIT <br>
>



## <a name="VPN Gateway: fetch the private IPs"></a> How to fetched the private IP of the VPN Gateway in ARM template

The **vpnGw1** private IPs can be fetched by: 
```json
"[ reference(resourceId('Microsoft.Network/virtualNetworkGateways',variables('gateway1Name')),'2023-11-01').ipConfigurations[0].properties.privateIPAddress ]",

"[ reference(resourceId('Microsoft.Network/virtualNetworkGateways',variables('gateway1Name')),'2023-11-01').ipConfigurations[1].properties.privateIPAddress ]",
```

The **vpnGw1** BGP IPs can be fetched by: 
```json
"[first(split( reference(resourceId('Microsoft.Network/virtualNetworkGateways',variables('gateway1Name')),'2023-11-01').bgpSettings.bgpPeeringAddress , ','))]",

 "[last(split( reference(resourceId('Microsoft.Network/virtualNetworkGateways',variables('gateway1Name')),'2023-11-01').bgpSettings.bgpPeeringAddress , ','))]",
```

VPN private IPs and BGP IPs are both required to define the local network gateways:
```json 
{
   "type": "Microsoft.Network/localNetworkGateways",
   "name": "[variables('localGatewayName11')]",
   "apiVersion": "2023-11-01",
   "comments": "public IP of remote IPSec peer",
   "location": "[variables('location2')]",
   "properties": {
      "gatewayIpAddress": "[reference(resourceId('Microsoft.Network/virtualNetworkGateways',variables('gateway1Name')),'2023-11-01').ipConfigurations[0].properties.privateIPAddress ]",
      "bgpSettings": {
         "asn": "[variables('asnGtw1')]",
         "bgpPeeringAddress": "[first(split( reference(resourceId('Microsoft.Network/virtualNetworkGateways',variables('gateway1Name')),'2023-11-01').bgpSettings.bgpPeeringAddress , ','))]",
         "peerWeight": 0
      }
   }
}
```

A less elegant way to extract the first BGP IP of the VPN Gateway is to use the index of array:
```json
"[split( reference(resourceId('Microsoft.Network/virtualNetworkGateways',variables('gateway1Name'))).bgpSettings.bgpPeeringAddress , ',')[0]]",
```


`Tags: Azure VPN, Site-to-Site VPN` <br>
`date: 22-11-2024` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/traffic-in-transit-between-vnets.png "traffic flows between the two vnets"
[3]: ./media/hairpinning-setting.png "hairpinning: enable routing between the two vnets through the ER circuit"
[4]: ./media/connection-private-ip.png "Connection with private IP"
[5]: ./media/s2s-config.png "configuration of the Site-to-Site VPN"
[6]: ./media/udr.png "UDRs applied to the subnet1 and subnet2"

<!--Link References-->

