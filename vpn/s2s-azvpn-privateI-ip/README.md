<properties
pageTitle= 'Site-to-Site VPN connection over vnet peering using VPN Gateway private IP addresses'
description= "Site-to-Site VPN connection over vnet peering using VPN Gateway private IP addresses"
services="Azure VPN"
documentationCenter="[github](https://github.com/fabferri/)"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure networking"
   ms.workload="VPN Gateway"
   ms.date="21/11/2023"
   ms.author="fabferri" />

# Site-to-Site VPN connection over vnet peering using VPN Gateway private IP addresses
This article contains ARM templates to create Site-to-Site VPN between Azure VNets using private IP addresses. <br>
The network configuration is illustrated in the diagram below:

[![1]][1]

The script sets up three different VNets across three Azure regions (specified in the ARM template by parameters **location1**, **location2**, and **location3**). The Azure VPN gateways are deployed in an active-active configuration.

### Key Points:
- **vpnGtw1** is created in **vnet1** with active-active mode and BGP.
- **vpnGtw2** is created in **vnet2** with active-active mode and BGP.
- **vnet1** and **vnet2** are not peered.
- Two IPSec tunnels are established between **vpnGtw1** and **vpnGtw2**.

To enable Site-to-Site tunnels through the private IPs of the VPN Gateway, the following settings are required:
- resource type: **Microsoft.Network/virtualNetworkGateways**, setting required: **"enablePrivateIpAddress": true**
- resource type: **Microsoft.Network/connections**, setting required: **"useLocalAzureIpAddress": true**

## Files Description
- `init.txt`: it contains a variables used as input of the ARM templates. The powershell script **vpn1.ps1** and **vpn2.ps1** start, the file init.txt is read the variables. 
- `01_vpn1.json`: ARM template creates the vnet1, vnet2, vpngw1, vpgw2, vm1 and vm2
- `01_vpn1.json`: powershell script to run the ARM template **01_vpn1.json** 
- `02_vpn2.json`: ARM template to create local networks and connections for the vpngw1 and vpngw2
- `02_vpn2.ps1`: powershell script to run the ARM template **02_vpn2.json** 
- `03_vnet99.json`: ARM template to create vnet99 and the two vnet peering: vnet1-vnet99 and vnet2-vnet99
- `03_vnet99.ps1`: powershell script to run the ARM template **03_vnet99.json** 
- `collect-priv-ip.json`: ARM template to collect private IP addresses and BGP IP addresses of the vpngw1 and vpngw2. the ARM template do not make any deployment
* `collect-priv-ip.ps1`: powershell script to run the ARM template **collect-priv-ip.json**

> [!NOTE]
>
> Before deploying the ARM template, set the variable names in the `init.txt` file:
> - subscriptionName = SUBSCRIPTION_NAME <br>
> - ResourceGroupName = RESOURCE_GROUP_NAME <br>
> - location1 = AZURE_REGION_vnet1 <br>
> - location2 = AZURE_REGION_vnet2 <br>
> - location99 = AZURE_REGION_vnet99 <br>
> - adminUsername = ADMINISTRATOR_USERNAME <br>
> - adminPassword = ADMINISTRATOR_PASSWORD <br>
>


## <a name="01_vpn1.json"></a> Provisioning of VPN Gateway
In **01_vpn1.json** to enable the transit of the Site-to-Site IPsec tunnels through the private IPs addresses of the VPN Gateway is required the following setting in the resource type **Microsoft.Network/virtualNetworkGateways**:

```json
"enablePrivateIpAddress": true
```
This property is also shown in the Azure portal:

[![2]][2]

> [!NOTE]
> When setting up the Site-to-Site tunnels between **vpnGw1** and **vpnGw2**, the private IPs of the VPN Gateways are used. However, Azure VPN Gateways require the association of public IPs to communicate with the VPN control plane.<br>
>


## <a name="02_vpn2.json"></a> VPN Gateways

The **vpn2.json** references the existing private IPs of the VPN gateway instances. As reported in the official Microsoft documentation, **reference an existing resource (or one not defined in the same template), a full resourceId must be supplied to the reference() function**. <br>
In the AM template **vpn2.json**, you can retrieve the private IP addresses of VPN Gateway instance_0 and instance_1 by: 

```json
"[reference(resourceId('Microsoft.Network/virtualNetworkGateways',variables('gateway1Name')),'2023-11-01').ipConfigurations[0].properties.privateIPAddress]"

"[reference(resourceId('Microsoft.Network/virtualNetworkGateways',variables('gateway1Name')),'2023-11-01').ipConfigurations[1].properties.privateIPAddress ]"
```

