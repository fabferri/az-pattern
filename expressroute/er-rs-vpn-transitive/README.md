<properties
pageTitle= 'transitive routing between Azure VPN Gateway with site-to-site VPN and ExpressRoute Gateway connected to an ExpressRoute circuit'
description= "ARM template to create transitive routing between ExpressRoute Gateway and Azure VPN Gateway"
documentationCenter="https://github.com/fabferri/az-pattern"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="ARM templates"
   ms.topic="Azure Networking"
   ms.tgt_pltfrm="ExpressRoute, Azure VPN"
   ms.workload="ExpressRoute Gateway, Azure VPN, Azure Route Server"
   ms.date="07/08/2023"
   ms.author="fabferri" />

# Routing between Azure VPN Gateway with site-to-site VPN and ExpressRoute Gateway connected to an ExpressRoute circuit
The article walks through a configuration with Azure Virtual Network (VNet) with ExpressRoute Gateway and Azure VPN Gateway. The Azure ExpressRoute Gateway is connected to an on-premises network through an ExpressRoute circuit. A remote site a connected in site-to-site VPN to the VNet through Azure VPN Gateway. The high-level network diagram is shown below:

[![1]][1]

To allow the advertisement of remote network (in our case vnet2 but it can be a banck office network) to on-premises is required the presence of Azure Route Server in **vnet1**. The full network diagram is shown below:

[![2]][2]

- An ExpressRoute Gateway and Azure VPN Gateway coexist in the GatewaySubnet of the **vnet1**. 
- The on-premises network 10.1.34.0/25 is advertised from the customer's edge routers to the ExpressRoute circuit (MSEE routers). The MSEE routers advertise in BGP the on-premises network 10.1.34.0/25 to the ExpressRoute Gateway.
- Two site-to-site VPN tunnels connect the **vnet1** and the remote site (**vnet2**) through Azure VPN Gateways **vpngtw1**  and **vpngtw2**.
- The Azure VPN Gateways **vpngtw1**  and **vpngtw2** are configured in active-active with static routing (without BGP). In Azure VPN Gateway BGP is not mandatory on site-to-site VPN, so if you choose not to enable its fine. The communication in BGP between Azure VPN Gateway and Azure Route server will still happen. 
- the Azure Route Server in **vnet1** establishes automatically iBGP sessions with Azure VPN Gateway and ExpressRoute Gateway. The Route Server works as reflector: 
   - the Azure Route Server advertises the networks learnt from the ExpressRoute Gateway to the VPN Gateway
   - the Azure Route Server advertises the networks learnt from the VPN Gateway to the ExpressRoute Gateway
- 

<br> 

The goal of the configuration: 
- enable the communication between the network on-premises and the workloads in the **vnet1** 
- enable the communication between the remote site (**vnet2**) and the **vnet1**
- enable the communication between the remote site (**vnet2**) and the on-premises network

[![3]][3]

## <a name="List of files"></a>1. List of project files

| file                | description                                                                |       
| ------------------- |:-------------------------------------------------------------------------- |
| **01-vpn.json**     | ARM template to create vnet1, vnet2, Azure VPN Gateways, site-to-site VPN and VMs in vnet1 and vnet2  |
| **01-vpn.ps1**      | powershell script to deploy the ARM template **01-vpn.json**                 |
| **02-rs-er.json**   | ARM template to create Azure Route Server, ExpressRoute Gateway, ExpressRoute Connection |
| **02-rs-er.ps1**    | powershell script to deploy the ARM template **02-rs-er.json**               |
| **init.json**       | input file to set the input variable across all the scripts and ARM templates|

