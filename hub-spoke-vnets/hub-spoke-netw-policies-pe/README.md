<properties
pageTitle= 'Network policies for Private Endpoints with UDR and NSG'
description= "Network policies for Private Endpoints with UDR and NSG"
documentationcenter: github
services=""
documentationCenter="github"
authors="fabferri"
editor=""/>

<tags
   ms.service="howto-Azure-examples"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="Azure hub-spoke vnets, Azure firewall and Network policies for Private Endpoint"
   ms.date="28/08/2023"
   ms.review=""
   ms.author="fabferri" />

# Network policies for Private Endpoints with UDR and NSG
The article aims to discuss the network policies for Private Endpoints with UDR and NSG. The high network diagram is shown below with hub-spoke vnets in peering:

[![1]][1]

When a Private Endpoints is defined a virtual NIC which is placed within a vnet and is attached to a PaaS service. <br>
Unlike regular NICs, private endpoints are a bit different because automatically create a /32 default route that will be propagated across its own vnet and other peered vnets. This means that if you have a hub-and-spoke model where you have a Private Endpoint in one of the spokes, then the private endpoint default route will be also propagated into the hub network as well.<br>
There is no option to see the effective routes directly on the private endpoints; therefore, if you want to see the routes you need to do it from a NIC of a virtual machine attached to the subnet of the private endpoint. <br>
You can configure a User-Defined Routes (UDR) or NSG for a private endpoint, but that requires that network policies must be enabled for the subnet to allow communication. <br>
Network policies can be enabled either for NSG only, for UDR only, or for both. <br>
The attribute to enable the network policy in a subnet is named **PrivateEndpointNetworkPolicies**. In other words, an Azure subnet **"Microsoft.Network/virtualNetworks/subnets"** has a property: <br>
**"privateEndpointNetworkPolicies"**: "string" <br>

This property can take the following values: 

**"privateEndpointNetworkPolicies"**: "Disabled" <br>
**"privateEndpointNetworkPolicies"**: "Enabled" <br>
**"privateEndpointNetworkPolicies"**: "NetworkSecurityGroupEnabled" <br>
**"privateEndpointNetworkPolicies"**: "RouteTableEnabled" <br>

By default, network policy for private endpoint is **"Disabled"** for a subnet in a virtual network.<br>

If you enable network security policies for UDR, <ins>you can use a custom address prefix equal to or larger than the VNet address space to invalidate the /32 default route propagated by the Private Endpoint</ins>. This can be useful if you want to ensure private endpoint connection requests go through a firewall or Virtual Appliance. Otherwise, the /32 default route would send traffic directly to the private endpoint in accordance with the longest prefix match algorithm.

A full network diagram with IP network addresses is shown below:

[![2]][2]

The Private Endpoint to access to Azure Storage blob is deployed in **pe-subnet** subnet of the **spoke1**. <br>
A private DNS zone is created **privatelink.blob.core.windows.net** to resolve the storage blob connected to the vnet through Private Endpoint. The private DNS zone is linked to the **hub** and **spoke1** vnets.

> Note <br>
> - SNAT is still required and best practice for traffic symmetry to ensure return traffic from Private Endpoints takes the same route back to the user. <br>
> - the default /32 route of Private endpoint is protocol aware and will only apply to TCP traffic. UDP and ICMP traffic will not be affected. <br>
>

## <a name="privateEndpointNetworkPolicies Disabled"></a>1. CASE1: privateEndpointNetworkPolicies is Disabled and no UDR applied to pe-subnet in spoke1
In this case:
- in the Private Endpoint subnet the **"privateEndpointNetworkPolicies"** is **Disabled**. <br>
- no UDRs are applied to the Private Endpoint subnet


Private Endpoints will automatically create a /32 default route that will be propagated across its own virtual network and other peered virtual networks. 
The network diagram is shown below:

[![3]][3]


Effective routes in **vmpespoke1-nic**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.50.0/24     | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.0.100.0/24    | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active | 10.1.34.0/25     | Virtual network gateway | 10.3.129.52         | \-                      |
| Virtual network gateway | Active | 10.1.34.0/25     | Virtual network gateway | 10.3.129.53         | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |
| Default                 | Active | 10.0.50.4/32     | InterfaceEndpoint       | \-                  | \-                      |

