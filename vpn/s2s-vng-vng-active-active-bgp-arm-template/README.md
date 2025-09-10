<properties
pageTitle= 'ARM template to create Site-to-Site VPN between two Azure VPN Gateways'
description= "ARM template to create Site-to-Site VPN between two Azure VPN Gateways"
documentationcenter: na
services="Azure VPN Gateway"
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

## ARM template to create Site-to-Site VPN between two VPN Gateways

This article contains an ARM template to create to vnets, vnet1 and vnet2, connected through site-to-site VPN. <br>
Two IPsec tunnels are established between the Azure VPN gateways deployed with zonal gateways (SKU: **"VpnGw1AZ", "VpnGw2AZ", "VpnGw3AZ", "VpnGw4AZ", "VpnGw5AZ"**). <br>

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
"[reference(resourceId('Microsoft.Network/publicIPAddresses', variables('publicIPName')),'2024-05-01').ipAddress]"
```

The same function is used in the **vpn.json** to carve out the values of public IPs assigned to each VPN Gateway.
<br>

Below a snippet of **vpn.json** showing how to collect the public IP of the remote vpn gateway and private IP of the remote BGP peer:

```json
        {
            "type": "Microsoft.Network/localNetworkGateways",
            "name": "[variables('localGatewayName11')]",
            "apiVersion": "2024-05-01",
            "comments": "public IP of remote IPSec peer",
            "location": "[variables('location2')]",
            "dependsOn": [
                "[resourceId('Microsoft.Network/virtualNetworkGateways', variables('gateway1Name'))]"
            ],
            "properties": {
                "localNetworkAddressSpace": {
                    "addressPrefixes": []
                },
                "gatewayIpAddress": "[reference(variables('gateway1PublicIP1Id'),'22024-05-01').ipAddress]",
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
>
> 1. edit the file **vpn.ps1** and set the correct values to the variables **$adminUsername**, **$adminPassword**
>
> 2. customize the values of variables in the **init.txt** file: <br>
>    subscriptionName=AZURE_SUBSCRIPTION_NAME <br>
>    ResourceGroupName=RESOURCE_GROUP_NAME <br>
>    location1=NAME_AZURE_REGION_1 <br>
>    location2=NAME_AZURE_REGION_2 <br>
>

<br>
Some powershell commands to fetch information on site-to-site VPN tunnels:  

```powershell
$rgName='test-vpn'
$connectionName11='conn11'
Get-AzVirtualNetworkGatewayConnection -Name $connectionName11 -ResourceGroupName $rgName
(Get-AzVirtualNetworkGatewayConnection -Name $connectionName11 -ResourceGroupName $rgName).ConnectionStatus
(Get-AzVirtualNetworkGatewayConnection -Name $connectionName11 -ResourceGroupName $rgName).EgressBytesTransferred
(Get-AzVirtualNetworkGatewayConnection -Name $connectionName11 -ResourceGroupName $rgName).IngressBytesTransferred
```

```powershell
$rgName='test-vpn'
$connectionName11='conn11'
az network vpn-connection show --name $connectionName11 --resource-group $rgName
az network vpn-connection show --name $connectionName11 --resource-group $rgName --query tunnelConnectionStatus
```


```powershell
$rgName='test-vpn'
$vpnName='gw1'
Get-AzVirtualNetworkGatewayLearnedRoute -VirtualNetworkGatewayName $vpnName -ResourceGroupName $rgName
```

```powershell
$rgName='test-vpn'
$vpnName='gw1'
az network vnet-gateway list-learned-routes -n $vpnName -g $rgName  -o table
```

```powershell
$rgName='test-vpn'
$vpnName='gw1'
Get-AzVirtualNetworkGatewayBGPPeerStatus -VirtualNetworkGatewayName $vpnName -ResourceGroupName $rgName |ft
```

```powershell
$rgName='test-vpn'
$vpnName='gw1'
$peer1=(Get-AzVirtualNetworkGatewayBGPPeerStatus -VirtualNetworkGatewayName $vpnName -ResourceGroupName $rgName).LocalAddress[0]
$peer2=(Get-AzVirtualNetworkGatewayBGPPeerStatus -VirtualNetworkGatewayName $vpnName -ResourceGroupName $rgName).LocalAddress[1]
Get-AzVirtualNetworkGatewayAdvertisedRoute -VirtualNetworkGatewayName $vpnName -ResourceGroupName $rgName -Peer $peer1 | ft
LocalAddress Network       NextHop    SourcePeer Origin AsPath Weight
------------ -------       -------    ---------- ------ ------ ------
10.0.1.197   10.0.2.197/32 10.0.1.197            Igp           0
10.0.1.197   10.0.2.0/24   10.0.1.197            Igp    65002  0
10.0.1.197   10.0.2.196/32 10.0.1.197            Igp           0

```

```powershell
$rgName='test-vpn'
$vpnName='gw1'
az network vnet-gateway list --query [].[name,bgpSettings.asn,bgpSettings.bgpPeeringAddress] -o table -g $rgName
az network vnet-gateway list --query "[?name=='vpnGw1'].[name,bgpSettings.bgpPeeringAddress,bgpSettings.asn]" -o table -g $rgName
az network vnet-gateway list --query "[?name=='vpnGw1'].{Name:name,BGPlocalIP:bgpSettings.bgpPeeringAddress,ASN:bgpSettings.asn}" -o table -g $rgName
```

```bash
$rgName='test-vpn'
$vpnName='gw1'
az network vnet-gateway list-advertised-routes -n $vpnName -g $rgName --peer $peer1
```

`Tags: Azure VPN Gateway, site-to-site VPN` <br>
`date: 11-08-2021` <br>
`date: 11-02-2024` <br>
`date: 09-09-2025` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram with site-to-site VPN details"

<!--Link References-->

