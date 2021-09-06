<properties
pageTitle= 'Virtual WAN: custom isolation for VNets and site-to-site VPN'
description= "Virtual WAN: custom isolation for VNets and site-to-site VPN"
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

# Virtual WAN: isolation VNets and site-to-site VPN
This article describes a configuration with spoke VNets connected to two virtual hub, hub1 and hub2.
The configuration establishes a selective interconnection between spoke VNets, preventing a specific set of spoke VNets from being able to reach other specific set of spoke VNets. This configuration is known as **isolating VNets**. The configuration establishes two site-to-site connections: 
* one site-to-site connection between the branch1 and virtual hub1 
* one site-to-site connection between the branch2 and virtual hub2
 
<br> 
Below the network diagram:

[![1]][1]

The Virtual WAN connections betwen spoke vnets and hubs have different colour as representation of association of each spoke vnet to a specific routing table.
The goal of this scenario is to allow and deny the following communications:  

[![2]][2]

<br>

Communications in the **red** group:
[![3]][3]

<br>

Communications in the **blue** group:
[![4]][4]

Below the network diagram with more details:

[![5]][5]

## <a name="routing table association"></a>1. Routing Tables and association of the connections  

In this case, three route route tables are used to achieve the wished communications:
- the red virtual networks (vnet1,vnet4,vnet5):
   - Associated route table: **red**
   - Propagating to route tables: **red** and **DefaultRoutingTable**
- blue virtual networks (vnet2,vnet3,vnet6): 
   - Associated route table: **blue**
   - Propagating to route tables: **red** and **DefaultRouteTable**
- branches (branch1, branch2):
   - Associated route table: **DefaultRouteTable**
   - Propagating to route tables: **red**, **blue** and **DefaultRouteTable**

The branches always have to be associated to the **DefaultRoutingTable**.
<br>

The branches need to learn the prefixes from both **red** and **blue** VNets, so all VNets will need to propagate to **DefaultRouteTable**

The associations and propagation of connections for hub1 are shown below:

[![6]][6]

<br><br>

A snippet of ARM template with structure of vnet1 connections is shown below: 
```json
{
   "type": "Microsoft.Network/virtualHubs/hubVirtualNetworkConnections",
   "name": "hub1/vnet1_conn",
   "apiVersion": "2021-02-01",
   "dependsOn": [
         "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', variables('hub1Name'), 'red')]",
         "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', variables('hub2Name'), 'red')]"
   ],
   "properties": {
         "routingConfiguration": {
            "associatedRouteTable": {
               "id": "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', 'hub1', 'red')]"
            },
            "propagatedRouteTables": {
               "ids": [
                     {
                        "id": "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', 'hub1', 'defaultRouteTable')]"
                     },
                     {
                        "id": "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', 'hub2', 'defaultRouteTable')]"
                     },
                     {
                        "id": "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', 'hub1', 'red')]"
                     },
                     {
                        "id": "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', 'hub2, 'red')]"
                     }
               ]
            }
         },
         "remoteVirtualNetwork": {
            "id": "[resourceId('Microsoft.Network/virtualNetworks', 'vnet1']"
         }
   }
}
```
The snippet shows:
- the **associatedRouteTable** to the routing table **red** in hub1 
- the **propagatedRouteTable** to the routing tables **hub1-DefaultRouteTable**, **hub2-DefaultRouteTable**, **hub1-red**, **hub2-red**

The structure of others VNet connections are comparable.
<br> 
The snippet of site-to-site VPN connection for the branch1 is shown below:

```json
{
   "type": "Microsoft.Network/vpnGateways/vpnConnections",
   "apiVersion": "2020-11-01",
   "name": "hub1_S2SvpnGW/hub1Tobranch1",
   "dependsOn": [
         "[resourceId('Microsoft.Network/vpnSites', 'h1-branch1')]"
   ],
   "properties": {
         "routingConfiguration": {
            "associatedRouteTable": {
               "id": "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', 'hub1', 'defaultRouteTable')]"
            },
            "propagatedRouteTables": {
               "ids": [
                     {
                        "id": "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', 'hub1', 'defaultRouteTable')]"
                     },
                     {
                        "id": "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', 'hub1', 'red')]"
                     },
                     {
                        "id": "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', 'hub1', 'blue')]"
                     },
                     {
                        "id": "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', 'hub2', 'defaultRouteTable')]"
                     },
                     {
                        "id": "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', 'hub2', 'red')]"
                     },
                     {
                        "id": "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', 'hub2', 'blue')]"
                     }
               ],
               "labels": [
                     "default"
               ]
            }
         },
         "remoteVpnSite": {
            "id": "[resourceId('Microsoft.Network/vpnSites', 'h1-branch1')]"
         },
         "vpnLinkConnections": [
            {
               "name": "conn1",
               "properties": {
                     "connectionBandwidth": 10,
                     "vpnConnectionProtocolType": "IKEv2",
                     "enableBgp": true,
                     "sharedKey": "[parameters('sharedKey')]",
                     "vpnSiteLink": {
                        "id": "[resourceId('Microsoft.Network/vpnSites/vpnSiteLinks', 'h1-branch1','tunnel1')]"
                     }
               }
            },
            {
               "name": "conn2",
               "properties": {
                     "connectionBandwidth": 10,
                     "vpnConnectionProtocolType": "IKEv2",
                     "enableBgp": true,
                     "sharedKey": "[parameters('sharedKey')]",
                     "vpnSiteLink": {
                        "id": "[resourceId('Microsoft.Network/vpnSites/vpnSiteLinks', 'h1-branch1','tunnel2')]"
                     }
               }
            }
         ]
   }
}
```
The snippet shows:
- the **associatedRouteTable** to the routing table **DefaultRouteTable** in hub1, 
- the **propagatedRouteTable** to the routing tables **hub1-DefaultRouteTable, hub2-DefaultRouteTable, hub1-red, hub2-red,hub1-blue, hub2-blue**


## <a name="Routing tables"></a>2. Routing tables in hub1
The network of the branch1 is advertised through BGP to the hub1 by AS 65010.
The network of the branch2 is advertised through BGP to the hub2 by AS 65011.
Each virtual hub advertised the learned routes to the peer hub through BGP by AS65520.

**DefaultRouteTable in hub1**
| Prefix         | Next Hop Type              | Next Hop       | Origin         | AS path           |
| -------------- | -------------------------- | -------------- | -------------- | ----------------- |
| 192.168.1.0/24 | VPN_S2S_Gateway            | hub1_S2SvpnGW  | hub1_S2SvpnGW  | 65010             |
| 10.0.2.0/24    | Virtual Network Connection | vnet2_conn     | vnet2_conn     |                   |
| 10.0.3.0/24    | Virtual Network Connection | vnet3_conn     | vnet3_conn     |                   |
| 10.0.1.0/24    | Virtual Network Connection | vnet1_conn     | vnet1_conn     |                   |
| 192.168.2.0/24 | Remote Hub                 | hub2           | hub2           | 65520-65520-65011 |
| 10.0.4.0/24    | Remote Hub                 | hub2           | hub2           | 65520-65520       |
| 10.0.5.0/24    | Remote Hub                 | hub2           | hub2           | 65520-65520       |
| 10.0.6.0/24    | Remote Hub                 | hub2           | hub2           | 65520-65520       |

<br>

**Routing table red in hub1**
| Prefix         | Next Hop Type              | Next Hop       | Origin         | AS path           |
| -------------- | -------------------------- | -------------- | -------------- | ----------------- |
| 192.168.1.0/24 | VPN_S2S_Gateway            | hub1_S2SvpnGW  | hub1_S2SvpnGW  | 65010             |
| 10.0.1.0/24    | Virtual Network Connection | vnet1_conn     | vnet1_conn     |                   |
| 192.168.2.0/24 | Remote Hub                 | hub2           | hub2           | 65520-65520-65011 |
| 10.0.4.0/24    | Remote Hub                 | hub2           | hub2           | 65520-65520       |
| 10.0.5.0/24    | Remote Hub                 | hub2           | hub2           | 65520-65520       |
<br>

**Routing table blue in hub1**
| Prefix         | Next Hop Type              | Next Hop       | Origin         | AS path           |
| -------------- | -------------------------- | -------------- | -------------- | ----------------- |
| 192.168.1.0/24 | VPN_S2S_Gateway            | hub1_S2SvpnGW  | hub1_S2SvpnGW  | 65010             |
| 10.0.2.0/24    | Virtual Network Connection | vnet2_conn     | vnet2_conn     |                   |
| 10.0.3.0/24    | Virtual Network Connection | vnet3_conn     | vnet3_conn     |                   |
| 192.168.2.0/24 | Remote Hub                 | hub2           | hub2           | 65520-65520-65011 |
| 10.0.6.0/24    | Remote Hub                 | hub2           | hub2           | 65520-65520       |



## <a name="Routing tables"></a>3. Routing tables in hub2
The network of the branch1 is advertised through BGP to the hub1 by AS 65010.
The network of the branch2 is advertised through BGP to the hub2 by AS 65011.