The meaning of input variables specified in the **init.json** are described here:
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "subscriptionName": "AZURE_SUBSCRITION_NAME",
    "ResourceGroupName": "RESOURCE_GROUP_NAME",
    "location1": "NAME_AZURE_REGION_VNET1",
    "location2": "NAME_AZURE_REGION_VNET2",
    "erSubscriptionId": "AZURE_SUBSCRIPTION_ID_WHERE_IS_DEPLOYED_ER_CIRCUIT",
    "erResourceGroup": "RESOURCE_GROUP_NAME_WHERE_IS_DEPLOYED_ER_CIRCUIT",
    "erCircuitName": "NAME_OF_THE_EXPRESSROUTE_CIRCUIT",
    "erAuthorizationKey": "AUTHROIZATION_KEY_OF_THE_EXPRESSROUTE_CIRCUIT",
    "onPremisesAddressPrefix": "ON_PREMISES_NETWORK"
}
```

## <a name="VPN Gateway"></a>2. VPN Gateways
The VPN Gateways in vnet1 and vnet2 are configured in **active-active** with static routing. 
The **Local Network Gateways** in VPN Gateway define the remote networks; the Local Network Gateways associated with  **vpngw2** are: 

```json
{
    "type": "Microsoft.Network/localNetworkGateways",
    "name": "[variables('localGatewayName11')]",
    "apiVersion": "2022-05-01",
    "location": "[variables('location2')]",
    "properties": {
        "localNetworkAddressSpace": {
            "addressPrefixes": [
                "[variables('vnet1AddressPrefix')]",
                "[parameters('onPremisesAddressPrefix')]"
            ]
        },
        "gatewayIpAddress": "[reference(variables('vpnGateway1PublicIP1Id'),'2022-05-01').ipAddress]"
    }
},
{
      "type": "Microsoft.Network/localNetworkGateways",
      "name": "[variables('localGatewayName12')]",
      "apiVersion": "2022-05-01",
      "location": "[variables('location2')]",
      "properties": {
        "localNetworkAddressSpace": {
            "addressPrefixes": [
                  "[variables('vnet1AddressPrefix')]",
                  "[parameters('onPremisesAddressPrefix')]"
            ]
        },
        "gatewayIpAddress": "[reference(variables('vpnGateway1PublicIP2Id'),'2022-05-01').ipAddress]"
      }
},
```
The network diagram below shows the Local Network Gateways and the Connections in Site-to-Site VPN: 

[![4]][4]

## <a name="routing tables"></a>3. Routing tables 

The effective routing table for the NIC in the **vm2** in **vnet2** is shown below:

| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.200.0.0/24    | Virtual network         | \-                  | \-                      |
| Virtual network gateway | Active | 10.100.0.0/23    | Virtual network gateway | 10.200.0.196        | \-                      |
| Virtual network gateway | Active | 10.100.0.0/23    | Virtual network gateway | 10.200.0.197        | \-                      |
| Virtual network gateway | Active | 10.1.34.0/25     | Virtual network gateway | 10.200.0.196        | \-                      |
| Virtual network gateway | Active | 10.1.34.0/25     | Virtual network gateway | 10.200.0.197        | \-                      |


The VPN Gateway **vpngtw1** in **vnet1** learns the following network prefixes:
```powershell
Get-AzVirtualNetworkGatewayLearnedRoute -VirtualNetworkGatewayName vpngw1 -ResourceGroupName transit-vpn-er | ft

