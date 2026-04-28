# Azure Virtual WAN two hubs with spoke VNets and child spoke VNets

## Overview

This project deploys an Azure Virtual WAN with two virtual hubs (**hub90** and **hub91**), each connected to a pair of spoke VNets. <br>
Each spoke VNet hosts a redundant pair of Linux-based NVAs (Network Virtual Appliances) behind a Standard Internal Load Balancer with HA ports, which steers east-west traffic between spokes through the NVA layer. Every parent spoke (spoke21, spoke22, spoke31, spoke32) has a child spoke (spoke21B, spoke22B, spoke31B, spoke32B) connected via VNet peering, with user-defined routes ensuring child-spoke traffic transits the parent NVAs. Two branch sites (branch1, branch2) connect to their respective virtual hubs over active-active site-to-site VPN gateways using BGP. All resources are deployed using ARM templates and PowerShell scripts.

## Architecture

The topology is organized around two virtual hubs (**hub90** and **hub91**) hosted in the same Azure Virtual WAN. Each hub is independent and manages its own set of spokes and branch connectivity.

The high-level network diagram is shown below:

[![1]][1]

The detailed network diagrams are shown below:

[![2]][2]

[![3]][3]

### Key Design Principles

#### 1. Redundant NVA pairs behind HA-ports ILBs
Each parent spoke (spoke21, spoke22, spoke31, spoke32) hosts two Linux VMs acting as NVAs, with IP forwarding enabled at both the OS level (`net.ipv4.ip_forward=1`) and the Azure NIC level (`enableIPForwarding: true`). The NVAs sit in a dedicated backend subnet (`subnetBE`) and are registered in a Standard Internal Load Balancer backend pool. A single HA-ports load-balancing rule (`protocol: All`, `frontendPort: 0`, `backendPort: 0`) distributes all IP flows across the pool, eliminating the need for per-protocol rules and providing active-active NVA load sharing with built-in health-probe failover.

#### 2. Child spoke extension via VNet peering
Each parent spoke has a child spoke peered to it (spoke21↔spoke21B, spoke22↔spoke22B, spoke31↔spoke31B, spoke32↔spoke32B). Both sides of the peering set `allowForwardedTraffic: true` so that packets forwarded by the NVAs are accepted across the peering link. `allowGatewayTransit` and `useRemoteGateways` are `false` on all peerings — hub connectivity for child spokes is achieved via static routes on the hub connection of the parent spoke, not through gateway transit over the peering.

#### 3. UDR-enforced NVA transit
Explicit user-defined routes on the parent workload subnets (`subnetWL`) and child spoke subnets send all inter-spoke and branch destination prefixes to the ILB frontend IP (`VirtualAppliance` next hop). This guarantees that traffic leaving these subnets always passes through an NVA before reaching the virtual hub. Parent workload route tables also set `disableBgpRoutePropagation: true` (`Propagate gateway routes = No` in the portal), preventing BGP-learned routes from the hub from overriding the UDR entries.

#### 4. Hub connection static routes
Each spoke's `hubVirtualNetworkConnection` object includes `vnetRoutes.staticRoutes` entries covering both the parent and child prefixes, with `nextHopIpAddress` set to the ILB frontend IP. The flag `staticRoutesConfig.vnetLocalRouteOverrideCriteria = Equal` ensures that when the hub resolves a prefix that matches a locally known route at equal length, the static route still takes precedence, forcing hub-to-spoke traffic through the NVA rather than taking a direct system route.

#### 5. Active-active S2S VPN with BGP
Branch sites connect to their hub over two active-active IPsec tunnels, one per VPN gateway instance. BGP is enabled on both sides: branch gateways use ASN 65011 (branch1) and 65012 (branch2), while the hub VPN gateways use ASN 65515. Active-active mode ensures that both tunnels carry traffic simultaneously and that failover is sub-second upon tunnel loss, without requiring manual intervention.

#### 6. Route-table association and propagation
All spoke and branch connections are associated with `defaultRouteTable` and propagate their routes with the label `default`. This causes each hub to learn the prefixes of all connected spokes and branches and makes those routes available to every other connection sharing the same label — including across hubs when inter-hub connectivity is configured. Combined with the hub connection static routes described above, this ensures fully symmetric forwarding paths (spoke-to-spoke, spoke-to-branch, and branch-to-spoke) through the NVA layer.

### Network Address Space — hub90

| VNet/Hub   | Address Space    | Purpose                                  |
|------------|------------------|------------------------------------------|
| hub90      | 10.90.0.0/23     | Virtual Hub                              |
| spoke21    | 10.21.0.0/24     | Spoke VNet with NVAs + workload          |
| spoke21B   | 10.21.1.0/24     | Extended spoke peered to spoke21         |
| spoke22    | 10.22.0.0/24     | Spoke VNet with NVAs + workload          |
| spoke22B   | 10.22.1.0/24     | Extended spoke peered to spoke22         |
| branch1    | 10.50.0.0/24     | Branch site1 connected via S2S VPN       |

### Network Address Space — hub91

| VNet/Hub   | Address Space    | Purpose                                  |
|------------|------------------|------------------------------------------|
| hub90      | 10.90.0.0/23     | Virtual Hub                              |
| spoke21    | 10.21.0.0/24     | Spoke VNet with NVAs + workload          |
| spoke21B   | 10.21.1.0/24     | Extended spoke peered to spoke21         |
| spoke22    | 10.22.0.0/24     | Spoke VNet with NVAs + workload          |
| spoke22B   | 10.22.1.0/24     | Extended spoke peered to spoke22         |
| branch1    | 10.50.0.0/24     | Branch site1 connected via S2SVPN        |

### Network Address Space for all componenets connect to hub91

| VNet/Hub   | Address Space    | Purpose                                  |
|------------|------------------|------------------------------------------|
| hub91      | 10.91.0.0/23     | Virtual Hub                              |
| spoke31    | 10.31.0.0/24     | Spoke VNet with NVAs + workload          |
| spoke31B   | 10.31.1.0/24     | Extended spoke peered to spoke31         |
| spoke32    | 10.32.0.0/24     | Spoke VNet with NVAs + workload          |
| spoke32B   | 10.32.1.0/24     | Extended spoke peered to spoke32         |
| branch2    | 10.51.0.0/24     | Branch site2 connected via S2SVPN        |

### Virtual Machines

| VM Name   | VNet     | Subnet      | Private IP   | Role            |
|-----------|----------|-------------|--------------|-----------------|
| R21-1     | spoke21  | subnetBE    | 10.21.0.20   | NVA (IP fwd)    |
| R21-2     | spoke21  | subnetBE    | 10.21.0.21   | NVA (IP fwd)    |
| WL21-1    | spoke21  | subnetWL    | 10.21.0.40   | Workload        |
| WL21B-1   | spoke21B | subnetWL21B | 10.21.1.4    | Workload        |
| R22-1     | spoke22  | subnetBE    | 10.22.0.20   | NVA (IP fwd)    |
| R22-2     | spoke22  | subnetBE    | 10.22.0.21   | NVA (IP fwd)    |
| WL22-1    | spoke22  | subnetWL    | 10.22.0.40   | Workload        |
| WL22B-1   | spoke22B | subnetWL22B | 10.22.1.4    | Workload        |
| branch1-vm| branch1  | subnet1     | (dynamic)    | Branch workload |

| VM Name   | VNet     | Subnet      | Private IP   | Role            |
|-----------|----------|-------------|--------------|-----------------|
| R31-1     | spoke31  | subnetBE    | 10.31.0.20   | NVA (IP fwd)    |
| R31-2     | spoke31  | subnetBE    | 10.31.0.21   | NVA (IP fwd)    |
| WL31-1    | spoke31  | subnetWL    | 10.31.0.40   | Workload        |
| WL31B-1   | spoke31B | subnetWL31B | 10.31.1.4    | Workload        |
| R32-1     | spoke32  | subnetBE    | 10.32.0.20   | NVA (IP fwd)    |
| R32-2     | spoke32  | subnetBE    | 10.32.0.21   | NVA (IP fwd)    |
| WL32-1    | spoke32  | subnetWL    | 10.32.0.40   | Workload        |
| WL32B-1   | spoke32B | subnetWL32B | 10.32.1.4    | Workload        |
| branch2-vm| branch2  | subnet1     | (dynamic)    | Branch workload |


All VMs run **Ubuntu** with **nginx** installed via custom script extension. <br>
**NVA VMs have IP forwarding enabled at both the OS and NIC level.**

### Routing

- Traffic is steered through the NVAs in each parent spoke by combining UDRs and internal load balancers. The parent-spoke ILBs are Standard internal load balancers with an HA Ports-style rule (`protocol: All`, `frontendPort: 0`, `backendPort: 0`), so any flow can be distributed to the NVA backend pool.
- In parent workload subnets (`subnetWL` in spoke21/spoke22 and spoke31/spoke32), UDR entries send inter-spoke and child-spoke prefixes to the local ILB frontend, so packets hit an NVA before leaving the VNet.
- UDR propagation flag: parent workload-subnet route tables are configured with `disableBgpRoutePropagation: true` (Azure portal shows this as `Propagate gateway routes = No`). This prevents BGP-propagated gateway routes from taking precedence over explicit UDR next-hop (`VirtualAppliance`) entries. Child-spoke route tables currently rely on explicit static routes and do not set this flag explicitly.
- VNet peering flags used by child-to-parent and parent-to-child peerings are: `allowVirtualNetworkAccess: true` (permit routed reachability), `allowForwardedTraffic: true` (required because traffic is forwarded by NVAs), `allowGatewayTransit: false`, and `useRemoteGateways: false` (no remote gateway transit through peering).
- Static routing on spoke hub-connections: each `hubVirtualNetworkConnection` to a spoke defines `vnetRoutes.staticRoutes` for exactly the parent-spoke and child-spoke prefixes (for example `to-spoke21-via-lb` and `to-spoke21B-via-lb`), with `nextHopIpAddress` set to the spoke ILB frontend. This forces hub-to-spoke/workload traffic through the NVA path instead of direct VNet system routing; `staticRoutesConfig.vnetLocalRouteOverrideCriteria = Equal` keeps the static route active when prefix lengths are equal.
- Hub connection route-table behavior: spoke connections are associated with `defaultRouteTable`, and propagated route tables include `defaultRouteTable` with label `default`. Route tables such as `RT_SHARED` and `RT_SPOKE` exist in the hub but are not directly bound in these connection blocks.
- Hub connection security/routing mode: `enableInternetSecurity` is set to `false` on the spoke `hubVirtualNetworkConnection` resources, so no secure internet breakout policy is enforced on these connections.
- Virtual Hub route-table propagation flags: in hub route tables, `Propagate routes from connections to this route table = Yes` allows branch (VPN/ER/User VPN) routes to be learned into the selected table, and propagation label `default` makes those learned routes available across hubs/tables using the same label. Combined with connection-level static routes to ILB next hops, this preserves symmetric VPN-to-spoke and spoke-to-spoke transit through NVAs.

## Configuration

All shared configuration is centralized in `init.json`.

### Full Variable Reference (`init.json`)