The Private Endpoint default route **10.0.50.4/32** is present in routing table. 
<br>

Effective routes in **vm1spoke1-nic**:
| Source  | State   | Address Prefixes | Next Hop Type     | Next Hop IP Address | User Defined Route Name |
| ------- | ------- | ---------------- | ----------------- | ------------------- | ----------------------- |
| Default | Active  | 10.0.50.0/24     | Virtual network   | \-                  | \-                      |
| Default | Active  | 10.0.100.0/24    | VNet peering      | \-                  | \-                      |
| Default | Invalid | 0.0.0.0/0        | Internet          | \-                  | \-                      |
| User    | Active  | 0.0.0.0/0        | Virtual appliance | 10.0.100.10         | to-nva                  |
| User    | Active  | 10.0.100.32/27   | Virtual appliance | 10.0.100.10         | to-tenant-subnet        |
| Default | Active  | 10.0.50.4/32     | InterfaceEndpoint | \-                  | \-                      |

The Private Endpoint default route **10.0.50.4/32** is present in routing table. 
<br>

Effective routes in **vm1hub-nic**:
| Source                  | State   | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------- | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active  | 10.0.100.0/24    | Virtual network         | \-                  | \-                      |
| Default                 | Invalid | 10.0.50.0/24     | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active  | 10.1.34.0/25     | Virtual network gateway | 10.3.129.52         | \-                      |
| Virtual network gateway | Active  | 10.1.34.0/25     | Virtual network gateway | 10.3.129.53         | \-                      |
| Default                 | Active  | 0.0.0.0/0        | Internet                | \-                  | \-                      |
| User                    | Active  | 10.0.50.0/24     | Virtual appliance       | 10.0.100.10         | to-spoke1               |
| Default                 | Active  | 10.0.50.4/32     | InterfaceEndpoint       | \-                  | \-                      |

The Private Endpoint default route **10.0.50.4/32** is present in routing table.
<br>

Effective routes in **nva-nic**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.100.0/24    | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.0.50.0/24     | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active | 10.1.34.0/25     | Virtual network gateway | 10.3.129.52         | \-                      |
| Virtual network gateway | Active | 10.1.34.0/25     | Virtual network gateway | 10.3.129.53         | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |
| Default                 | Active | 10.0.50.4/32     | InterfaceEndpoint       | \-                  | \-                      |

The Private Endpoint default route **10.0.50.4/32** is present in routing table.

<br>

Routing table in ExpressRoute Gateway:
```powershell
$gwName= 'ergw'
$bgpPeerStatus = Get-AzVirtualNetworkGatewayBGPPeerStatus -VirtualNetworkGatewayName $gwName -ResourceGroupName $rgName
$bgpPeerStatus[0].Neighbor
$bgpPeerStatus[1].Neighbor
Get-AzVirtualNetworkGatewayAdvertisedRoute -VirtualNetworkGatewayName $gwName -ResourceGroupName $rgName -Peer $bgpPeerStatus[0].Neighbor

LocalAddress Network       NextHop      SourcePeer Origin AsPath Weight
------------ -------       -------      ---------- ------ ------ ------
10.0.100.205 10.0.100.0/24 10.0.100.205            Igp    65515  0
10.0.100.205 10.0.50.0/24  10.0.100.205            Igp    65515  0


Get-AzVirtualNetworkGatewayLearnedRoute -VirtualNetworkGatewayName $gwName -ResourceGroupName $rgName  | ft

LocalAddress Network       NextHop      SourcePeer   Origin  AsPath      Weight
------------ -------       -------      ----------   ------  ------      ------
10.0.100.204 10.0.100.0/24              10.0.100.204 Network             32768
10.0.100.204 10.0.50.0/24               10.0.100.204 Network             32768
10.0.100.204 10.1.34.0/25  10.0.100.196 10.0.100.196 EBgp    12076-65020 32769
10.0.100.204 10.1.34.0/25  10.0.100.197 10.0.100.197 EBgp    12076-65020 32769

```