To get the VPN Gateway private IPs in powershell:
```powershell
((Get-AzVirtualNetworkGateway -Name $vpngw1Name -ResourceGroupName $rg)[0].IpConfigurations).PrivateIpAddress[0]
((Get-AzVirtualNetworkGateway -Name $vpngw1Name -ResourceGroupName $rg)[0].IpConfigurations).PrivateIpAddress[1]
```

In the same way, to get the BGP private IPs of the VPN gateway instance_0 and instance_1: 
```json
"[first(split( reference(resourceId('Microsoft.Network/virtualNetworkGateways',variables('gateway1Name')),'2023-11-01').bgpSettings.bgpPeeringAddress , ','))]"

"[last(split( reference(resourceId('Microsoft.Network/virtualNetworkGateways',variables('gateway1Name')),'2023-11-01').bgpSettings.bgpPeeringAddress , ','))]",
```


* the function **split** accepts in input a string and returns an array of strings that contains the substrings of the input string that are delimited by the specified delimiters. 
* the function **first** accepts in input an array of string and returns the first element of the array.



An alternative method to extract the BGP IPs of the VPN Gateway is by using the array index, though it may not be the most refined approach:
```json
"[split( reference(resourceId('Microsoft.Network/virtualNetworkGateways',variables('gateway1Name'))).bgpSettings.bgpPeeringAddress , ',')[0]]"

"[split( reference(resourceId('Microsoft.Network/virtualNetworkGateways',variables('gateway1Name'))).bgpSettings.bgpPeeringAddress , ',')[1]]",
```

VPN private IPs and BGP IPs are both required to define the local network gateways; an example of Local Network Gateway for the vpnGw1 instance_0:
```json 
{
   "type": "Microsoft.Network/localNetworkGateways",
   "name": "[variables('localGatewayName11')]",
   "apiVersion": "2023-11-01",
   "comments": "public IP of remote IPSec peer",
   "location": "[variables('location2')]",
   "dependsOn": [],
   "properties": {
         "gatewayIpAddress": "[reference(resourceId('Microsoft.Network/virtualNetworkGateways',variables('gateway1Name')),'2023-11-01').ipConfigurations[0].properties.privateIPAddress]",
         "bgpSettings": {
         "asn": "[variables('asnGtw1')]",
         "bgpPeeringAddress": "[first(split( reference(resourceId('Microsoft.Network/virtualNetworkGateways',variables('gateway1Name')),'2023-11-01').bgpSettings.bgpPeeringAddress , ','))]",
         "peerWeight": 0
         }
   }
}
```

To enable the transit of Site-to-Site tunnels through the private peering is required the enablement in the Connections (resource type: **Microsoft.Network/connections**):
```json
"useLocalAzureIpAddress": true
``` 
This setting is shown in the Azure management portal:

[![3]][3]

The VPN Gateway to show all the properties of a VPN Gateway:
```powershell
(Get-AzVirtualNetworkGateway -Name $vpngw1Name -ResourceGroupName $rg) | fc
```

## <a name="03_vnet99.json"></a> VNet peering and VM with ip forwarding in vnet99
The properties of the vnet peering are shown in the diagram:

[![4]][4]


A UDR is applied to the GatewaySubnet of the VPN Gateways to route traffic to **vm99** in **vnet99**. The **vm99** must function as a router, receiving packets from one VPN Gateway and forwarding the traffic to the other VPN Gateway. To enable the router behavior in **vm99**, the following settings are required:
- In the ARM template **03_vnet99.json**, IP forwarding in the **vm99-NIC** is activated by the property **"enableIPForwarding": true** in the resource type **Microsoft.Network/networkInterfaces**.
- IP forwarding in the OS (Ubuntu) is enabled by a custom script extension, running the following command at bootstrap:
```bash
sed -i -e '$a\net.ipv4.ip_forward = 1' /etc/sysctl.conf && sysctl -p  
```

## <a name="Checking traffic in transit through vm99"></a> Checking traffic in transit through vm99
The communication between the two Azure VPN Gateways can be verified by tcpdump in the vm99:

```bash
root@vm99:~# tcpdump -i eth0 net 10.0.10.0/24 or net 10.0.20.0/24
```

`Tags: Azure VPN, Site-to-Site VPN` <br>
`date: 21-11-2023` <br>

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram1"
[2]: ./media/enablePrivateIpAddress.png "enable Private IP Address in VPN Gateway"
[3]: ./media/vpn-connection.png "enable Private IP Address in VPN Connection"
[4]: ./media/vnet-peering.png "vnet peering setting"

<!--Link References-->