| Variable | Description |
|----------|-------------|
| `adminPassword` | Local administrator password used by VM deployments |
| `adminUsername` | Local administrator username used by VM deployments |
| `branch1AddressPrefix` | Address space prefix for the branch1 VNet |
| `branch1connectionGtwName1` | Name of VPN connection #1 on branch1 VPN gateway |
| `branch1connectionGtwName2` | Name of VPN connection #2 on branch1 VPN gateway |
| `branch1gatewaysubnetPrefix` | Address prefix for `GatewaySubnet` in branch1 VNet |
| `branch1gtwASN` | BGP ASN used by branch1 VPN gateway |
| `branch1localgatewayName1` | Name of local network gateway object #1 in branch resource group |
| `branch1localgatewayName2` | Name of local network gateway object #2 in branch resource group |
| `branch1location` | Azure region for branch1 resources |
| `branch1Name` | Name of branch1 VNet (also reused as VPN site logical name) |
| `branch1subnet1Name` | Name of workload subnet in branch1 VNet |
| `branch1subnet1Prefix` | Address prefix for branch1 workload subnet |
| `branch1vpnGtwName` | Name of branch1 VPN gateway resource |
| `hub1addressPrefix` | Address prefix for the virtual hub |
| `hub1location` | Azure region for virtual hub resources |
| `hub1Name` | Name of the virtual hub resource |
| `hub1ToBranchConnectionName` | Name of vHub-to-branch VPN connection |
| `hub1vpnGwName` | Name of VPN gateway deployed in the virtual hub |
| `R21_1_privIP` | Private IP assigned to VM `R21-1` |
| `R21_2_privIP` | Private IP assigned to VM `R21-2` |
| `R21-1` | VM name for first NVA in spoke21 |
| `R21-2` | VM name for second NVA in spoke21 |
| `R22_1_privIP` | Private IP assigned to VM `R22-1` |
| `R22_2_privIP` | Private IP assigned to VM `R22-2` |
| `R22-1` | VM name for first NVA in spoke22 |
| `R22-2` | VM name for second NVA in spoke22 |
| `rgBranch` | Resource group name for branch resources |
| `rgSpoke21` | Resource group name for spoke21 resources |
| `rgSpoke21B` | Resource group name used for spoke21B resources |
| `rgSpoke22` | Resource group name for spoke22 resources |
| `rgSpoke22B` | Resource group name used for spoke22B resources |
| `rgWanName` | Resource group name for vWAN and virtual hub resources |
| `sharedKey` | Pre-shared key for site-to-site VPN tunnels |
| `spoke21AddressPrefix` | Address space prefix for spoke21 VNet |
| `spoke21BAddressPrefix` | Address space prefix for spoke21B VNet |
| `spoke21Blocation` | Azure region for spoke21B resources |
| `spoke21BrtEntryNameMajorNet` | Route name in spoke21B route table for major network summary |
| `spoke21BrtEntryNameParentSpoke` | Route name in spoke21B route table toward parent spoke21 |
| `spoke21BrtSubnetWLName` | Route table name associated with spoke21B workload subnet |
| `spoke21BsubnetWLName` | Workload subnet name in spoke21B |
| `spoke21BsubnetWLPrefix` | Workload subnet prefix in spoke21B |
| `spoke21BvnetName` | VNet name for spoke21B |
| `spoke21lbBackEndPoolName` | Backend pool name of spoke21 internal load balancer |
| `spoke21lbFrontEndConfigName` | Frontend configuration name of spoke21 internal load balancer |
| `spoke21lbFrontEndIP` | Frontend private IP of spoke21 internal load balancer |
| `spoke21lbName` | Name of spoke21 internal load balancer |
| `spoke21lbProbeName` | Health probe name for spoke21 internal load balancer |
| `spoke21location` | Azure region for spoke21 resources |
| `spoke21rtEntryNameLocalChildSpoke` | Route name in spoke21 route table toward spoke21B |
| `spoke21rtEntryNameRemoteChildSpoke` | Route name in spoke21 route table toward spoke22B |
| `spoke21rtEntryNameRemoteSpoke` | Route name in spoke21 route table toward spoke22 |
| `spoke21rtSubnetWLName` | Route table name associated with spoke21 workload subnet |
| `spoke21subnetBEName` | Backend subnet name in spoke21 |
| `spoke21subnetBEPrefix` | Backend subnet prefix in spoke21 |
| `spoke21subnetFEName` | Frontend subnet name in spoke21 |
| `spoke21subnetFEPrefix` | Frontend subnet prefix in spoke21 |
| `spoke21subnetWLName` | Workload subnet name in spoke21 |
| `spoke21subnetWLPrefix` | Workload subnet prefix in spoke21 |
| `spoke21vnetName` | VNet name for spoke21 |
| `spoke22AddressPrefix` | Address space prefix for spoke22 VNet |
| `spoke22BAddressPrefix` | Address space prefix for spoke22B VNet |
| `spoke22Blocation` | Azure region for spoke22B resources |
| `spoke22BrtEntryNameMajorNet` | Route name in spoke22B route table for major network summary |
| `spoke22BrtEntryNameParentSpoke` | Route name in spoke22B route table toward parent spoke22 |
| `spoke22BrtSubnetWLName` | Route table name associated with spoke22B workload subnet |
| `spoke22BsubnetWLName` | Workload subnet name in spoke22B |
| `spoke22BsubnetWLPrefix` | Workload subnet prefix in spoke22B |
| `spoke22BvnetName` | VNet name for spoke22B |
| `spoke22lbBackEndPoolName` | Backend pool name of spoke22 internal load balancer |
| `spoke22lbFrontEndConfigName` | Frontend configuration name of spoke22 internal load balancer |
| `spoke22lbFrontEndIP` | Frontend private IP of spoke22 internal load balancer |
| `spoke22lbName` | Name of spoke22 internal load balancer |
| `spoke22lbProbeName` | Health probe name for spoke22 internal load balancer |
| `spoke22location` | Azure region for spoke22 resources |
| `spoke22rtEntryNameLocalChildSpoke` | Route name in spoke22 route table toward spoke22B |
| `spoke22rtEntryNameRemoteChildSpoke` | Route name in spoke22 route table toward spoke21B |
| `spoke22rtEntryNameRemoteSpoke` | Route name in spoke22 route table toward spoke21 |
| `spoke22rtSubnetWLName` | Route table name associated with spoke22 workload subnet |
| `spoke22subnetBEName` | Backend subnet name in spoke22 |
| `spoke22subnetBEPrefix` | Backend subnet prefix in spoke22 |
| `spoke22subnetFEName` | Frontend subnet name in spoke22 |
| `spoke22subnetFEPrefix` | Frontend subnet prefix in spoke22 |
| `spoke22subnetWLName` | Workload subnet name in spoke22 |
| `spoke22subnetWLPrefix` | Workload subnet prefix in spoke22 |
| `spoke22vnetName` | VNet name for spoke22 |
| `subscriptionName` | Azure subscription display name used by deployment scripts |
| `vnetpeeringName21Bto21` | Peering resource name from spoke21B to spoke21 |
| `vnetpeeringName21to21B` | Peering resource name from spoke21 to spoke21B |
| `vnetpeeringName22Bto22` | Peering resource name from spoke22B to spoke22 |
| `vnetpeeringName22to22B` | Peering resource name from spoke22 to spoke22B |
| `vpnSiteLink1Name` | Name of first link object in vWAN VPN site definition |
| `vpnSiteLink2Name` | Name of second link object in vWAN VPN site definition |
| `vwanName` | Name of Azure Virtual WAN resource |
| `WL21_1_privIP` | Private IP assigned to VM `WL21-1` |
| `WL21-1` | Workload VM name in spoke21 |
| `WL21B_1_privIP` | Private IP assigned to VM `WL21B-1` |
| `WL21B-1` | Workload VM name in spoke21B |
| `WL22_1_privIP` | Private IP assigned to VM `WL22-1` |
| `WL22-1` | Workload VM name in spoke22 |
| `WL22B_1_privIP` | Private IP assigned to VM `WL22B-1` |
| `WL22B-1` | Workload VM name in spoke22B |

> **Important**: Update `init.json` with your own subscription name, credentials, and shared key before running any script.
>
> All deployment scripts use `init.json` by default. To use a different parameter file, pass `-initFile <file-name-or-path>`. Example: `./01-spoke21.ps1 -initFile init2.json`.

## File Descriptions

| File                  | Type             | Description                                                                                       |
|-----------------------|------------------|---------------------------------------------------------------------------------------------------|
| `init.json`           | Configuration    | Shared input parameters (subscription, resource groups, locations, credentials) used by all scripts |
| `01-spoke21.json`     | ARM Template     | Deploys spoke21 VNet with subnets (FE, BE, WL), internal load balancer, NVA VMs (R21-1, R21-2), workload VM (WL21-1), route tables, and NSGs |
| `01-spoke21.ps1`      | PowerShell       | Deployment script for `01-spoke21.json` into the spoke21 resource group                           |
| `01-spoke22.json`     | ARM Template     | Deploys spoke22 VNet with subnets (FE, BE, WL), internal load balancer, NVA VMs (R22-1, R22-2), workload VM (WL22-1), route tables, and NSGs |
| `01-spoke22.ps1`      | PowerShell       | Deployment script for `01-spoke22.json` into the spoke22 resource group                           |
| `02-vwan.json`        | ARM Template     | Deploys Virtual WAN, Virtual Hub (hub90), hub route tables (defaultRouteTable, RT_SHARED, RT_SPOKE), VNet connections for spoke21 and spoke22 with static routes, and the S2S VPN gateway |
| `02-vwan.ps1`         | PowerShell       | Deployment script for `02-vwan.json` into the vWAN resource group                                 |
| `02-spoke21B.json`    | ARM Template     | Deploys spoke21B VNet, VNet peering to spoke21, route table, workload VM (WL21B-1), and NSGs      |
| `02-spoke21B.ps1`     | PowerShell       | Deployment script for `02-spoke21B.json` into the spoke21 resource group                          |
| `02-spoke22B.json`    | ARM Template     | Deploys spoke22B VNet, VNet peering to spoke22, route table, workload VM (WL22B-1), and NSGs      |
| `02-spoke22B.ps1`     | PowerShell       | Deployment script for `02-spoke22B.json` into the spoke22 resource group                          |
| `03-vpn.json`         | ARM Template     | Deploys branch1 VNet, active-active VPN gateway (gw-branch1), local network gateways, VPN connections to the hub, and branch VM (vm-branch1) |
| `03-vpn.ps1`          | PowerShell       | Deployment script for `03-vpn.json`; reads vWAN VPN gateway public IPs and BGP IPs at runtime     |
| `03-vwan-site.json`   | ARM Template     | Creates the VPN site in vWAN and the VPN connection from the hub to branch1 with BGP-enabled links |
| `03-vwan-site.ps1`    | PowerShell       | Deployment script for `03-vwan-site.json`; reads branch1 VPN gateway public IPs and BGP IPs at runtime |
| `README.md`           | Documentation    | Original project documentation                                                                     |

## Deployment sequence for hub90 and related components

The scripts must be executed **sequentially** in the following order. Each step depends on resources created in the previous step.

### Step 1: Deploy Spoke VNets (can run in parallel)

```powershell
.\01-spoke21.ps1
.\01-spoke22.ps1
```

Deploys the spoke21 and spoke22 VNets with their NVA VMs, load balancers, route tables, and workload VMs.

### Step 2: Deploy Virtual WAN, Hub, and Extended Spokes

```powershell
.\02-vwan.ps1
```

Deploys the Virtual WAN, Virtual Hub (hub90), hub routing tables, VNet-to-hub connections with static routes, and the S2S VPN gateway. **Spoke21 and spoke22 VNets must already exist** (from Step 1).

Then deploy the extended spokes (can run in parallel):

```powershell
.\02-spoke21B.ps1
.\02-spoke22B.ps1
```

Deploys spoke21B and spoke22B VNets with VNet peering to their parent spokes and workload VMs.

### Step 3: Deploy Branch VPN and vWAN Site

```powershell
.\03-vpn.ps1
```

Deploys the branch1 VNet with an active-active VPN gateway. This script **automatically reads** the vWAN VPN gateway public IPs and BGP IPs from the deployed hub gateway.

```powershell
.\03-vwan-site.ps1
```

Creates the VPN site definition in vWAN and establishes the VPN connection from the hub to branch1. This script **automatically reads** the branch1 VPN gateway public IPs and BGP peer addresses.

### Re-deploy for a second hub (`hub91`) in the same vWAN

To deploy a second hub using the same Virtual WAN, prepare `init2.json` with second-hub values (at minimum set `hub1Name` to `hub91` and align hub-specific prefixes/gateway names), then run the full sequence with `-initFile`

## Deployment sequence for hub91 and related components

The deployment sequence for hub91 and its associated resources is:

1. Parent spokes: `spoke31` and `spoke32`
2. Hub and vWAN connection objects: `hub91` in `vwan1`
3. Child spokes: `spoke31B` and `spoke32B` with peering to parent spokes
4. Branch components: `branch2` VPN gateway and hub91-to-branch2 vWAN site connection

Run commands in this order (parallel only inside each step where indicated):

```powershell
# Step 1 - Parent spokes (can run in parallel)
.\01-spoke21.ps1 -initFile .\init2.json   # spoke31
.\01-spoke22.ps1 -initFile .\init2.json   # spoke32

# Step 2 - Hub91 in existing vWAN
.\02-vwan.ps1 -initFile .\init2.json

# Step 3 - Child spokes (can run in parallel)
.\02-spoke21B.ps1 -initFile .\init2.json  # spoke31B
.\02-spoke22B.ps1 -initFile .\init2.json  # spoke32B

# Step 4 - Branch2 VPN and site connection
.\03-vpn.ps1 -initFile .\init2.json
.\03-vwan-site.ps1 -initFile .\init2.json
```

