<properties
pageTitle= 'Example of configuration with ExpressRoute Gateway and Azure VPN Gateway in coexistence'
description= "ARM template to create ExpressRoute Gateway and Azure VPN Gateway in coexistence"
documentationCenter="https://github.com/fabferri/az-pattern"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="ARM templates"
   ms.topic="Azure Networking"
   ms.tgt_pltfrm="ExpressRoute, Azure VPN"
   ms.workload="ExpressRoute Gateway, Azure VPN"
   ms.date="26/09/2021"
   ms.author="fabferri" />

## Example of configuration with ExpressRoute Gateway and Azure VPN Gateway in coexistence
The article walks through a configuration with Azure Virtual Network (VNet) connected to an on-premises network and a remote site. The network diagram is shown below:

[![1]][1]


- An ExpressRoute Gateway and an Azure VPN Gateway coexist in the GatewaySubnet of the VNet01. The ExpressRoute Gateway connect the VNet01 to the on-premises network and the VPN Gateway connect the VNet01 to the remote site (VNet02).
- The on-premises customer edge routers advertise the network 10.2.12.0/25 via BGP to the ExpressRoute circuit 
- The VNet02 is connected to the VNet01 through site-to-site VPN, in configuration active-active with static routing. Two IPsec tunnels are established between the two VPN Gateways.
- the VNet02 has an address space 10.2.12.64/26 more specific of the on-premises network 10.2.12.0/25.

<br> 

The goal of the configuration: 
- enable the communication between the network on-premises and the workloads in the VNet01 
- enable the communication between the remote site (VNet02) and the VNet01
- check that overlapping of address space between the on-premises network (10.2.12.0/25) and the remote site (10.2.12.64/26) does not cause issue to the communication because the routing in the VNet follow the **Longest Prefix Match**
- verifying that the static networks defined in Local Network Gateway are propagated in the VNet01 system routing table

## <a name="routing"></a>1. Routing considerations 
The ExpressRoute Gateway in VNet01 learns through iBGP the network 10.2.12.64/26 from the VPN Gateway, but it doesn't re-advertise this route to on-premises. The behaviour is normally described as **_"non-transitive routing"_** between the VPN Gateway and the ExpressRoute Gateway. The overlapping of networks between the address space (10.2.12.64/26) of the VNet02 and the network on-premises (10.2.12.0/25) doesn't cause conflict. 

<br>

In this specific case, the on-premises network will be able to communicate with VNet01 only through a range of IP Addresses belonging to the network 10.2.12.0/25 but out of the range 10.2.12.64/26. The valid on-premises IP prefixes to communicate with the VNet01 are in the range: **[10.2.12.0, 10.2.12.63]**

[![2]][2]

<br>

The effective routing table for the NIC in the VM01 in VNet01 is shown below:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.10.12.0/24    | Virtual network         | \-                  | \-                      |
| Virtual network gateway | Active | 10.2.12.0/25     | Virtual network gateway | 10.20.78.137        | \-                      |
| Virtual network gateway | Active | 10.2.12.0/25     | Virtual network gateway | 10.20.78.138        | \-                      |
| Virtual network gateway | Active | 10.2.12.64/26    | Virtual network gateway | 10.10.12.142        | \-                      |
| Virtual network gateway | Active | 10.2.12.64/26    | Virtual network gateway | 10.10.12.143        | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |

The network 10.2.12.64/26 has a next-hop the IP address of the VPN Gateway:
```powershell
C:\> (Get-AzVirtualNetworkGateway -Name ASH-Cust12-VNet01-gw-vpn -ResourceGroupName ASH-Cust12).BgpSettings.BgpPeeringAddress           
10.10.12.142,10.10.12.143
```
The ExpressRoute Gateway in VNet01 learns the following network prefixes:
```powershell
C:\> Get-AzVirtualNetworkGatewayLearnedRoute -VirtualNetworkGatewayName ASH-Cust12-VNet01-gw-er -ResourceGroupName ASH-Cust12 | ft

LocalAddress Network       NextHop      SourcePeer   Origin  AsPath      Weight
------------ -------       -------      ----------   ------  ------      ------
10.10.12.141 10.10.12.0/24              10.10.12.141 Network              32768
10.10.12.141 10.2.12.0/25  10.10.12.132 10.10.12.132 EBgp    12076-65021  32769
10.10.12.141 10.2.12.0/25  10.10.12.133 10.10.12.133 EBgp    12076-65021  32769
10.10.12.141 10.2.12.64/26 10.10.12.143 10.10.12.143 IBgp                 32768
10.10.12.141 10.2.12.64/26 10.10.12.142 10.10.12.142 IBgp                 32768
```

