<properties
pageTitle= 'Resize the address space of Azure vnets that are peered'
description= "Resize the address space of Azure vnets that are peered"
documentationcenter: na
services=""
documentationCenter="github"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="howto-Azure-examples"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="resize the address space of the vnets that are peered"
   ms.date="20/09/2022"
   ms.review=""
   ms.author="fabferri" />

# Resize the address space of Azure vnets that are peered
You can resize the address space of Azure virtual networks that are peered without incurring any downtime on the currently peered address space. After resizing the address space, all that is required is for peers to be synced with the new address space changes.

[![1]][1]

The vnet1 and vnet2 are deployed in two different azure regions and are in vnet peering. <br>
The ARM template has a custom script extension to install iperf3 in the VMs. iperf3 is useful tool to verify the TCP flows between vm1 and vm2 do not have downtime interruption along the processes of resizing of address space of the vnet in peering.<br>


**NOTE:** 
* adding network prefix to the address space to a vnet in peering works only if the new network prefix doesn't overlap other address spaces.
* When an update is made to the address space for a virtual network, you will need to sync the virtual network peer for each remote peered VNet to learn of the new address space updates. The synchronization commands are:
```powershell
Sync-AzVirtualNetworkPeering
    -VirtualNetworkName <String>
    -ResourceGroupName <String>
    -Name <String>

Sync-AzVirtualNetworkPeering
    -VirtualNetworkPeering <PSVirtualNetworkPeering>
```

The article walks you through three different actions:
* <ins>add a new address prefix</ins> to the address space of a vnet in peering. It is achievable by **adding-new-NetworkPrefix.ps1**
* <ins>change the address prefix</ins> of a vnet in peering. It can be achieved by **change-NetworkPrefix.ps1**
* <ins>delete the existing address prefix</ins> in a vnet in peering. It can be achieved by **remove-existingNetworkPrefix.ps1**

## <a name="list of files"></a>1. File list

| File name                 | Description                                                                                 |
| ------------------------- | ------------------------------------------------------------------------------------------- |
| **init.json**             | define the value of input variables required for the deployment                             |
| **vnets.json**            | ARM template to deploy two vnets in different azure regions, vnet peering, VMs              |
| **vnets.ps1**             | powershell script to run **vnets.json**                                                     |
| **adding-new-NetworkPrefix.ps1** | script for adding a new network prefix to address space of the vnet1                 |
| **change-NetworkPrefix.ps1**     | script for change (extend or shrink) the network prefix in the address space of vnet1|
| **remove-existingNetworkPrefix.ps1** | script to delete a network prefix in the address space of vnet1                  |


The meaning of input variables in **init.json** are shown below:
```json
{
    "subscriptionName": "NAME_OF_AZURE_SUBSCRIPTION",
    "ResourceGroupName": "NAME_OF_RESOURCE_GROUP",
    "location1": "AZURE_LOCATION_VNET1",
    "location2": "AZURE_LOCATION_VNET2",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "authenticationType": "AUTHETICATION_TYPE", 
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "mngIP": "PUBLIC_IP_ADDRESS_TO_FILTER_SSH_ACCESS_TO_VMS - it can be empty string, if you do not want to lock SSH access to a specific IP by NSG!"
}
```
The **autheticationType** can take the two allow values: "password" or "sshPublicKey".


## <a name="Add a new address prefix"></a>2. Add a new address prefix to the vnet1
After the deployment of the ARM template, the address space in vnet2 is shown:
```powershell
(Get-AzVirtualNetworkPeering -name vnet2Tovnet1 -ResourceGroupName rg-prod -VirtualNetworkName vnet2).PeeredRemoteAddressSpace.AddressPrefixes
10.1.0.0/24

(Get-AzVirtualNetworkPeering -name vnet2Tovnet1 -ResourceGroupName rg-prod -VirtualNetworkName vnet2).RemoteVirtualNetworkAddressSpace.AddressPrefixes
10.1.0.0/24
```

Let run the script **adding-new-NetworkPrefix.ps1** to add the new network prefix 10.101.0.0/24 to the vnet1:

[![2]][2]

```powershell
(Get-AzVirtualNetworkPeering -name vnet2Tovnet1 -ResourceGroupName rg-prod -VirtualNetworkName vnet2).PeeredRemoteAddressSpace.AddressPrefixes
10.1.0.0/24
10.101.0.0/24

(Get-AzVirtualNetworkPeering -name vnet2Tovnet1 -ResourceGroupName rg-prod -VirtualNetworkName vnet2).RemoteVirtualNetworkAddressSpace.AddressPrefixes
10.1.0.0/24
10.101.0.0/24
```

## <a name="Change the existing network prefix"></a>3. Change of the existing network prefix in vnet1
Check the address space in vnet2:
```powershell
(Get-AzVirtualNetworkPeering -name vnet2Tovnet1 -ResourceGroupName rg-prod -VirtualNetworkName vnet2).PeeredRemoteAddressSpace.AddressPrefixes
10.1.0.0/24
10.101.0.0/24

(Get-AzVirtualNetworkPeering -name vnet2Tovnet1 -ResourceGroupName rg-prod -VirtualNetworkName vnet2).RemoteVirtualNetworkAddressSpace.AddressPrefixes
10.1.0.0/24
10.101.0.0/24
```

Let run the script  **change-NetworkPrefix.ps1**; the script extends in the vnet1 the network prefix from 10.101.0.0/24 to 10.101.0.0/23:

[![3]][3]

```powershell
(Get-AzVirtualNetworkPeering -name vnet2Tovnet1 -ResourceGroupName rg-prod -VirtualNetworkName vnet2).PeeredRemoteAddressSpace.AddressPrefixes
10.1.0.0/24
10.101.0.0/23

(Get-AzVirtualNetworkPeering -name vnet2Tovnet1 -ResourceGroupName rg-prod -VirtualNetworkName vnet2).RemoteVirtualNetworkAddressSpace.AddressPrefixes
10.1.0.0/24
10.101.0.0/23
```

## <a name="remove a network prefix"></a>3. Remove a network prefix in vnet1
The address space in vnet2:
```powershell
(Get-AzVirtualNetworkPeering -name vnet2Tovnet1 -ResourceGroupName rg-prod -VirtualNetworkName vnet2).PeeredRemoteAddressSpace.AddressPrefixes
10.1.0.0/24
10.101.0.0/23

(Get-AzVirtualNetworkPeering -name vnet2Tovnet1 -ResourceGroupName rg-prod -VirtualNetworkName vnet2).RemoteVirtualNetworkAddressSpace.AddressPrefixes
10.1.0.0/24
10.101.0.0/23
```

Let run the script **remove-existingNetworkPrefix.ps1** to remove the network prefix 10.101.0.0/23 in the vnet1:

[![4]][4]

```powershell
(Get-AzVirtualNetworkPeering -name vnet2Tovnet1 -ResourceGroupName rg-prod -VirtualNetworkName vnet2).PeeredRemoteAddressSpace.AddressPrefixes
10.1.0.0/24


(Get-AzVirtualNetworkPeering -name vnet2Tovnet1 -ResourceGroupName rg-prod -VirtualNetworkName vnet2).RemoteVirtualNetworkAddressSpace.AddressPrefixes
10.1.0.0/24
```


`Tags: resize address space of vnets in peering, vnets`
`date: 20-09-22`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/add-address-prefix.png "add a new address prefix to the address space of a vnet in peering"
[3]: ./media/change-address-prefix.png "change the address prefix of a vnet in peering"
[4]: ./media/remove-address-prefix.png "remove the existing address prefix in a vnet in peering"

<!--Link References-->
