<properties
pageTitle= 'Summarization of address prefixes advertised over Site-to-Site VPN'
description= "Apply and remove summarization of address prefixes advertised by Azure VPN Gateways over S2S VPN with BGP"
documentationcenter: na
services="Azure VPN Gateway"
documentationCenter="https://github.com/fabferri"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="na"
   ms.date="23/06/2026"
   ms.author="fabferri" />

## Summarization of address prefixes advertised over Site-to-Site VPN

This article walks through how to **apply and remove route summarization** for address prefixes advertised by an Azure VPN Gateway over a site-to-site VPN connection with BGP. Route summarization (also known as route aggregation) replaces multiple specific routes with a single aggregated route, reducing the size of the BGP routing table on the remote peer.

### Network diagram

The environment consists of a hub-spoke topology connected to a remote site via site-to-site VPN:

- **vnet1** (10.0.1.0/24) — hub VNet with VPN Gateway **gw1** (ASN 65001)
- **vnet2** (10.0.2.0/24) — remote site VNet with VPN Gateway **gw2** (ASN 65002)
- **spoke-1 through spoke-6** — spoke VNets peered to the hub with gateway transit enabled
- Two IPsec tunnels between gw1 and gw2 (active-active mode with BGP)

The VPN Gateways are deployed as zonal gateways (SKU: **VpnGw1AZ / VpnGw2AZ / VpnGw3AZ / VpnGw4AZ / VpnGw5AZ**) with Standard SKU public IPs.

[![1]][1]

The spoke VNets have multiple /24 address prefixes:

| Spoke VNet | Address prefixes |
|------------|-----------------|
| spoke-1    | 10.90.0.0/24 through 10.90.7.0/24 (8 prefixes) |
| spoke-2    | 10.90.8.0/24 through 10.90.11.0/24 (4 prefixes) |
| spoke-3    | 10.90.16.0/24 through 10.90.19.0/24 (4 prefixes) |
| spoke-4    | 10.90.24.0/24 through 10.90.27.0/24 (4 prefixes) |
| spoke-5    | 10.90.32.0/24 through 10.90.35.0/24 (4 prefixes) |
| spoke-6    | 10.90.40.0/24 through 10.90.43.0/24 (4 prefixes) |

Details diagram of IPSec tunnels between the two Azure VPN Gateways:

[![2]][2]

### How summarization works

The `summarizedGatewayPrefixes` property on the Azure Virtual Network resource controls which prefixes the VPN Gateway advertises via BGP to remote peers. When configured, the gateway replaces all individual spoke routes that fall within the summarized ranges with the specified aggregate prefixes.

**Without summarization** — gw2 learns all individual /24 routes from gw1 (28 spoke routes):
```
10.90.0.0/24, 10.90.1.0/24, 10.90.2.0/24, ..., 10.90.43.0/24
```

**With summarization** — gw2 learns only 7 summarized routes from gw1:
```
10.90.0.0/21, 10.90.8.0/21, 10.90.16.0/21, 10.90.24.0/21, 10.90.32.0/21, 10.90.40.0/21, 10.99.0.0/24
```

This significantly reduces the number of BGP routes exchanged across the VPN tunnel.

### Project files

| File | Description |
|------|-------------|
| **init.json** | Input parameters: subscription, resource group, locations, gateway names, ASNs, spoke names, credentials |
| **01_vpn.json** | ARM template to create vnet1, vnet2, VPN gateways (active-active), and S2S connections with BGP |
| **01_vpn.ps1** | PowerShell script to deploy **01_vpn.json** |
| **02_deploy-vnets.json** | ARM template to create the spoke VNets (spoke-1 through spoke-6) |
| **02_deploy-vnets.ps1** | PowerShell script to deploy **02_deploy-vnets.json** |
| **03_deploy-peer-vnets.json** | ARM template to create hub-to-spoke VNet peerings with gateway transit |
| **03_deploy-peer-vnets.ps1** | PowerShell script to deploy **03_deploy-peer-vnets.json** |
| **hub-summarization.json** | ARM template to apply summarization (`summarizedGatewayPrefixes` with /21 aggregates) |
| **hub-summarization.ps1** | PowerShell script to deploy **hub-summarization.json** |
| **hub-no_summarization.json** | ARM template to remove summarization (empty `summarizedGatewayPrefixes`) |
| **hub-no_summarization.ps1** | PowerShell script to deploy **hub-no_summarization.json** |
| **routing-table-gw.ps1** | Script to check BGP learned routes on both gateways |
| **delete-peerings.ps1** | Script to delete all VNet peerings |

