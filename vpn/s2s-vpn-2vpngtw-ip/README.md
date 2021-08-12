<properties
pageTitle= 'Single ARM template to create Site-to-site VPN between two VPN Gateways'
description= "Single ARM template to create Site-to-site VPN between two VPN Gateways"
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
   ms.date="11/08/2021"
   ms.author="fabferri" />

## Single ARM template to create Site-to-site VPN between two VPN Gateways

This article contains an ARM template to create to vnets, vnet1 and vnet2, connected through site-to-site VPN. 
<br>

Two IPsec tunnels are established between the Azure VPN gateways deployed with zonal gateways (SKU: **"VpnGw1AZ", "VpnGw2AZ", "VpnGw3AZ", "VpnGw4AZ", "VpnGw5AZ"**).
<br>

Zonal VPN Gateways require public IP with Standard SKU and static assigment.

[![1]][1]


| file                | description                                                               |       
| ------------------- |:------------------------------------------------------------------------- |
| **vpn.json**        | ARM template to create two VNets interconnected through site-to-site VPN  |
| **vpn.ps1**         | powershell script to deploy the ARM template **vpn1.json**                |
| **public-ip.json**  | basic ARM template to create a public IP with standard SKU                |
| **public-ip.ps1**   | powershell script to deploy the ARM template **public-ip.json**           |


As reported in the **public-ip.json**, the value of the public IP can be retrieved by the function:

```json
"[reference(resourceId('Microsoft.Network/publicIPAddresses', variables('publicIPName')),'2020-11-01').ipAddress]"
```

The same function is used in the **vpn.json** to carve out the values of public IPs assigned to each VPN Gateway.
<br>

Below a snippet of **vpn.json** showing how to collect the public IP of the remote vpn gateway and private IP of the remote BGP peer:
```json
        {
            "type": "Microsoft.Network/localNetworkGateways",
            "name": "[variables('localGatewayName11')]",
            "apiVersion": "2020-11-01",
            "comments": "public IP of remote IPSec peer",
            "location": "[variables('location2')]",
            "dependsOn": [
                "[resourceId('Microsoft.Network/virtualNetworkGateways', variables('gateway1Name'))]"
            ],
            "properties": {
                "localNetworkAddressSpace": {
                    "addressPrefixes": []
                },
                "gatewayIpAddress": "[reference(variables('gateway1PublicIP1Id'),'2020-11-01').ipAddress]",
                "bgpSettings": {
                    "asn": "[variables('asnGtw1')]",
                    "bgpPeeringAddress": "[first(split( reference(resourceId('Microsoft.Network/virtualNetworkGateways',variables('gateway1Name')),'2020-06-01').bgpSettings.bgpPeeringAddress , ','))]",
                    "peerWeight": 0
                }
            }
        },
```

[![2][2]



> [!NOTE]
> Before spinning up the ARM template you should:
> 1. edit the file **vms.ps1** and set the administrator username and password of the Azure VMs in the variables **$adminUsername**, **$adminPassword**
>
> 2. customize the values of variables stored in the **init.txt** file
>

<br>
Some powershell commands to fetch information on site-to-site VPN tunnels:  

```powershell
$rgName='test-vpn'
$connectionName11='gtw1-to-gtw2-pubIP1'
Get-AzVirtualNetworkGatewayConnection -Name $connectionName11 -ResourceGroupName $rgName
(Get-AzVirtualNetworkGatewayConnection -Name $connectionName11 -ResourceGroupName $rgName).ConnectionStatus
(Get-AzVirtualNetworkGatewayConnection -Name $connectionName11 -ResourceGroupName $rgName).EgressBytesTransferred
(Get-AzVirtualNetworkGatewayConnection -Name $connectionName11 -ResourceGroupName $rgName).IngressBytesTransferred
```

```powershell
$rgName='test-vpn'
$vpnName='vpnGw1'
Get-AzVirtualNetworkGatewayLearnedRoute -VirtualNetworkGatewayName $vpnName -ResourceGroupName $rgName
```

```powershell
$rgName='test-vpn'
$vpnName='vpnGw1'
Get-AzVirtualNetworkGatewayBGPPeerStatus -VirtualNetworkGatewayName $vpnName -ResourceGroupName $rgName |ft
```

```powershell
$rgName='test-vpn'
$vpnName='vpnGw1'
$peer1=(Get-AzVirtualNetworkGatewayBGPPeerStatus -VirtualNetworkGatewayName $vpnName -ResourceGroupName $rgName).LocalAddress[0]
$peer2=(Get-AzVirtualNetworkGatewayBGPPeerStatus -VirtualNetworkGatewayName $vpnName -ResourceGroupName $rgName).LocalAddress[1]
Get-AzVirtualNetworkGatewayAdvertisedRoute -VirtualNetworkGatewayName $vpnName -ResourceGroupName $rgName -Peer $peer1 | ft
LocalAddress Network         NextHop    SourcePeer Origin AsPath Weight
------------ -------         -------    ---------- ------ ------ ------
10.100.3.4   10.200.0.228/32 10.100.3.4            Igp                0
10.100.3.4   10.200.0.229/32 10.100.3.4            Igp                0
10.100.3.4   10.200.0.0/24   10.100.3.4            Igp    65002       0

```

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram with site-to-site VPN details"

<!--Link References-->

