# Azure Virtual WAN Secure Hubs with Parent Spokes and Child Spokes

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Topology Overview](#topology-overview)
- [Parent Spokes](#parent-spokes)
- [Child Spokes](#child-spokes)
- [Secure Hub and Routing Intent](#secure-hub-and-routing-intent)
- [Routing Model](#routing-model)
- [Child Spoke to Parent Spoke](#child-spoke-to-parent-spoke)
- [Hub to Child Spoke](#hub-to-child-spoke)
- [Peering Behavior](#peering-behavior)
- [Secure Hub Behavior](#secure-hub-behavior)
- [IP Addressing Plan](#ip-addressing-plan)
- [Configuration Files](#configuration-files)
- [File List](#file-list)
- [Deployment Order](#deployment-order)
- [Deployment sequence for `init.json`](#deployment-sequence-for-initjson)
- [Deployment sequence for `init2.json`](#deployment-sequence-for-init2json)
- [How to check symmetric data traffic through NVAs](#how-to-check-symmetric-data-traffic-through-nvas)
- [ANNEX: Checking flow symmetry through the NVAs](#annex-checking-flow-symmetry-through-the-nvas)

## Overview

This project deploys an Azure Virtual WAN topology with two secure virtual hubs, each serving two parent spokes, two child spokes, and two branch site connected over active-active site-to-site VPN with BGP.

The current design is built around these principles:

- Each hub is a secure hub with Azure Firewall deployed in the virtual hub.
- Routing intent is enabled for `PrivateTraffic`, so private traffic learned by the hub is sent to Azure Firewall.
- Parent spokes host the transit layer only: a frontend subnet for the internal load balancer and a backend subnet for the NVA pair.
- Workload subnets are deployed only in the child spokes.
- Child spokes are peered to their parent spokes and use UDRs to send traffic to the parent spoke internal load balancer.
- Hub VNet connections also use static routes so hub-to-child-spoke traffic is sent to the parent spoke NVA path.

The same templates are reused twice:

- `init.json` deploys the first environment: `hub90`, `spoke21`, `spoke22`, `spoke21B`, `spoke22B`, and `branch1`
- `init2.json` deploys the second environment in the same vWAN: `hub91`, `spoke31`, `spoke32`, `spoke31B`, `spoke32B`, and `branch2`

Both parameter files use the same variable list.

## Architecture

The high-level network diagram is shown below:

[![1]][1]

Detailed diagrams:

[![2]][2]

[![3]][3]

### Topology Overview

- `hub90` and `hub91` are virtual hubs inside the same Azure Virtual WAN.
- Each hub contains an Azure Firewall secured by a firewall policy.
- Each hub has two parent spokes connected directly to the hub.
- Each parent spoke has one child spoke connected with bidirectional VNet peering.
- Each branch site connects to its corresponding hub VPN gateway with two BGP-enabled IPsec tunnels.

### Parent Spokes

Parent spokes are transit VNets. They do not host workload subnets in the current configuration.

Each parent spoke contains:

- `subnetFE`: frontend subnet for the Standard internal load balancer
- `subnetBE`: backend subnet hosting two Linux NVA VMs
- One Standard internal load balancer with an HA-ports style rule
- Two Ubuntu VMs with NIC IP forwarding enabled and Linux IP forwarding enabled in the guest

The parent spoke templates are:

- `01-spoke21.json`
- `01-spoke22.json`

When used with `init2.json`, those same templates deploy `spoke31` and `spoke32`.

### Child Spokes

Child spokes host the workloads.

Each child spoke contains:

- One workload subnet
- One workload VM running Ubuntu with nginx
- One route table associated with the workload subnet
- VNet peering to the parent spoke

The child spoke templates are:

- `02-spoke21B.json`
- `02-spoke22B.json`

When used with `init2.json`, those same templates deploy `spoke31B` and `spoke32B`.

### Secure Hub and Routing Intent

Each hub deployment created by `02-vwan.json` includes:

- Azure Virtual WAN
- Virtual Hub
- Default hub route table
- Azure Firewall Policy
- Azure Firewall using `AZFW_Hub`
- Hub VNet connections for the two parent spokes
- Optional hub VPN gateway deployment
- Routing intent for `PrivateTraffic`

The routing intent resource points `PrivateTraffic` to Azure Firewall. The `Internet` routing policy is present in the template as commented code and is not deployed, so this configuration is a private-traffic secure hub design, not an internet breakout design.

## Routing Model

Traffic steering is implemented through two routing mechanisms: child-spoke route tables (UDRs) and static routes configured on virtual hub VNet connections.

In addition to child-spoke UDRs, static routes are explicitly defined in each hub VNet Connection (`hubVirtualNetworkConnection`). These connection-level static routes map child-spoke prefixes to the parent spoke ILB frontend IP as `nextHopIpAddress`, so traffic arriving at the hub for those prefixes follows the NVA path in the parent spoke.

For branch VPN connections, do not set an explicit `routingConfiguration` on `Microsoft.Network/vpnGateways/vpnConnections` when Virtual Hub Routing Intent is enabled. Azure must auto-populate connection routing in this case; otherwise deployment fails with `ConnectionRoutingConfigConflictsWithRoutingIntent`.

### Child Spoke to Parent Spoke

Each child spoke route table sends `10.0.0.0/8` to the frontend IP of the parent spoke internal load balancer with `nextHopType = VirtualAppliance`.

The parent spoke ILB is configured with an HA-ports rule, so all TCP/UDP ports are eligible for load distribution to the NVA backend pool.

That means:

- Workload traffic leaves the child spoke.
- It is sent across the peering to the parent spoke.
- It reaches the parent ILB frontend IP.
- The ILB distributes the flow to one of the two NVAs.

### Hub to Child Spoke

Each `hubVirtualNetworkConnection` for a parent spoke includes a static route for the child spoke prefix with `nextHopIpAddress` set to the parent spoke ILB frontend IP.

Examples in the hub template:

- `to-spoke21B-via-lb`
- `to-spoke22B-via-lb`

The connection also sets:

- `associatedRouteTable = defaultRouteTable`
- `propagatedRouteTables.labels = ["default"]`
- `staticRoutesConfig.vnetLocalRouteOverrideCriteria = "Equal"`

This ensures traffic entering from the hub toward the child spoke is redirected to the NVA path rather than using direct local VNet routing.

### Peering Behavior

Child-to-parent and parent-to-child peerings are configured with:

- `allowVirtualNetworkAccess = true`
- `allowForwardedTraffic = true`
- `allowGatewayTransit = false`
- `useRemoteGateways = false`

`allowForwardedTraffic = true` is required because the packet path includes forwarding by the NVA layer.

### Secure Hub Behavior

At the hub level:

- Private traffic is sent to Azure Firewall through routing intent.
- The Azure Firewall Policy permits transit across all private address prefixes; therefore, traffic between spoke VNets and between spoke VNets and branch networks is allowed.
- Spoke hub connections set `enableInternetSecurity = false`.
- No internet routing intent is configured.

So the design combines Azure Firewall inspection in the virtual hub with explicit NVA steering for traffic to and from child spokes.

## IP Addressing Plan

| Component | Prefix | Purpose |
| --------- | ------ | ------- |
| `hub90` | `10.90.0.0/23` | Virtual hub |
| `spoke21` | `10.21.0.0/24` | Parent spoke transit VNet |
| `spoke21B` | `10.21.1.0/24` | Child spoke with workload subnet |
| `spoke22` | `10.22.0.0/24` | Parent spoke transit VNet |
| `spoke22B` | `10.22.1.0/24` | Child spoke with workload subnet |
| `branch1` | `10.50.0.0/24` | Branch VNet connected by S2S VPN |

| Component | Prefix | Purpose |
| --------- | ------ | ------- |
| `hub91` | `10.91.0.0/23` | Virtual hub |
| `spoke31` | `10.31.0.0/24` | Parent spoke transit VNet |
| `spoke31B` | `10.31.1.0/24` | Child spoke with workload subnet |
| `spoke32` | `10.32.0.0/24` | Parent spoke transit VNet |
| `spoke32B` | `10.32.1.0/24` | Child spoke with workload subnet |
| `branch2` | `10.51.0.0/24` | Branch VNet connected by S2S VPN |

| VM Name | Network | Subnet | Private IP | Role |
| ------- | ------- | ------ | ---------- | ---- |
| `R21-1` | `spoke21` | `subnetBE` | `10.21.0.20` | NVA |
| `R21-2` | `spoke21` | `subnetBE` | `10.21.0.21` | NVA |
| `WL21B-1` | `spoke21B` | `subnetWL21B` | `10.21.1.4` | Workload |
| `R22-1` | `spoke22` | `subnetBE` | `10.22.0.20` | NVA |
| `R22-2` | `spoke22` | `subnetBE` | `10.22.0.21` | NVA |
| `WL22B-1` | `spoke22B` | `subnetWL22B` | `10.22.1.4` | Workload |
| `branch1vm` | `branch1` | `subnet1` | dynamic | Branch workload |

| VM Name | Network | Subnet | Private IP | Role |
| ------- | ------- | ------ | ---------- | ---- |
| `R31-1` | `spoke31` | `subnetBE` | `10.31.0.20` | NVA |
| `R31-2` | `spoke31` | `subnetBE` | `10.31.0.21` | NVA |
| `WL31B-1` | `spoke31B` | `subnetWL31B` | `10.31.1.4` | Workload |
| `R32-1` | `spoke32` | `subnetBE` | `10.32.0.20` | NVA |
| `R32-2` | `spoke32` | `subnetBE` | `10.32.0.21` | NVA |
| `WL32B-1` | `spoke32B` | `subnetWL32B` | `10.32.1.4` | Workload |
| `branch2vm` | `branch2` | `subnet1` | dynamic | Branch workload |

All Linux VMs install nginx through custom script extensions. The parent spoke NVAs also enable IP forwarding in the guest OS and on the NIC.

## Configuration Files

`init.json` and `init2.json` have the same variable names and drive the same deployment logic.

Key parameter groups include:

- Subscription and resource group names
- Hub names, prefixes, VPN gateway names, firewall names, and firewall policy names
- Parent spoke names, address spaces, FE and BE subnet prefixes, and ILB frontend IPs
- Child spoke names, workload subnet prefixes, route table names, and peering names
- Branch names, address spaces, gateway settings, ASN values, and VPN link names
- VM names, private IPs, and admin credentials

Before deployment, update at least:

- In both `init.json` and `init2.json`, customize the values of variables `adminUsername`, `adminPassword`, and `sharedKey`
- Subscription name


## File List

| File | Description |
| ---- | ----------- |
| `init.json` | Parameters for the first secure hub environment |
| `init2.json` | Parameters for the second secure hub environment; variable list matches `init.json` |
| `01-spoke21.json` | Parent spoke template for the first spoke slot; creates only `subnetFE`, `subnetBE`, ILB, and two NVA VMs |
| `01-spoke21.ps1` | Deploys `01-spoke21.json` using either `init.json` or another file passed via `-initFile` |
| `01-spoke22.json` | Parent spoke template for the second spoke slot; creates only `subnetFE`, `subnetBE`, ILB, and two NVA VMs |
| `01-spoke22.ps1` | Deploys `01-spoke22.json` |
| `02-vwan.json` | Creates the vWAN hub objects, Azure Firewall, firewall policy, parent-spoke hub connections, `PrivateTraffic` routing intent, and optionally the hub VPN gateway |
| `02-vwan.ps1` | Deploys `02-vwan.json` and skips hub VPN gateway creation if it already exists |
| `02-spoke21B.json` | Child spoke template for the first child-spoke slot; creates workload subnet, route table, VM, and VNet peering |
| `02-spoke21B.ps1` | Deploys `02-spoke21B.json` |
| `02-spoke22B.json` | Child spoke template for the second child-spoke slot; creates workload subnet, route table, VM, and VNet peering |
| `02-spoke22B.ps1` | Deploys `02-spoke22B.json` |
| `03-vpn.json` | Creates the branch VNet, branch VPN gateway, local network gateways, VPN connections, and branch VM |
| `03-vpn.ps1` | Deploys `03-vpn.json` after reading the hub VPN gateway public and BGP IPs |
| `03-vwan-site.json` | Creates the VPN site in the vWAN and the hub-to-branch VPN connection |
| `03-vwan-site.ps1` | Deploys `03-vwan-site.json` after reading the branch gateway public and BGP IPs |
| `checkingVMsStatus.ps1` | Helper script to check VM status |

## Deployment Order

The deployment is sequential. Inside a step, the two spoke deployments can run in parallel if you want.

### Deployment sequence for `init.json`

```powershell
# Step 1 - Parent spokes. It can run in parallel
.\01-spoke21.ps1
.\01-spoke22.ps1

# Step 2 - Secure hub
.\02-vwan.ps1

# Step 3 - Child spokes. It can run in parallel
.\02-spoke21B.ps1
.\02-spoke22B.ps1

# Step 4 - Branch VPN and vWAN site. Run in sequence
.\03-vpn.ps1
.\03-vwan-site.ps1
```

### Deployment sequence for `init2.json`

```powershell
# Step 1 - Parent spokes
.\01-spoke21.ps1 -initFile .\init2.json
.\01-spoke22.ps1 -initFile .\init2.json

# Step 2 - Secure hub in the same vWAN
.\02-vwan.ps1 -initFile .\init2.json

# Step 3 - Child spokes
.\02-spoke21B.ps1 -initFile .\init2.json
.\02-spoke22B.ps1 -initFile .\init2.json

# Step 4 - Branch VPN and vWAN site. Run in sequence
.\03-vpn.ps1 -initFile .\init2.json
.\03-vwan-site.ps1 -initFile .\init2.json
```

## How to check symmetric data traffic through NVAs

The easiest functional validation is traffic between child-spoke workloads, because in the architecture the workload subnets exist only in the child spokes.

Examples:

- `WL21B-1` to `WL22B-1`
- `WL31B-1` to `WL32B-1`
- Branch VM to child-spoke workload VM

To confirm symmetric transit through the NVA layer, capture traffic on the NVA VMs with `tcpdump`.

Example:

```console
root@R21-1:~# tcpdump -i eth0 -n "net 10.21.1.0/24" and tcp
root@R22-1:~# tcpdump -i eth0 -n "net 10.22.1.0/24" and tcp
root@R31-1:~# tcpdump -i eth0 -n "net 10.31.1.0/24" and tcp
root@R32-1:~# tcpdump -i eth0 -n "net 10.32.1.0/24" and tcp
```

## Notes

- Some embedded comments in the ARM templates still describe the previous layout. The actual resources declared in the templates are the authoritative source.
- Parent spokes are transit-only VNets in the current design.
- Workloads are deployed only in child spokes. if you deploy workloads in parent spoke vnet the traffic parent spoke-to-parent spoke will be asymmetric
- Secure hub routing intent currently applies only to `PrivateTraffic`.


## ANNEX: Checking flow symmetry through the NVAs

### HTTP traffic flow from WL22B-1 to WL21B-1

[![4]][4]

HTTP query:

```console
WL21B-1:~$ curl 10.22.1.4
```

```console
R21-1:~# tcpdump -i eth0 -n "net 10.21.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
08:52:54.363442 IP 10.21.1.4.57796 > 10.22.1.4.80: Flags [S], seq 2461169956, win 64240, options [mss 1418,sackOK,TS val 1201996613 ecr 0,nop,wscale 7], length 0
08:52:54.363468 IP 10.21.1.4.57796 > 10.22.1.4.80: Flags [S], seq 2461169956, win 64240, options [mss 1418,sackOK,TS val 1201996613 ecr 0,nop,wscale 7], length 0
08:52:54.379512 IP 10.22.1.4.80 > 10.21.1.4.57796: Flags [S.], seq 2434512662, ack 2461169957, win 65160, options [mss 1334,sackOK,TS val 1790453985 ecr 1201996613,nop,wscale 7], length 0
08:52:54.379519 IP 10.22.1.4.80 > 10.21.1.4.57796: Flags [S.], seq 2434512662, ack 2461169957, win 65160, options [mss 1334,sackOK,TS val 1790453985 ecr 1201996613,nop,wscale 7], length 0
08:52:54.381522 IP 10.21.1.4.57796 > 10.22.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1201996632 ecr 1790453985], length 0
08:52:54.381522 IP 10.21.1.4.57796 > 10.22.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 1201996632 ecr 1790453985], length 72: HTTP: GET / HTTP/1.1
08:52:54.381525 IP 10.21.1.4.57796 > 10.22.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1201996632 ecr 1790453985], length 0
08:52:54.381527 IP 10.21.1.4.57796 > 10.22.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 1201996632 ecr 1790453985], length 72: HTTP: GET / HTTP/1.1
08:52:54.390731 IP 10.22.1.4.80 > 10.21.1.4.57796: Flags [.], ack 73, win 509, options [nop,nop,TS val 1790453999 ecr 1201996632], length 0
08:52:54.390736 IP 10.22.1.4.80 > 10.21.1.4.57796: Flags [.], ack 73, win 509, options [nop,nop,TS val 1790453999 ecr 1201996632], length 0
08:52:54.395531 IP 10.22.1.4.80 > 10.21.1.4.57796: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 1790454004 ecr 1201996632], length 302: HTTP: HTTP/1.1 200 OK
08:52:54.395536 IP 10.22.1.4.80 > 10.21.1.4.57796: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 1790454004 ecr 1201996632], length 302: HTTP: HTTP/1.1 200 OK
08:52:54.395741 IP 10.21.1.4.57796 > 10.22.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 1201996647 ecr 1790454004], length 0
08:52:54.395743 IP 10.21.1.4.57796 > 10.22.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 1201996647 ecr 1790454004], length 0
08:52:54.395921 IP 10.21.1.4.57796 > 10.22.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 1201996647 ecr 1790454004], length 0
08:52:54.395923 IP 10.21.1.4.57796 > 10.22.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 1201996647 ecr 1790454004], length 0
08:52:54.397264 IP 10.22.1.4.80 > 10.21.1.4.57796: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 1790454006 ecr 1201996647], length 0
08:52:54.397266 IP 10.22.1.4.80 > 10.21.1.4.57796: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 1790454006 ecr 1201996647], length 0
08:52:54.397416 IP 10.21.1.4.57796 > 10.22.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 1201996649 ecr 1790454006], length 0
08:52:54.397418 IP 10.21.1.4.57796 > 10.22.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 1201996649 ecr 1790454006], length 0
08:54:47.345263 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [S], seq 2097969339, win 64240, options [mss 1418,sackOK,TS val 1202109595 ecr 0,nop,wscale 7], length 0
08:54:47.345301 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [S], seq 2097969339, win 64240, options [mss 1418,sackOK,TS val 1202109595 ecr 0,nop,wscale 7], length 0
08:54:47.351274 IP 10.22.1.4.80 > 10.21.1.4.47990: Flags [S.], seq 1198503491, ack 2097969340, win 65160, options [mss 1334,sackOK,TS val 1790566959 ecr 1202109595,nop,wscale 7], length 0
08:54:47.351280 IP 10.22.1.4.80 > 10.21.1.4.47990: Flags [S.], seq 1198503491, ack 2097969340, win 65160, options [mss 1334,sackOK,TS val 1790566959 ecr 1202109595,nop,wscale 7], length 0
08:54:47.352393 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1202109604 ecr 1790566959], length 0
08:54:47.352393 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 1202109604 ecr 1790566959], length 72: HTTP: GET / HTTP/1.1
08:54:47.352403 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1202109604 ecr 1790566959], length 0
08:54:47.352408 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 1202109604 ecr 1790566959], length 72: HTTP: GET / HTTP/1.1
08:54:47.354082 IP 10.22.1.4.80 > 10.21.1.4.47990: Flags [.], ack 73, win 509, options [nop,nop,TS val 1790566963 ecr 1202109604], length 0
08:54:47.354084 IP 10.22.1.4.80 > 10.21.1.4.47990: Flags [.], ack 73, win 509, options [nop,nop,TS val 1790566963 ecr 1202109604], length 0
08:54:47.354695 IP 10.22.1.4.80 > 10.21.1.4.47990: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 1790566963 ecr 1202109604], length 302: HTTP: HTTP/1.1 200 OK
08:54:47.354697 IP 10.22.1.4.80 > 10.21.1.4.47990: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 1790566963 ecr 1202109604], length 302: HTTP: HTTP/1.1 200 OK
08:54:47.354873 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 1202109606 ecr 1790566963], length 0
08:54:47.354875 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 1202109606 ecr 1790566963], length 0
08:54:47.355319 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 1202109606 ecr 1790566963], length 0
08:54:47.355321 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 1202109606 ecr 1790566963], length 0
08:54:47.362325 IP 10.22.1.4.80 > 10.21.1.4.47990: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 1790566971 ecr 1202109606], length 0
08:54:47.362328 IP 10.22.1.4.80 > 10.21.1.4.47990: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 1790566971 ecr 1202109606], length 0
08:54:47.362501 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 1202109614 ecr 1790566971], length 0
08:54:47.362503 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 1202109614 ecr 1790566971], length 0
```

```console
R22-1:~# tcpdump -i eth0 -n "net 10.22.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
08:54:47.349075 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [S], seq 2097969339, win 64240, options [mss 1334,sackOK,TS val 1202109595 ecr 0,nop,wscale 7], length 0
08:54:47.349097 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [S], seq 2097969339, win 64240, options [mss 1334,sackOK,TS val 1202109595 ecr 0,nop,wscale 7], length 0
08:54:47.350544 IP 10.22.1.4.80 > 10.21.1.4.47990: Flags [S.], seq 1198503491, ack 2097969340, win 65160, options [mss 1418,sackOK,TS val 1790566959 ecr 1202109595,nop,wscale 7], length 0
08:54:47.350547 IP 10.22.1.4.80 > 10.21.1.4.47990: Flags [S.], seq 1198503491, ack 2097969340, win 65160, options [mss 1418,sackOK,TS val 1790566959 ecr 1202109595,nop,wscale 7], length 0
08:54:47.354287 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1202109604 ecr 1790566959], length 0
08:54:47.354287 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 1202109604 ecr 1790566959], length 72: HTTP: GET / HTTP/1.1
08:54:47.354292 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1202109604 ecr 1790566959], length 0
08:54:47.354293 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 1202109604 ecr 1790566959], length 72: HTTP: GET / HTTP/1.1
08:54:47.354690 IP 10.22.1.4.80 > 10.21.1.4.47990: Flags [.], ack 73, win 509, options [nop,nop,TS val 1790566963 ecr 1202109604], length 0
08:54:47.354692 IP 10.22.1.4.80 > 10.21.1.4.47990: Flags [.], ack 73, win 509, options [nop,nop,TS val 1790566963 ecr 1202109604], length 0
08:54:47.354965 IP 10.22.1.4.80 > 10.21.1.4.47990: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 1790566963 ecr 1202109604], length 302: HTTP: HTTP/1.1 200 OK
08:54:47.354967 IP 10.22.1.4.80 > 10.21.1.4.47990: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 1790566963 ecr 1202109604], length 302: HTTP: HTTP/1.1 200 OK
08:54:47.362379 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 1202109606 ecr 1790566963], length 0
08:54:47.362379 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 1202109606 ecr 1790566963], length 0
08:54:47.362388 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 1202109606 ecr 1790566963], length 0
08:54:47.362390 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 1202109606 ecr 1790566963], length 0
08:54:47.362922 IP 10.22.1.4.80 > 10.21.1.4.47990: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 1790566971 ecr 1202109606], length 0
08:54:47.362926 IP 10.22.1.4.80 > 10.21.1.4.47990: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 1790566971 ecr 1202109606], length 0
08:54:47.364062 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 1202109614 ecr 1790566971], length 0
08:54:47.364064 IP 10.21.1.4.47990 > 10.22.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 1202109614 ecr 1790566971], length 0
```

### HTTP traffic flow from WL21B-1 to vm-branch1

[![5]][5]

HTTP query:

```console
WL21B-1:~$ curl 10.50.0.4
```

```console
R21-1:~# tcpdump -i eth0 -n "net 10.21.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
09:08:00.075325 IP 10.21.1.4.52452 > 10.50.0.4.80: Flags [S], seq 1287025723, win 64240, options [mss 1418,sackOK,TS val 3897611273 ecr 0,nop,wscale 7], length 0
09:08:00.075350 IP 10.21.1.4.52452 > 10.50.0.4.80: Flags [S], seq 1287025723, win 64240, options [mss 1418,sackOK,TS val 3897611273 ecr 0,nop,wscale 7], length 0
09:08:00.080536 IP 10.50.0.4.80 > 10.21.1.4.52452: Flags [S.], seq 3183515898, ack 1287025724, win 65160, options [mss 1276,sackOK,TS val 392405853 ecr 3897611273,nop,wscale 7], length 0
09:08:00.080539 IP 10.50.0.4.80 > 10.21.1.4.52452: Flags [S.], seq 3183515898, ack 1287025724, win 65160, options [mss 1276,sackOK,TS val 392405853 ecr 3897611273,nop,wscale 7], length 0
09:08:00.086979 IP 10.21.1.4.52452 > 10.50.0.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 3897611289 ecr 392405853], length 0
09:08:00.086979 IP 10.21.1.4.52452 > 10.50.0.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 3897611289 ecr 392405853], length 72: HTTP: GET / HTTP/1.1
09:08:00.086984 IP 10.21.1.4.52452 > 10.50.0.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 3897611289 ecr 392405853], length 0
09:08:00.086986 IP 10.21.1.4.52452 > 10.50.0.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 3897611289 ecr 392405853], length 72: HTTP: GET / HTTP/1.1
09:08:00.088716 IP 10.50.0.4.80 > 10.21.1.4.52452: Flags [.], ack 73, win 509, options [nop,nop,TS val 392405862 ecr 3897611289], length 0
09:08:00.088718 IP 10.50.0.4.80 > 10.21.1.4.52452: Flags [.], ack 73, win 509, options [nop,nop,TS val 392405862 ecr 3897611289], length 0
09:08:00.091638 IP 10.50.0.4.80 > 10.21.1.4.52452: Flags [P.], seq 1:305, ack 73, win 509, options [nop,nop,TS val 392405865 ecr 3897611289], length 304: HTTP: HTTP/1.1 200 OK
09:08:00.091640 IP 10.50.0.4.80 > 10.21.1.4.52452: Flags [P.], seq 1:305, ack 73, win 509, options [nop,nop,TS val 392405865 ecr 3897611289], length 304: HTTP: HTTP/1.1 200 OK
09:08:00.091814 IP 10.21.1.4.52452 > 10.50.0.4.80: Flags [.], ack 305, win 501, options [nop,nop,TS val 3897611295 ecr 392405865], length 0
09:08:00.091816 IP 10.21.1.4.52452 > 10.50.0.4.80: Flags [.], ack 305, win 501, options [nop,nop,TS val 3897611295 ecr 392405865], length 0
09:08:00.091960 IP 10.21.1.4.52452 > 10.50.0.4.80: Flags [F.], seq 73, ack 305, win 501, options [nop,nop,TS val 3897611295 ecr 392405865], length 0
09:08:00.091962 IP 10.21.1.4.52452 > 10.50.0.4.80: Flags [F.], seq 73, ack 305, win 501, options [nop,nop,TS val 3897611295 ecr 392405865], length 0
09:08:00.095427 IP 10.50.0.4.80 > 10.21.1.4.52452: Flags [F.], seq 305, ack 74, win 509, options [nop,nop,TS val 392405869 ecr 3897611295], length 0
09:08:00.095429 IP 10.50.0.4.80 > 10.21.1.4.52452: Flags [F.], seq 305, ack 74, win 509, options [nop,nop,TS val 392405869 ecr 3897611295], length 0
09:08:00.095573 IP 10.21.1.4.52452 > 10.50.0.4.80: Flags [.], ack 306, win 501, options [nop,nop,TS val 3897611298 ecr 392405869], length 0
09:08:00.095575 IP 10.21.1.4.52452 > 10.50.0.4.80: Flags [.], ack 306, win 501, options [nop,nop,TS val 3897611298 ecr 392405869], length 0
```


### HTTP traffic flow from vm-branch1 to WL31B-1

[![6]][6]

```console
R31-1:~# tcpdump -i eth0 -n "net 10.31.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
09:22:59.716388 IP 10.21.1.4.58032 > 10.31.1.4.80: Flags [S], seq 845287936, win 64240, options [mss 1292,sackOK,TS val 1469502935 ecr 0,nop,wscale 7], length 0
09:22:59.716412 IP 10.21.1.4.58032 > 10.31.1.4.80: Flags [S], seq 845287936, win 64240, options [mss 1292,sackOK,TS val 1469502935 ecr 0,nop,wscale 7], length 0
09:22:59.719335 IP 10.31.1.4.80 > 10.21.1.4.58032: Flags [S.], seq 2693678200, ack 845287937, win 65160, options [mss 1418,sackOK,TS val 3069029136 ecr 1469502935,nop,wscale 7], length 0
09:22:59.719338 IP 10.31.1.4.80 > 10.21.1.4.58032: Flags [S.], seq 2693678200, ack 845287937, win 65160, options [mss 1418,sackOK,TS val 3069029136 ecr 1469502935,nop,wscale 7], length 0
09:22:59.723857 IP 10.21.1.4.58032 > 10.31.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1469502948 ecr 3069029136], length 0
09:22:59.723857 IP 10.21.1.4.58032 > 10.31.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 1469502948 ecr 3069029136], length 72: HTTP: GET / HTTP/1.1
09:22:59.723866 IP 10.21.1.4.58032 > 10.31.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1469502948 ecr 3069029136], length 0
09:22:59.723870 IP 10.21.1.4.58032 > 10.31.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 1469502948 ecr 3069029136], length 72: HTTP: GET / HTTP/1.1
09:22:59.724209 IP 10.31.1.4.80 > 10.21.1.4.58032: Flags [.], ack 73, win 509, options [nop,nop,TS val 3069029142 ecr 1469502948], length 0
09:22:59.724215 IP 10.31.1.4.80 > 10.21.1.4.58032: Flags [.], ack 73, win 509, options [nop,nop,TS val 3069029142 ecr 1469502948], length 0
09:22:59.726676 IP 10.31.1.4.80 > 10.21.1.4.58032: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 3069029145 ecr 1469502948], length 302: HTTP: HTTP/1.1 200 OK
09:22:59.726678 IP 10.31.1.4.80 > 10.21.1.4.58032: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 3069029145 ecr 1469502948], length 302: HTTP: HTTP/1.1 200 OK
09:22:59.728880 IP 10.21.1.4.58032 > 10.31.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 1469502954 ecr 3069029145], length 0
09:22:59.728880 IP 10.21.1.4.58032 > 10.31.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 1469502954 ecr 3069029145], length 0
09:22:59.728887 IP 10.21.1.4.58032 > 10.31.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 1469502954 ecr 3069029145], length 0
09:22:59.728891 IP 10.21.1.4.58032 > 10.31.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 1469502954 ecr 3069029145], length 0
09:22:59.729323 IP 10.31.1.4.80 > 10.21.1.4.58032: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 3069029148 ecr 1469502954], length 0
09:22:59.729328 IP 10.31.1.4.80 > 10.21.1.4.58032: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 3069029148 ecr 1469502954], length 0
09:22:59.730362 IP 10.21.1.4.58032 > 10.31.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 1469502956 ecr 3069029148], length 0
09:22:59.730364 IP 10.21.1.4.58032 > 10.31.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 1469502956 ecr 3069029148], length 0
```


### HTTP traffic flow from WL22B-1 to branch2-vm

[![7]][7]

```console
R22-1:~# tcpdump -i eth0 -n "net 10.22.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
09:41:30.141687 IP 10.22.1.4.45106 > 10.51.0.4.80: Flags [S], seq 1221751375, win 64240, options [mss 1418,sackOK,TS val 1676084563 ecr 0,nop,wscale 7], length 0
09:41:30.141710 IP 10.22.1.4.45106 > 10.51.0.4.80: Flags [S], seq 1221751375, win 64240, options [mss 1418,sackOK,TS val 1676084563 ecr 0,nop,wscale 7], length 0
09:41:30.147958 IP 10.51.0.4.80 > 10.22.1.4.45106: Flags [S.], seq 3829405133, ack 1221751376, win 65160, options [mss 1234,sackOK,TS val 3854716802 ecr 1676084563,nop,wscale 7], length 0
09:41:30.147970 IP 10.51.0.4.80 > 10.22.1.4.45106: Flags [S.], seq 3829405133, ack 1221751376, win 65160, options [mss 1234,sackOK,TS val 3854716802 ecr 1676084563,nop,wscale 7], length 0
09:41:30.148875 IP 10.22.1.4.45106 > 10.51.0.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1676084571 ecr 3854716802], length 0
09:41:30.148875 IP 10.22.1.4.45106 > 10.51.0.4.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 1676084571 ecr 3854716802], length 73: HTTP: GET / HTTP/1.1
09:41:30.148879 IP 10.22.1.4.45106 > 10.51.0.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 1676084571 ecr 3854716802], length 0
09:41:30.148881 IP 10.22.1.4.45106 > 10.51.0.4.80: Flags [P.], seq 1:74, ack 1, win 502, options [nop,nop,TS val 1676084571 ecr 3854716802], length 73: HTTP: GET / HTTP/1.1
09:41:30.150875 IP 10.51.0.4.80 > 10.22.1.4.45106: Flags [.], ack 74, win 509, options [nop,nop,TS val 3854716806 ecr 1676084571], length 0
09:41:30.150879 IP 10.51.0.4.80 > 10.22.1.4.45106: Flags [.], ack 74, win 509, options [nop,nop,TS val 3854716806 ecr 1676084571], length 0
09:41:30.154547 IP 10.51.0.4.80 > 10.22.1.4.45106: Flags [P.], seq 1:305, ack 74, win 509, options [nop,nop,TS val 3854716810 ecr 1676084571], length 304: HTTP: HTTP/1.1 200 OK
09:41:30.154559 IP 10.51.0.4.80 > 10.22.1.4.45106: Flags [P.], seq 1:305, ack 74, win 509, options [nop,nop,TS val 3854716810 ecr 1676084571], length 304: HTTP: HTTP/1.1 200 OK
09:41:30.154953 IP 10.22.1.4.45106 > 10.51.0.4.80: Flags [.], ack 305, win 501, options [nop,nop,TS val 1676084577 ecr 3854716810], length 0
09:41:30.154955 IP 10.22.1.4.45106 > 10.51.0.4.80: Flags [.], ack 305, win 501, options [nop,nop,TS val 1676084577 ecr 3854716810], length 0
09:41:30.155389 IP 10.22.1.4.45106 > 10.51.0.4.80: Flags [F.], seq 74, ack 305, win 501, options [nop,nop,TS val 1676084578 ecr 3854716810], length 0
09:41:30.155391 IP 10.22.1.4.45106 > 10.51.0.4.80: Flags [F.], seq 74, ack 305, win 501, options [nop,nop,TS val 1676084578 ecr 3854716810], length 0
09:41:30.157183 IP 10.51.0.4.80 > 10.22.1.4.45106: Flags [F.], seq 305, ack 75, win 509, options [nop,nop,TS val 3854716813 ecr 1676084578], length 0
09:41:30.157185 IP 10.51.0.4.80 > 10.22.1.4.45106: Flags [F.], seq 305, ack 75, win 509, options [nop,nop,TS val 3854716813 ecr 1676084578], length 0
09:41:30.157539 IP 10.22.1.4.45106 > 10.51.0.4.80: Flags [.], ack 306, win 501, options [nop,nop,TS val 1676084580 ecr 3854716813], length 0
09:41:30.157541 IP 10.22.1.4.45106 > 10.51.0.4.80: Flags [.], ack 306, win 501, options [nop,nop,TS val 1676084580 ecr 3854716813], length 0
```


### HTTP traffic flow from WL31B-1 to WL22B-1

[![8]][8]

```console
R22-1:~# tcpdump -i eth0 -n "net 10.22.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
09:53:12.039193 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [S], seq 1099357163, win 64240, options [mss 1292,sackOK,TS val 2305508917 ecr 0,nop,wscale 7], length 0
09:53:12.039218 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [S], seq 1099357163, win 64240, options [mss 1292,sackOK,TS val 2305508917 ecr 0,nop,wscale 7], length 0
09:53:12.040831 IP 10.22.1.4.80 > 10.31.1.4.49398: Flags [S.], seq 1566935196, ack 1099357164, win 65160, options [mss 1418,sackOK,TS val 465215085 ecr 2305508917,nop,wscale 7], length 0
09:53:12.040834 IP 10.22.1.4.80 > 10.31.1.4.49398: Flags [S.], seq 1566935196, ack 1099357164, win 65160, options [mss 1418,sackOK,TS val 465215085 ecr 2305508917,nop,wscale 7], length 0
09:53:12.044850 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 2305508928 ecr 465215085], length 0
09:53:12.044850 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 2305508928 ecr 465215085], length 72: HTTP: GET / HTTP/1.1
09:53:12.044853 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 2305508928 ecr 465215085], length 0
09:53:12.044855 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 2305508928 ecr 465215085], length 72: HTTP: GET / HTTP/1.1
09:53:12.045400 IP 10.22.1.4.80 > 10.31.1.4.49398: Flags [.], ack 73, win 509, options [nop,nop,TS val 465215090 ecr 2305508928], length 0
09:53:12.045402 IP 10.22.1.4.80 > 10.31.1.4.49398: Flags [.], ack 73, win 509, options [nop,nop,TS val 465215090 ecr 2305508928], length 0
09:53:12.049653 IP 10.22.1.4.80 > 10.31.1.4.49398: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 465215094 ecr 2305508928], length 302: HTTP: HTTP/1.1 200 OK
09:53:12.049656 IP 10.22.1.4.80 > 10.31.1.4.49398: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 465215094 ecr 2305508928], length 302: HTTP: HTTP/1.1 200 OK
09:53:12.052305 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 2305508935 ecr 465215094], length 0
09:53:12.052305 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 2305508935 ecr 465215094], length 0
09:53:12.052307 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 2305508935 ecr 465215094], length 0
09:53:12.052308 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 2305508935 ecr 465215094], length 0
09:53:12.052868 IP 10.22.1.4.80 > 10.31.1.4.49398: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 465215097 ecr 2305508935], length 0
09:53:12.052870 IP 10.22.1.4.80 > 10.31.1.4.49398: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 465215097 ecr 2305508935], length 0
09:53:12.053936 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 2305508937 ecr 465215097], length 0
09:53:12.053938 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 2305508937 ecr 465215097], length 0
```

```console
R31-1:~# tcpdump -i eth0 -n "net 10.31.1.0/24" and tcp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
09:53:12.036603 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [S], seq 1099357163, win 64240, options [mss 1418,sackOK,TS val 2305508917 ecr 0,nop,wscale 7], length 0
09:53:12.036625 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [S], seq 1099357163, win 64240, options [mss 1418,sackOK,TS val 2305508917 ecr 0,nop,wscale 7], length 0
09:53:12.044790 IP 10.22.1.4.80 > 10.31.1.4.49398: Flags [S.], seq 1566935196, ack 1099357164, win 65160, options [mss 1292,sackOK,TS val 465215085 ecr 2305508917,nop,wscale 7], length 0
09:53:12.044794 IP 10.22.1.4.80 > 10.31.1.4.49398: Flags [S.], seq 1566935196, ack 1099357164, win 65160, options [mss 1292,sackOK,TS val 465215085 ecr 2305508917,nop,wscale 7], length 0
09:53:12.045734 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 2305508928 ecr 465215085], length 0
09:53:12.045736 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 2305508928 ecr 465215085], length 0
09:53:12.045746 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 2305508928 ecr 465215085], length 72: HTTP: GET / HTTP/1.1
09:53:12.045748 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [P.], seq 1:73, ack 1, win 502, options [nop,nop,TS val 2305508928 ecr 465215085], length 72: HTTP: GET / HTTP/1.1
09:53:12.047680 IP 10.22.1.4.80 > 10.31.1.4.49398: Flags [.], ack 73, win 509, options [nop,nop,TS val 465215090 ecr 2305508928], length 0
09:53:12.047683 IP 10.22.1.4.80 > 10.31.1.4.49398: Flags [.], ack 73, win 509, options [nop,nop,TS val 465215090 ecr 2305508928], length 0
09:53:12.052299 IP 10.22.1.4.80 > 10.31.1.4.49398: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 465215094 ecr 2305508928], length 302: HTTP: HTTP/1.1 200 OK
09:53:12.052301 IP 10.22.1.4.80 > 10.31.1.4.49398: Flags [P.], seq 1:303, ack 73, win 509, options [nop,nop,TS val 465215094 ecr 2305508928], length 302: HTTP: HTTP/1.1 200 OK
09:53:12.052660 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 2305508935 ecr 465215094], length 0
09:53:12.052660 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 2305508935 ecr 465215094], length 0
09:53:12.052663 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [.], ack 303, win 501, options [nop,nop,TS val 2305508935 ecr 465215094], length 0
09:53:12.052664 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [F.], seq 73, ack 303, win 501, options [nop,nop,TS val 2305508935 ecr 465215094], length 0
09:53:12.055042 IP 10.22.1.4.80 > 10.31.1.4.49398: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 465215097 ecr 2305508935], length 0
09:53:12.055044 IP 10.22.1.4.80 > 10.31.1.4.49398: Flags [F.], seq 303, ack 74, win 509, options [nop,nop,TS val 465215097 ecr 2305508935], length 0
09:53:12.055173 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 2305508937 ecr 465215097], length 0
09:53:12.055175 IP 10.31.1.4.49398 > 10.22.1.4.80: Flags [.], ack 304, win 501, options [nop,nop,TS val 2305508937 ecr 465215097], length 0
```

`Tags: Azure vWAN, Site-to-Site VPN, hub-spoke vnets, NVA, Load Balancer` <br>
`date: 01-05-2026` <br>

<!--Image References-->
[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/network-diagram01.png "detailed network diagram 1"
[3]: ./media/network-diagram02.png "detailed network diagram 2"
[4]: ./media/flow-1.png "transit of the HTTP flow"
[5]: ./media/flow-2.png "transit of the HTTP flow"
[6]: ./media/flow-3.png "transit of the HTTP flow"
[7]: ./media/flow-4.png "transit of the HTTP flow"
[8]: ./media/flow-5.png "transit of the HTTP flow"