All scripts read deployment parameters from **init.json** and use Azure CLI commands with try-catch error handling.

### Deployment sequence

```
Step 1: Deploy the VPN infrastructure
         01_vpn.ps1 → creates vnet1, vnet2, gw1, gw2, and S2S VPN tunnels with BGP

Step 2: Create spoke VNets
         02_deploy-vnets.ps1 → creates spoke-1 through spoke-6 with /24 address spaces

Step 3: Peer spokes with hub
         03_deploy-peer-vnets.ps1 → peers spokes to vnet1 with gateway transit

Step 4: Verify routes WITHOUT summarization
         routing-table-gw.ps1 → gw2 shows all individual /24 routes from spokes

Step 5: Apply summarization
         hub-summarization.ps1 → sets summarizedGatewayPrefixes on vnet1

Step 6: Verify routes WITH summarization
         routing-table-gw.ps1 → gw2 now shows only aggregated /21 routes

Step 7: (Optional) Remove summarization
         hub-no_summarization.ps1 → clears summarizedGatewayPrefixes on vnet1
```

### Prerequisites

1. An Azure subscription
2. Azure CLI installed and authenticated (`az login`)
3. Customize **init.json** with your values before running any script:

```json
{
    "subscriptionName": "YOUR_SUBSCRIPTION_NAME",
    "rgName": "RESOURCE_GROUP_NAME",
    "location": "AZURE_REGION",
    "location1": "AZURE_REGION_GW1",
    "location2": "AZURE_REGION_GW2",
    "gateway1Name": "gw1",
    "gateway2Name": "gw2",
    "asnGtw1": 65001,
    "asnGtw2": 65002,
    "spoke1": "spoke-1",
    "spoke2": "spoke-2",
    "spoke3": "spoke-3",
    "spoke4": "spoke-4",
    "spoke5": "spoke-5",
    "spoke6": "spoke-6",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD"
}
```

### ARM template: applying summarization

The `summarizedGatewayPrefixes` property is set on the VNet resource at API version `2025-07-01`:

```json
{
    "name": "vnet1",
    "type": "Microsoft.Network/virtualNetworks",
    "apiVersion": "2025-07-01",
    "location": "[parameters('location1')]",
    "properties": {
        "addressSpace": {
            "addressPrefixes": ["10.0.1.0/24"]
        },
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
    }
}
```

### ARM template: removing summarization

Setting `"addressPrefixes": []` in `summarizedGatewayPrefixes` disables summarization and reverts to advertising individual routes:

```json
{
    "name": "vnet1",
    "type": "Microsoft.Network/virtualNetworks",
    "apiVersion": "2025-07-01",
    "location": "[parameters('location1')]",
    "properties": {
        "addressSpace": {
            "addressPrefixes": ["10.0.1.0/24"]
        },
        "summarizedGatewayPrefixes": {
            "addressPrefixes": []
        }
    }
}
```

### BGP routes: before summarization

Running `az network vnet-gateway list-learned-routes -n gw2 -g $rgName -o table` on gw2 shows all individual /24 routes learned from gw1:

```
Network        NextHop     Origin    SourcePeer    AsPath    Weight
-------------  ----------  --------  ------------  --------  --------
10.0.2.0/24                Network   10.0.2.197              32768
10.0.1.197/32              Network   10.0.2.197              32768
10.0.1.197/32  10.0.2.196  IBgp      10.0.2.196              32768
10.0.1.0/24    10.0.1.197  EBgp      10.0.1.197    65001     32768
10.0.1.0/24    10.0.1.196  EBgp      10.0.1.196    65001     32768
10.0.1.0/24    10.0.2.196  IBgp      10.0.2.196    65001     32768
10.0.1.196/32              Network   10.0.2.197              32768
10.0.1.196/32  10.0.2.196  IBgp      10.0.2.196              32768
10.90.32.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.32.0/24  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.32.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.33.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.33.0/24  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.33.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.34.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.34.0/24  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.34.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.35.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.35.0/24  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.35.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.16.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.16.0/24  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.16.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.17.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.17.0/24  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.17.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.18.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.18.0/24  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.18.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.19.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.19.0/24  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.19.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.40.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.40.0/24  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.40.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.41.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.41.0/24  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.41.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.42.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.42.0/24  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.42.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.43.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.43.0/24  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.43.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.24.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.24.0/24  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.24.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.25.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.25.0/24  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.25.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.26.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.26.0/24  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.26.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.27.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.27.0/24  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.27.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.8.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.8.0/24   10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.8.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.9.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.9.0/24   10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.9.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.10.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.10.0/24  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.10.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.11.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.11.0/24  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.11.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.0.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.0.0/24   10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.0.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.1.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.1.0/24   10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.1.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.2.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.2.0/24   10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.2.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.3.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.3.0/24   10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.3.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.4.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.4.0/24   10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.4.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.5.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.5.0/24   10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.5.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.6.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.6.0/24   10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.6.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.7.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.7.0/24   10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.7.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.0.2.0/24                Network   10.0.2.196              32768
10.0.1.197/32              Network   10.0.2.196              32768
10.0.1.197/32  10.0.2.197  IBgp      10.0.2.197              32768
10.0.1.196/32              Network   10.0.2.196              32768
10.0.1.196/32  10.0.2.197  IBgp      10.0.2.197              32768
10.0.1.0/24    10.0.1.196  EBgp      10.0.1.196    65001     32768
10.0.1.0/24    10.0.2.197  IBgp      10.0.2.197    65001     32768
10.0.1.0/24    10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.32.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.32.0/24  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.32.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.33.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.33.0/24  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.33.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.34.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.34.0/24  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.34.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.35.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.35.0/24  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.35.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.16.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.16.0/24  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.16.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.17.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.17.0/24  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.17.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.18.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.18.0/24  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.18.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.19.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.19.0/24  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.19.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.40.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.40.0/24  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.40.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.41.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.41.0/24  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.41.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.42.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.42.0/24  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.42.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.43.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.43.0/24  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.43.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.24.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.24.0/24  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.24.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.25.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.25.0/24  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.25.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.26.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.26.0/24  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.26.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.27.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.27.0/24  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.27.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.8.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.8.0/24   10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.8.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.9.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.9.0/24   10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.9.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.10.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.10.0/24  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.10.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.11.0/24  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.11.0/24  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.11.0/24  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.0.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.0.0/24   10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.0.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.1.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.1.0/24   10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.1.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.2.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.2.0/24   10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.2.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.3.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.3.0/24   10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.3.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.4.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.4.0/24   10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.4.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.5.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.5.0/24   10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.5.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.6.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.6.0/24   10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.6.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.7.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.7.0/24   10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.7.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
```

Each spoke /24 prefix appears as a separate route (28 spoke routes total).

### BGP routes: after summarization

After applying summarization on vnet1, gw2 learns only the aggregated /21 prefixes:

```
Network        NextHop     Origin    SourcePeer    AsPath    Weight
-------------  ----------  --------  ------------  --------  --------
10.0.2.0/24                Network   10.0.2.196              32768
10.0.1.197/32              Network   10.0.2.196              32768
10.0.1.197/32  10.0.2.197  IBgp      10.0.2.197              32768
10.0.1.196/32              Network   10.0.2.196              32768
10.0.1.196/32  10.0.2.197  IBgp      10.0.2.197              32768
10.90.0.0/21   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.0.0/21   10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.0.0/21   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.8.0/21   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.8.0/21   10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.8.0/21   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.16.0/21  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.16.0/21  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.16.0/21  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.24.0/21  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.24.0/21  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.24.0/21  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.32.0/21  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.32.0/21  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.32.0/21  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.40.0/21  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.40.0/21  10.0.2.197  IBgp      10.0.2.197    65001     32768
10.90.40.0/21  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.99.0.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.99.0.0/24   10.0.2.197  IBgp      10.0.2.197    65001     32768
10.99.0.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.0.2.0/24                Network   10.0.2.197              32768
10.0.1.197/32              Network   10.0.2.197              32768
10.0.1.197/32  10.0.2.196  IBgp      10.0.2.196              32768
10.0.1.196/32              Network   10.0.2.197              32768
10.0.1.196/32  10.0.2.196  IBgp      10.0.2.196              32768
10.90.0.0/21   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.0.0/21   10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.0.0/21   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.8.0/21   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.8.0/21   10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.8.0/21   10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.16.0/21  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.16.0/21  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.16.0/21  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.24.0/21  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.24.0/21  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.24.0/21  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.32.0/21  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.32.0/21  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.32.0/21  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.90.40.0/21  10.0.1.196  EBgp      10.0.1.196    65001     32768
10.90.40.0/21  10.0.2.196  IBgp      10.0.2.196    65001     32768
10.90.40.0/21  10.0.1.197  EBgp      10.0.1.197    65001     32768
10.99.0.0/24   10.0.1.196  EBgp      10.0.1.196    65001     32768
10.99.0.0/24   10.0.2.196  IBgp      10.0.2.196    65001     32768
10.99.0.0/24   10.0.1.197  EBgp      10.0.1.197    65001     32768
```