```powershell
.\01-spoke21.ps1 -initFile .\init2.json
.\01-spoke22.ps1 -initFile .\init2.json
.\02-vwan.ps1 -initFile .\init2.json
.\02-spoke21B.ps1 -initFile .\init2.json
.\02-spoke22B.ps1 -initFile .\init2.json
.\03-vpn.ps1 -initFile .\init2.json
.\03-vwan-site.ps1 -initFile .\init2.json
```

This keeps the same deployment logic while sourcing all parameters from `init2.json`.

## ANNEX: Checking flow symmetry through the NVAs

**tcpdump** in linux NVAs allows to verify the traffic in transit and the symmetric transit through the NVAs.
The **tcpdump** command are used in R21-1, R21-2, R22-1 and R22-2:

```console
root@R21-1:~# tcpdump -i eth0 -n "net 10.21.0.32/28 or net 10.21.1.0/24" and tcp
root@R22-1:~# tcpdump -i eth0 -n "net 10.22.0.32/28 or net 10.22.1.0/24" and tcp
```

### HTTP traffic flow from WL22B-1 to WL21B-1

[![4]][4]

```console
R21-1:~# tcpdump -i eth0 -n "net 10.21.0.32/28 or net 10.21.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
12:34:26.445122 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [S], seq 3435797763, win 64240, options [mss 1334,sackOK,TS val 2554232246 ecr 0,nop,wscale 7], length 0
12:34:26.445162 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [S], seq 3435797763, win 64240, options [mss 1334,sackOK,TS val 2554232246 ecr 0,nop,wscale 7], length 0
12:34:26.451511 IP 10.21.1.4.80 > 10.22.1.4.53268: Flags [S.], seq 897302288, ack 3435797764, win 65160, options [mss 1418,sackOK,TS val 151730069 ecr 2554232246,nop,wscale 7], length 0
12:34:26.451514 IP 10.21.1.4.80 > 10.22.1.4.53268: Flags [S.], seq 897302288, ack 3435797764, win 65160, options [mss 1418,sackOK,TS val 151730069 ecr 2554232246,nop,wscale 7], length 0
12:34:26.457438 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 2554232267 ecr 151730069], length 0
12:34:26.457439 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 2554232267 ecr 151730069], length 73: HTTP: GET / HTTP/1.1
12:34:26.457448 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 2554232267 ecr 151730069], length 0
12:34:26.457452 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 2554232267 ecr 151730069], length 73: HTTP: GET / HTTP/1.1
12:34:26.458804 IP 10.21.1.4.80 > 10.22.1.4.53268: Flags [.], ack 74, win 509, options [nop,nop,TS val 151730076 ecr 2554232267], length 0
12:34:26.458806 IP 10.21.1.4.80 > 10.22.1.4.53268: Flags [.], ack 74, win 509, options [nop,nop,TS val 151730076 ecr 2554232267], length 0
12:34:26.461374 IP 10.21.1.4.80 > 10.22.1.4.53268: Flags [P.], seq 1:303, ack 74, win 509, options [nop,nop,TS val 151730079 ecr 2554232267], length 302: HTTP: HTTP/1.1 200 OK
12:34:26.461376 IP 10.21.1.4.80 > 10.22.1.4.53268: Flags [P.], seq 1:303, ack 74, win 509, options [nop,nop,TS val 151730079 ecr 2554232267], length 302: HTTP: HTTP/1.1 200 OK
12:34:26.463904 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 2554232274 ecr 151730079], length 0
12:34:26.463904 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [F.], seq 74, ack 303, win 501, options [nop,nop,TS val 2554232274 ecr 151730079], length 0
12:34:26.463907 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 2554232274 ecr 151730079], length 0
12:34:26.463908 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [F.], seq 74, ack 303, win 501, options [nop,nop,TS val 2554232274 ecr 151730079], length 0
12:34:26.464573 IP 10.21.1.4.80 > 10.22.1.4.53268: Flags [F.], seq 303, ack 75, win 509, options [nop,nop,TS val 151730082 ecr 2554232274], length 0
12:34:26.464575 IP 10.21.1.4.80 > 10.22.1.4.53268: Flags [F.], seq 303, ack 75, win 509, options [nop,nop,TS val 151730082 ecr 2554232274], length 0
12:34:26.466466 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 2554232277 ecr 151730082], length 0
12:34:26.466468 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 2554232277 ecr 151730082], length 0
```

```console
R22-1:~# tcpdump -i eth0 -n "net 10.22.0.32/28 or net 10.22.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
12:34:26.435981 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [S], seq 3435797763, win 64240, options [mss 1418,sackOK,TS val 2554232246 ecr 0,nop,wscale 7], length 0
12:34:26.436004 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [S], seq 3435797763, win 64240, options [mss 1418,sackOK,TS val 2554232246 ecr 0,nop,wscale 7], length 0
12:34:26.453767 IP 10.21.1.4.80 > 10.22.1.4.53268: Flags [S.], seq 897302288, ack 3435797764, win 65160, options [mss 1334,sackOK,TS val 151730069 ecr 2554232246,nop,wscale 7], length 0
12:34:26.453781 IP 10.21.1.4.80 > 10.22.1.4.53268: Flags [S.], seq 897302288, ack 3435797764, win 65160, options [mss 1334,sackOK,TS val 151730069 ecr 2554232246,nop,wscale 7], length 0
12:34:26.456743 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 2554232267 ecr 151730069], length 0
12:34:26.456743 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 2554232267 ecr 151730069], length 73: HTTP: GET / HTTP/1.1
12:34:26.456746 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 2554232267 ecr 151730069], length 0
12:34:26.456748 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 2554232267 ecr 151730069], length 73: HTTP: GET / HTTP/1.1
12:34:26.459574 IP 10.21.1.4.80 > 10.22.1.4.53268: Flags [.], ack 74, win 509, options [nop,nop,TS val 151730076 ecr 2554232267], length 0
12:34:26.459575 IP 10.21.1.4.80 > 10.22.1.4.53268: Flags [.], ack 74, win 509, options [nop,nop,TS val 151730076 ecr 2554232267], length 0
12:34:26.462699 IP 10.21.1.4.80 > 10.22.1.4.53268: Flags [P.], seq 1:303, ack 74, win 509, options [nop,nop,TS val 151730079 ecr 2554232267], length 302: HTTP: HTTP/1.1 200 OK
12:34:26.462701 IP 10.21.1.4.80 > 10.22.1.4.53268: Flags [P.], seq 1:303, ack 74, win 509, options [nop,nop,TS val 151730079 ecr 2554232267], length 302: HTTP: HTTP/1.1 200 OK
12:34:26.463058 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 2554232274 ecr 151730079], length 0
12:34:26.463060 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 2554232274 ecr 151730079], length 0
12:34:26.463422 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [F.], seq 74, ack 303, win 501, options [nop,nop,TS val 2554232274 ecr 151730079], length 0
12:34:26.463424 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [F.], seq 74, ack 303, win 501, options [nop,nop,TS val 2554232274 ecr 151730079], length 0
12:34:26.465367 IP 10.21.1.4.80 > 10.22.1.4.53268: Flags [F.], seq 303, ack 75, win 509, options [nop,nop,TS val 151730082 ecr 2554232274], length 0
12:34:26.465368 IP 10.21.1.4.80 > 10.22.1.4.53268: Flags [F.], seq 303, ack 75, win 509, options [nop,nop,TS val 151730082 ecr 2554232274], length 0
12:34:26.466007 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 2554232277 ecr 151730082], length 0
12:34:26.466009 IP 10.22.1.4.53268 > 10.21.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 2554232277 ecr 151730082], length 0
```

### HTTP traffic flow from WL21B-1 to WL22B-1

[![5]][5]

```console
R21-1:~# tcpdump -i eth0 -n "net 10.21.0.32/28 or net 10.21.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
12:36:24.719821 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [S], seq 1713933705, win 64240, options [mss 1418,sackOK,TS val 151848336 ecr 0,nop,wscale 7], length 0
12:36:24.719849 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [S], seq 1713933705, win 64240, options [mss 1418,sackOK,TS val 151848336 ecr 0,nop,wscale 7], length 0
12:36:24.725287 IP 10.22.1.4.80 > 10.21.1.4.47984: Flags [S.], seq 770527061, ack 1713933706, win 65160, options [mss 1334,sackOK,TS val 2554350535 ecr 151848336,nop,wscale 7], length 0
12:36:24.725289 IP 10.22.1.4.80 > 10.21.1.4.47984: Flags [S.], seq 770527061, ack 1713933706, win 65160, options [mss 1334,sackOK,TS val 2554350535 ecr 151848336,nop,wscale 7], length 0
12:36:24.727289 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 151848344 ecr 2554350535], length 0
12:36:24.727289 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 151848345 ecr 2554350535], length 72: HTTP: GET / HTTP/1.1
12:36:24.727298 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 151848344 ecr 2554350535], length 0
12:36:24.727302 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 151848345 ecr 2554350535], length 72: HTTP: GET / HTTP/1.1
12:36:24.728942 IP 10.22.1.4.80 > 10.21.1.4.47984: Flags [.], ack 73, win 509, options [nop,nop,TS val 2554350540 ecr 151848345], length 0
12:36:24.728943 IP 10.22.1.4.80 > 10.21.1.4.47984: Flags [.], ack 73, win 509, options [nop,nop,TS val 2554350540 ecr 151848345], length 0
12:36:24.736692 IP 10.22.1.4.80 > 10.21.1.4.47984: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 2554350547 ecr 151848345], length 302: HTTP: HTTP/1.1 200 OK
12:36:24.736697 IP 10.22.1.4.80 > 10.21.1.4.47984: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 2554350547 ecr 151848345], length 302: HTTP: HTTP/1.1 200 OK
12:36:24.737612 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 151848355 ecr 2554350547], length 0
12:36:24.737612 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 151848355 ecr 2554350547], length 0
12:36:24.737614 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 151848355 ecr 2554350547], length 0
12:36:24.737616 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 151848355 ecr 2554350547], length 0
12:36:24.739789 IP 10.22.1.4.80 > 10.21.1.4.47984: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 2554350550 ecr 151848355], length 0
12:36:24.739794 IP 10.22.1.4.80 > 10.21.1.4.47984: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 2554350550 ecr 151848355], length 0
12:36:24.740482 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 151848358 ecr 2554350550], length 0
12:36:24.740487 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 151848358 ecr 2554350550], length 0
```

```console
R22-1:~# tcpdump -i eth0 -n "net 10.22.0.32/28 or net 10.22.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
12:36:24.722289 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [S], seq 1713933705, win 64240, options [mss 1334,sackOK,TS val 151848336 ecr 0,nop,wscale 7], length 0
12:36:24.722313 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [S], seq 1713933705, win 64240, options [mss 1334,sackOK,TS val 151848336 ecr 0,nop,wscale 7], length 0
12:36:24.724195 IP 10.22.1.4.80 > 10.21.1.4.47984: Flags [S.], seq 770527061, ack 1713933706, win 65160, options [mss 1418,sackOK,TS val 2554350535 ecr 151848336,nop,wscale 7], length 0
12:36:24.724225 IP 10.22.1.4.80 > 10.21.1.4.47984: Flags [S.], seq 770527061, ack 1713933706, win 65160, options [mss 1418,sackOK,TS val 2554350535 ecr 151848336,nop,wscale 7], length 0
12:36:24.728318 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 151848344 ecr 2554350535], length 0
12:36:24.728318 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 151848345 ecr 2554350535], length 72: HTTP: GET / HTTP/1.1
12:36:24.728327 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 151848344 ecr 2554350535], length 0
12:36:24.728330 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 151848345 ecr 2554350535], length 72: HTTP: GET / HTTP/1.1
12:36:24.728828 IP 10.22.1.4.80 > 10.21.1.4.47984: Flags [.], ack 73, win 509, options [nop,nop,TS val 2554350540 ecr 151848345], length 0
12:36:24.728830 IP 10.22.1.4.80 > 10.21.1.4.47984: Flags [.], ack 73, win 509, options [nop,nop,TS val 2554350540 ecr 151848345], length 0
12:36:24.736228 IP 10.22.1.4.80 > 10.21.1.4.47984: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 2554350547 ecr 151848345], length 302: HTTP: HTTP/1.1 200 OK
12:36:24.736236 IP 10.22.1.4.80 > 10.21.1.4.47984: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 2554350547 ecr 151848345], length 302: HTTP: HTTP/1.1 200 OK
12:36:24.738969 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 151848355 ecr 2554350547], length 0
12:36:24.738970 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 151848355 ecr 2554350547], length 0
12:36:24.738973 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 151848355 ecr 2554350547], length 0
12:36:24.738976 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 151848355 ecr 2554350547], length 0
12:36:24.739274 IP 10.22.1.4.80 > 10.21.1.4.47984: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 2554350550 ecr 151848355], length 0
12:36:24.739276 IP 10.22.1.4.80 > 10.21.1.4.47984: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 2554350550 ecr 151848355], length 0
12:36:24.741319 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 151848358 ecr 2554350550], length 0
12:36:24.741321 IP 10.21.1.4.47984 > 10.22.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 151848358 ecr 2554350550], length 0
```