LocalAddress Network       NextHop      SourcePeer   Origin  AsPath      Weight
------------ -------       -------      ----------   ------  ------      ------
10.100.0.196 10.100.0.0/23              10.100.0.196 Network              32768
10.100.0.196 10.200.0.0/24              10.100.0.196 Network              32768
10.100.0.196 10.200.0.0/24 10.100.0.197 10.100.0.197 IBgp                 32768
10.100.0.196 10.1.34.0/25  10.100.0.199 10.100.0.68  IBgp    12076-65020  32768
10.100.0.196 10.1.34.0/25  10.100.0.199 10.100.0.69  IBgp    12076-65020  32768
10.100.0.197 10.100.0.0/23              10.100.0.197 Network              32768
10.100.0.197 10.200.0.0/24              10.100.0.197 Network              32768
10.100.0.197 10.200.0.0/24 10.100.0.196 10.100.0.196 IBgp                 32768
10.100.0.197 10.200.0.0/24 10.100.0.196 10.100.0.69  IBgp                 32768
10.100.0.197 10.200.0.0/24 10.100.0.196 10.100.0.68  IBgp                 32768
10.100.0.197 10.1.34.0/25  10.100.0.199 10.100.0.68  IBgp    12076-65020  32768
10.100.0.197 10.1.34.0/25  10.100.0.199 10.100.0.69  IBgp    12076-65020  3276
```
- **10.100.0.68, 10.100.0.69**: IP addresses of the Azure Route Server. 
- **10.100.0.0/23**: IP address space of the vnet1
- **10.200.0.0/24**: IP address space of the vnet2
- **10.1.34.0/25**: IP address space of the on-premises network
- **12076**: Microsoft's ASN 
- **65020**: customer's ASN 

The ExpressRoute Gateway **ergtw** in **vnet1** learns the following network prefixes:

```powershell
Get-AzVirtualNetworkGatewayLearnedRoute -VirtualNetworkGatewayName ergw -ResourceGroupName transit-vpn-er | ft  

LocalAddress Network       NextHop      SourcePeer   Origin  AsPath      Weight
------------ -------       -------      ----------   ------  ------      ------
10.100.0.204 10.100.0.0/23              10.100.0.204 Network              32768
10.100.0.204 10.200.0.0/24 10.100.0.196 10.100.0.68  IBgp                 32768
10.100.0.204 10.200.0.0/24 10.100.0.196 10.100.0.69  IBgp                 32768
10.100.0.204 10.1.34.0/25  10.100.0.199 10.100.0.199 EBgp    12076-65020  32769
10.100.0.204 10.1.34.0/25  10.100.0.198 10.100.0.198 EBgp    12076-65020  32769
```

The ExpressRoute Gateway in vnet1
- the ExpressRoute Gateway **ergw** learns the vnet2 address space 10.200.0.0/24 through iBGP session. This happens because ExpressRoute Gateway and Azure Route Server establish automatically an iBGP session, 
- the network 10.1.34.0/25 is announced from on-premises edge routers with ASN 65021 to the MSEE routers and then re-advertised to the ExpressRoute Gateway

<br>

Routing table in ExpressRoute circuit:
```powershell
C:\> Get-AzExpressRouteCircuitRouteTable -ResourceGroupName SEA-Cust34 -ExpressRouteCircuitName SEA-Cust34-ER -PeeringType AzurePrivatePeering -DevicePath Primary | ft

Network       NextHop       LocPrf Weight Path
-------       -------       ------ ------ ----
10.1.34.0/25  192.168.34.17             0 65020
10.100.0.0/23 10.100.0.205              0 65515
10.100.0.0/23 10.100.0.204*             0 65515
10.200.0.0/24 10.100.0.205              0 65515
10.200.0.0/24 10.100.0.204*             0 65515
```

## <a name="summary"></a>4. Conclusions
The deployment proofs that's possible connect on-premises network and remote site through site-to-site VPN. The site-to-site VPN does not require activation of BGP in VPN Gateway to advertise the remote networks to the Azure Route Server. The BGP peering between Azure Route Server <--> ExpressRoute Gateway and Azure Route Server <--> VPN Gateway happens automatically and does not require a peering configuration.<br>


## <a name="Estimated deployment time"></a>5. Estimated deployment time

- **01-vpn.json**: ~ 30 minutes
- **02-rs-er.json**: ~ 30 minutes


`Tags: VPN Gateway, Route Server, ExpressRoute` <br>
`date: 07-08-23`

<!--Image References-->
[1]: ./media/high-level-network-diagram.png "high level network diagram"
[2]: ./media/network-diagram.png "network diagram"
[3]: ./media/data-path.png "communication flows"
[4]: ./media/s2s-vpn.png "site-to-site VPN"
<!--Link References-->

