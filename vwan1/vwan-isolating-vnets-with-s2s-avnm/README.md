# Virtual WAN: VNet isolation with S2S VPN and Azure Virtual Network Manager

This project demonstrates **custom VNet isolation** in Azure Virtual WAN across two hubs (hub1, hub2): spoke VNets in the **red** group and spoke VNets in the **blue** group cannot reach each other, while both groups can reach branch sites over site-to-site VPN.

- Two S2S VPN connections: `branch1 ↔ hub1` and `branch2 ↔ hub2`
- **Azure Virtual Network Manager (AVNM)** manages all spoke-to-hub peering dynamically via tag-based Azure Policy, replacing static `hubVirtualNetworkConnections`

## Table of Contents

1. [Routing tables and VNet-to-hub association](#1-routing-tables-and-vnet-to-hub-association)
2. [Routing tables in hub1](#2-routing-tables-in-hub1)
3. [Routing tables in hub2](#3-routing-tables-in-hub2)
4. [Effective routing table in VMs](#4-effective-routing-table-in-vms)
5. [File reference](#5-file-reference)
6. [Deployment steps](#6-deployment-steps)
7. [Azure Virtual Network Manager integration](#7-azure-virtual-network-manager-integration)
8. [Useful PowerShell commands](#8-useful-powershell-commands)
9. [AVNM ARM template deep dive](#9-avnm-arm-template-deep-dive)

## Architecture

The solution is built in two complementary layers:

| Layer | Technology | Responsibility |
|-------|-----------|----------------|
| **Routing** | Azure vWAN route tables (red, blue, default) + labels | Controls which VNets can communicate — isolation enforcement |
| **Connectivity** | Azure Virtual Network Manager (AVNM) | Creates and maintains the VNet-to-hub peering connections dynamically, based on VNet tags |

The two layers are decoupled: vWAN route tables define *what traffic is allowed*, AVNM connection policies define *how VNets attach to the hub and which route table governs them*. When a new spoke VNet is tagged correctly, AVNM automatically connects it to the right hub with the right routing — no manual `hubVirtualNetworkConnection` resource is needed.

[![1]][1]

Three route tables are used to achieve the desired traffic isolation:

- **Red VNets** (vnet1, vnet4, vnet5):
   - Associated route table: **red**
   - Propagating to route tables: **red** and **DefaultRoutingTable**
- **Blue VNets** (vnet2, vnet3, vnet6):
   - Associated route table: **blue**
   - Propagating to route tables: **blue** and **DefaultRouteTable**
- **Branches** (branch1, branch2):
   - Associated route table: **DefaultRouteTable**
   - Propagating to route tables: **red**, **blue** and **DefaultRouteTable**


Communication matrix — **YES** means traffic is allowed, **NO** means traffic is blocked by route table isolation:

|         | vnet1 | vnet2 | vnet3 | Vnet4 | Vnet5 | Vnet6 | branch1 | branch2 |
| ------- | ----- | ----- | ----- | ----- | ----- | ----- | ------- | ------- |
| vnet1   |  \-   | NO    | NO    | YES   | YES   | NO    | YES     | YES     |
| vnet2   | NO    | \-    | YES   | NO    | NO    | YES   | YES     | YES     |
| vnet3   | NO    | YES   | \-    | NO    | NO    | YES   | YES     | YES     |
| vnet4   | YES   | NO    | NO    | \-    | YES   | NO    | YES     | YES     |
| vnet5   | YES   | NO    | NO    | YES   |  \-   | NO    | YES     | YES     |
| vnet6   | NO    | YES   | YES   | NO    | NO    | \-    | YES     | YES     |
| branch1 | YES   | YES   | YES   | YES   | YES   | YES   | \-      | YES     |
| brnach2 | YES   | YES   | YES   | YES   | YES   | YES   | YES     | \-      |

Allow communications allow within the **red** group:

[![3]][3]

Allow communications allow within the **blue** group:

[![4]][4]


## 1. Routing in branches

Branches are always associated to the **DefaultRoutingTable**. They need to learn prefixes from both **red** and **blue** VNets, so all VNets also propagate to **DefaultRouteTable**.

> **Note**: `01-vwan.json` does **not** create any `hubVirtualNetworkConnections` resources. The spoke VNets are deployed standalone; all hub attachments are created exclusively by AVNM (step 6) once it is deployed and its connectivity configurations are committed.

The S2S VPN connection snippet from `03-vwan-site.json` (using a copy loop over all VPN sites):

```json
{
    "type": "Microsoft.Network/vpnGateways/vpnConnections",
    "apiVersion": "2020-11-01",
    "name": "[concat(variables('vpnsiteArray')[copyIndex()].hubvpnGatewayName,'/',variables('vpnsiteArray')[copyIndex()].hubToBranchConnectionName)]",
    "dependsOn": [
        "[resourceId('Microsoft.Network/vpnSites', variables('vpnsiteArray')[copyIndex()].vpnsiteName)]"
    ],
    "properties": {
        "routingConfiguration": {
            "associatedRouteTable": {
                "id": "[resourceId('Microsoft.Network/virtualHubs/hubRouteTables', variables('vpnsiteArray')[copyIndex()].hubName, 'defaultRouteTable')]"
            },
            "propagatedRouteTables": {
                "ids": [],
                "labels": [ "default", "red", "blue" ]
            }
        },
        "remoteVpnSite": {
            "id": "[resourceId('Microsoft.Network/vpnSites', variables('vpnsiteArray')[copyIndex()].vpnsiteName)]"
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
                        "id": "[resourceId('Microsoft.Network/vpnSites/vpnSiteLinks', variables('vpnsiteArray')[copyIndex()].vpnsiteName,'tunnel1')]"
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
                        "id": "[resourceId('Microsoft.Network/vpnSites/vpnSiteLinks', variables('vpnsiteArray')[copyIndex()].vpnsiteName,'tunnel2')]"
                    }
                }
            }
        ]
    },
    "copy": {
        "name": "vpnConnectionCopy",
        "count": "[variables('vpnSiteCount')]"
    }
}
```

The snippet shows:
- `associatedRouteTable` set to `defaultRouteTable` on the local hub
- `propagatedRouteTables` using only **labels** (`default`, `red`, `blue`) with `"ids": []` — Azure resolves labels at runtime to all matching route tables across every hub in the vWAN
- A copy loop iterates over `vpnsiteArray` (hub1 ↔ branch1 and hub2 ↔ branch2), so both connections are created from a single resource block
- Two active/active IKEv2 tunnels (`conn1`, `conn2`) with BGP enabled

---

## 2. Routing tables in hub1

The network of branch1 is advertised through BGP to hub1 by AS 65010.
The network of branch2 is advertised through BGP to hub2 by AS 65011.
Each virtual hub advertises the learned routes to the peer hub through BGP by AS65520.

**DefaultRouteTable in hub1**

| Prefix         | Next Hop Type              | Next Hop                     | Origin                | AS path     |
| -------------- | -------------------------- | ---------------------------- | --------------------- | ----------- |
| 192.168.1.0/24 | VPN_S2S_Gateway            | hub1_gw                      | hub1_gw               | 65010       |
| 10.0.1.0/24    | Virtual Network Connection | hub1/ANM_<ID>_vnet1          | hub1/ANM_<ID>_vnet1   |             |
| 10.0.2.0/24    | Virtual Network Connection | hub1/ANM_<ID>_vnet2          | hub1/ANM_<ID>_vnet2   |             |
| 10.0.3.0/24    | Virtual Network Connection | hub1/ANM_<ID>_vnet3          | hub1/ANM_<ID>_vnet3   |             |
| 192.168.2.0/24 | Remote Hub                 | hub2                         | hub2                  | 65520-65520-65011 |
| 10.0.4.0/24    | Remote Hub                 | hub2                         | hub2                  | 65520-65520       |
| 10.0.5.0/24    | Remote Hub                 | hub2                         | hub2                  | 65520-65520       |
| 10.0.6.0/24    | Remote Hub                 | hub2                         | hub2                  | 65520-65520       |

```powershell
# defatul route table in hub1
$routeTableId = (Get-AzVHubRouteTable -ResourceGroupName $rgName -HubName hub1 -Name defaultRouteTable).Id
Get-AzVHubEffectiveRoute -ResourceGroupName $rgName -VirtualHubName hub1 `
    -VirtualWanResourceType RouteTable -ResourceId $routeTableId
```

**Routing table red in hub1**

| Prefix         | Next Hop Type              | Next Hop                     | Origin           | AS path           |
| -------------- | -------------------------- | ---------------------------- | ---------------- | ----------------- |
| 192.168.1.0/24 | VPN_S2S_Gateway            | hub1_gw                      | hub1_gw          | 65010             |
| 10.0.1.0/24    | Virtual Network Connection | hub1/ANM_<ID>_vnet1          | hub1/ANM_<ID_vnet1 |                 |
| 192.168.2.0/24 | Remote Hub                 | hub2                         | hub2             | 65520-65520-65011 |
| 10.0.4.0/24    | Remote Hub                 | hub2                         | hub2             | 65520-65520       |
| 10.0.5.0/24    | Remote Hub                 | hub2                         | hub2             | 65520-65520       |

```powershell
# red route table in hub1
$routeTableId = (Get-AzVHubRouteTable -ResourceGroupName $rgName -HubName hub1 -Name red).Id
Get-AzVHubEffectiveRoute -ResourceGroupName $rgName -VirtualHubName hub1 `
    -VirtualWanResourceType RouteTable -ResourceId $routeTableId
```

**Routing table blue in hub1**

| Prefix         | Next Hop Type              | Next Hop                   | Origin            | AS path           |
| -------------- | -------------------------- | ---------------------------| ----------------- | ----------------- |
| 192.168.1.0/24 | VPN_S2S_Gateway            | hub1_gw                    | hub1_gw           | 65010             |
| 10.0.2.0/24    | Virtual Network Connection | hub1/ANM_<ID>_vnet2        | hub1/ANM_<ID>_vnet2 | |
| 10.0.3.0/24    | Virtual Network Connection | hub1/ANM_<ID>_vnet3        | hub1/ANM_<ID>_vnet3 | |
| 192.168.2.0/24 | Remote Hub                 | hub2                       | hub2               | 65520-65520-65011 |
| 10.0.6.0/24    | Remote Hub                 | hub2                       | hub2               | 65520-65520       |
---

## 3. Routing tables in hub2

The network of branch1 is advertised through BGP to hub1 by AS 65010.

The network of branch2 is advertised through BGP to hub2 by AS 65011.

```powershell
$routeTableId = (Get-AzVHubRouteTable -ResourceGroupName $rgName -HubName hub2 -Name defaultRouteTable).Id
Get-AzVHubEffectiveRoute -ResourceGroupName $rgName -VirtualHubName hub2 `
    -VirtualWanResourceType RouteTable -ResourceId $routeTableId
```

**DefaultRouteTable in hub2**

| Prefix         | Next Hop Type              | Next Hop               | Origin                   | AS path           |
| -------------- | -------------------------- | ---------------------- | ------------------------ | ----------------- |
| 192.168.2.0/24 | VPN_S2S_Gateway            | hub2_gw                | hub2_gw                  | 65011             |
| 192.168.1.0/24 | Remote Hub                 | hub1                   | hub1                     | 65520-65520-65010 |
| 10.0.1.0/24    | Remote Hub                 | hub1                   | hub1                     | 65520-65520       |
| 10.0.2.0/24    | Remote Hub                 | hub1                   | hub1                     | 65520-65520       |
| 10.0.3.0/24    | Remote Hub                 | hub1                   | hub1                     | 65520-65520       |
| 10.0.6.0/24    | Virtual Network Connection | hub2/ANM_<ID>_vnet6    | hub2/ANM_<ID>_vnet6 |
| 10.0.5.0/24    | Virtual Network Connection | hub2/ANM_<ID>_vnet5    | hub2/ANM_<ID>_vnet5 |
| 10.0.4.0/24    | Virtual Network Connection | hub2/ANM_<ID>_vnet4    | hub2/ANM_<ID>_vnet4 |

```powershell
$routeTableId = (Get-AzVHubRouteTable -ResourceGroupName $rgName -HubName hub2 -Name red).Id
Get-AzVHubEffectiveRoute -ResourceGroupName $rgName -VirtualHubName hub2 `
    -VirtualWanResourceType RouteTable -ResourceId $routeTableId
```

**Routing table red in hub2**

| Prefix         | Next Hop Type              | Next Hop                | Origin                 | AS path           |
| -------------- | -------------------------- | ----------------------- | ---------------------- | ----------------- |
| 192.168.2.0/24 | VPN_S2S_Gateway            | hub2_gw                 | hub2_gw                | 65011             |
| 192.168.1.0/24 | Remote Hub                 | hub1                    | hub1                   | 65520-65520-65010 |
| 10.0.1.0/24    | Remote Hub                 | hub1                    | hub1                   | 65520-65520       |
| 10.0.5.0/24    | Virtual Network Connection | hub2/ANM_<ID>_vnet5     | hub2/ANM_<ID>_vnet5    | |
| 10.0.4.0/24    | Virtual Network Connection | hub2/ANM_<ID>_vnet4     | hub2/ANM_<ID>_vnet4    | |

```powershell
$routeTableId = (Get-AzVHubRouteTable -ResourceGroupName $rgName -HubName hub2 -Name blue).Id
Get-AzVHubEffectiveRoute -ResourceGroupName $rgName -VirtualHubName hub2 `
    -VirtualWanResourceType RouteTable -ResourceId $routeTableId
```

**Routing table blue in hub2**

| Prefix         | Next Hop Type              | Next Hop                 | Origin                          | AS path           |
| -------------- | -------------------------- | ------------------------ | ------------------------------- | ----------------- |
| 192.168.2.0/24 | VPN_S2S_Gateway            | hub2_gw                  | hub2_gw                         | 65011             |
| 192.168.1.0/24 | Remote Hub                 | hub1                     | hub1                            | 65520-65520-65010 |
| 10.0.2.0/24    | Remote Hub                 | hub1                     | hub1                            | 65520-65520       |
| 10.0.3.0/24    | Remote Hub                 | hub1                     | hub1                            | 65520-65520       |
| 10.0.6.0/24    | Virtual Network Connection | hub2/ANM_<ID>_vnet6      | hub2/ANM_<ID>_vnet6 | |

---

## 4. Effective routing table in VMs

The effective routing table in **vm1** (vnet1):
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.1.0/24      | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.10.0.0/23     | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active | 192.168.2.0/24   | Virtual network gateway | 10.10.0.68          | \-                      |
| Virtual network gateway | Active | 192.168.1.0/24   | Virtual network gateway | 10.10.0.13, 1 more  | \-                      |
| Virtual network gateway | Active | 10.0.4.0/24      | Virtual network gateway | 10.10.0.68          | \-                      |
| Virtual network gateway | Active | 10.0.5.0/24      | Virtual network gateway | 10.10.0.68          | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |


The effective routing table in **vm6** (vnet6):

| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.6.0/24      | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.11.0.0/23     | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 10.11.0.68          | \-                      |
| Virtual network gateway | Active | 192.168.1.0/24   | Virtual network gateway | 10.11.0.68          | \-                      |
| Virtual network gateway | Active | 192.168.2.0/24   | Virtual network gateway | 10.11.0.12, 1 more  | \-                      |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 10.11.0.68          | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |

---

## 5. File reference

| File | Description |
| ---- |:----------- |
| **init.json** | Input variables shared by all scripts. Customize this file before running any deployment. |
| **01-vwan.json** | ARM template: vWAN, hub1 and hub2, route tables (red/blue labels), 6 standalone spoke VNets tagged for AVNM dynamic membership (`environment=red1/blue1/red2/blue2`). No `hubVirtualNetworkConnections` are created here — AVNM (step 6) creates all hub attachments. |
| **01-vwan.ps1** | PowerShell script to deploy **01-vwan.json** |
| **02-vpn.json** | ARM template: branch1 and branch2 networks, VPN gateways |
| **02-vpn.ps1** | PowerShell script to deploy **02-vpn.json** |
| **03-vwan-site.json** | ARM template: S2S VPN sites and connections between branches and vWAN hubs |
| **03-vwan-site.ps1** | PowerShell script to deploy **03-vwan-site.json** |
| **04-avnm-conn-policies.json** | ARM template: 4 `connectionPolicies` resources on hub1 and hub2 (`policy1-red`, `policy1-blue`, `policyhub2-red`, `policyhub2-blue`). Each policy encodes the routing configuration (associated + propagated route tables via **labels**) that AVNM applies when connecting spoke VNets. Must run before step 6. |
| **04-avnm-conn-policies.ps1** | PowerShell script to deploy `04-avnm-conn-policies.json`. |
| **05-avnm-manager.json** | ARM template (subscription-scoped): Azure Virtual Network Manager `net-mgr1` with 4 network groups, 4 HubAndSpoke connectivity configurations, 4 Azure Policy definitions/assignments for dynamic VNet membership, and a deployment script that commits and activates the configurations. |
| **05-avnm-manager.ps1** | PowerShell script to deploy `05-avnm-manager.json` via `New-AzDeployment` (subscription scope). Reads all parameters from `init.json`. |
| **get-avnm-policies.ps1** | PowerShell script to query and display the Azure Policy definitions and assignments created for AVNM dynamic network group membership. |

Before spinning up the powershell scripts, you should edit the file **init.json** and customize the values:
The structure of **init.json** file is shown below:
```json
{
    "subscriptionName": "YOUR_SUBSCRIPTION_NAME",
    "ResourceGroupName": "YOUR_RESOURCE_GROUP",
    "hub1location": "swedencentral",
    "hub2location": "swedencentral",
    "branch1location": "swedencentral",
    "branch2location": "swedencentral",
    "hub1Name": "hub1",
    "hub2Name": "hub2",
    "sharedKey": "VPN_SHARED_SECRET",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD"
}
```
<br>

Meaning of the variables:

- **subscriptionName**: Azure subscription name
- **ResourceGroupName**: name of the resource group
- **hub1location**: Azure region for virtual hub1
- **hub2location**: Azure region for virtual hub2
- **branch1location**: Azure region to deploy branch1
- **branch2location**: Azure region to deploy branch2
- **hub1Name**: name of virtual hub1
- **hub2Name**: name of virtual hub2
- **sharedKey**: VPN shared secret (PSK) for the S2S connections
- **adminUsername**: administrator username for the Azure VMs
- **adminPassword**: administrator password for the Azure VMs

`init.json` guarantees consistency by providing the same input values to all ARM templates.

---

## 6. Deployment steps

Deployment must be carried out in the strict sequence below. Each step depends on resources created by the previous one.

| Step | Script | What it deploys | Prerequisite |
|:----:|--------|-----------------|:------------:|
| 1 | customize **init.json** | Input variables for all scripts | — |
| 2 | **01-vwan.ps1** | vWAN, hub1, hub2, route tables (red/blue/default with labels), 6 standalone tagged spoke VNets, VMs. No `hubVirtualNetworkConnections` — AVNM (step 6) creates all hub attachments. | — |
| 3 | **02-vpn.ps1** | branch1 and branch2 VNets with Azure VPN Gateways (Generation 2, BGP). Reads `hub1_gw` and `hub2_gw` public IPs and BGP IPs from step 2 and passes them as parameters to `02-vpn.json` so branch gateways can peer with the vWAN hubs. | step 2 — hub1_gw and hub2_gw must exist |
| 4 | **03-vwan-site.ps1** | VPN sites (`h1-branch1`, `h2-branch2`) and S2S connections. Uses label-based route propagation (`default`, `red`, `blue`) so branches learn prefixes from both hubs without cross-hub ID references. | step 3 — VPN gateways must exist |
| 5 | **04-avnm-conn-policies.ps1** | 4 `connectionPolicies` sub-resources on hub1 and hub2. These are the hub targets referenced by AVNM connectivity configurations. Each policy encodes which route table a VNet is associated to and which labels its routes propagate into. | step 2 — hubs and route tables (red/blue) must exist |
| 6 | **05-avnm-manager.ps1** | Subscription-scoped ARM deployment: Network Manager, 4 network groups, 4 HubAndSpoke connectivity configs, 4 Azure Policy definitions + assignments, deployment script that commits and activates all configurations. | step 5 — connection policies must exist; step 2 — VNet tags must exist |

### Dependency chain

```
 init.json
    │
    ▼
 01-vwan.ps1  ────────────────────────────────────────┐
 (vWAN, hubs, route tables, tagged VNets)             │
    │                                                 │
    ▼                                                 ▼
 02-vpn.ps1                              04-avnm-conn-policies.ps1
 (VPN gateways hub1_gw / hub2_gw)        (connectionPolicies on hubs)
    │                                                 │
    ▼                                                 ▼
 03-vwan-site.ps1                        05-avnm-manager.ps1
 (VPN sites + S2S connections)           (AVNM: groups, configs, policies, commit)
```

> **Why does 01-vwan.json not create hub-VNet connections?**
> `hubVirtualNetworkConnections` (static connections) and AVNM-managed connections are **mutually exclusive** for the same VNet. Creating both for the same VNet results in a conflict error. `01-vwan.json` intentionally omits them entirely, leaving AVNM as the sole authority for all spoke-to-hub attachments.

> **Why must step 5 run before step 6?**
> `05-avnm-manager.json` (step 6) references the connection policy resource IDs in its connectivity configuration definitions. If the policies do not exist when the AVNM template is deployed, the ARM validation fails with a resource-not-found error.

<br>

---

## 7. Azure Virtual Network Manager integration

Starting from step 5, spoke VNet connectivity to the vWAN hubs is managed exclusively by **Azure Virtual Network Manager (AVNM)** instead of static `hubVirtualNetworkConnections`.

### End-to-end AVNM pipeline

The following chain describes how a tagged VNet automatically gets connected to the correct hub with the correct routing:

```
 VNet tag (environment=red1)
      │
      ▼ evaluated by
 Azure Policy (policy-red1)
      │  mode: Microsoft.Network.Data
      │  effect: addToNetworkGroup
      ▼
 Network Group (grp1-red)
      │
      ▼ target of
 Connectivity Configuration (connConfig1)  ── HubAndSpoke topology
      │                                        isGlobal: True
      ▼ references
 Connection Policy (hub1/policy1-red)
      │  associatedRouteTable: hub1/red
      │  propagatedLabels: [default, red]
      ▼
 Hub-VNet peering created by AVNM
 (equivalent to hubVirtualNetworkConnection but AVNM-managed)
```

This pipeline is fully automated: tagging a new VNet with `environment=red1` is sufficient to trigger the Azure Policy evaluation, add the VNet to `grp1-red`, and have AVNM create the hub peering with the correct route table association — no additional ARM deployments required.

### Connection Policies (step 5 — `04-avnm-conn-policies.json`)

A `connectionPolicy` is a sub-resource of a virtual hub (`Microsoft.Network/virtualHubs/connectionPolicies`). It acts as the **hub target** inside an AVNM connectivity configuration and encodes the routing behaviour that AVNM applies to every VNet it connects through that policy.

| Policy | Hub | Associated route table | Propagates via labels |
|--------|-----|------------------------|----------------------|
| `policy1-red` | hub1 | hub1/**red** | `default`, `red` → all hubs |
| `policy1-blue` | hub1 | hub1/**blue** | `default`, `blue` → all hubs |
| `policyhub2-red` | hub2 | hub2/**red** | `default`, `red` → all hubs |
| `policyhub2-blue` | hub2 | hub2/**blue** | `default`, `blue` → all hubs |

Using **labels** in `propagatedRouteTables` instead of explicit resource IDs means Azure automatically resolves the label to every matching route table across all hubs in the vWAN, without requiring cross-hub ID references. Adding a third hub in the future requires no changes to the connection policies.

### Network Manager (`net-mgr1`) — step 6 — `05-avnm-manager.json`

The ARM template is **subscription-scoped** (`subscriptionDeploymentTemplate.json#`). It is deployed via `New-AzDeployment` (not `New-AzResourceGroupDeployment`). It contains three nested deployments:

1. **`avnm` nested deployment** (RG-scoped) — creates the Network Manager resource, 4 network groups, and 4 connectivity configurations.
2. **`policy` nested deployment** (subscription-scoped) — creates 4 Azure Policy definitions and assignments.
3. **`commitConnectivityConfigs` nested deployment** (RG-scoped) — runs a `Microsoft.Resources/deploymentScripts` resource that calls `Deploy-AzNetworkManagerCommit` to activate the configurations. The commit step is mandatory: AVNM configurations are not enforced until explicitly committed.

#### Network groups and dynamic membership

| Tag value | Network group | Hub | Route table | Policy name |
|-----------|--------------|-----|-------------|-------------|
| `environment=red1` | `grp1-red` | hub1 | red | `policy-red1` |
| `environment=blue1` | `grp1-blue` | hub1 | blue | `policy-blue1` |
| `environment=red2` | `grp2-red` | hub2 | red | `policy-red2` |
| `environment=blue2` | `grp2-blue` | hub2 | blue | `policy-blue2` |

Azure Policy uses `mode: Microsoft.Network.Data` and `effect: addToNetworkGroup`. This mode evaluates VNet resources specifically and is required for AVNM dynamic membership — it cannot be replaced by a standard resource tag policy.

#### Connectivity configurations

| Config | Network group | Hub target (connection policy) |
|--------|--------------|--------------------------------|
| `connConfig1` | `grp1-red` | `hub1/policy1-red` |
| `connConfig2` | `grp1-blue` | `hub1/policy1-blue` |
| `connConfig3` | `grp2-blue` | `hub2/policyhub2-blue` |
| `connConfig4` | `grp2-red` | `hub2/policyhub2-red` |

All configurations use `connectivityTopology: HubAndSpoke` and `isGlobal: True` so that VNets in a group can reach the remote hub (cross-hub connectivity is enabled through the vWAN inter-hub BGP peering).

#### VNet tags set in `01-vwan.json`

The VNet tags set at deployment time align directly with the policy rules above:

| VNet  | CIDR        | Tag | Network group | Hub |
|-------|-------------|-----|---------------|-----|
| vnet1 | 10.0.1.0/24 | `environment=red1`  | grp1-red | hub1 |
| vnet2 | 10.0.2.0/24 | `environment=blue1` | grp1-blue | hub1 |
| vnet3 | 10.0.3.0/24 | `environment=blue1` | grp1-blue | hub1 |
| vnet4 | 10.0.4.0/24 | `environment=red2`  | grp2-red | hub2 |
| vnet5 | 10.0.5.0/24 | `environment=red2`  | grp2-red | hub2 |
| vnet6 | 10.0.6.0/24 | `environment=blue2` | grp2-blue | hub2 |

> **Adding a new spoke VNet**: create the VNet and set the correct `environment` tag. Azure Policy will add it to the right network group automatically. The next AVNM commit cycle (or a manual commit) will create the hub peering with the correct route table association. No changes to ARM templates or AVNM configurations are required.

---

## 8. Useful PowerShell commands

### vWAN VPN gateways

How to get the public IPs and the BGP peering IPs of the site-to-site VPN Gateway in **hub1**:
```powershell
$vpnGateway = Get-AzVpnGateway -ResourceGroupName $rgName -Name hub1_gw
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

How to retrieve the routing configuration of the S2S connection on hub1:
```powershell
(Get-AzVpnConnection -ResourceGroupName $rgName -ParentResourceName hub1_gw).RoutingConfiguration
```

To get the list of routing tables with properties in hub1:
```powershell
Get-AzVHubRouteTable -ResourceGroupName $rgName -HubName hub1
```

To inspect a specific route table (e.g., **red** in hub1):
```powershell
Get-AzVHubRouteTable -ResourceGroupName $rgName -HubName hub1 -Name red
```

To get the **effective routes** learned by a route table in hub1 (e.g., **red**):
```powershell
$routeTableId = (Get-AzVHubRouteTable -ResourceGroupName $rgName -HubName hub1 -Name red).Id
Get-AzVHubEffectiveRoute -ResourceGroupName $rgName -VirtualHubName hub1 `
    -VirtualWanResourceType RouteTable -ResourceId $routeTableId
```

How to check the peering status between vnet1 and hub1:
```powershell
Get-AzVirtualNetworkPeering -ResourceGroupName $rgName -VirtualNetworkName vnet1
```

### Azure Virtual Network Manager

List all network groups in the Network Manager:
```powershell
Get-AzNetworkManagerGroup -ResourceGroupName $rgName -NetworkManagerName net-mgr1
```

List effective connectivity configurations applied to a VNet (e.g., vnet1):
```powershell
Get-AzNetworkManagerEffectiveConnectivityConfiguration -VirtualNetworkName vnet1 -VirtualNetworkResourceGroupName $rgName
```

Check the status of the AVNM connectivity configurations:
```powershell
Get-AzNetworkManagerConnectivityConfiguration -ResourceGroupName $rgName -NetworkManagerName net-mgr1
```

Manually commit all 4 connectivity configurations (connConfig1–connConfig4):
```powershell
$subId = (Get-AzContext).Subscription.Id
$configIds = @(
    "/subscriptions/$subId/resourceGroups/$rgName/providers/Microsoft.Network/networkManagers/net-mgr1/connectivityConfigurations/connConfig1",
    "/subscriptions/$subId/resourceGroups/$rgName/providers/Microsoft.Network/networkManagers/net-mgr1/connectivityConfigurations/connConfig2",
    "/subscriptions/$subId/resourceGroups/$rgName/providers/Microsoft.Network/networkManagers/net-mgr1/connectivityConfigurations/connConfig3",
    "/subscriptions/$subId/resourceGroups/$rgName/providers/Microsoft.Network/networkManagers/net-mgr1/connectivityConfigurations/connConfig4"
)
Deploy-AzNetworkManagerCommit -ResourceGroupName $rgName -Name net-mgr1 `
    -TargetLocation @('swedencentral') -ConfigurationId $configIds -CommitType Connectivity
```

List AVNM connection policies on hub1 (child resources, not returned by Get-AzVirtualHub):
```powershell
$subId = (Get-AzContext).Subscription.Id
$uri = "https://management.azure.com/subscriptions/$subId/resourceGroups/$rgName/providers/Microsoft.Network/virtualHubs/hub1/connectionPolicies?api-version=2023-11-01"
(Invoke-AzRestMethod -Uri $uri -Method GET).Content | ConvertFrom-Json | Select-Object -ExpandProperty value
```

---

## 9. AVNM ARM template deep dive

Deployment of the Azure Virtual Network Manager (AVNM) in **05-avnm-manager.json** creates:

- 1 Network Manager (`net-mgr1`) scoped to the subscription, with `Connectivity` access
- 4 Network Groups (VirtualNetwork member type) — `grp1-red`, `grp1-blue`, `grp2-red`, `grp2-blue`
- 4 Connectivity Configurations (`connConfig1`–`connConfig4`) using `HubAndSpoke` topology, each targeting a vWAN virtual hub connection policy
- 4 Azure Policy definitions + assignments for **dynamic network group membership** based on VNet tags
- 1 User-Assigned Managed Identity + Contributor role assignment (needed by the deployment script)
- 1 Deployment Script that calls `Deploy-AzNetworkManagerCommit` to activate the connectivity configurations

---

### Resource architecture

```
Subscription
└── Resource Group
    └── Network Manager: net-mgr1  (scope: subscription, access: Connectivity)
        ├── Network Group: grp1-red   ──► connConfig1  ──► hub1 / policy1-red
        ├── Network Group: grp1-blue  ──► connConfig2  ──► hub1 / policy1-blue
        ├── Network Group: grp2-red   ──► connConfig4  ──► hub2 / policyhub2-red
        └── Network Group: grp2-blue  ──► connConfig3  ──► hub2 / policyhub2-blue

Subscription (policy scope)
├── Policy Definition + Assignment  ──► tag environment=red1  ──► grp1-red
├── Policy Definition + Assignment  ──► tag environment=blue1 ──► grp1-blue
├── Policy Definition + Assignment  ──► tag environment=red2  ──► grp2-red
└── Policy Definition + Assignment  ──► tag environment=blue2 ──► grp2-blue
```

### Dynamic membership

All four network groups use **dynamic membership** via Azure Policy (mode `Microsoft.Network.Data`, effect `addToNetworkGroup`). VNets are automatically placed into a group based on a tag:

| Tag `environment` value | Target Network Group |
|---|---|
| `red1`  | `grp1-red`  |
| `blue1` | `grp1-blue` |
| `red2`  | `grp2-red`  |
| `blue2` | `grp2-blue` |

There are **no static members** — group membership is fully driven by policy evaluation.

---

### ARM template: 05-avnm-manager.json

#### Deployment schema

The template uses the **subscription-scope schema**:

```
https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#
```

This is required because `Microsoft.Authorization/policyDefinitions` and `policyAssignments` are subscription-scoped resources. A resource-group deployment schema (`2019-04-01`) cannot host these resources at the correct scope.

#### Parameters
|---|---|---|
| `location` | `swedencentral` | Region for all resources |
| `resourceGroupName` | `vwan-avnm-1` | Resource group for the Network Manager |
| `hub1RedPolicyResourceId` | _(derived)_ | Full resource ID of `hub1/connectionPolicies/policy1-red` |
| `hub1BluePolicyResourceId` | _(derived)_ | Full resource ID of `hub1/connectionPolicies/policy1-blue` |
| `hub2BluePolicyResourceId` | _(derived)_ | Full resource ID of `hub2/connectionPolicies/policyhub2-blue` |
| `hub2RedPolicyResourceId` | _(derived)_ | Full resource ID of `hub2/connectionPolicies/policyhub2-red` |

Hub resource IDs are parameterised (not hardcoded) so the template is reusable across subscriptions and environments.

#### Nested deployment structure

The template uses three nested deployments to respect Azure scope constraints:

```
subscriptionDeploymentTemplate (root)
├── [nested RG deployment]  "avnm"
│   ├── Microsoft.ManagedIdentity/userAssignedIdentities    uai-net-mgr1
│   ├── Microsoft.Authorization/roleAssignments             Contributor on RG
│   ├── Microsoft.Network/networkManagers                   net-mgr1
│   ├── Microsoft.Network/networkManagers/networkGroups     grp1-red, grp1-blue, grp2-red, grp2-blue
│   └── Microsoft.Network/networkManagers/connectivityConfigurations  connConfig1–4
│
├── [nested subscription deployment]  "policy"
│   ├── Microsoft.Authorization/policyDefinitions           ×4 (one per group)
│   └── Microsoft.Authorization/policyAssignments           ×4 (one per definition)
│
└── [nested RG deployment]  "commitConnectivityConfigs"
    └── Microsoft.Resources/deploymentScripts               calls Deploy-AzNetworkManagerCommit
```

#### Why Three Nested Deployments?

Azure does not allow mixing resource-group–scoped resources (`Microsoft.Network/networkManagers`) and subscription-scoped resources (`Microsoft.Authorization/policyDefinitions`) in the same inline resource block. The solution is:

1. **`avnm` (RG-scoped)** — all network resources live here with `"resourceGroup": "[parameters('resourceGroupName')]"`
2. **`policy` (subscription-scoped)** — receives network group IDs as parameters via `reference(extensionResourceId(...)).outputs`, then creates policy definitions and assignments at subscription scope
3. **`commitConnectivityConfigs` (RG-scoped)** — runs after both previous deployments; activates the configurations via a PowerShell deployment script

### `expressionEvaluationOptions: { "scope": "inner" }`

All nested deployments include:

```json
"expressionEvaluationOptions": { "scope": "inner" }
```

Without this, ARM resolves `resourceId()` calls inside the nested template at the **outer deployment scope** (subscription), not the resource group scope — producing incorrect resource IDs. This is a silent bug that would cause the deployment to create resources with wrong parent references.

#### Connectivity configurations — commit requirement

Creating a connectivity configuration resource in AVNM does **not** automatically apply it to VNets. The configuration must be explicitly **committed** using `Deploy-AzNetworkManagerCommit`. The deployment script in `commitConnectivityConfigs` does this automatically as part of the ARM deployment, following the pattern from the [Azure Quickstart template](https://github.com/Azure/azure-quickstart-templates/tree/master/subscription-deployments/microsoft.network/virtual-network-manager-connectivity).

The script requires a User-Assigned Managed Identity with at least `Contributor` rights on the resource group to authenticate via `Connect-AzAccount -Identity`.

#### Policy definition names

Policy definitions are named with `uniqueString(networkGroupId)` instead of hardcoded names like `policy-red1`. This approach:

- Avoids name collisions when deploying to different subscriptions
- Matches the Azure quickstart reference pattern
- Keeps policy names idempotent across redeployments

---

### Deployment command

Because the root template is subscription-scoped, deploy with:

```powershell
New-AzDeployment `
  -Location swedencentral `
  -TemplateFile .\05-avnm-manager.json
```

Or with custom hub policy IDs for a different environment:

```powershell
New-AzDeployment `
  -Location swedencentral `
  -TemplateFile .\05-avnm-manager.json `
  -resourceGroupName my-rg `
  -hub1RedPolicyResourceId "/subscriptions/.../hub1/connectionPolicies/my-policy-red"
```

> **Prerequisites**: The vWAN hubs (`hub1`, `hub2`) and their connection policies must already exist before running this template. The ARM template references them by resource ID but does not create them.

### Cleanup

**Deleting the resource group alone is not sufficient.** The 4 Azure Policy definitions and 4 assignments are deployed at **subscription scope** and survive a resource group deletion. Remove them explicitly before or after deleting the group:

```powershell
# 1. Remove policy assignments (must precede definition removal)
Get-AzPolicyAssignment -Scope "/subscriptions/$subscriptionId" |
    Where-Object { $_.DisplayName -like 'AVNM dynamic membership*' } |
    ForEach-Object { Remove-AzPolicyAssignment -Id $_.Id }

# 2. Remove policy definitions
Get-AzPolicyDefinition -SubscriptionId $subscriptionId -Custom |
    Where-Object { $_.Mode -eq 'Microsoft.Network.Data' -and $_.Id -like "*/subscriptions/$subscriptionId/*" } |
    ForEach-Object { Remove-AzPolicyDefinition -Id $_.Id -Force }

# 3. Delete the resource group (removes all remaining resources)
Remove-AzResourceGroup -Name $ResourceGroupName -Force
```

Use **get-avnm-policies.ps1** to list and verify the policies before deleting them.

---

### Key design considerations

**1 — Scope mismatch is the central complexity**

`Microsoft.Authorization/policyDefinitions` and `policyAssignments` are subscription-scoped. `Microsoft.Network/networkManagers` and all its child resources are resource-group–scoped. These two scopes **cannot coexist** in a single deployment template that uses the resource-group schema. The solution is to use the subscription-scope schema at the root and nest the resource-group resources inside a `Microsoft.Resources/deployments` with a `resourceGroup` property.

**2 — Policy assignments scope**

In the live environment, policy assignments were created at subscription scope (not resource group scope). The ARM template replicates this by placing assignments inside the subscription-scoped `policy` nested deployment. If placed in a resource-group deployment, assignments would only apply to resources in that specific RG.

**3 — AVNM configurations must be committed**

Connectivity configurations exist as ARM resources but have no effect on VNet connectivity until committed. This is specific to AVNM and differs from most Azure resources. The ARM template handles this automatically via the deployment script. If deploying imperatively (the `.ps1` script), the commit step must be run separately.

**4 — Hub connection policy IDs are not ARM resource references**

The `hubs[].resourceId` inside connectivity configurations is a string field that AVNM uses to look up the vWAN integration — it is **not** a tracked ARM dependency. ARM will not validate that the referenced virtual hub or connection policy exists. Ensure the vWAN hub and its AVNM connection policies are deployed before committing.

**5 — Dynamic vs static membership**

All four network groups use dynamic membership (policy-based). There are no static members. When adding new VNets to a group, simply apply the correct `environment` tag to the VNet — no ARM redeployment is required.

**6 — Reference template**

The template structure follows the official Azure Quickstart:
[https://github.com/Azure/azure-quickstart-templates/tree/master/subscription-deployments/microsoft.network/virtual-network-manager-connectivity](https://github.com/Azure/azure-quickstart-templates/tree/master/subscription-deployments/microsoft.network/virtual-network-manager-connectivity)

Key patterns adopted from the reference:
- `expressionEvaluationOptions: { scope: "inner" }` on all nested deployments
- Policy resources isolated in their own nested subscription-scoped deployment
- Deployment script for automated config commit using a UAI
- Inner deployment outputs wired via `reference(extensionResourceId(...))`
- `uniqueString(networkGroupId)` for policy resource names


`Tags: virtual WAN, vWAN, Azure Virtual Network Mnager, AVNM` <br>
`testing date: 15-06-26`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/communication.png "communications"
[3]: ./media/red.png "network diagram"
[4]: ./media/blue.png "network diagram"


<!--Link References-->