- the ExpressRoute Gateway learns the VNet02 address space (network 10.2.12.64/26) through iBGP session. This is happening because ExpressRoute Gateway and VPN Gateway in coexistence establish automatically an iBGP session, 
- the network 10.2.12.0/25 is announced from on-premises edge routers with ASN 65021 to the MSEE routers and then re-advertised to the ExpressRoute Gateway; 

<br>

The network 10.2.12.64/26 is not present in the routing table of the ExpressRoute circuit"
```powershell
C:\> Get-AzExpressRouteCircuitRouteTable -ResourceGroupName ASH-Cust12 -ExpressRouteCircuitName ASH-Cust12-ER -PeeringType AzurePrivatePeering -DevicePath Primary | ft

Network       NextHop       LocPrf Weight Path
-------       -------       ------ ------ ----
10.2.12.0/25  192.168.12.17             0 65021
10.10.12.0/24 10.10.12.141              0 65515
10.10.12.0/24 10.10.12.140*             0 65515
```


## <a name="summary"></a>2. VPN Gateways
The VPN Gateways, in VNet01 and VNet02, are configured in active-active with static routing; the Local Network Gateways define the remote network: 

```json
{
  "name": "localGateway11",
  "type": "Microsoft.Network/localNetworkGateways",
  "location": "eastus2",
  "properties": {
    "localNetworkAddressSpace": {
      "addressPrefixes": [ "10.10.12.0/24"]
    },
    "gatewayIpAddress": "VNet01-gw-vpn-pip1"
  }
}
```

```json
{
  "name": "localGateway21",
  "type": "Microsoft.Network/localNetworkGateways",
  "location": "eastus2",
  "properties": {
    "localNetworkAddressSpace": {
      "addressPrefixes": ["10.2.12.64/26"]
    },
    "gatewayIpAddress": "VNet02-gw-vpn-pip1"
  }
}
```
The network diagram below shows the Local Network Gateways and the Connections in Site-to-Site VPN: 
[![3]][3]


## <a name="summary"></a>3. Conclusions
The deployment proofs that's possible connect an on-premises network and remote site, with partial overlapping networks, to the same VNet.  
<br>

 A deterministic path to the destinations is established by the **Longest Prefix Match** routing in Azure VNet.

<br>

## <a name="List of files"></a>4. List of ARM templates and scripts

| file                        | description                                                                |       
| --------------------------- |:-------------------------------------------------------------------------- |
| **01-vnets-gtws.json**      | ARM template to create VNet01, VNEt02, ExpressRoute Gateway and VPN Gateways, connection between ExpressRoute Gateway and ExpressRoute circuit  |
| **01-vnets-gtws.ps1**       | powershell script to deploy the ARM template **01-vnets-gtws.json**        |
| **02-vpn-conns.json**       | ARM template to create VPN loacal Network Gateways and connections         |
| **02-vpn-conns.ps1**        | powershell script to deploy the ARM template **02-vpn-conns.json**         |
| **init.json**               | input file to set all the variable across all the scripts and ARM templates|