**DefaultRouteTable in hub2**
| Prefix         | Next Hop Type              | Next Hop       | Origin         | AS path           |
| -------------- | -------------------------- | -------------- | -------------- | ----------------- |
| 192.168.2.0/24 | VPN_S2S_Gateway            | hub2_S2SvpnGW  | hub2_S2SvpnGW  | 65011             |
| 10.0.5.0/24    | Virtual Network Connection | vnet5_conn     | vnet5_conn     |                   |
| 10.0.4.0/24    | Virtual Network Connection | vnet4_conn     | vnet4_conn     |                   |
| 10.0.6.0/24    | Virtual Network Connection | vnet6_conn     | vnet6_conn     |                   |
| 192.168.1.0/24 | Remote Hub                 | hub1           | hub1           | 65520-65520-65010 |
| 10.0.1.0/24    | Remote Hub                 | hub1           | hub1           | 65520-65520       |
| 10.0.2.0/24    | Remote Hub                 | hub1           | hub1           | 65520-65520       |
| 10.0.3.0/24    | Remote Hub                 | hub1           | hub1           | 65520-65520       |

<br>

**Routing table red in hub2**
| Prefix         | Next Hop Type              | Next Hop       | Origin         | AS path           |
| -------------- | -------------------------- | -------------- | -------------- | ----------------- |
| 192.168.2.0/24 | VPN_S2S_Gateway            | hub2_S2SvpnGW  | hub2_S2SvpnGW  | 65011             |
| 10.0.5.0/24    | Virtual Network Connection | vnet5_conn     | vnet5_conn     |                   |
| 10.0.4.0/24    | Virtual Network Connection | vnet4_conn     | vnet4_conn     |                   |
| 192.168.1.0/24 | Remote Hub                 | hub1           | hub1           | 65520-65520-65010 |
| 10.0.1.0/24    | Remote Hub                 | hub1           | hub1           | 65520-65520       |

<br>

**Routing table blue in hub2**
| Prefix         | Next Hop Type              | Next Hop       | Origin         | AS path           |
| -------------- | -------------------------- | -------------- | -------------- | ----------------- |
| 192.168.2.0/24 | VPN_S2S_Gateway            | hub2_S2SvpnGW  | hub2_S2SvpnGW  | 65011             |
| 10.0.6.0/24    | Virtual Network Connection | vnet6_conn     | vnet6_conn     |                   |
| 192.168.1.0/24 | Remote Hub                 | hub1           | hub1           | 65520-65520-65010 |
| 10.0.2.0/24    | Remote Hub                 | hub1           | hub1           | 65520-65520       |
| 10.0.3.0/24    | Remote Hub                 | hub1           | hub1           | 65520-65520       |

<br>

## <a name="Routing tables"></a>4. Effective routing table in VMs
The effective routing table in **vm1**-vnet1:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.1.0/24      | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.10.0.0/23     | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active | 192.168.2.0/24   | Virtual network gateway | 20.42.150.113       | \-                      |
| Virtual network gateway | Active | 192.168.1.0/24   | Virtual network gateway | 10.10.0.12          | \-                      |
| Virtual network gateway | Active | 192.168.1.0/24   | Virtual network gateway | 10.10.0.13          | \-                      |
| Virtual network gateway | Active | 10.0.4.0/24      | Virtual network gateway | 20.42.150.113       | \-                      |
| Virtual network gateway | Active | 10.0.5.0/24      | Virtual network gateway | 20.42.150.113       | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |

 - 10.10.0.12: BGP peering IP of the instance0 of the site-to-site VPN Gateway (hub1_S2SvpnGW) in hub1
 - 10.10.0.13: BGP peering IP of the instance1 of the site-to-site VPN Gateway (hub1_S2SvpnGW) in hub1
 

The effective routing table in **vm6**-vnet6:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.6.0/24      | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.11.0.0/23     | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 40.91.75.236        | \-                      |
| Virtual network gateway | Active | 192.168.1.0/24   | Virtual network gateway | 40.91.75.236        | \-                      |
| Virtual network gateway | Active | 192.168.2.0/24   | Virtual network gateway | 10.11.0.12          | \-                      |
| Virtual network gateway | Active | 192.168.2.0/24   | Virtual network gateway | 10.11.0.13          | \-                      |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 40.91.75.236        | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |

- 10.11.0.12: BGP peering IP of the instance0 of the site-to-site VPN Gateway (hub2_S2SvpnGW) in hub2
- 10.11.0.13: BGP peering IP of the instance1 of the site-to-site VPN Gateway (hub2_S2SvpnGW) in hub2

## <a name="list of ARM templates and scripts"></a>5. List of ARM templates and powershell scripts

