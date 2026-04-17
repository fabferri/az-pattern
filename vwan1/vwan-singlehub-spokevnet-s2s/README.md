<properties
pageTitle= 'Azure Virtual WAN single hub with Spoke VNets and Site-to-Site VPN'
description= "Azure Virtual WAN single hub with Spoke VNets and Site-to-Site VPN"
services="Azure Virtual WAN"
documentationCenter="https://github.com/fabferri"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="howto-Azure-examples"
   ms.devlang="ARM templates"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="Azure Virtual WAN"
   ms.date="28/11/2024"
   ms.author="fabferri" />

# Azure Virtual WAN single hub with Spoke VNets and Site-to-Site VPN

## Overview

This project deploys an Azure Virtual WAN architecture with spoke VNets containing NVA (Network Virtual Appliance) routing through internal load balancers, and a branch site connected via site-to-site VPN. All resources are deployed in the same Azure region using ARM templates and PowerShell scripts.

## Architecture

The architecture consists of the following components:

[![1]][1]

### Key Design Principles

- **Traffic transit through NVAs**: Spoke VNets (spoke21, spoke22) contain Linux VMs acting as NVAs (with IP forwarding enabled) behind an internal Standard Load Balancer with HA ports.
- **VNet peering for extended spokes**: spoke21B and spoke22B are peered to spoke21 and spoke22 respectively, with traffic routed through the NVA load balancers.
- **Site-to-site VPN**: Branch1 connects to the virtual hub via an active-active VPN gateway with BGP (ASN 65011 for branch, ASN 65515 for hub).

### Network Address Space

| VNet/Hub   | Address Space    | Purpose                                  |
|------------|------------------|------------------------------------------|
| hub90      | 10.90.0.0/23     | Virtual Hub                              |
| spoke21    | 10.21.0.0/24     | Spoke VNet with NVAs + workload          |
| spoke21B   | 10.21.1.0/24     | Extended spoke peered to spoke21         |
| spoke22    | 10.22.0.0/24     | Spoke VNet with NVAs + workload          |
| spoke22B   | 10.22.1.0/24     | Extended spoke peered to spoke22         |
| branch1    | 10.50.0.0/24     | Branch site connected via S2S VPN        |

### Virtual Machines

| VM Name   | VNet     | Subnet    | Private IP   | Role            |
|-----------|----------|-----------|--------------|-----------------|
| R21-1     | spoke21  | subnetBE  | 10.21.0.20   | NVA (IP fwd)    |
| R21-2     | spoke21  | subnetBE  | 10.21.0.21   | NVA (IP fwd)    |
| WL21-1    | spoke21  | subnetWL  | 10.21.0.40   | Workload        |
| WL21B-1   | spoke21B | subnetWL21B | 10.21.1.4  | Workload        |
| R22-1     | spoke22  | subnetBE  | 10.22.0.20   | NVA (IP fwd)    |
| R22-2     | spoke22  | subnetBE  | 10.22.0.21   | NVA (IP fwd)    |
| WL22-1    | spoke22  | subnetWL  | 10.22.0.40   | Workload        |
| WL22B-1   | spoke22B | subnetWL22B | 10.22.1.4  | Workload        |
| vm-branch1| branch1  | subnet1   | (dynamic)    | Branch workload |

All VMs run **Ubuntu** with **nginx** installed via custom script extension. <br>
**NVA VMs have IP forwarding enabled at both the OS and NIC level.**

### Routing

**Spoke21 / Spoke22 subnets (subnetWL)**:
- UDR routes inter-spoke and extended-spoke traffic to the internal load balancer frontend IP (e.g., `10.21.0.10` for spoke21).

**Spoke21B / Spoke22B subnets**:
- UDR routes all `10.0.0.0/8` traffic and spoke-specific traffic through the parent spoke's load balancer.