Routing table in ExpressRoute circuit private peering-primary link:
| Network       | Next hop       | LocPrf | Weight | Path  |
| ------------- | -------------- | ------ | ------ | ----- |
| 10.0.50.0/24  | 10.0.100.204   |        | 0      | 65515 |
| 10.0.50.0/24  | 10.0.100.205\* |        | 0      | 65515 |
| 10.0.100.0/24 | 10.0.100.204   |        | 0      | 65515 |
| 10.0.100.0/24 | 10.0.100.205\* |        | 0      | 65515 |
| 10.1.34.0/25  | 192.168.34.17  |        | 0      | 65020 |


The Expressroute circuit BGP table contains the address space of hub vnet, spoke1 vnets and the network on-premises (10.1.34.0/25) but it doesn't contain the Private Endpoint default route **10.0.50.4/32**.

<br>

Data traffic paths are shown in the diagram:

[![4]][4]

[![5]][5]

## <a name="privateEndpointNetworkPolicies Enabled"></a>2. CASE2: privateEndpointNetworkPolicies Enabled and UDR applied to pe-subnet in spoke1 
In this case:
- in the Private Endpoint subnet the **"privateEndpointNetworkPolicies"** is **Enabled**. 
- UDRs are applied to the Private Endpoint subnet to force the traffic to transit through the **nva**


<br>

The network diagram is showm below:

[![6]][6]

Effective routes in **vmpespoke1-nic**:
| Source  | State   | Address Prefixes | Next Hop Type     | Next Hop IP Address | User Defined Route Name |
| ------- | ------- | ---------------- | ----------------- | ------------------- | ----------------------- |
| Default | Invalid | 10.0.50.0/24     | Virtual network   | \-                  | \-                      |
| Default | Active  | 10.0.100.0/24    | VNet peering      | \-                  | \-                      |
| Default | Invalid | 0.0.0.0/0        | Internet          | \-                  | \-                      |
| User    | Active  | 10.0.50.0/24     | Virtual appliance | 10.0.100.10         | to-spoke1               |
| User    | Active  | 10.0.100.32/27   | Virtual appliance | 10.0.100.10         | to-tenant-subnet        |
| User    | Active  | 0.0.0.0/0        | Virtual appliance | 10.0.100.10         | to-nva                  |
| Default | Invalid | 10.0.50.4/32     | InterfaceEndpoint | \-                  | \-                      |

the effective routing table shows that the default network for the private endpoint **10.0.50.4/32** is invalid.

<br>

Effective routes in **vm1spoke1-nic**:
| Source  | State   | Address Prefixes | Next Hop Type     | Next Hop IP Address | User Defined Route Name |
| ------- | ------- | ---------------- | ----------------- | ------------------- | ----------------------- |
| Default | Active  | 10.0.50.0/24     | Virtual network   | \-                  | \-                      |
| Default | Active  | 10.0.100.0/24    | VNet peering      | \-                  | \-                      |
| Default | Invalid | 0.0.0.0/0        | Internet          | \-                  | \-                      |
| User    | Active  | 0.0.0.0/0        | Virtual appliance | 10.0.100.10         | to-nva                  |
| User    | Active  | 10.0.100.32/27   | Virtual appliance | 10.0.100.10         | to-tenant-subnet        |
| Default | Active  | 10.0.50.4/32     | InterfaceEndpoint | \-                  | \-                      |

<br>

Effective routes in **vm1hub-nic**:
| Source                  | State   | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------- | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active  | 10.0.100.0/24    | Virtual network         | \-                  | \-                      |
| Default                 | Invalid | 10.0.50.0/24     | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active  | 10.1.34.0/25     | Virtual network gateway | 10.3.129.52         | \-                      |
| Virtual network gateway | Active  | 10.1.34.0/25     | Virtual network gateway | 10.3.129.53         | \-                      |
| Default                 | Active  | 0.0.0.0/0        | Internet                | \-                  | \-                      |
| User                    | Active  | 10.0.50.0/24     | Virtual appliance       | 10.0.100.10         | to-spoke1               |
| Default                 | Invalid | 10.0.50.4/32     | InterfaceEndpoint       | \-                  | \-                      |

<br>

Effective routes in **nva-nic**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.100.0/24    | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.0.50.0/24     | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active | 10.1.34.0/25     | Virtual network gateway | 10.3.129.52         | \-                      |
| Virtual network gateway | Active | 10.1.34.0/25     | Virtual network gateway | 10.3.129.53         | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |
| Default                 | Active | 10.0.50.4/32     | InterfaceEndpoint       | \-                  | \-                      |