| file                        | description                                                               |       
| --------------------------- |:------------------------------------------------------------------------- |
| **01-vwan.json**            | ARM template to create virtual WAN the virtual hub, VNets, routing tables and connections between VNets and virtual hub  |
| **01-vwan.ps1**             | powershell script to deploy the ARM template **01-vwan.json**             |
| **02-vpn.json**             | ARM template to create the remote branch1<br> The ARM template create the vnet, VPN gateway and VM in the branch1 |
| **02-vpn.ps1**              | powershell script to deploy the ARM template **02-vpn.json**              |
| **03-vwan-site.json**       | create in the hub1 a site-to-site connection with the branch1             |
| **03-vwan-site.ps1**        | powershell script to deploy the ARM template **03-vwan-site.json**        |
| **init.json**               | it contains a list of input variables. <br>All the powershell scripts read the init.json to assign the variables values|

Before spinning up the powershell scripts, you should edit the file **init.json** and customize the values:
The structure of **init.json** file is shown below:
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "subscriptionName": "AzureDemo",
    "ResourceGroupName": "vwan1-grp",
    "hub1location": "westus2",
    "branch1location": "westus2",
    "hub1Name": "hub1",
    "sharedKey": "VPN_SHARED_SECRET",
    "mngIP": "MANAGEMENT_PUBLIC_IP_ADDRESS",
    "RGTagExpireDate": "09/30/2021",
    "RGTagContact": "user1@contoso.com",
    "RGTagNinja": "user1",
    "RGTagUsage": "vWAN-configuration with site-to-site VPN"
}
```
<br>

Meaning of the variables:
- **adminUsername**: administrator username of the Azure VMs
- **adminPassword**: administrator password of the Azure VMs
- **subscriptionName**: Azure subscription name
- **ResourceGroupName**: name of the resource group
- **hub1location**: Azure region of the virtual hub1
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

The file **init.json** guaratees a cosnistency by assigment of same values of input paramenters across all the ARM templates.
<br>

## <a name="how to run the deployment"></a>6. How to run the deployment
Deployment needs to be carried out in sequence:
- 1st step: customize the values in **init.json**
- 2nd step: run the script **01-vwan.ps1**
- 3rd step: run the script **02-vpn.ps1**
- 4th step: run the script **03-vwan-site.ps1**

<br>

## <a name="how to get the IPs"></a>7. Useful powershell commands

How to get the public IPs and the BGP peering IPs of the site-to-site VPN Gateway in **hub1**:
```powershell
$vpnGateway = Get-AzVpnGateway -ResourceGroupName $rgName -Name hub1_S2SvpnGW
$vpnGateway.IpConfigurations.PublicIpAddress[0]
$vpnGateway.IpConfigurations.PublicIpAddress[1]
$vpnGateway.BgpSettings.BgpPeeringAddresses[0].DefaultBgpIpAddresses
$vpnGateway.BgpSettings.BgpPeeringAddresses[1].DefaultBgpIpAddresses
```

<br>

How to get the public IPs and the BGP peering IPs of the Azure VPN Gateway in **branch1**:
```powershell
$vpnGtwBranch = Get-AzVirtualNetworkGateway -ResourceGroupName $rgName -Name $vpnGtwBranchName
$vpnGtwBranch.BgpSettings.BgpPeeringAddresses[0].TunnelIpAddresses
$vpnGtwBranch.BgpSettings.BgpPeeringAddresses[1].TunnelIpAddresses
$vpnGtwBranch.BgpSettings.BgpPeeringAddresses[0].DefaultBgpIpAddresses
$vpnGtwBranch.BgpSettings.BgpPeeringAddresses[1].DefaultBgpIpAddresses
```

How to retrieve the routing table setting in hub1:
```powershell
(Get-AzVpnConnection -ResourceGroupName $rgName  -ParentResourceName hub1_S2SvpnGW).RoutingConfiguration
```

To get the <ins>list of routing tables</ins> with properties in hub1:
```powershell
Get-AzVHubRouteTable -ResourceGroupName $rgName -HubName hub1
```

To select the **red** routing table:
```powershell
Get-AzVHubRouteTable -ResourceGroupName $rgName -HubName hub1 -Name red
```

How to check the status of vnet peering between the vnet1 and hub1:
```powershell
Get-AzVirtualNetworkPeering -ResourceGroupName $rgName -VirtualNetworkName vnet1
```

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/communication.png "communications"
[3]: ./media/red.png "network diagram"
[4]: ./media/blue.png "network diagram"
[5]: ./media/network-diagram2.png "network diagram"
[6]: ./media/routing-tables.png "routing tables"

<!--Link References-->