**Virtual Hub connections**:
- spoke21 and spoke22 connections use static routes pointing to their respective LB frontend IPs.
- The hub's defaultRouteTable handles VPN-to-spoke routing.


## Configuration

All shared configuration is centralized in `init.json`:

| Parameter           | Description                                   |
|---------------------|-----------------------------------------------|
| `subscriptionName`  | Target Azure subscription name                |
| `rgName`            | Resource group for vWAN and hub               |
| `vwanName`          | Virtual WAN name                              |
| `hub1Name`          | Virtual Hub name                              |
| `location`          | Primary Azure region                          |
| `hub1location`      | Hub Azure region                              |
| `rgSpoke21`         | Resource group for spoke21 and spoke21B       |
| `spoke21location`   | Azure region for spoke21                      |
| `rgSpoke22`         | Resource group for spoke22 and spoke22B       |
| `spoke22location`   | Azure region for spoke22                      |
| `hub1vpnGwName`     | VPN gateway name in the hub                   |
| `rgBranch1`         | Resource group for branch1                    |
| `branch1vpnGtwName` | VPN gateway name for branch1                  |
| `branch1location`   | Azure region for branch1                      |
| `sharedKey`         | Pre-shared key for VPN tunnels                |
| `adminUsername`     | VM administrator username                     |
| `adminPassword`     | VM administrator password                     |

> **Important**: Update `init.json` with your own subscription name, credentials, and shared key before running any script.

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

## Deployment Order

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

## Summary of Execution

```console
Step 1:  01-spoke21.ps1  +  01-spoke22.ps1    (spoke VNets, NVAs, LBs, workloads)
Step 2:  02-vwan.ps1                          (vWAN, hub, connections, VPN GW)
         02-spoke21B.ps1 +  02-spoke22B.ps1   (extended spokes with peering)
Step 3:  03-vpn.ps1                           (branch VPN gateway)
         03-vwan-site.ps1                     (vWAN site + VPN connection)
```

## ANNEX: Checking flow symmetry through the NVAs

**tcpdump** in linux NVAs allows to verify the traffic in transit and the symmetric transit through the NVAs.
The **tcpdump** command are used in R21-1, R21-2, R22-1 and R22-2: 

```console
root@R21-1:~# tcpdump -i eth0 -n "net 10.21.0.32/28 or net 10.21.1.0/24" and tcp
root@R22-1:~# tcpdump -i eth0 -n "net 10.22.0.32/28 or net 10.22.1.0/24" and tcp
```

### HTTP traffic flow from WL22B-1 to WL21B-1

[![2]][2]

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

[![3]][3]

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

[![4]][4]

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


### HTTP traffic flow from WL22-1 to WL21B-1

[![5]][5]

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

[![6]][6]

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

[![7]][7]

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

[![8]][8]

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

### HTTP traffic flow from vm-branch1 to WL21B-1

[![9]][9]

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


### HTTP traffic flow from vm-branch1 to WL21B-1

[![10]][10]

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

[![11]][11]

### Effective routes WL22-1 and WL22B-1

[![12]][12]

`Tags: Azure vWAN, Site-to-Site VPN, hub-spoke vnets, NVA, Load Balancer` <br>
`date: 17-04-2026` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/flow-1.png "transit of the HTTP flow"
[3]: ./media/flow-2.png "transit of the HTTP flow"
[4]: ./media/flow-3.png "transit of the HTTP flow"
[5]: ./media/flow-4.png "transit of the HTTP flow"
[6]: ./media/flow-5.png "transit of the HTTP flow"
[7]: ./media/flow-6.png "transit of the HTTP flow"
[8]: ./media/flow-7.png "transit of the HTTP flow"
[9]: ./media/flow-8.png "transit of the HTTP flow"
[10]: ./media/flow-9.png "transit of the HTTP flow"
[11]: ./media/effectiveRoutes-1.png "effective routes"
[12]: ./media/effectiveRoutes-2.png "effective routes"

<!--Link References-->