### HTTP traffic flow from WL21-1 to WL22B-1

[![6]][6]

```console
R21-1:~# tcpdump -i eth0 -n "net 10.21.0.32/28 or net 10.21.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
12:38:42.876742 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [S], seq 2924366574, win 64240, options [mss 1418,sackOK,TS val 1565667425 ecr 0,nop,wscale 7], length 0
12:38:42.876778 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [S], seq 2924366574, win 64240, options [mss 1418,sackOK,TS val 1565667425 ecr 0,nop,wscale 7], length 0
12:38:42.889363 IP 10.22.1.4.80 > 10.21.0.40.54814: Flags [S.], seq 2433409774, ack 2924366575, win 65160, options [mss 1334,sackOK,TS val 3064955085 ecr 1565667425,nop,wscale 7], length 0
12:38:42.889372 IP 10.22.1.4.80 > 10.21.0.40.54814: Flags [S.], seq 2433409774, ack 2924366575, win 65160, options [mss 1334,sackOK,TS val 3064955085 ecr 1565667425,nop,wscale 7], length 0
12:38:42.891180 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1565667440 ecr 3064955085], length 0
12:38:42.891180 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 1565667441 ecr 3064955085], length 72: HTTP: GET / HTTP/1.1
12:38:42.891183 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1565667440 ecr 3064955085], length 0
12:38:42.891184 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 1565667441 ecr 3064955085], length 72: HTTP: GET / HTTP/1.1
12:38:42.893521 IP 10.22.1.4.80 > 10.21.0.40.54814: Flags [.], ack 73, win 509, options [nop,nop,TS val 3064955091 ecr 1565667441], length 0
12:38:42.893521 IP 10.22.1.4.80 > 10.21.0.40.54814: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 3064955091 ecr 1565667441], length 302: HTTP: HTTP/1.1 200 OK
12:38:42.893523 IP 10.22.1.4.80 > 10.21.0.40.54814: Flags [.], ack 73, win 509, options [nop,nop,TS val 3064955091 ecr 1565667441], length 0
12:38:42.893524 IP 10.22.1.4.80 > 10.21.0.40.54814: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 3064955091 ecr 1565667441], length 302: HTTP: HTTP/1.1 200 OK
12:38:42.894485 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 1565667444 ecr 3064955091], length 0
12:38:42.894486 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 1565667444 ecr 3064955091], length 0
12:38:42.894655 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 1565667445 ecr 3064955091], length 0
12:38:42.894657 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 1565667445 ecr 3064955091], length 0
12:38:42.896738 IP 10.22.1.4.80 > 10.21.0.40.54814: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 3064955094 ecr 1565667445], length 0
12:38:42.896740 IP 10.22.1.4.80 > 10.21.0.40.54814: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 3064955094 ecr 1565667445], length 0
12:38:42.897612 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 1565667448 ecr 3064955094], length 0
12:38:42.897614 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 1565667448 ecr 3064955094], length 0
```

```console
R22-1:~# tcpdump -i eth0 -n "net 10.22.0.32/28 or net 10.22.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
12:38:42.884705 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [S], seq 2924366574, win 64240, options [mss 1334,sackOK,TS val 1565667425 ecr 0,nop,wscale 7], length 0
12:38:42.884731 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [S], seq 2924366574, win 64240, options [mss 1334,sackOK,TS val 1565667425 ecr 0,nop,wscale 7], length 0
12:38:42.886956 IP 10.22.1.4.80 > 10.21.0.40.54814: Flags [S.], seq 2433409774, ack 2924366575, win 65160, options [mss 1418,sackOK,TS val 3064955085 ecr 1565667425,nop,wscale 7], length 0
12:38:42.886962 IP 10.22.1.4.80 > 10.21.0.40.54814: Flags [S.], seq 2433409774, ack 2924366575, win 65160, options [mss 1418,sackOK,TS val 3064955085 ecr 1565667425,nop,wscale 7], length 0
12:38:42.892258 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1565667440 ecr 3064955085], length 0
12:38:42.892258 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 1565667441 ecr 3064955085], length 72: HTTP: GET / HTTP/1.1
12:38:42.892268 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1565667440 ecr 3064955085], length 0
12:38:42.892272 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 1565667441 ecr 3064955085], length 72: HTTP: GET / HTTP/1.1
12:38:42.892665 IP 10.22.1.4.80 > 10.21.0.40.54814: Flags [.], ack 73, win 509, options [nop,nop,TS val 3064955091 ecr 1565667441], length 0
12:38:42.892667 IP 10.22.1.4.80 > 10.21.0.40.54814: Flags [.], ack 73, win 509, options [nop,nop,TS val 3064955091 ecr 1565667441], length 0
12:38:42.893306 IP 10.22.1.4.80 > 10.21.0.40.54814: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 3064955091 ecr 1565667441], length 302: HTTP: HTTP/1.1 200 OK
12:38:42.893308 IP 10.22.1.4.80 > 10.21.0.40.54814: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 3064955091 ecr 1565667441], length 302: HTTP: HTTP/1.1 200 OK
12:38:42.895775 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 1565667444 ecr 3064955091], length 0
12:38:42.895776 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 1565667445 ecr 3064955091], length 0
12:38:42.895779 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 1565667444 ecr 3064955091], length 0
12:38:42.895781 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 1565667445 ecr 3064955091], length 0
12:38:42.896171 IP 10.22.1.4.80 > 10.21.0.40.54814: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 3064955094 ecr 1565667445], length 0
12:38:42.896175 IP 10.22.1.4.80 > 10.21.0.40.54814: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 3064955094 ecr 1565667445], length 0
12:38:42.898355 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 1565667448 ecr 3064955094], length 0
12:38:42.898358 IP 10.21.0.40.54814 > 10.22.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 1565667448 ecr 3064955094], length 0
```


### HTTP traffic flow from WL21-1 to WL21B-1

[![7]][7]

```console
R21-1:~# tcpdump -i eth0 -n "net 10.21.0.32/28 or net 10.21.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
12:41:11.345847 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [S], seq 1261367137, win 64240, options [mss 1334,sackOK,TS val 3418678746 ecr 0,nop,wscale 7], length 0
12:41:11.345871 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [S], seq 1261367137, win 64240, options [mss 1334,sackOK,TS val 3418678746 ecr 0,nop,wscale 7], length 0
12:41:11.348982 IP 10.21.1.4.80 > 10.22.0.40.35078: Flags [S.], seq 1990158662, ack 1261367138, win 65160, options [mss 1418,sackOK,TS val 1612027152 ecr 3418678746,nop,wscale 7], length 0
12:41:11.348989 IP 10.21.1.4.80 > 10.22.0.40.35078: Flags [S.], seq 1990158662, ack 1261367138, win 65160, options [mss 1418,sackOK,TS val 1612027152 ecr 3418678746,nop,wscale 7], length 0
12:41:11.352816 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 3418678755 ecr 1612027152], length 0
12:41:11.352817 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 3418678755 ecr 1612027152], length 72: HTTP: GET / HTTP/1.1
12:41:11.352824 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 3418678755 ecr 1612027152], length 0
12:41:11.352826 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 3418678755 ecr 1612027152], length 72: HTTP: GET / HTTP/1.1
12:41:11.353727 IP 10.21.1.4.80 > 10.22.0.40.35078: Flags [.], ack 73, win 509, options [nop,nop,TS val 1612027157 ecr 3418678755], length 0
12:41:11.353732 IP 10.21.1.4.80 > 10.22.0.40.35078: Flags [.], ack 73, win 509, options [nop,nop,TS val 1612027157 ecr 3418678755], length 0
12:41:11.354114 IP 10.21.1.4.80 > 10.22.0.40.35078: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 1612027158 ecr 3418678755], length 302: HTTP: HTTP/1.1 200 OK
12:41:11.354120 IP 10.21.1.4.80 > 10.22.0.40.35078: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 1612027158 ecr 3418678755], length 302: HTTP: HTTP/1.1 200 OK
12:41:11.355990 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 3418678759 ecr 1612027158], length 0
12:41:11.355990 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 3418678759 ecr 1612027158], length 0
12:41:11.355992 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 3418678759 ecr 1612027158], length 0
12:41:11.355993 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 3418678759 ecr 1612027158], length 0
12:41:11.356711 IP 10.21.1.4.80 > 10.22.0.40.35078: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 1612027160 ecr 3418678759], length 0
12:41:11.356716 IP 10.21.1.4.80 > 10.22.0.40.35078: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 1612027160 ecr 3418678759], length 0
12:41:11.358489 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 3418678761 ecr 1612027160], length 0
12:41:11.358490 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 3418678761 ecr 1612027160], length 0
```

```console
R22-1:~# tcpdump -i eth0 -n "net 10.22.0.32/28 or net 10.22.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
12:41:11.343947 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [S], seq 1261367137, win 64240, options [mss 1418,sackOK,TS val 3418678746 ecr 0,nop,wscale 7], length 0
12:41:11.343972 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [S], seq 1261367137, win 64240, options [mss 1418,sackOK,TS val 3418678746 ecr 0,nop,wscale 7], length 0
12:41:11.351318 IP 10.21.1.4.80 > 10.22.0.40.35078: Flags [S.], seq 1990158662, ack 1261367138, win 65160, options [mss 1334,sackOK,TS val 1612027152 ecr 3418678746,nop,wscale 7], length 0
12:41:11.351326 IP 10.21.1.4.80 > 10.22.0.40.35078: Flags [S.], seq 1990158662, ack 1261367138, win 65160, options [mss 1334,sackOK,TS val 1612027152 ecr 3418678746,nop,wscale 7], length 0
12:41:11.352176 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 3418678755 ecr 1612027152], length 0
12:41:11.352176 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 3418678755 ecr 1612027152], length 72: HTTP: GET / HTTP/1.1
12:41:11.352179 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 3418678755 ecr 1612027152], length 0
12:41:11.352181 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 3418678755 ecr 1612027152], length 72: HTTP: GET / HTTP/1.1
12:41:11.354795 IP 10.21.1.4.80 > 10.22.0.40.35078: Flags [.], ack 73, win 509, options [nop,nop,TS val 1612027157 ecr 3418678755], length 0
12:41:11.354797 IP 10.21.1.4.80 > 10.22.0.40.35078: Flags [.], ack 73, win 509, options [nop,nop,TS val 1612027157 ecr 3418678755], length 0
12:41:11.355222 IP 10.21.1.4.80 > 10.22.0.40.35078: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 1612027158 ecr 3418678755], length 302: HTTP: HTTP/1.1 200 OK
12:41:11.355226 IP 10.21.1.4.80 > 10.22.0.40.35078: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 1612027158 ecr 3418678755], length 302: HTTP: HTTP/1.1 200 OK
12:41:11.355431 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 3418678759 ecr 1612027158], length 0
12:41:11.355433 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 3418678759 ecr 1612027158], length 0
12:41:11.355603 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 3418678759 ecr 1612027158], length 0
12:41:11.355604 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 3418678759 ecr 1612027158], length 0
12:41:11.357674 IP 10.21.1.4.80 > 10.22.0.40.35078: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 1612027160 ecr 3418678759], length 0
12:41:11.357677 IP 10.21.1.4.80 > 10.22.0.40.35078: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 1612027160 ecr 3418678759], length 0
12:41:11.357810 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 3418678761 ecr 1612027160], length 0
12:41:11.357812 IP 10.22.0.40.35078 > 10.21.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 3418678761 ecr 1612027160], length 0
```

### HTTP traffic flow from WL21-1 to WL22-1

[![8]][8]

