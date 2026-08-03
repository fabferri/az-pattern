<properties
pageTitle= 'Summarization of address prefixes advertised to an ExpressRoute circuit'
description= "Apply and remove summarization of address prefixes advertised to an ExpressRoute circuit"
documentationcenter: github
services="Azure ExpressRoute Gateway"
documentationCenter="https://github.com/fabferri"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="na"
   ms.date="02/08/2026"
   ms.author="fabferri" />

# ExpressRoute Gateway Route Summarization

## Contents

- [Introduction](#introduction)
- [1. Routing without summarization at the beginning](#1-routing-without-summarization-at-the-beginning)
- [2. Applying summarization in vnet1](#2-applying-summarization-in-vnet1)
- [3. Adding new networks to the hub vnet1 address space](#3-adding-new-networks-to-the-hub-vnet1-address-space)
- [4. Adding a new summary route to the summarization property](#4-adding-a-new-summary-route-to-the-summarization-property)
- [5. Adding a new prefix to spoke-1](#5-adding-a-new-prefix-to-spoke-1)
- [6. Adding a new major network to summarization property - not associated to any vnet address space](#6-adding-a-new-major-network-to-summarization-property---not-associated-to-any-vnet-address-space)
- [7. Remove the summarization by ARM template](#7-remove-the-summarization-by-arm-template)
- [8. Applying the summarization by ARM template](#8-applying-the-summarization-by-arm-template)

## Introduction

This article reports the validation of route summarization in a hub-and-spoke topology. The hub virtual network contains an ExpressRoute gateway connected to an ExpressRoute circuit.

The objective of this validation is to confirm that route summarization operates as expected after the feature reaches general availability. The test verifies summarized route propagation between the hub, connected spokes, and the ExpressRoute circuit, while confirming that existing ExpressRoute connectivity and FastPath functionality remain operational.

**Lab setup:**

- The hub and spoke virtual networks are deployed in **UK South**.
- The ExpressRoute gateway in the hub virtual network (vnet1) uses the **ErGw3AZ** SKU.
- The ExpressRoute circuit named SEA-Cust11-ER is deployed in **West US 2**, with Seattle as the ExpressRoute peering location and Equinix as the provider. Bandwidth is set to 50Mbps. The circuit is in a different subscription from the hub-and-spoke virtual networks. The **Premium** SKU is required because the circuit connects to a virtual network in a different geopolitical region.
- **FastPath** is enabled on the ExpressRoute connection.
- Setting of vnet peering in vnet1:
    - "allowVirtualNetworkAccess": true,
    - "allowForwardedTraffic": true,
    - "allowGatewayTransit": true,
    - "useRemoteGateways": false,
- Setting of vnet peering in spoke vnets:
    - "allowVirtualNetworkAccess": true,
    - "allowForwardedTraffic": true,
    - "allowGatewayTransit": false,
    - "useRemoteGateways": true,

[![1]][1]

## 1. Routing without summarization at the beginning

### VNets address space

```azurecli
az network vnet show --resource-group test-summarization-er --name vnet1 --query "addressSpace.addressPrefixes" -o tsv
10.0.1.0/24

az network vnet show --resource-group test-summarization-er --name spoke-1 --query "addressSpace.addressPrefixes" -o tsv
10.90.0.0/24
10.90.1.0/24
10.90.2.0/24
10.90.3.0/24
10.90.4.0/24
10.90.5.0/24
10.90.6.0/24
10.90.7.0/24

az network vnet show --resource-group test-summarization-er --name spoke-2 --query "addressSpace.addressPrefixes" -o tsv
10.90.8.0/24
10.90.9.0/24
10.90.10.0/24
10.90.11.0/24


az network vnet show --resource-group test-summarization-er --name spoke-3 --query "addressSpace.addressPrefixes" -o tsv
10.90.16.0/24
10.90.17.0/24
10.90.18.0/24
10.90.19.0/24


az network vnet show --resource-group test-summarization-er --name spoke-4 --query "addressSpace.addressPrefixes" -o tsv
10.90.24.0/24
10.90.25.0/24
10.90.26.0/24
10.90.27.0/24


az network vnet show --resource-group test-summarization-er --name spoke-5 --query "addressSpace.addressPrefixes" -o tsv
10.90.32.0/24
10.90.33.0/24
10.90.34.0/24
10.90.35.0/24


az network vnet show --resource-group test-summarization-er --name spoke-6 --query "addressSpace.addressPrefixes" -o tsv
10.90.40.0/24
10.90.41.0/24
10.90.42.0/24
10.90.43.0/24
```

### Routing table in the ExpressRoute private peering (MSEE routers)

```powershell
az network express-route list-route-tables `
   --resource-group SEA-Cust11 `
   --name SEA-Cust11-ER `
   --peering-name AzurePrivatePeering `
   --path primary `
   --query "value[].{Network:network, NextHop:nextHop, Path:path}" -o table
```

<ins>Without summarization</ins>, the MSEE routers learn all individual /24 routes from each spoke (28 spoke routes total, each with 3 next-hops from the ErGw3AZ instances):

```
Network        NextHop        Path
-------------  -------------  ------
10.0.1.0/24    10.0.1.204*    65515       <- vnet1
10.0.1.0/24    10.0.1.207     65515       <- vnet1
10.0.1.0/24    10.0.1.208     65515       <- vnet1
10.1.11.0/25   192.168.11.17  65020       <- on-premises network
10.90.0.0/24   10.0.1.204*    65515       <- spoke-1
10.90.0.0/24   10.0.1.207     65515       <- spoke-1
10.90.0.0/24   10.0.1.208     65515       <- spoke-1
10.90.1.0/24   10.0.1.204*    65515       <- spoke-1
10.90.1.0/24   10.0.1.207     65515       <- spoke-1
10.90.1.0/24   10.0.1.208     65515       <- spoke-1
10.90.2.0/24   10.0.1.204*    65515       <- spoke-1
10.90.2.0/24   10.0.1.207     65515       <- spoke-1
10.90.2.0/24   10.0.1.208     65515       <- spoke-1
10.90.3.0/24   10.0.1.204*    65515       <- spoke-1
10.90.3.0/24   10.0.1.207     65515       <- spoke-1
10.90.3.0/24   10.0.1.208     65515       <- spoke-1
10.90.4.0/24   10.0.1.204*    65515       <- spoke-1
10.90.4.0/24   10.0.1.207     65515       <- spoke-1
10.90.4.0/24   10.0.1.208     65515       <- spoke-1
10.90.5.0/24   10.0.1.204*    65515       <- spoke-1
10.90.5.0/24   10.0.1.207     65515       <- spoke-1
10.90.5.0/24   10.0.1.208     65515       <- spoke-1
10.90.6.0/24   10.0.1.204*    65515       <- spoke-1
10.90.6.0/24   10.0.1.207     65515       <- spoke-1
10.90.6.0/24   10.0.1.208     65515       <- spoke-1
10.90.7.0/24   10.0.1.204*    65515       <- spoke-1
10.90.7.0/24   10.0.1.207     65515       <- spoke-1
10.90.7.0/24   10.0.1.208     65515       <- spoke-1
10.90.8.0/24   10.0.1.204*    65515       <- spoke-2
10.90.8.0/24   10.0.1.207     65515       <- spoke-2
10.90.8.0/24   10.0.1.208     65515       <- spoke-2
10.90.9.0/24   10.0.1.204*    65515       <- spoke-2
10.90.9.0/24   10.0.1.207     65515       <- spoke-2
10.90.9.0/24   10.0.1.208     65515       <- spoke-2
10.90.10.0/24  10.0.1.204*    65515       <- spoke-2
10.90.10.0/24  10.0.1.207     65515       <- spoke-2
10.90.10.0/24  10.0.1.208     65515       <- spoke-2
10.90.11.0/24  10.0.1.204*    65515       <- spoke-2
10.90.11.0/24  10.0.1.207     65515       <- spoke-2
10.90.11.0/24  10.0.1.208     65515       <- spoke-2
10.90.16.0/24  10.0.1.204*    65515       <- spoke-3
10.90.16.0/24  10.0.1.207     65515       <- spoke-3
10.90.16.0/24  10.0.1.208     65515       <- spoke-3
10.90.17.0/24  10.0.1.204*    65515       <- spoke-3
10.90.17.0/24  10.0.1.207     65515       <- spoke-3
10.90.17.0/24  10.0.1.208     65515       <- spoke-3
10.90.18.0/24  10.0.1.204*    65515       <- spoke-3
10.90.18.0/24  10.0.1.207     65515       <- spoke-3
10.90.18.0/24  10.0.1.208     65515       <- spoke-3
10.90.19.0/24  10.0.1.204*    65515       <- spoke-3
10.90.19.0/24  10.0.1.207     65515       <- spoke-3
10.90.19.0/24  10.0.1.208     65515       <- spoke-3
10.90.24.0/24  10.0.1.204*    65515       <- spoke-4
10.90.24.0/24  10.0.1.207     65515       <- spoke-4
10.90.24.0/24  10.0.1.208     65515       <- spoke-4
10.90.25.0/24  10.0.1.204*    65515       <- spoke-4
10.90.25.0/24  10.0.1.207     65515       <- spoke-4
10.90.25.0/24  10.0.1.208     65515       <- spoke-4
10.90.26.0/24  10.0.1.204*    65515       <- spoke-4
10.90.26.0/24  10.0.1.207     65515       <- spoke-4
10.90.26.0/24  10.0.1.208     65515       <- spoke-4
10.90.27.0/24  10.0.1.204*    65515       <- spoke-4
10.90.27.0/24  10.0.1.207     65515       <- spoke-4
10.90.27.0/24  10.0.1.208     65515       <- spoke-4
10.90.32.0/24  10.0.1.204*    65515       <- spoke-5
10.90.32.0/24  10.0.1.207     65515       <- spoke-5
10.90.32.0/24  10.0.1.208     65515       <- spoke-5
10.90.33.0/24  10.0.1.204*    65515       <- spoke-5
10.90.33.0/24  10.0.1.207     65515       <- spoke-5
10.90.33.0/24  10.0.1.208     65515       <- spoke-5
10.90.34.0/24  10.0.1.204*    65515       <- spoke-5
10.90.34.0/24  10.0.1.207     65515       <- spoke-5
10.90.34.0/24  10.0.1.208     65515       <- spoke-5
10.90.35.0/24  10.0.1.204*    65515       <- spoke-5
10.90.35.0/24  10.0.1.207     65515       <- spoke-5
10.90.35.0/24  10.0.1.208     65515       <- spoke-5
10.90.40.0/24  10.0.1.204*    65515       <- spoke-6
10.90.40.0/24  10.0.1.207     65515       <- spoke-6
10.90.40.0/24  10.0.1.208     65515       <- spoke-6
10.90.41.0/24  10.0.1.204*    65515       <- spoke-6
10.90.41.0/24  10.0.1.207     65515       <- spoke-6
10.90.41.0/24  10.0.1.208     65515       <- spoke-6
10.90.42.0/24  10.0.1.204*    65515       <- spoke-6
10.90.42.0/24  10.0.1.207     65515       <- spoke-6
10.90.42.0/24  10.0.1.208     65515       <- spoke-6
10.90.43.0/24  10.0.1.204*    65515       <- spoke-6
10.90.43.0/24  10.0.1.207     65515       <- spoke-6
10.90.43.0/24  10.0.1.208     65515       <- spoke-6
```


## 2. Applying summarization in vnet1

The following summarization configuration is applied to vnet1:

```json
"summarizedGatewayPrefixes": {
    "addressPrefixes": [
       "10.90.0.0/21",
       "10.90.8.0/21",
       "10.90.16.0/21",
       "10.90.24.0/21",
       "10.90.32.0/21",
       "10.90.40.0/21",
       "10.99.0.0/24"
    ]
}
```

Summarized network ranges:

| Network       | Range                     |
|---------------|---------------------------|
| 10.90.0.0/21  | 10.90.0.0 – 10.90.7.255   |
| 10.90.8.0/21  | 10.90.8.0 – 10.90.15.255  |
| 10.90.16.0/21 | 10.90.16.0 – 10.90.23.255 |
| 10.90.24.0/21 | 10.90.24.0 – 10.90.31.255 |
| 10.90.32.0/21 | 10.90.32.0 – 10.90.39.255 |
| 10.90.40.0/21 | 10.90.40.0 – 10.90.47.255 |
| 10.99.0.0/24  | 10.99.0.0 – 10.99.0.255   |

In Azure portal the summarization setting in vnet1 is shown as:
 
[![2]][2]

After applying summarization, the MSEE routing table shows aggregated routes:

```powershell
az network express-route list-route-tables `
    --resource-group SEA-Cust11 `
   --name SEA-Cust11-ER `
   --peering-name AzurePrivatePeering `
   --path primary `
   --query "value[].{Network:network, NextHop:nextHop, Path:path}" -o table

Network        NextHop        Path
-------------  -------------  ------
10.0.1.0/24    10.0.1.204*    65515        <- vnet1
10.0.1.0/24    10.0.1.207     65515        <- vnet1
10.0.1.0/24    10.0.1.208     65515        <- vnet1
10.1.11.0/25   192.168.11.17  65020        <- on-premises network
10.90.0.0/21   10.0.1.204*    65515        <- spoke-1
10.90.0.0/21   10.0.1.207     65515        <- spoke-1
10.90.0.0/21   10.0.1.208     65515        <- spoke-1
10.90.8.0/21   10.0.1.204*    65515        <- spoke-2
10.90.8.0/21   10.0.1.207     65515        <- spoke-2
10.90.8.0/21   10.0.1.208     65515        <- spoke-2
10.90.16.0/21  10.0.1.204*    65515        <- spoke-3
10.90.16.0/21  10.0.1.207     65515        <- spoke-3
10.90.16.0/21  10.0.1.208     65515        <- spoke-3
10.90.24.0/21  10.0.1.204*    65515        <- spoke-4
10.90.24.0/21  10.0.1.207     65515        <- spoke-4
10.90.24.0/21  10.0.1.208     65515        <- spoke-4
10.90.32.0/21  10.0.1.204*    65515        <- spoke-5
10.90.32.0/21  10.0.1.207     65515        <- spoke-5
10.90.32.0/21  10.0.1.208     65515        <- spoke-5
10.90.40.0/21  10.0.1.204*    65515        <- spoke-6
10.90.40.0/21  10.0.1.207     65515        <- spoke-6
10.90.40.0/21  10.0.1.208     65515        <- spoke-6
10.99.0.0/24   10.0.1.204*    65515        <- network is not assigned to any vnets but added to summarization
10.99.0.0/24   10.0.1.207     65515        <- network is not assigned to any vnets but added to summarization
10.99.0.0/24   10.0.1.208     65515        <- network is not assigned to any vnets but added to summarization

```

Checking the summarization in ExpressRoute circuit though Azure portal:

[![3]][3]

## 3. Adding new networks to the hub vnet1 address space

New address prefixes `10.50.0.0/24`, `10.50.50.0/24`, and `10.50.100.0/24` were added to the vnet1 address space. These prefixes are **not covered** by any summarization entry, so they appear as individual routes in the ExpressRoute circuit routing table.

```powershell
az network vnet show --resource-group test-summarization-er --name vnet1 --query "addressSpace.addressPrefixes" -o tsv
10.0.1.0/24
10.50.0.0/24
10.50.50.0/24
10.50.100.0/24
```

[![4]][4]

## 4. Adding a new summary route to the summarization property

After adding `10.50.0.0/17` to the `summarizedGatewayPrefixes`, the three individual `/24` prefixes (`10.50.0.0/24`, `10.50.50.0/24`, `10.50.100.0/24`) are replaced by the single summarized route `10.50.0.0/17` in the MSEE routing table.

[![5]][5]

Routing table in MSEE router:

[![6]][6]

## 5. Adding a new prefix to spoke-1

A new prefix `10.99.100.0/25` was added to the address space of spoke-1.

>
> [!IMPORTANT]
>
> Changing the address space of a spoke VNet causes the VNet peering to go **out-of-sync**. The peering must be re-synced before the new prefix is advertised.

After re-syncing the peering, the MSEE routing table shows:

```powershell
az network express-route list-route-tables `
    --resource-group SEA-Cust11 `
   --name SEA-Cust11-ER `
   --peering-name AzurePrivatePeering `
   --path primary `
   --query "value[].{Network:network, NextHop:nextHop, Path:path}" -o table

Network         NextHop        Path
--------------  -------------  ------
10.0.1.0/24     10.0.1.204*    65515
10.0.1.0/24     10.0.1.207     65515
10.0.1.0/24     10.0.1.208     65515
10.1.11.0/25    192.168.11.17  65020
10.50.0.0/17    10.0.1.204*    65515
10.50.0.0/17    10.0.1.207     65515
10.50.0.0/17    10.0.1.208     65515
10.90.0.0/21    10.0.1.204*    65515
10.90.0.0/21    10.0.1.207     65515
10.90.0.0/21    10.0.1.208     65515
10.90.8.0/21    10.0.1.204*    65515
10.90.8.0/21    10.0.1.207     65515
10.90.8.0/21    10.0.1.208     65515
10.90.16.0/21   10.0.1.204*    65515
10.90.16.0/21   10.0.1.207     65515
10.90.16.0/21   10.0.1.208     65515
10.90.24.0/21   10.0.1.204*    65515
10.90.24.0/21   10.0.1.207     65515
10.90.24.0/21   10.0.1.208     65515
10.90.32.0/21   10.0.1.204*    65515
10.90.32.0/21   10.0.1.207     65515
10.90.32.0/21   10.0.1.208     65515
10.90.40.0/21   10.0.1.204*    65515
10.90.40.0/21   10.0.1.207     65515
10.90.40.0/21   10.0.1.208     65515
10.99.0.0/24    10.0.1.204*    65515
10.99.0.0/24    10.0.1.207     65515
10.99.0.0/24    10.0.1.208     65515
10.99.100.0/25  10.0.1.204*    65515
10.99.100.0/25  10.0.1.207     65515
10.99.100.0/25  10.0.1.208     65515
```

The prefix `10.99.100.0/25` appears as an **individual route** because it is not covered by any existing summarization entry.

## 6. Adding a new major network to summarization property - not associated to any vnet address space

Adding `10.99.0.0/17` to the `summarizedGatewayPrefixes` property. The major network `10.99.0.0/17` covers the range `[10.99.0.0, 10.99.127.255]`.

The prefix `10.99.100.0/25` (assigned to spoke-1) falls within `10.99.0.0/17`, so it is **no longer advertised individually** — it is included in the summarized route.

After applying summarization with the additional `10.50.0.0/17` entry:

```powershell
az network express-route list-route-tables `
    --resource-group SEA-Cust11 `
   --name SEA-Cust11-ER `
   --peering-name AzurePrivatePeering `
   --path primary `
   --query "value[].{Network:network, NextHop:nextHop, Path:path}" -o table


Network        NextHop        Path
-------------  -------------  ------
10.0.1.0/24    10.0.1.204*    65515   (vnet1 - not summarized)
10.0.1.0/24    10.0.1.207     65515   (vnet1 - not summarized)
10.0.1.0/24    10.0.1.208     65515   (vnet1 - not summarized)
10.1.11.0/25   192.168.11.17  65020   (on-premises network)
10.50.0.0/17   10.0.1.204*    65515   (new added summary route)
10.50.0.0/17   10.0.1.207     65515   (new added summary route)
10.50.0.0/17   10.0.1.208     65515   (new added summary route)
10.90.0.0/21   10.0.1.204*    65515   
10.90.0.0/21   10.0.1.207     65515
10.90.0.0/21   10.0.1.208     65515
10.90.8.0/21   10.0.1.204*    65515
10.90.8.0/21   10.0.1.207     65515
10.90.8.0/21   10.0.1.208     65515
10.90.16.0/21  10.0.1.204*    65515
10.90.16.0/21  10.0.1.207     65515
10.90.16.0/21  10.0.1.208     65515
10.90.24.0/21  10.0.1.204*    65515
10.90.24.0/21  10.0.1.207     65515
10.90.24.0/21  10.0.1.208     65515
10.90.32.0/21  10.0.1.204*    65515
10.90.32.0/21  10.0.1.207     65515
10.90.32.0/21  10.0.1.208     65515
10.90.40.0/21  10.0.1.204*    65515
10.90.40.0/21  10.0.1.207     65515
10.90.40.0/21  10.0.1.208     65515
10.99.0.0/17   10.0.1.204*    65515   (it includes 10.99.100.0/25)
10.99.0.0/17   10.0.1.207     65515   (it includes 10.99.100.0/25)
10.99.0.0/17   10.0.1.208     65515   (it includes 10.99.100.0/25)

```

## 7. Remove the summarization by ARM template

Initial address space in vnet1:

```powershell
az network vnet show `
   --resource-group test-summarization-er `
   --name vnet1 `
   --query "addressSpace.addressPrefixes" `
   -o tsv
10.0.1.0/24
10.50.0.0/24
10.50.50.0/24
10.50.100.0/24
```

ARM template to reset summarization (setting `addressPrefixes` to an empty array):

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location1": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]",
            "metadata": {
                "description": "Azure region for the deployment"
            }
        }
    },
    "variables": {},
    "resources": [
        {
            "name": "vnet1",
            "type": "Microsoft.Network/virtualNetworks",
            "apiVersion": "2025-07-01",
            "location": "[parameters('location1')]",
            "properties": {
                "addressSpace": {
                    "addressPrefixes": [
                        "10.0.1.0/24",
                        "10.50.0.0/24"
                    ]
                },
                "summarizedGatewayPrefixes": {
                    "addressPrefixes": []
                }
            }
        }
    ]
}
```

After execution, the vnet1 address space is reset to:

```
10.0.1.0/24
10.50.0.0/24
```

The MSEE routing table reverts to individual /24 routes for all spoke prefixes:

```
az network express-route list-route-tables `
   --resource-group SEA-Cust11 `
   --name SEA-Cust11-ER `
   --peering-name AzurePrivatePeering `
   --path primary `
   --query "value[].{Network:network, NextHop:nextHop, Path:path}" -o table

Network         NextHop        Path
--------------  -------------  ------
10.0.1.0/24     10.0.1.204*    65515
10.0.1.0/24     10.0.1.207     65515
10.0.1.0/24     10.0.1.208     65515
10.1.11.0/25    192.168.11.17  65020
10.50.0.0/24    10.0.1.204*    65515
10.50.0.0/24    10.0.1.207     65515
10.50.0.0/24    10.0.1.208     65515
10.90.0.0/24    10.0.1.204*    65515
10.90.0.0/24    10.0.1.207     65515
10.90.0.0/24    10.0.1.208     65515
10.90.1.0/24    10.0.1.204*    65515
10.90.1.0/24    10.0.1.207     65515
10.90.1.0/24    10.0.1.208     65515
10.90.2.0/24    10.0.1.204*    65515
10.90.2.0/24    10.0.1.207     65515
10.90.2.0/24    10.0.1.208     65515
10.90.3.0/24    10.0.1.204*    65515
10.90.3.0/24    10.0.1.207     65515
10.90.3.0/24    10.0.1.208     65515
10.90.4.0/24    10.0.1.204*    65515
10.90.4.0/24    10.0.1.207     65515
10.90.4.0/24    10.0.1.208     65515
10.90.5.0/24    10.0.1.204*    65515
10.90.5.0/24    10.0.1.207     65515
10.90.5.0/24    10.0.1.208     65515
10.90.6.0/24    10.0.1.204*    65515
10.90.6.0/24    10.0.1.207     65515
10.90.6.0/24    10.0.1.208     65515
10.90.7.0/24    10.0.1.204*    65515
10.90.7.0/24    10.0.1.207     65515
10.90.7.0/24    10.0.1.208     65515
10.90.8.0/24    10.0.1.204*    65515
10.90.8.0/24    10.0.1.207     65515
10.90.8.0/24    10.0.1.208     65515
10.90.9.0/24    10.0.1.204*    65515
10.90.9.0/24    10.0.1.207     65515
10.90.9.0/24    10.0.1.208     65515
10.90.10.0/24   10.0.1.204*    65515
10.90.10.0/24   10.0.1.207     65515
10.90.10.0/24   10.0.1.208     65515
10.90.11.0/24   10.0.1.204*    65515
10.90.11.0/24   10.0.1.207     65515
10.90.11.0/24   10.0.1.208     65515
10.90.16.0/24   10.0.1.204*    65515
10.90.16.0/24   10.0.1.207     65515
10.90.16.0/24   10.0.1.208     65515
10.90.17.0/24   10.0.1.204*    65515
10.90.17.0/24   10.0.1.207     65515
10.90.17.0/24   10.0.1.208     65515
10.90.18.0/24   10.0.1.204*    65515
10.90.18.0/24   10.0.1.207     65515
10.90.18.0/24   10.0.1.208     65515
10.90.19.0/24   10.0.1.204*    65515
10.90.19.0/24   10.0.1.207     65515
10.90.19.0/24   10.0.1.208     65515
10.90.24.0/24   10.0.1.204*    65515
10.90.24.0/24   10.0.1.207     65515
10.90.24.0/24   10.0.1.208     65515
10.90.25.0/24   10.0.1.204*    65515
10.90.25.0/24   10.0.1.207     65515
10.90.25.0/24   10.0.1.208     65515
10.90.26.0/24   10.0.1.204*    65515
10.90.26.0/24   10.0.1.207     65515
10.90.26.0/24   10.0.1.208     65515
10.90.27.0/24   10.0.1.204*    65515
10.90.27.0/24   10.0.1.207     65515
10.90.27.0/24   10.0.1.208     65515
10.90.32.0/24   10.0.1.204*    65515
10.90.32.0/24   10.0.1.207     65515
10.90.32.0/24   10.0.1.208     65515
10.90.33.0/24   10.0.1.204*    65515
10.90.33.0/24   10.0.1.207     65515
10.90.33.0/24   10.0.1.208     65515
10.90.34.0/24   10.0.1.204*    65515
10.90.34.0/24   10.0.1.207     65515
10.90.34.0/24   10.0.1.208     65515
10.90.35.0/24   10.0.1.204*    65515
10.90.35.0/24   10.0.1.207     65515
10.90.35.0/24   10.0.1.208     65515
10.90.40.0/24   10.0.1.204*    65515
10.90.40.0/24   10.0.1.207     65515
10.90.40.0/24   10.0.1.208     65515
10.90.41.0/24   10.0.1.204*    65515
10.90.41.0/24   10.0.1.207     65515
10.90.41.0/24   10.0.1.208     65515
10.90.42.0/24   10.0.1.204*    65515
10.90.42.0/24   10.0.1.207     65515
10.90.42.0/24   10.0.1.208     65515
10.90.43.0/24   10.0.1.204*    65515
10.90.43.0/24   10.0.1.207     65515
10.90.43.0/24   10.0.1.208     65515
10.99.100.0/25  10.0.1.204*    65515
10.99.100.0/25  10.0.1.207     65515
10.99.100.0/25  10.0.1.208     65515
```

## 8. Applying the summarization by ARM template

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location1": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]",
            "metadata": {
                "description": "Azure region for the deployment"
            }
        }
    },
    "variables": {},
    "resources": [
        {
            "name": "vnet1",
            "type": "Microsoft.Network/virtualNetworks",
            "apiVersion": "2025-07-01",
            "location": "[parameters('location1')]",
            "properties": {
                "addressSpace": {
                    "addressPrefixes": [
                        "10.0.1.0/24",
                        "10.50.0.0/24"
                    ]
                },
                "summarizedGatewayPrefixes": {
                    "addressPrefixes": [
                        "10.50.0.0/17",
                        "10.90.0.0/21",
                        "10.90.8.0/21",
                        "10.90.16.0/21",
                        "10.90.24.0/21",
                        "10.90.32.0/21",
                        "10.90.40.0/21",
                        "10.99.0.0/24"
                    ]
                }
            }
        }
    ]
}
```
The routing table in MSEE router:

```
az network express-route list-route-tables `
   --resource-group SEA-Cust11 `
   --name SEA-Cust11-ER `
   --peering-name AzurePrivatePeering `
   --path primary `
   --query "value[].{Network:network, NextHop:nextHop, Path:path}" -o table
Network         NextHop        Path
--------------  -------------  ------
10.0.1.0/24     10.0.1.204*    65515      <- vnet1 without summarization
10.0.1.0/24     10.0.1.207     65515      <- vnet1 without summarization
10.0.1.0/24     10.0.1.208     65515      <- vnet1 without summarization
10.1.11.0/25    192.168.11.17  65020      <- on-premises network
10.50.0.0/17    10.0.1.204*    65515
10.50.0.0/17    10.0.1.207     65515
10.50.0.0/17    10.0.1.208     65515
10.90.0.0/21    10.0.1.204*    65515
10.90.0.0/21    10.0.1.207     65515
10.90.0.0/21    10.0.1.208     65515
10.90.8.0/21    10.0.1.204*    65515
10.90.8.0/21    10.0.1.207     65515
10.90.8.0/21    10.0.1.208     65515
10.90.16.0/21   10.0.1.204*    65515
10.90.16.0/21   10.0.1.207     65515
10.90.16.0/21   10.0.1.208     65515
10.90.24.0/21   10.0.1.204*    65515
10.90.24.0/21   10.0.1.207     65515
10.90.24.0/21   10.0.1.208     65515
10.90.32.0/21   10.0.1.204*    65515
10.90.32.0/21   10.0.1.207     65515
10.90.32.0/21   10.0.1.208     65515
10.90.40.0/21   10.0.1.204*    65515
10.90.40.0/21   10.0.1.207     65515
10.90.40.0/21   10.0.1.208     65515
10.99.0.0/24    10.0.1.204*    65515
10.99.0.0/24    10.0.1.207     65515
10.99.0.0/24    10.0.1.208     65515
10.99.100.0/25  10.0.1.204*    65515     <- network associated to spoke-1 without summarization
10.99.100.0/25  10.0.1.207     65515     <- network associated to spoke-1 without summarization
10.99.100.0/25  10.0.1.208     65515     <- network associated to spoke-1 without summarization
```

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/summarization1.png "summarization in vnet1"
[3]: ./media/summarization1-er.png "summarization in ExpressRoute circuit"
[4]: ./media/summarization2-er.png "summarization in ExpressRoute circuit"
[5]: ./media/summarization2.png "summarization in vnet1 after adding 10.50.0.0/17"
[6]: ./media/summarization3-er.png "summarization in ExpressRoute circuit"

<!--Link References-->

`Tags: route summarization, Azure ExpressRoute Gateway` <br>
`date: 02/08/2026` <br>