The 28 individual /24 routes have been replaced by 7 summarized routes (6x /21 + 1x /24).


Effective routes table in the vm2 (without summmarization):
```bash
# list of NIC name
az network nic list --resource-group test-summarization-101 --query "[].name" -o tsv                                                   
vm11-nic
vm21-nic                       

az network nic show-effective-route-table --resource-group $rgName --name vm21-nic --output table 
Source                 State    Address Prefix    Next Hop Type          Next Hop IP
---------------------  -------  ----------------  ---------------------  ---------------------
Default                Active   10.0.2.0/24       VnetLocal
VirtualNetworkGateway  Active   10.0.1.197/32     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.0.1.0/24       VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.16.0/24     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.35.0/24     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.0.1.196/32     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.32.0/24     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.33.0/24     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.34.0/24     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.17.0/24     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.18.0/24     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.19.0/24     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.2.0/24      VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.40.0/24     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.3.0/24      VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.41.0/24     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.4.0/24      VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.42.0/24     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.43.0/24     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.24.0/24     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.25.0/24     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.26.0/24     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.27.0/24     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.8.0/24      VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.9.0/24      VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.10.0/24     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.11.0/24     VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.0.0/24      VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.1.0/24      VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.5.0/24      VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.6.0/24      VirtualNetworkGateway  10.0.2.196 10.0.2.197
VirtualNetworkGateway  Active   10.90.7.0/24      VirtualNetworkGateway  10.0.2.196 10.0.2.197
Default                Active   0.0.0.0/0         Internet
```



### Useful commands

Check BGP learned routes:
```powershell
az network vnet-gateway list-learned-routes -n gw2 -g $rg -o table
```

Check BGP peer status:
```powershell
az network vnet-gateway list-bgp-peer-status -n gw1 -g $rg -o table
```

Check S2S VPN connection status:
```powershell
az network vpn-connection show --name conn11 --resource-group $rg --query connectionStatus
```

Check VPN tunnel status:
```powershell
az network vpn-connection show --name conn11 --resource-group $rg --query tunnelConnectionStatus
```

### Notes

- The `summarizedGatewayPrefixes` property requires API version **2025-07-01** or later.
- Summarization applies only to routes advertised **outbound** by the VPN Gateway via BGP. It does not affect routes learned from remote peers.
- The summarized prefixes do not need to match the exact address spaces of the spoke VNets — they can be broader supernets that encompass multiple spoke prefixes.
- Changes to `summarizedGatewayPrefixes` take effect within a few minutes without requiring a gateway restart.

```bash
# collect Gateway name, ASN, BGP IPs of VPN Gateway
$rgName='test-vpn'
$vpnName='gw1'
az network vnet-gateway list --query [].[name,bgpSettings.asn,bgpSettings.bgpPeeringAddress] -o table -g $rgName

# collect ASN, BGP IPs for the gw1
az network vnet-gateway list --query "[?name=='gw1'].{Name:name,BGPlocalIP:bgpSettings.bgpPeeringAddress,ASN:bgpSettings.asn}" -o table -g $rgName

# list of BGP IPs
$peers = az network vnet-gateway show -n gw2 -g $rgName --query "bgpSettings.bgpPeeringAddresses[].defaultBgpIpAddresses[]" -o tsv

# collect the advertised routes to the remote peer
$vpnName='gw1'
$peer1=$peers[0]
az network vnet-gateway list-advertised-routes -n $vpnName -g $rgName --peer $peer1 -o table 
```

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram with site-to-site VPN details"

<!--Link References-->

`Tags: Azure VPN Gateway, site-to-site VPN, summarization` <br>
`date: 23/06/2026` <br>

