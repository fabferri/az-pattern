<properties
pageTitle= 'Virtual WAN: configuration with site-to-site VPN'
description= "Virtual WAN: configuration with site-to-site VPN"
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

## Virtual WAN: configuration with site-to-site VPN

This article reports a configuration with two VNets connected to one virtual hub and a site-to-site connection. The VNets are associated and propagated to the defaultRouteTable. Below the network diagram:

[![1]][1]


The configuration support any-to-any communication between VNets:
- vnet1 and vnet2 can communicate
- vnet1 can communicate with the branch1
- vnet2 can communicate with the branch1
<br>

### <a name="routing of the connection"></a>1. Routing configuration of the connections  

[![2]][2]


### <a name="file list"></a>2. File list
| file                        | description                                                               |       
| --------------------------- |:------------------------------------------------------------------------- |
| **01-vwan.json**            | ARM template to create virtual WAN the virtual hub, VNets, routing tables and connections between VNets and virtual hub  |
| **01-vwan.ps1**             | powershell script to deploy the ARM template **01-vwan.json**             |
| **02-vpn.json**             | ARM template to create the remote branch1<br> The ARM template create the vnet, VPN gateway and VM in the branch1 |
| **02-vpn.ps1**              | powershell script to deploy the ARM template **02-vpn.json**              |
| **03-vwan-site.json**       | create in the hub1 a site-to-site connection with the branch1             |
| **03-vwan-site.ps1**        | powershell script to deploy the ARM template **03-vwan-site.json**        |

<br>

### <a name="structure of the file init.json"></a>13. Structure of init.json file
Before spinning up the powershell scripts, you should edit the file **init.json** and customize the values:
The structure of **init.json** file is shown below:
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "subscriptionName": "AzureDemo",
    "ResourceGroupName": "vwan1-grp",
    "vwanName" : "vwan2",
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
- **vwanName**: virtual WAN name
- **hub1location**: Azure region of the virtual hub1
- **branch1location**: Azure region to deploy the branch1
- **hub1Name**: name of the virtual hub1
- **sharedKey**: VPN shared secret
- **mngIP**: public IP used to connect to the Azure VMs in SSH
- **RGTagExpireDate**: tag assigned to the resource group. It is used to track the expiration date of the deployment in testing.
- **RGTagContact**: tag assigned to the resource group. It is used to email to the owner of the deployment
- **RGTagNinja**: alias of the user
- **RGTagUsage**: short description of the deployment purpose

<br>

### <a name="how to run the deployment"></a>1. how to run the deployment
Deployment needs to be carried out in sequence:
- 1st step: customize the values in **init.json**
- 2nd step: run the script **01-vwan.ps1**
- 3rd step: run the script **02-vpn.ps1**
- 4th step: run the script **03-vwan-site.ps1**


### <a name="how to get the IPs"></a>1. how to fetch the IPs and BGP peering IPs of the VPN Gateways

The diagram below shows how to fetch the public IPs and BGP peering IPs in site-to-site VPN and in the branch1:

[![3]][3]

To get the public IPs and the BGP peering IPs of the site-to-site VPN Gateway in **hub1**:
```powershell
$vpnGateway = Get-AzVpnGateway -ResourceGroupName $rgName -Name hub1_S2SvpnGW
$vpnGateway.IpConfigurations.PublicIpAddress[0]
$vpnGateway.IpConfigurations.PublicIpAddress[1]
$vpnGateway.BgpSettings.BgpPeeringAddresses[0].DefaultBgpIpAddresses
$vpnGateway.BgpSettings.BgpPeeringAddresses[1].DefaultBgpIpAddresses
```
The same values can be grabbed from the Azure management portal:

[![4]][4]

<br>

To get the public IPs and the BGP peering IPs of the Azure VPN Gateway in **branch1**:
```powershell
$vpnGtwBranch = Get-AzVirtualNetworkGateway -ResourceGroupName $rgName -Name $vpnGtwBranchName
$vpnGtwBranch.BgpSettings.BgpPeeringAddresses[0].TunnelIpAddresses
$vpnGtwBranch.BgpSettings.BgpPeeringAddresses[1].TunnelIpAddresses
$vpnGtwBranch.BgpSettings.BgpPeeringAddresses[0].DefaultBgpIpAddresses
$vpnGtwBranch.BgpSettings.BgpPeeringAddresses[1].DefaultBgpIpAddresses
```

To retrieve the routing table setting in hub1:
```powershell
(Get-AzVpnConnection -ResourceGroupName $rgName  -ParentResourceName hub1_S2SvpnGW).RoutingConfiguration
```


<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram"
[3]: ./media/network-diagram3.png "network diagram"
[4]: ./media/network-diagram4.png "network diagram"

<!--Link References-->