<br>

Routing table in ExpressRoute Gateway:
```powershell
$gwName= 'ergw'
$bgpPeerStatus = Get-AzVirtualNetworkGatewayBGPPeerStatus -VirtualNetworkGatewayName $gwName -ResourceGroupName $rgName
$bgpPeerStatus[0].Neighbor
$bgpPeerStatus[1].Neighbor
Get-AzVirtualNetworkGatewayAdvertisedRoute -VirtualNetworkGatewayName $gwName -ResourceGroupName $rgName -Peer $bgpPeerStatus[0].Neighbor

LocalAddress Network       NextHop      SourcePeer Origin AsPath Weight
------------ -------       -------      ---------- ------ ------ ------
10.0.100.204 10.0.100.0/24 10.0.100.204            Igp    65515  0
10.0.100.204 10.0.50.0/24  10.0.100.204            Igp    65515  0


Get-AzVirtualNetworkGatewayLearnedRoute -VirtualNetworkGatewayName $gwName -ResourceGroupName $rgName  | ft

LocalAddress Network       NextHop      SourcePeer   Origin  AsPath      Weight
------------ -------       -------      ----------   ------  ------      ------
10.0.100.204 10.0.100.0/24              10.0.100.204 Network             32768
10.0.100.204 10.1.34.0/25  10.0.100.196 10.0.100.196 EBgp    12076-65020 32769
10.0.100.204 10.1.34.0/25  10.0.100.197 10.0.100.197 EBgp    12076-65020 32769
10.0.100.204 10.0.50.0/24               10.0.100.204 Network             32768
```
- address space of the spoke1 10.0.50.0/24 
- address space of the hub 10.0.100.0/24 
- address space of network on-premises 10.1.34.0/25

<br>

Routing table in ExpressRoute circuit private peering-primary link:

| Network       | Next hop       | LocPrf | Weight | Path  |
| ------------- | -------------- | ------ | ------ | ----- |
| 10.0.50.0/24  | 10.0.100.204   |        | 0      | 65515 |
| 10.0.50.0/24  | 10.0.100.205\* |        | 0      | 65515 |
| 10.0.100.0/24 | 10.0.100.204   |        | 0      | 65515 |
| 10.0.100.0/24 | 10.0.100.205\* |        | 0      | 65515 |
| 10.1.34.0/25  | 192.168.34.17  |        | 0      | 65020 |

The BGP routin table in ExpressRoute circuit remains unchanged vs the CASE1 described above.

Running the capture in the **nva** for traffic going to the Private Endpoint 10.0.50.4:
root@nva:~# **tcpdump -nq net 10.0.50.0/27** <br>
or larger tcpdump filter: <br>
root@nva:~# **tcpdump -nq net 10.1.34.0/25 or net 10.0.100.32/27 or net 10.0.50.32/27 or net 10.0.50.0/27** <br>

From on-prem client 10.1.34.11, connect by storage explorer through Private Endpoint. The traffic is pass through the **nva**; here a snippet of the capture:

```console
root@nva:~# tcpdump -nq net 10.0.50.0/27
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
12:23:32.537609 IP 10.1.34.11.52610 > 10.0.50.4.443: tcp 0
12:23:32.537668 IP 10.1.34.11.52610 > 10.0.50.4.443: tcp 0
12:23:32.539576 IP 10.0.50.4.443 > 10.1.34.11.52610: tcp 0
12:23:32.539599 IP 10.0.100.10 > 10.0.50.4: ICMP redirect 10.1.34.11 to host 10.0.100.1, length 60
12:23:32.539609 IP 10.0.50.4.443 > 10.1.34.11.52610: tcp 0
12:23:32.545183 IP 10.1.34.11.52610 > 10.0.50.4.443: tcp 0
12:23:32.545194 IP 10.1.34.11.52610 > 10.0.50.4.443: tcp 0
12:23:32.545830 IP 10.1.34.11.52610 > 10.0.50.4.443: tcp 285
12:23:32.545841 IP 10.1.34.11.52610 > 10.0.50.4.443: tcp 285
12:23:32.548541 IP 10.0.50.4.443 > 10.1.34.11.52610: tcp 7498
12:23:32.548554 IP 10.0.50.4.443 > 10.1.34.11.52610: tcp 7498
12:23:32.553314 IP 10.1.34.11.52610 > 10.0.50.4.443: tcp 0
12:23:32.553314 IP 10.1.34.11.52610 > 10.0.50.4.443: tcp 0
12:23:32.553314 IP 10.1.34.11.52610 > 10.0.50.4.443: tcp 0
12:23:32.553325 IP 10.1.34.11.52610 > 10.0.50.4.443: tcp 0
12:23:32.553329 IP 10.1.34.11.52610 > 10.0.50.4.443: tcp 0
12:23:32.553330 IP 10.1.34.11.52610 > 10.0.50.4.443: tcp 0
12:23:32.583095 IP 10.1.34.11.52610 > 10.0.50.4.443: tcp 158
12:23:32.583131 IP 10.1.34.11.52610 > 10.0.50.4.443: tcp 158
12:23:32.585509 IP 10.0.50.4.443 > 10.1.34.11.52610: tcp 51
```
tcpdump shows a symmetric transit through the **nva**.