```console
R21-1:~# tcpdump -i eth0 -n "net 10.21.0.32/28 or net 10.21.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
12:43:05.758697 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [S], seq 2634609872, win 64240, options [mss 1418,sackOK,TS val 267390605 ecr 0,nop,wscale 7], length 0
12:43:05.758732 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [S], seq 2634609872, win 64240, options [mss 1418,sackOK,TS val 267390605 ecr 0,nop,wscale 7], length 0
12:43:05.764888 IP 10.22.0.40.80 > 10.21.0.40.56424: Flags [S.], seq 1886984927, ack 2634609873, win 65160, options [mss 1334,sackOK,TS val 2951629707 ecr 267390605,nop,wscale 7], length 0
12:43:05.764892 IP 10.22.0.40.80 > 10.21.0.40.56424: Flags [S.], seq 1886984927, ack 2634609873, win 65160, options [mss 1334,sackOK,TS val 2951629707 ecr 267390605,nop,wscale 7], length 0
12:43:05.767828 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 267390616 ecr 2951629707], length 0
12:43:05.767828 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 267390616 ecr 2951629707], length 73: HTTP: GET / HTTP/1.1
12:43:05.767831 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 267390616 ecr 2951629707], length 0
12:43:05.767832 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 267390616 ecr 2951629707], length 73: HTTP: GET / HTTP/1.1
12:43:05.770122 IP 10.22.0.40.80 > 10.21.0.40.56424: Flags [.], ack 74, win 509, options [nop,nop,TS val 2951629715 ecr 267390616], length 0
12:43:05.770127 IP 10.22.0.40.80 > 10.21.0.40.56424: Flags [.], ack 74, win 509, options [nop,nop,TS val 2951629715 ecr 267390616], length 0
12:43:05.770185 IP 10.22.0.40.80 > 10.21.0.40.56424: Flags [P.], seq 1:302, ack 74, win 509, options [nop,nop,TS val 2951629715 ecr 267390616], length 301: HTTP: HTTP/1.1 200 OK
12:43:05.770191 IP 10.22.0.40.80 > 10.21.0.40.56424: Flags [P.], seq 1:302, ack 74, win 509, options [nop,nop,TS val 2951629715 ecr 267390616], length 301: HTTP: HTTP/1.1 200 OK
12:43:05.770948 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [.], ack 302, win 501, options [nop,nop,TS val 267390619 ecr 2951629715], length 0
12:43:05.770949 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [.], ack 302, win 501, options [nop,nop,TS val 267390619 ecr 2951629715], length 0
12:43:05.772374 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [F.], seq 74, ack 302, win 501, options [nop,nop,TS val 267390620 ecr 2951629715], length 0
12:43:05.772378 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [F.], seq 74, ack 302, win 501, options [nop,nop,TS val 267390620 ecr 2951629715], length 0
12:43:05.774412 IP 10.22.0.40.80 > 10.21.0.40.56424: Flags [F.], seq 302, ack 75, win 509, options [nop,nop,TS val 2951629719 ecr 267390620], length 0
12:43:05.774414 IP 10.22.0.40.80 > 10.21.0.40.56424: Flags [F.], seq 302, ack 75, win 509, options [nop,nop,TS val 2951629719 ecr 267390620], length 0
12:43:05.775672 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 267390624 ecr 2951629719], length 0
12:43:05.775677 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 267390624 ecr 2951629719], length 0
```

```console
R22-1:~# tcpdump -i eth0 -n "net 10.22.0.32/28 or net 10.22.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
12:43:05.760739 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [S], seq 2634609872, win 64240, options [mss 1334,sackOK,TS val 267390605 ecr 0,nop,wscale 7], length 0
12:43:05.760761 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [S], seq 2634609872, win 64240, options [mss 1334,sackOK,TS val 267390605 ecr 0,nop,wscale 7], length 0
12:43:05.762561 IP 10.22.0.40.80 > 10.21.0.40.56424: Flags [S.], seq 1886984927, ack 2634609873, win 65160, options [mss 1418,sackOK,TS val 2951629707 ecr 267390605,nop,wscale 7], length 0
12:43:05.762573 IP 10.22.0.40.80 > 10.21.0.40.56424: Flags [S.], seq 1886984927, ack 2634609873, win 65160, options [mss 1418,sackOK,TS val 2951629707 ecr 267390605,nop,wscale 7], length 0
12:43:05.769220 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 267390616 ecr 2951629707], length 0
12:43:05.769220 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 267390616 ecr 2951629707], length 73: HTTP: GET / HTTP/1.1
12:43:05.769228 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 267390616 ecr 2951629707], length 0
12:43:05.769230 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 267390616 ecr 2951629707], length 73: HTTP: GET / HTTP/1.1
12:43:05.769722 IP 10.22.0.40.80 > 10.21.0.40.56424: Flags [.], ack 74, win 509, options [nop,nop,TS val 2951629715 ecr 267390616], length 0
12:43:05.769724 IP 10.22.0.40.80 > 10.21.0.40.56424: Flags [.], ack 74, win 509, options [nop,nop,TS val 2951629715 ecr 267390616], length 0
12:43:05.769810 IP 10.22.0.40.80 > 10.21.0.40.56424: Flags [P.], seq 1:302, ack 74, win 509, options [nop,nop,TS val 2951629715 ecr 267390616], length 301: HTTP: HTTP/1.1 200 OK
12:43:05.769812 IP 10.22.0.40.80 > 10.21.0.40.56424: Flags [P.], seq 1:302, ack 74, win 509, options [nop,nop,TS val 2951629715 ecr 267390616], length 301: HTTP: HTTP/1.1 200 OK
12:43:05.771913 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [.], ack 302, win 501, options [nop,nop,TS val 267390619 ecr 2951629715], length 0
12:43:05.771927 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [.], ack 302, win 501, options [nop,nop,TS val 267390619 ecr 2951629715], length 0
12:43:05.773163 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [F.], seq 74, ack 302, win 501, options [nop,nop,TS val 267390620 ecr 2951629715], length 0
12:43:05.773167 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [F.], seq 74, ack 302, win 501, options [nop,nop,TS val 267390620 ecr 2951629715], length 0
12:43:05.773778 IP 10.22.0.40.80 > 10.21.0.40.56424: Flags [F.], seq 302, ack 75, win 509, options [nop,nop,TS val 2951629719 ecr 267390620], length 0
12:43:05.773780 IP 10.22.0.40.80 > 10.21.0.40.56424: Flags [F.], seq 302, ack 75, win 509, options [nop,nop,TS val 2951629719 ecr 267390620], length 0
12:43:05.776510 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 267390624 ecr 2951629719], length 0
12:43:05.776513 IP 10.21.0.40.56424 > 10.22.0.40.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 267390624 ecr 2951629719], length 0
```

### HTTP traffic flow from WL22-1 to WL21-1

[![9]][9]

```console
R21-1:~# tcpdump -i eth0 -n "net 10.21.0.32/28 or net 10.21.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
12:44:58.224049 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [S], seq 1563015754, win 64240, options [mss 1334,sackOK,TS val 2951742161 ecr 0,nop,wscale 7], length 0
12:44:58.224072 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [S], seq 1563015754, win 64240, options [mss 1334,sackOK,TS val 2951742161 ecr 0,nop,wscale 7], length 0
12:44:58.225864 IP 10.21.0.40.80 > 10.22.0.40.60928: Flags [S.], seq 2197176778, ack 1563015755, win 65160, options [mss 1418,sackOK,TS val 267503074 ecr 2951742161,nop,wscale 7], length 0
12:44:58.225867 IP 10.21.0.40.80 > 10.22.0.40.60928: Flags [S.], seq 2197176778, ack 1563015755, win 65160, options [mss 1418,sackOK,TS val 267503074 ecr 2951742161,nop,wscale 7], length 0
12:44:58.230510 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 2951742175 ecr 267503074], length 0
12:44:58.230510 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 2951742175 ecr 267503074], length 73: HTTP: GET / HTTP/1.1
12:44:58.230513 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 2951742175 ecr 267503074], length 0
12:44:58.230514 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 2951742175 ecr 267503074], length 73: HTTP: GET / HTTP/1.1
12:44:58.231444 IP 10.21.0.40.80 > 10.22.0.40.60928: Flags [.], ack 74, win 509, options [nop,nop,TS val 267503080 ecr 2951742175], length 0
12:44:58.231446 IP 10.21.0.40.80 > 10.22.0.40.60928: Flags [.], ack 74, win 509, options [nop,nop,TS val 267503080 ecr 2951742175], length 0
12:44:58.236424 IP 10.21.0.40.80 > 10.22.0.40.60928: Flags [P.], seq 1:302, ack 74, win 509, options [nop,nop,TS val 267503085 ecr 2951742175], length 301: HTTP: HTTP/1.1 200 OK
12:44:58.236426 IP 10.21.0.40.80 > 10.22.0.40.60928: Flags [P.], seq 1:302, ack 74, win 509, options [nop,nop,TS val 267503085 ecr 2951742175], length 301: HTTP: HTTP/1.1 200 OK
12:44:58.238982 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [.], ack 302, win 501, options [nop,nop,TS val 2951742183 ecr 267503085], length 0
12:44:58.238982 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [F.], seq 74, ack 302, win 501, options [nop,nop,TS val 2951742183 ecr 267503085], length 0
12:44:58.238985 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [.], ack 302, win 501, options [nop,nop,TS val 2951742183 ecr 267503085], length 0
12:44:58.238986 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [F.], seq 74, ack 302, win 501, options [nop,nop,TS val 2951742183 ecr 267503085], length 0
12:44:58.240793 IP 10.21.0.40.80 > 10.22.0.40.60928: Flags [F.], seq 302, ack 75, win 509, options [nop,nop,TS val 267503088 ecr 2951742183], length 0
12:44:58.240794 IP 10.21.0.40.80 > 10.22.0.40.60928: Flags [F.], seq 302, ack 75, win 509, options [nop,nop,TS val 267503088 ecr 2951742183], length 0
12:44:58.243009 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 2951742188 ecr 267503088], length 0
12:44:58.243011 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 2951742188 ecr 267503088], length 0
```

```console
R22-1:~# tcpdump -i eth0 -n "net 10.22.0.32/28 or net 10.22.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
12:44:58.218215 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [S], seq 1563015754, win 64240, options [mss 1418,sackOK,TS val 2951742161 ecr 0,nop,wscale 7], length 0
12:44:58.218240 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [S], seq 1563015754, win 64240, options [mss 1418,sackOK,TS val 2951742161 ecr 0,nop,wscale 7], length 0
12:44:58.227750 IP 10.21.0.40.80 > 10.22.0.40.60928: Flags [S.], seq 2197176778, ack 1563015755, win 65160, options [mss 1334,sackOK,TS val 267503074 ecr 2951742161,nop,wscale 7], length 0
12:44:58.227759 IP 10.21.0.40.80 > 10.22.0.40.60928: Flags [S.], seq 2197176778, ack 1563015755, win 65160, options [mss 1334,sackOK,TS val 267503074 ecr 2951742161,nop,wscale 7], length 0
12:44:58.229939 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 2951742175 ecr 267503074], length 0
12:44:58.229940 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 2951742175 ecr 267503074], length 73: HTTP: GET / HTTP/1.1
12:44:58.229944 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 2951742175 ecr 267503074], length 0
12:44:58.229947 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 2951742175 ecr 267503074], length 73: HTTP: GET / HTTP/1.1
12:44:58.232597 IP 10.21.0.40.80 > 10.22.0.40.60928: Flags [.], ack 74, win 509, options [nop,nop,TS val 267503080 ecr 2951742175], length 0
12:44:58.232600 IP 10.21.0.40.80 > 10.22.0.40.60928: Flags [.], ack 74, win 509, options [nop,nop,TS val 267503080 ecr 2951742175], length 0
12:44:58.237521 IP 10.21.0.40.80 > 10.22.0.40.60928: Flags [P.], seq 1:302, ack 74, win 509, options [nop,nop,TS val 267503085 ecr 2951742175], length 301: HTTP: HTTP/1.1 200 OK
12:44:58.237523 IP 10.21.0.40.80 > 10.22.0.40.60928: Flags [P.], seq 1:302, ack 74, win 509, options [nop,nop,TS val 267503085 ecr 2951742175], length 301: HTTP: HTTP/1.1 200 OK
12:44:58.238237 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [.], ack 302, win 501, options [nop,nop,TS val 2951742183 ecr 267503085], length 0
12:44:58.238237 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [F.], seq 74, ack 302, win 501, options [nop,nop,TS val 2951742183 ecr 267503085], length 0
12:44:58.238241 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [.], ack 302, win 501, options [nop,nop,TS val 2951742183 ecr 267503085], length 0
12:44:58.238242 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [F.], seq 74, ack 302, win 501, options [nop,nop,TS val 2951742183 ecr 267503085], length 0
12:44:58.242330 IP 10.21.0.40.80 > 10.22.0.40.60928: Flags [F.], seq 302, ack 75, win 509, options [nop,nop,TS val 267503088 ecr 2951742183], length 0
12:44:58.242331 IP 10.21.0.40.80 > 10.22.0.40.60928: Flags [F.], seq 302, ack 75, win 509, options [nop,nop,TS val 267503088 ecr 2951742183], length 0
12:44:58.242566 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 2951742188 ecr 267503088], length 0
12:44:58.242567 IP 10.22.0.40.60928 > 10.21.0.40.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 2951742188 ecr 267503088], length 0
```