The meaning of input variables specified in the **init.json** are described here:
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME_OF_AZURE_VMs",
    "adminPassword": "ADMINISTRATOR_PASSWORD_OF_AZURE_VMs",
    "subscriptionName": "AZURE_SUBSCRIPTION_NAME",
    "ResourceGroupName": "NAME_OF_THE_RESOURCE_GROUP",
    "RGTagExpireDate": "10/05/21",
    "RGTagContact": "user1@contoso.com",
    "RGTagNinja": "user1",
    "RGTagUsage": "configuration with ExpressRoute Gateway and VPN Gateway in coexistence",
    "rgName_erCircuit1":  "RESOURCE_GROUP_NAME_OF_THE_EXPRESSROUTE_CIRCUIT",
    "erCircuit1Name":  "NAME_OF_EXPRESSROUTE_CIRCUIT",
    "erConnection1Name": "NAME_OF_THE_EXPRESSROUTE_CONNECTION",
    "location1": "NAME_OF_AZURE_REGION_VNET01",
    "location2": "NAME_OF_AZURE_REGION_VNET01",
    "vNet1Name": "NAME_OF_VNET01",
    "vNet2Name": "NAME_OF_VNET02",
    "vNet1AddressPrefix": "ADDRESS_SPACE_VNET01_INCLUSIVE_OF_MASK",
    "vNet2AddressPrefix": "ADDRESS_SPACE_VNET02_INCLUSIVE_OF_MASK",
    "vnet1subnet1Name": "NAME_OF_THE_SUBNET1_IN_VNET01",
    "vnet2subnet1Name": "NAME_OF_THE_SUBNET1_IN_VNET02",
    "vnet1subnet1Prefix": "NETWORK_SUBNET1_IN_VNET01",
    "gateway1subnetPrefix": "NETWORK_GATEWAYSUBNET_IN_VNET01",
    "vnet2subnet1Prefix": "NETWORK_SUBNET1_IN_VNET02",
    "gateway2subnetPrefix": "NETWORK_GATEWAYSUBNET_IN_VNET02",
    "erGateway1Name": "NAME_OF_THE_EXPRESSROUTE_GATEWAY",
    "erGateway1PublicIP1Name": "PUBLIC_IP_NAME_OF_THE_EXPRESSROUTE_GATEWAY",
    "vpnGateway1Name": "VPN_GATEWAY_NAME_VNET01",
    "vpnGateway2Name": "VPN_GATEWAY_NAME_VNET02",
    "vpnGateway1PublicIP1Name": "PUBLIC_IP1_NAME_OF_THE_VPN_GATEWAY_IN_VNET01",
    "vpnGateway1PublicIP2Name": "PUBLIC_IP2_NAME_OF_THE_VPN_GATEWAY_IN_VNET01",
    "vpnGateway2PublicIP1Name": "PUBLIC_IP1_NAME_OF_THE_VPN_GATEWAY_IN_VNET02",
    "vpnGateway2PublicIP2Name": "PUBLIC_IP2_NAME_OF_THE_VPN_GATEWAY_IN_VNET02",
    "erGatewaySku": "SKU_EXPRESSROUTE_GATEWAY_VNET01",
    "vpnGatewaySku":  "SKU_VPN_GATEWAY_VNET01_AND_VNET02",
    "localGatewayName11": "LOCAL_NETWORK_GATEWAY1_PUBLIC_IP1. IT'S_ASSOCIATED_WITH_VPN_GATEWAY_IN_VNET02",
    "localGatewayName12": "LOCAL_NETWORK_GATEWAY1_PUBLIC_IP2. IT'S_ASSOCIATED_WITH_VPN_GATEWAY_IN_VNET02",
    "localGatewayName21": "LOCAL_NETWORK_GATEWAY2_PUBLIC_IP1. IT'S_ASSOCIATED_WITH_VPN_GATEWAY_IN_VNET01",
    "localGatewayName22": "LOCAL_NETWORK_GATEWAY2_PUBLIC_IP2. IT'S_ASSOCIATED_WITH_VPN_GATEWAY_IN_VNET01",
    "connectionName11-21": "CONNECTION_FROM_VPN_GATEWAY1_PUBLICIP1-TO-VPN_GATEWAY2-PUBLICIP1",
    "connectionName21-11": "CONNECTION_FROM_VPN_GATEWAY2_PUBLICIP1-TO-VPN_GATEWAY1-PUBLICIP1",
    "connectionName12-22": "CONNECTION_FROM_VPN_GATEWAY1_PUBLICIP2-TO-VPN_GATEWAY2-PUBLICIP2",
    "connectionName22-12": "CONNECTION_FROM_VPN_GATEWAY2_PUBLICIP2-TO-VPN_GATEWAY1-PUBLICIP2",
    "sharedKey": "SHARED_SECRET_SITE_TO_SITE_VPN",
    "vm1Name": "VM_NAME_IN_VNET01",
    "vm2Name": "VM_NAME_IN_VNET02"
}
```

## <a name="Estimated deployment time"></a>5. Estimated deployment time

- **01-vnets-gtws.json**: 30 minutes
- **02-vpn-conns.json**: 5 minutes

<!--Image References-->
[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram"
[3]: ./media/network-diagram3.png "network diagram"

<!--Link References-->