<br>
The data traffic paths are shown in the diagrams:

[![7]][7]

[![8]][8]


### <a name="list of files"></a>3. Project files

| File name                    | Description                                                                                             |
| ---------------------------- | ------------------------------------------------------------------------------------------------------- |
| **init.json**                | define the value of input variables required for the full deployment                                    |
| **01-az.json**               | ARM template to deploy hub and spoke vnets, vnet peering,  ExpressRoute Gateway and Connection to the Expressroute circuit, Azure VMs |
| **01-az.ps1**                | powershell script to deploy **01-az.json**                                                              |
| **02-private-endpoint.json** | ARM template to create an Azure storage account, private endpoint for the blob, Azure private DNS zone for the blob |
| **02-private-endpoint.ps1**  | powershell to script to run **02-private-endpoint.json**                                               | 
| **03-vnet-peering-udr.json** | ARM template to modify the vnet peering , create UDRs and apply the UDRs                               |
| **03-vnet-peering-udr.ps1**  | powershell to script to run **03-vnet-peering-udr.json**                                               | 

To run the project, follow the steps in sequence:
1. change/modify the value of input variables in the file **init.json**
2. run the powershell script **01-az.ps1**
3. run the powershell script **02-private-endpoint.ps1** 
4. run the powershell script **03-vnet-peering-udr.ps1** 

The meaning of input variables in **init.json** are explained below:
```json
{
    "subscriptionName": "NAME_OF_AZURE_SUBSCRIPTION",
    "ResourceGroupName": "NAME_OF_RESOURCE_GROUP",
    "location1": "AZURE_LOCATION_hub_VNET",
    "location2": "AZURE_LOCATION_spoke1_VNET",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPasswordOrKey": "ADMINISTRATOR_PASSWORD",
    "erSubscriptionId": "AZURE_SUBSCRIPTION_ID_WHERE_IS_DEPLOYED_THE_EXPRESSROUTE_CIRCUIT",
    "erResourceGroup": "RESOUCE_GROUP_NAME_WHERE_IS_DEPLOYED_THE_EXPRESSROUTE_CIRCUIT",
    "erCircuitName": "NAME_OF_EXPRESSROUTE_CIRCUIT",
    "erAuthorizationKey": "AUTHORIZATION_KEY_TO_JOIN_TO_THE_EXPRESSROUTE_CIRCUIT"
}
```



`Tags: hub-spoke vnets, Network policies for Private Endpoints` <br>
`date: 28-08-23`

<!--Image References-->

[1]: ./media/network-diagram01.png "high level network diagram"
[2]: ./media/network-diagram02.png "network diagram with details"
[3]: ./media/network-diagram03.png "network diagram with privateEndpointNetworkPolicies Disabled and no UDR applied to the private endpoint subnet"
[4]: ./media/network-diagram04.png "CASE1: data path"
[5]: ./media/network-diagram05.png "CASE1: data path"
[6]: ./media/network-diagram06.png "network diagram with privateEndpointNetworkPolicies Enabled and UDR applied to the private endpoint subnet"
[7]: ./media/network-diagram07.png "CASE2: data path"
[8]: ./media/network-diagram08.png "CASE2: data path"

<!--Link References-->