### HTTP traffic flow from WL21B-1 to vm-branch1

[![10]][10]

```console
R21-1:~# tcpdump -i eth0 -n "net 10.21.0.32/28 or net 10.21.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
12:51:30.040140 IP 10.21.1.4.37322 > 10.50.0.4.80: Flags [S], seq 2062193712, win 64240, options [mss 1418,sackOK,TS val 1936134459 ecr 0,nop,wscale 7], length 0
12:51:30.040161 IP 10.21.1.4.37322 > 10.50.0.4.80: Flags [S], seq 2062193712, win 64240, options [mss 1418,sackOK,TS val 1936134459 ecr 0,nop,wscale 7], length 0
12:51:30.049638 IP 10.50.0.4.80 > 10.21.1.4.37322: Flags [S.], seq 2363040750, ack 2062193713, win 65160, options [mss 1318,sackOK,TS val 1543140118 ecr 1936134459,nop,wscale 7], length 0
12:51:30.049641 IP 10.50.0.4.80 > 10.21.1.4.37322: Flags [S.], seq 2363040750, ack 2062193713, win 65160, options [mss 1318,sackOK,TS val 1543140118 ecr 1936134459,nop,wscale 7], length 0
12:51:30.054097 IP 10.21.1.4.37322 > 10.50.0.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1936134473 ecr 1543140118], length 0
12:51:30.054097 IP 10.21.1.4.37322 > 10.50.0.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 1936134473 ecr 1543140118], length 72: HTTP: GET / HTTP/1.1
12:51:30.054100 IP 10.21.1.4.37322 > 10.50.0.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1936134473 ecr 1543140118], length 0
12:51:30.054101 IP 10.21.1.4.37322 > 10.50.0.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 1936134473 ecr 1543140118], length 72: HTTP: GET / HTTP/1.1
12:51:30.055861 IP 10.50.0.4.80 > 10.21.1.4.37322: Flags [.], ack 73, win 509, options [nop,nop,TS val 1543140127 ecr 1936134473], length 0
12:51:30.055866 IP 10.50.0.4.80 > 10.21.1.4.37322: Flags [.], ack 73, win 509, options [nop,nop,TS val 1543140127 ecr 1936134473], length 0
12:51:30.056065 IP 10.50.0.4.80 > 10.21.1.4.37322: Flags [P.], seq 1:306, ack 73, win 509, options [nop,nop,TS val 1543140128 ecr 1936134473], length 305: HTTP: HTTP/1.1 200 OK
12:51:30.056071 IP 10.50.0.4.80 > 10.21.1.4.37322: Flags [P.], seq 1:306, ack 73, win 509, options [nop,nop,TS val 1543140128 ecr 1936134473], length 305: HTTP: HTTP/1.1 200 OK
12:51:30.056642 IP 10.21.1.4.37322 > 10.50.0.4.80: Flags [.], ack 306, win 501, options [nop,nop,TS val 1936134477 ecr 1543140128], length 0
12:51:30.056644 IP 10.21.1.4.37322 > 10.50.0.4.80: Flags [.], ack 306, win 501, options [nop,nop,TS val 1936134477 ecr 1543140128], length 0
12:51:30.056872 IP 10.21.1.4.37322 > 10.50.0.4.80: Flags [F.], seq 73, ack 306, win 501, options [nop,nop,TS val 1936134477 ecr 1543140128], length 0
12:51:30.056873 IP 10.21.1.4.37322 > 10.50.0.4.80: Flags [F.], seq 73, ack 306, win 501, options [nop,nop,TS val 1936134477 ecr 1543140128], length 0
12:51:30.058692 IP 10.50.0.4.80 > 10.21.1.4.37322: Flags [F.], seq 306, ack 74, win 509, options [nop,nop,TS val 1543140130 ecr 1936134477], length 0
12:51:30.058694 IP 10.50.0.4.80 > 10.21.1.4.37322: Flags [F.], seq 306, ack 74, win 509, options [nop,nop,TS val 1543140130 ecr 1936134477], length 0
12:51:30.059327 IP 10.21.1.4.37322 > 10.50.0.4.80: Flags [.], ack 307, win 501, options [nop,nop,TS val 1936134479 ecr 1543140130], length 0
12:51:30.059329 IP 10.21.1.4.37322 > 10.50.0.4.80: Flags [.], ack 307, win 501, options [nop,nop,TS val 1936134479 ecr 1543140130], length 0
```


### HTTP traffic flow from branch1-vm to WL21B-1

[![11]][11]

```console
R21-1:~# tcpdump -i eth0 -n "net 10.21.0.32/28 or net 10.21.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
12:59:36.864203 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [S], seq 1180132583, win 64240, options [mss 1318,sackOK,TS val 1543626934 ecr 0,nop,wscale 7], length 0
12:59:36.864229 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [S], seq 1180132583, win 64240, options [mss 1318,sackOK,TS val 1543626934 ecr 0,nop,wscale 7], length 0
12:59:36.867569 IP 10.21.1.4.80 > 10.50.0.4.43408: Flags [S.], seq 3614414061, ack 1180132584, win 65160, options [mss 1418,sackOK,TS val 1936621287 ecr 1543626934,nop,wscale 7], length 0
12:59:36.867571 IP 10.21.1.4.80 > 10.50.0.4.43408: Flags [S.], seq 3614414061, ack 1180132584, win 65160, options [mss 1418,sackOK,TS val 1936621287 ecr 1543626934,nop,wscale 7], length 0
12:59:36.870690 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1543626942 ecr 1936621287], length 0
12:59:36.870690 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 1543626942 ecr 1936621287], length 72: HTTP: GET / HTTP/1.1
12:59:36.870693 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1543626942 ecr 1936621287], length 0
12:59:36.870694 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 1543626942 ecr 1936621287], length 72: HTTP: GET / HTTP/1.1
12:59:36.871700 IP 10.21.1.4.80 > 10.50.0.4.43408: Flags [.], ack 73, win 509, options [nop,nop,TS val 1936621291 ecr 1543626942], length 0
12:59:36.871700 IP 10.21.1.4.80 > 10.50.0.4.43408: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 1936621291 ecr 1543626942], length 302: HTTP: HTTP/1.1 200 OK
12:59:36.871702 IP 10.21.1.4.80 > 10.50.0.4.43408: Flags [.], ack 73, win 509, options [nop,nop,TS val 1936621291 ecr 1543626942], length 0
12:59:36.871704 IP 10.21.1.4.80 > 10.50.0.4.43408: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 1936621291 ecr 1543626942], length 302: HTTP: HTTP/1.1 200 OK
12:59:36.873049 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 1543626945 ecr 1936621291], length 0
12:59:36.873051 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 1543626945 ecr 1936621291], length 0
12:59:36.873435 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 1543626945 ecr 1936621291], length 0
12:59:36.873437 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 1543626945 ecr 1936621291], length 0
12:59:36.874200 IP 10.21.1.4.80 > 10.50.0.4.43408: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 1936621294 ecr 1543626945], length 0
12:59:36.874203 IP 10.21.1.4.80 > 10.50.0.4.43408: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 1936621294 ecr 1543626945], length 0
12:59:36.876128 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 1543626947 ecr 1936621294], length 0
12:59:36.876133 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 1543626947 ecr 1936621294], length 0
```


### HTTP traffic flow from WL21B-1 to branch1-vm

[![12]][12]

```console
R21-1:~# tcpdump -i eth0 -n "net 10.21.0.32/28 or net 10.21.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
12:59:36.864203 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [S], seq 1180132583, win 64240, options [mss 1318,sackOK,TS val 1543626934 ecr 0,nop,wscale 7], length 0
12:59:36.864229 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [S], seq 1180132583, win 64240, options [mss 1318,sackOK,TS val 1543626934 ecr 0,nop,wscale 7], length 0
12:59:36.867569 IP 10.21.1.4.80 > 10.50.0.4.43408: Flags [S.], seq 3614414061, ack 1180132584, win 65160, options [mss 1418,sackOK,TS val 1936621287 ecr 1543626934,nop,wscale 7], length 0
12:59:36.867571 IP 10.21.1.4.80 > 10.50.0.4.43408: Flags [S.], seq 3614414061, ack 1180132584, win 65160, options [mss 1418,sackOK,TS val 1936621287 ecr 1543626934,nop,wscale 7], length 0
12:59:36.870690 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1543626942 ecr 1936621287], length 0
12:59:36.870690 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 1543626942 ecr 1936621287], length 72: HTTP: GET / HTTP/1.1
12:59:36.870693 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1543626942 ecr 1936621287], length 0
12:59:36.870694 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 1543626942 ecr 1936621287], length 72: HTTP: GET / HTTP/1.1
12:59:36.871700 IP 10.21.1.4.80 > 10.50.0.4.43408: Flags [.], ack 73, win 509, options [nop,nop,TS val 1936621291 ecr 1543626942], length 0
12:59:36.871700 IP 10.21.1.4.80 > 10.50.0.4.43408: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 1936621291 ecr 1543626942], length 302: HTTP: HTTP/1.1 200 OK
12:59:36.871702 IP 10.21.1.4.80 > 10.50.0.4.43408: Flags [.], ack 73, win 509, options [nop,nop,TS val 1936621291 ecr 1543626942], length 0
12:59:36.871704 IP 10.21.1.4.80 > 10.50.0.4.43408: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 1936621291 ecr 1543626942], length 302: HTTP: HTTP/1.1 200 OK
12:59:36.873049 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 1543626945 ecr 1936621291], length 0
12:59:36.873051 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 1543626945 ecr 1936621291], length 0
12:59:36.873435 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 1543626945 ecr 1936621291], length 0
12:59:36.873437 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 1543626945 ecr 1936621291], length 0
12:59:36.874200 IP 10.21.1.4.80 > 10.50.0.4.43408: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 1936621294 ecr 1543626945], length 0
12:59:36.874203 IP 10.21.1.4.80 > 10.50.0.4.43408: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 1936621294 ecr 1543626945], length 0
12:59:36.876128 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 1543626947 ecr 1936621294], length 0
12:59:36.876133 IP 10.50.0.4.43408 > 10.21.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 1543626947 ecr 1936621294], length 0
```

### Effective routes WL21-1 and WL21B-1

[![13]][13]

### Effective routes WL22-1 and WL22B-1

[![14]][14]

### HTTP traffic flow from branch1-vm to WL31-1

[![15]][15]

