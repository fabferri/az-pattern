<properties
pageTitle= 'Migration of a spoke vnet peering between two hub vnets'
description= "Migration of a spoke vnet peering between two hub vnets"
documentationcenter: github
services="Azure vnet peering"
documentationCenter="na"
authors="fabferri"
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="powershell"
   ms.topic="article, script"
   ms.tgt_pltfrm="na"
   ms.workload="vnet peering"
   ms.date="22/05/2022"
   ms.author="fabferri" />

## Migration of a spoke vnet peering between two hub vnets

The article aims to discuss the migration of spoke vnet in peering with hub vnet to a new hub vnet.
the initial configuration is shown in the network diagram:

[![1]][1]


- All the vnets are deployed in the same Azure subscription, but in different resource groups.
- The hub1 and hub2 vnet are configured with a Gateway subnet with Virtual Network Gateway (Expressroute Gateway or/and VPN Gateway) for a connectivity with remote networks.
- the hub1 vnet is the origin hub vnet
- the hub2 vnet is the destination vnet
- spoke vnet is the spoke vnet with initial peering to the hub1

The migration of vnet peering in spoke vnet is excuted in steps:
1. create a new vnet peering between the spoke and the hub2 (destination) vnet
2. delete the vnet peering between the hub1 (origin) and the spoke vnet
3. change the attribute of new vnet peering between the spoke vnet and destination hub vnet: 
   - enable ALLOW GATEWAY TRANSIT attribute in the peering from the destination hub to the spoke vnet
   - enable USE REMOTE GATEWAY attribute in the peering from the spoke vnet to the destination hub vnet

[![2]][2]

The migration uses the powershell script named **migration.ps1**. The script **migration-rollback.ps1** executes a rollback of the vnet peering, reinstate the orgin configuration.
The scripts **migration.ps1** and **migration-rollback.ps1** are identical, with the only difference of initial variables:
- **$origin_rgNamehubName**
- **$origin_hubvnetName**
- **$destination_rgNamehubName** 
- **$destination_hubvnetName** 

The network configuration after execution of the **migration.ps1** script is shown below:

[![3]][3]


## <a name="powershell commands to manage vnet peering "></a> List of azure powershell to manage the vnet peering

Create vnet peering:
```powershell
$hubvnet = get-AzVirtualNetwork -ResourceGroupName $rgNamehubName -Name $hubvnetName 
$spokevnet = get-AzVirtualNetwork -ResourceGroupName $rgNamespokeName -Name $spokevnetName 
Add-AzVirtualNetworkPeering -Name $hubVNetPeeringName -VirtualNetwork $hubvnet -RemoteVirtualNetworkId $spokeVNet.Id -AllowForwardedTraffic 
Add-AzVirtualNetworkPeering -Name $spokeVNetPeeringName -VirtualNetwork $spokeVNet -RemoteVirtualNetworkId $hubvnet.Id -AllowForwardedTraffic
```

Get vnet peering:
```powershell
$hubvnetPeering = Get-AzVirtualNetworkPeering  -Name $hubVNetPeeringName -VirtualNetwork $hubVNetName -ResourceGroupName $rgNamehubName
$spokevnetPeering = Get-AzVirtualNetworkPeering  -Name $spokeVNetPeeringName -VirtualNetwork $spokeVNetName -ResourceGroupName $rgName
```

Delete vnet peering:
```powershell
$hubvnet = get-AzVirtualNetwork -ResourceGroupName $rgNamehubName -Name $hubvnetName 
$spokevnet = get-AzVirtualNetwork -ResourceGroupName $rgNamespokeName -Name $spokevnetName 
$hubvnetPeering = Get-AzVirtualNetworkPeering  -Name $hubVNetPeeringName -VirtualNetwork $hubVNetName -ResourceGroupName $rgNamehubName
$spokevnetPeering = Get-AzVirtualNetworkPeering  -Name $spokeVNetPeeringName -VirtualNetwork $spokeVNetName -ResourceGroupName $rgNamespokeName
Remove-AzVirtualNetworkPeering -Name $hubvnetPeering.Name -VirtualNetworkName  $hubvnet.Name -ResourceGroupName $rgNamehubName -Force
Remove-AzVirtualNetworkPeering -Name $spokevnetPeering.Name -VirtualNetworkName  $spokeVNet.Name -ResourceGroupName $rgNamespokeName -Force
```

Setting vnet peering properties:
```powershell
$spokeVNetPeering = Get-AzVirtualNetworkPeering  -Name $spokeVNetPeeringName -VirtualNetwork $spokeVNetName -ResourceGroupName $rgNamespokeName
$spokeVNetPeering.UseRemoteGateways = $True
# Update the virtual network peering
Set-AzVirtualNetworkPeering -VirtualNetworkPeering $spokeVNetPeeringvnetPeering

$hubvnetPeering = Get-AzVirtualNetworkPeering  -Name $hubVNetPeeringName -VirtualNetwork $hubVNetName -ResourceGroupName $rgNamehubName
$hubvnetPeering.AllowGatewayTransit = $True
# Update the virtual network peering
Set-AzVirtualNetworkPeering -VirtualNetworkPeering $hubvnetPeering
```

<!--Image References-->

[1]: ./media/network-diagram1.png "initial network diagram"
[2]: ./media/network-diagram2.png "apply a change in the network configuration"
[3]: ./media/network-diagram3.png "final network diagram"

<!--Link References-->