```console
R31-1:~# tcpdump -i eth0 -n "net 10.31.0.32/28 or net 10.31.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
15:20:22.482716 IP 10.50.0.4.49522 > 10.31.0.40.80: Flags [S], seq 764449696, win 64240, options [mss 1276,sackOK,TS val 3269670899 ecr 0,nop,wscale 7], length 0
15:20:22.482752 IP 10.50.0.4.49522 > 10.31.0.40.80: Flags [S], seq 764449696, win 64240, options [mss 1276,sackOK,TS val 3269670899 ecr 0,nop,wscale 7], length 0
15:20:22.484682 IP 10.31.0.40.80 > 10.50.0.4.49522: Flags [S.], seq 1182047163, ack 764449697, win 65160, options [mss 1418,sackOK,TS val 3270849958 ecr 3269670899,nop,wscale 7], length 0
15:20:22.484685 IP 10.31.0.40.80 > 10.50.0.4.49522: Flags [S.], seq 1182047163, ack 764449697, win 65160, options [mss 1418,sackOK,TS val 3270849958 ecr 3269670899,nop,wscale 7], length 0
15:20:22.490896 IP 10.50.0.4.49522 > 10.31.0.40.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 3269670911 ecr 3270849958], length 0
15:20:22.490897 IP 10.50.0.4.49522 > 10.31.0.40.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 3269670911 ecr 3270849958], length 73: HTTP: GET / HTTP/1.1
15:20:22.490918 IP 10.50.0.4.49522 > 10.31.0.40.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 3269670911 ecr 3270849958], length 0
15:20:22.490922 IP 10.50.0.4.49522 > 10.31.0.40.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 3269670911 ecr 3270849958], length 73: HTTP: GET / HTTP/1.1
15:20:22.491520 IP 10.31.0.40.80 > 10.50.0.4.49522: Flags [.], ack 74, win 509, options [nop,nop,TS val 3270849965 ecr 3269670911], length 0
15:20:22.491523 IP 10.31.0.40.80 > 10.50.0.4.49522: Flags [.], ack 74, win 509, options [nop,nop,TS val 3270849965 ecr 3269670911], length 0
15:20:22.491776 IP 10.31.0.40.80 > 10.50.0.4.49522: Flags [P.], seq 1:302, ack 74, win 509, options [nop,nop,TS val 3270849965 ecr 3269670911], length 301: HTTP: HTTP/1.1 200 OK
15:20:22.491778 IP 10.31.0.40.80 > 10.50.0.4.49522: Flags [P.], seq 1:302, ack 74, win 509, options [nop,nop,TS val 3270849965 ecr 3269670911], length 301: HTTP: HTTP/1.1 200 OK
15:20:22.495232 IP 10.50.0.4.49522 > 10.31.0.40.80: Flags [.], ack 302, win 501, options [nop,nop,TS val 3269670915 ecr 3270849965], length 0
15:20:22.495232 IP 10.50.0.4.49522 > 10.31.0.40.80: Flags [F.], seq 74, ack 302, win 501, options [nop,nop,TS val 3269670915 ecr 3270849965], length 0
15:20:22.495236 IP 10.50.0.4.49522 > 10.31.0.40.80: Flags [.], ack 302, win 501, options [nop,nop,TS val 3269670915 ecr 3270849965], length 0
15:20:22.495238 IP 10.50.0.4.49522 > 10.31.0.40.80: Flags [F.], seq 74, ack 302, win 501, options [nop,nop,TS val 3269670915 ecr 3270849965], length 0
15:20:22.495789 IP 10.31.0.40.80 > 10.50.0.4.49522: Flags [F.], seq 302, ack 75, win 509, options [nop,nop,TS val 3270849969 ecr 3269670915], length 0
15:20:22.495791 IP 10.31.0.40.80 > 10.50.0.4.49522: Flags [F.], seq 302, ack 75, win 509, options [nop,nop,TS val 3270849969 ecr 3269670915], length 0
15:20:22.498392 IP 10.50.0.4.49522 > 10.31.0.40.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 3269670917 ecr 3270849969], length 0
15:20:22.498395 IP 10.50.0.4.49522 > 10.31.0.40.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 3269670917 ecr 3270849969], length 0
```

### HTTP traffic flow from branch1-vm to WL31B-1

[![16]][16]

```console
R31-1:~# tcpdump -i eth0 -n "net 10.31.0.32/28 or net 10.31.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
15:47:49.186336 IP 10.50.0.4.42972 > 10.31.1.4.80: Flags [S], seq 3392736324, win 64240, options [mss 1276,sackOK,TS val 3829200063 ecr 0,nop,wscale 7], length 0
15:47:49.186373 IP 10.50.0.4.42972 > 10.31.1.4.80: Flags [S], seq 3392736324, win 64240, options [mss 1276,sackOK,TS val 3829200063 ecr 0,nop,wscale 7], length 0
15:47:49.187317 IP 10.31.1.4.80 > 10.50.0.4.42972: Flags [S.], seq 530408605, ack 3392736325, win 65160, options [mss 1418,sackOK,TS val 3352033127 ecr 3829200063,nop,wscale 7], length 0
15:47:49.187323 IP 10.31.1.4.80 > 10.50.0.4.42972: Flags [S.], seq 530408605, ack 3392736325, win 65160, options [mss 1418,sackOK,TS val 3352033127 ecr 3829200063,nop,wscale 7], length 0
15:47:49.189941 IP 10.50.0.4.42972 > 10.31.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 3829200067 ecr 3352033127], length 0
15:47:49.189941 IP 10.50.0.4.42972 > 10.31.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 3829200067 ecr 3352033127], length 72: HTTP: GET / HTTP/1.1
15:47:49.189946 IP 10.50.0.4.42972 > 10.31.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 3829200067 ecr 3352033127], length 0
15:47:49.189947 IP 10.50.0.4.42972 > 10.31.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 3829200067 ecr 3352033127], length 72: HTTP: GET / HTTP/1.1
15:47:49.190154 IP 10.31.1.4.80 > 10.50.0.4.42972: Flags [.], ack 73, win 509, options [nop,nop,TS val 3352033130 ecr 3829200067], length 0
15:47:49.190156 IP 10.31.1.4.80 > 10.50.0.4.42972: Flags [.], ack 73, win 509, options [nop,nop,TS val 3352033130 ecr 3829200067], length 0
15:47:49.191365 IP 10.31.1.4.80 > 10.50.0.4.42972: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 3352033131 ecr 3829200067], length 302: HTTP: HTTP/1.1 200 OK
15:47:49.191368 IP 10.31.1.4.80 > 10.50.0.4.42972: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 3352033131 ecr 3829200067], length 302: HTTP: HTTP/1.1 200 OK
15:47:49.192768 IP 10.50.0.4.42972 > 10.31.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 3829200071 ecr 3352033131], length 0
15:47:49.192770 IP 10.50.0.4.42972 > 10.31.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 3829200071 ecr 3352033131], length 0
15:47:49.192961 IP 10.50.0.4.42972 > 10.31.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 3829200071 ecr 3352033131], length 0
15:47:49.192963 IP 10.50.0.4.42972 > 10.31.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 3829200071 ecr 3352033131], length 0
15:47:49.193129 IP 10.31.1.4.80 > 10.50.0.4.42972: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 3352033133 ecr 3829200071], length 0
15:47:49.193131 IP 10.31.1.4.80 > 10.50.0.4.42972: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 3352033133 ecr 3829200071], length 0
15:47:49.194167 IP 10.50.0.4.42972 > 10.31.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 3829200072 ecr 3352033133], length 0
15:47:49.194171 IP 10.50.0.4.42972 > 10.31.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 3829200072 ecr 3352033133], length 0
```

### HTTP traffic flow from WL21-1 to WL31-1

[![17]][17]

```console
R21-1:~# tcpdump -i eth0 -n "net 10.21.0.32/28 or net 10.21.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
16:13:01.158265 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [S], seq 1798051304, win 64240, options [mss 1418,sackOK,TS val 2588915404 ecr 0,nop,wscale 7], length 0
16:13:01.158291 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [S], seq 1798051304, win 64240, options [mss 1418,sackOK,TS val 2588915404 ecr 0,nop,wscale 7], length 0
16:13:01.164469 IP 10.31.0.40.80 > 10.21.0.40.59344: Flags [S.], seq 2970897675, ack 1798051305, win 65160, options [mss 1292,sackOK,TS val 29057388 ecr 2588915404,nop,wscale 7], length 0
16:13:01.164492 IP 10.31.0.40.80 > 10.21.0.40.59344: Flags [S.], seq 2970897675, ack 1798051305, win 65160, options [mss 1292,sackOK,TS val 29057388 ecr 2588915404,nop,wscale 7], length 0
16:13:01.165363 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 2588915411 ecr 29057388], length 0
16:13:01.165370 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 2588915411 ecr 29057388], length 0
16:13:01.166254 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 2588915413 ecr 29057388], length 73: HTTP: GET / HTTP/1.1
16:13:01.166263 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 2588915413 ecr 29057388], length 73: HTTP: GET / HTTP/1.1
16:13:01.169081 IP 10.31.0.40.80 > 10.21.0.40.59344: Flags [.], ack 74, win 509, options [nop,nop,TS val 29057394 ecr 2588915413], length 0
16:13:01.169081 IP 10.31.0.40.80 > 10.21.0.40.59344: Flags [P.], seq 1:302, ack 74, win 509, options [nop,nop,TS val 29057394 ecr 2588915413], length 301: HTTP: HTTP/1.1 200 OK
16:13:01.169105 IP 10.31.0.40.80 > 10.21.0.40.59344: Flags [.], ack 74, win 509, options [nop,nop,TS val 29057394 ecr 2588915413], length 0
16:13:01.169113 IP 10.31.0.40.80 > 10.21.0.40.59344: Flags [P.], seq 1:302, ack 74, win 509, options [nop,nop,TS val 29057394 ecr 2588915413], length 301: HTTP: HTTP/1.1 200 OK
16:13:01.169599 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [.], ack 302, win 501, options [nop,nop,TS val 2588915416 ecr 29057394], length 0
16:13:01.169602 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [.], ack 302, win 501, options [nop,nop,TS val 2588915416 ecr 29057394], length 0
16:13:01.169732 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [F.], seq 74, ack 302, win 501, options [nop,nop,TS val 2588915416 ecr 29057394], length 0
16:13:01.169734 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [F.], seq 74, ack 302, win 501, options [nop,nop,TS val 2588915416 ecr 29057394], length 0
16:13:01.171958 IP 10.31.0.40.80 > 10.21.0.40.59344: Flags [F.], seq 302, ack 75, win 509, options [nop,nop,TS val 29057397 ecr 2588915416], length 0
16:13:01.171968 IP 10.31.0.40.80 > 10.21.0.40.59344: Flags [F.], seq 302, ack 75, win 509, options [nop,nop,TS val 29057397 ecr 2588915416], length 0
16:13:01.172481 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 2588915419 ecr 29057397], length 0
16:13:01.172485 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 2588915419 ecr 29057397], length 0
```

```console
R31-1:~# tcpdump -i eth0 -n "net 10.31.0.32/28 or net 10.31.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
16:13:01.160470 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [S], seq 1798051304, win 64240, options [mss 1292,sackOK,TS val 2588915404 ecr 0,nop,wscale 7], length 0
16:13:01.160479 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [S], seq 1798051304, win 64240, options [mss 1292,sackOK,TS val 2588915404 ecr 0,nop,wscale 7], length 0
16:13:01.161783 IP 10.31.0.40.80 > 10.21.0.40.59344: Flags [S.], seq 2970897675, ack 1798051305, win 65160, options [mss 1418,sackOK,TS val 29057388 ecr 2588915404,nop,wscale 7], length 0
16:13:01.161790 IP 10.31.0.40.80 > 10.21.0.40.59344: Flags [S.], seq 2970897675, ack 1798051305, win 65160, options [mss 1418,sackOK,TS val 29057388 ecr 2588915404,nop,wscale 7], length 0
16:13:01.166168 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 2588915411 ecr 29057388], length 0
16:13:01.166175 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 2588915411 ecr 29057388], length 0
16:13:01.167178 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 2588915413 ecr 29057388], length 73: HTTP: GET / HTTP/1.1
16:13:01.167180 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 2588915413 ecr 29057388], length 73: HTTP: GET / HTTP/1.1
16:13:01.167784 IP 10.31.0.40.80 > 10.21.0.40.59344: Flags [.], ack 74, win 509, options [nop,nop,TS val 29057394 ecr 2588915413], length 0
16:13:01.167784 IP 10.31.0.40.80 > 10.21.0.40.59344: Flags [P.], seq 1:302, ack 74, win 509, options [nop,nop,TS val 29057394 ecr 2588915413], length 301: HTTP: HTTP/1.1 200 OK
16:13:01.167787 IP 10.31.0.40.80 > 10.21.0.40.59344: Flags [.], ack 74, win 509, options [nop,nop,TS val 29057394 ecr 2588915413], length 0
16:13:01.167789 IP 10.31.0.40.80 > 10.21.0.40.59344: Flags [P.], seq 1:302, ack 74, win 509, options [nop,nop,TS val 29057394 ecr 2588915413], length 301: HTTP: HTTP/1.1 200 OK
16:13:01.170241 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [.], ack 302, win 501, options [nop,nop,TS val 2588915416 ecr 29057394], length 0
16:13:01.170245 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [.], ack 302, win 501, options [nop,nop,TS val 2588915416 ecr 29057394], length 0
16:13:01.170328 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [F.], seq 74, ack 302, win 501, options [nop,nop,TS val 2588915416 ecr 29057394], length 0
16:13:01.170331 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [F.], seq 74, ack 302, win 501, options [nop,nop,TS val 2588915416 ecr 29057394], length 0
16:13:01.170962 IP 10.31.0.40.80 > 10.21.0.40.59344: Flags [F.], seq 302, ack 75, win 509, options [nop,nop,TS val 29057397 ecr 2588915416], length 0
16:13:01.170966 IP 10.31.0.40.80 > 10.21.0.40.59344: Flags [F.], seq 302, ack 75, win 509, options [nop,nop,TS val 29057397 ecr 2588915416], length 0
16:13:01.173188 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 2588915419 ecr 29057397], length 0
16:13:01.173193 IP 10.21.0.40.59344 > 10.31.0.40.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 2588915419 ecr 29057397], length 0
```

### HTTP traffic flow from WL21B-1 to WL31B-1

[![18]][18]

```console
R21-1:~# tcpdump -i eth0 -n "net 10.21.0.32/28 or net 10.21.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
16:20:11.892060 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [S], seq 345284666, win 64240, options [mss 1418,sackOK,TS val 4292521678 ecr 0,nop,wscale 7], length 0
16:20:11.892090 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [S], seq 345284666, win 64240, options [mss 1418,sackOK,TS val 4292521678 ecr 0,nop,wscale 7], length 0
16:20:11.898037 IP 10.31.1.4.80 > 10.21.1.4.47272: Flags [S.], seq 3615851820, ack 345284667, win 65160, options [mss 1292,sackOK,TS val 76377717 ecr 4292521678,nop,wscale 7], length 0
16:20:11.898055 IP 10.31.1.4.80 > 10.21.1.4.47272: Flags [S.], seq 3615851820, ack 345284667, win 65160, options [mss 1292,sackOK,TS val 76377717 ecr 4292521678,nop,wscale 7], length 0
16:20:11.899800 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 4292521687 ecr 76377717], length 0
16:20:11.899800 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 4292521687 ecr 76377717], length 72: HTTP: GET / HTTP/1.1
16:20:11.899812 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 4292521687 ecr 76377717], length 0
16:20:11.899816 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 4292521687 ecr 76377717], length 72: HTTP: GET / HTTP/1.1
16:20:11.901554 IP 10.31.1.4.80 > 10.21.1.4.47272: Flags [.], ack 73, win 509, options [nop,nop,TS val 76377722 ecr 4292521687], length 0
16:20:11.901563 IP 10.31.1.4.80 > 10.21.1.4.47272: Flags [.], ack 73, win 509, options [nop,nop,TS val 76377722 ecr 4292521687], length 0
16:20:11.904774 IP 10.31.1.4.80 > 10.21.1.4.47272: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 76377725 ecr 4292521687], length 302: HTTP: HTTP/1.1 200 OK
16:20:11.904784 IP 10.31.1.4.80 > 10.21.1.4.47272: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 76377725 ecr 4292521687], length 302: HTTP: HTTP/1.1 200 OK
16:20:11.905229 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 4292521692 ecr 76377725], length 0
16:20:11.905233 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 4292521692 ecr 76377725], length 0
16:20:11.905380 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 4292521693 ecr 76377725], length 0
16:20:11.905382 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 4292521693 ecr 76377725], length 0
16:20:11.906858 IP 10.31.1.4.80 > 10.21.1.4.47272: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 76377727 ecr 4292521693], length 0
16:20:11.906868 IP 10.31.1.4.80 > 10.21.1.4.47272: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 76377727 ecr 4292521693], length 0
16:20:11.907212 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 4292521694 ecr 76377727], length 0
16:20:11.907215 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 4292521694 ecr 76377727], length 0
```

```console
R31-1:~# tcpdump -i eth0 -n "net 10.31.0.32/28 or net 10.31.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
16:20:11.894496 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [S], seq 345284666, win 64240, options [mss 1292,sackOK,TS val 4292521678 ecr 0,nop,wscale 7], length 0
16:20:11.894533 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [S], seq 345284666, win 64240, options [mss 1292,sackOK,TS val 4292521678 ecr 0,nop,wscale 7], length 0
16:20:11.896183 IP 10.31.1.4.80 > 10.21.1.4.47272: Flags [S.], seq 3615851820, ack 345284667, win 65160, options [mss 1418,sackOK,TS val 76377717 ecr 4292521678,nop,wscale 7], length 0
16:20:11.896186 IP 10.31.1.4.80 > 10.21.1.4.47272: Flags [S.], seq 3615851820, ack 345284667, win 65160, options [mss 1418,sackOK,TS val 76377717 ecr 4292521678,nop,wscale 7], length 0
16:20:11.900675 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 4292521687 ecr 76377717], length 0
16:20:11.900675 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 4292521687 ecr 76377717], length 72: HTTP: GET / HTTP/1.1
16:20:11.900680 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 4292521687 ecr 76377717], length 0
16:20:11.900682 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 4292521687 ecr 76377717], length 72: HTTP: GET / HTTP/1.1
16:20:11.900908 IP 10.31.1.4.80 > 10.21.1.4.47272: Flags [.], ack 73, win 509, options [nop,nop,TS val 76377722 ecr 4292521687], length 0
16:20:11.900910 IP 10.31.1.4.80 > 10.21.1.4.47272: Flags [.], ack 73, win 509, options [nop,nop,TS val 76377722 ecr 4292521687], length 0
16:20:11.903713 IP 10.31.1.4.80 > 10.21.1.4.47272: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 76377725 ecr 4292521687], length 302: HTTP: HTTP/1.1 200 OK
16:20:11.903715 IP 10.31.1.4.80 > 10.21.1.4.47272: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 76377725 ecr 4292521687], length 302: HTTP: HTTP/1.1 200 OK
16:20:11.906004 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 4292521692 ecr 76377725], length 0
16:20:11.906004 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 4292521693 ecr 76377725], length 0
16:20:11.906009 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 4292521692 ecr 76377725], length 0
16:20:11.906011 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 4292521693 ecr 76377725], length 0
16:20:11.906189 IP 10.31.1.4.80 > 10.21.1.4.47272: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 76377727 ecr 4292521693], length 0
16:20:11.906192 IP 10.31.1.4.80 > 10.21.1.4.47272: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 76377727 ecr 4292521693], length 0
16:20:11.907741 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 4292521694 ecr 76377727], length 0
16:20:11.907748 IP 10.21.1.4.47272 > 10.31.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 4292521694 ecr 76377727], length 0
```

### HTTP traffic flow from WL21-1 to WL31B-1


[![18]][18]

```console
R21-1:~# tcpdump -i eth0 -n "net 10.21.0.32/28 or net 10.21.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
16:26:57.194384 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [S], seq 2824207374, win 64240, options [mss 1418,sackOK,TS val 3446815356 ecr 0,nop,wscale 7], length 0
16:26:57.194409 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [S], seq 2824207374, win 64240, options [mss 1418,sackOK,TS val 3446815356 ecr 0,nop,wscale 7], length 0
16:26:57.201336 IP 10.31.1.4.80 > 10.21.0.40.58862: Flags [S.], seq 79908996, ack 2824207375, win 65160, options [mss 1292,sackOK,TS val 1335449016 ecr 3446815356,nop,wscale 7], length 0
16:26:57.201359 IP 10.31.1.4.80 > 10.21.0.40.58862: Flags [S.], seq 79908996, ack 2824207375, win 65160, options [mss 1292,sackOK,TS val 1335449016 ecr 3446815356,nop,wscale 7], length 0
16:26:57.201924 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 3446815364 ecr 1335449016], length 0
16:26:57.201928 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 3446815364 ecr 1335449016], length 0
16:26:57.201941 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 3446815364 ecr 1335449016], length 72: HTTP: GET / HTTP/1.1
16:26:57.201944 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 3446815364 ecr 1335449016], length 72: HTTP: GET / HTTP/1.1
16:26:57.204982 IP 10.31.1.4.80 > 10.21.0.40.58862: Flags [.], ack 73, win 509, options [nop,nop,TS val 1335449022 ecr 3446815364], length 0
16:26:57.204992 IP 10.31.1.4.80 > 10.21.0.40.58862: Flags [.], ack 73, win 509, options [nop,nop,TS val 1335449022 ecr 3446815364], length 0
16:26:57.205143 IP 10.31.1.4.80 > 10.21.0.40.58862: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 1335449022 ecr 3446815364], length 302: HTTP: HTTP/1.1 200 OK
16:26:57.205146 IP 10.31.1.4.80 > 10.21.0.40.58862: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 1335449022 ecr 3446815364], length 302: HTTP: HTTP/1.1 200 OK
16:26:57.205548 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 3446815368 ecr 1335449022], length 0
16:26:57.205550 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 3446815368 ecr 1335449022], length 0
16:26:57.205614 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 3446815368 ecr 1335449022], length 0
16:26:57.205616 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 3446815368 ecr 1335449022], length 0
16:26:57.207000 IP 10.31.1.4.80 > 10.21.0.40.58862: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 1335449024 ecr 3446815368], length 0
16:26:57.207005 IP 10.31.1.4.80 > 10.21.0.40.58862: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 1335449024 ecr 3446815368], length 0
16:26:57.207369 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 3446815370 ecr 1335449024], length 0
16:26:57.207371 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 3446815370 ecr 1335449024], length 0
```

```console
R31-1:~# tcpdump -i eth0 -n "net 10.31.0.32/28 or net 10.31.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
16:26:57.197100 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [S], seq 2824207374, win 64240, options [mss 1292,sackOK,TS val 3446815356 ecr 0,nop,wscale 7], length 0
16:26:57.197149 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [S], seq 2824207374, win 64240, options [mss 1292,sackOK,TS val 3446815356 ecr 0,nop,wscale 7], length 0
16:26:57.199421 IP 10.31.1.4.80 > 10.21.0.40.58862: Flags [S.], seq 79908996, ack 2824207375, win 65160, options [mss 1418,sackOK,TS val 1335449016 ecr 3446815356,nop,wscale 7], length 0
16:26:57.199435 IP 10.31.1.4.80 > 10.21.0.40.58862: Flags [S.], seq 79908996, ack 2824207375, win 65160, options [mss 1418,sackOK,TS val 1335449016 ecr 3446815356,nop,wscale 7], length 0
16:26:57.203984 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 3446815364 ecr 1335449016], length 0
16:26:57.203984 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 3446815364 ecr 1335449016], length 72: HTTP: GET / HTTP/1.1
16:26:57.203994 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 3446815364 ecr 1335449016], length 0
16:26:57.203999 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 3446815364 ecr 1335449016], length 72: HTTP: GET / HTTP/1.1
16:26:57.204230 IP 10.31.1.4.80 > 10.21.0.40.58862: Flags [.], ack 73, win 509, options [nop,nop,TS val 1335449022 ecr 3446815364], length 0
16:26:57.204241 IP 10.31.1.4.80 > 10.21.0.40.58862: Flags [.], ack 73, win 509, options [nop,nop,TS val 1335449022 ecr 3446815364], length 0
16:26:57.204480 IP 10.31.1.4.80 > 10.21.0.40.58862: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 1335449022 ecr 3446815364], length 302: HTTP: HTTP/1.1 200 OK
16:26:57.204482 IP 10.31.1.4.80 > 10.21.0.40.58862: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 1335449022 ecr 3446815364], length 302: HTTP: HTTP/1.1 200 OK
16:26:57.206324 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 3446815368 ecr 1335449022], length 0
16:26:57.206324 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 3446815368 ecr 1335449022], length 0
16:26:57.206327 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 3446815368 ecr 1335449022], length 0
16:26:57.206328 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 3446815368 ecr 1335449022], length 0
16:26:57.206529 IP 10.31.1.4.80 > 10.21.0.40.58862: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 1335449024 ecr 3446815368], length 0
16:26:57.206531 IP 10.31.1.4.80 > 10.21.0.40.58862: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 1335449024 ecr 3446815368], length 0
16:26:57.207969 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 3446815370 ecr 1335449024], length 0
16:26:57.208004 IP 10.21.0.40.58862 > 10.31.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 3446815370 ecr 1335449024], length 0
```
`Tags: Azure vWAN, Site-to-Site VPN, hub-spoke vnets, NVA, Load Balancer` <br>
`date: 17-04-2026` <br>
`date: 28-04-2026` <br>

<!--Image References-->
[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/network-diagram01.png "network diagram"
[3]: ./media/network-diagram02.png "network diagram"
[4]: ./media/flow-1.png "transit of the HTTP flow"
[5]: ./media/flow-2.png "transit of the HTTP flow"
[6]: ./media/flow-3.png "transit of the HTTP flow"
[7]: ./media/flow-4.png "transit of the HTTP flow"
[8]: ./media/flow-5.png "transit of the HTTP flow"
[9]: ./media/flow-6.png "transit of the HTTP flow"
[10]: ./media/flow-7.png "transit of the HTTP flow"
[11]: ./media/flow-8.png "transit of the HTTP flow"
[12]: ./media/flow-9.png "transit of the HTTP flow"
[13]: ./media/effectiveRoutes-1.png "effective routes"
[14]: ./media/effectiveRoutes-2.png "effective routes"
[15]: ./media/flow-10.png "transit of the HTTP flow"
[16]: ./media/flow-11.png "transit of the HTTP flow"
[17]: ./media/flow-12.png "transit of the HTTP flow"
[18]: ./media/flow-13.png "transit of the HTTP flow"

<!--Link References-->