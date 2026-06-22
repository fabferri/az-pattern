<properties
   pageTitle=" Site-to-Site VPN between strongSwan with two NICs and Azure VPN Gateway with Custom IPsec/IKE Policy (GCMAES256)"
   description=" Site-to-Site VPN between strongSwan with two NICs and Azure VPN Gateway with Custom IPsec/IKE Policy (GCMAES256)"
   services="Site-to-Site VPN"
   documentationCenter="[na](https://github.com/fabferri/)"
   authors="fabferri"
   editor="fabferri"/>

<tags
   ms.service="Configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="VPN Gateway"
   ms.date="22/06/2026"
   ms.author="fabferri" />

# Site-to-Site VPN between strongSwan with two NICs and Azure VPN Gateway with Custom IPsec/IKE Policy (GCMAES256)

- [Introduction](#introduction)
- [Why GCMAES256?](#why-gcmaes256)
- [Architecture overview](#architecture-overview)
- [Custom IPsec/IKE policy](#custom-ipsecike-policy)
- [Network topology](#network-topology)
- [Project files](#project-files)
- [Deployment steps](#deployment-steps)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Key configuration files on NVA](#key-configuration-files-on-nva)
- [swanctl.conf reference](#swanctlconf-reference)
- [IPsec authentication hardening](#ipsec-authentication-hardening)
- [Annex: throw routes in table 220](#annex-throw-routes-in-table-220)
- [Annex: Linux multiple routing tables](#annex-linux-multiple-routing-tables)
- [Annex: Dual-NIC routing for IPsec](#annex-dual-nic-routing-for-ipsec)
- [References](#references)

## Introduction

This article demonstrates how to establish a Site-to-Site (S2S) IKEv2 VPN between an **Azure VPN Gateway** configured in active-active mode and a Linux-based NVA running **strongSwan** on Ubuntu 24.04, using a **custom IPsec/IKE policy with GCMAES256 encryption**.

Azure VPN Gateway supports custom IPsec/IKE policies that let you select specific cryptographic algorithms and key strengths for each connection — instead of relying on the default proposal set. This is essential when compliance or security requirements mandate particular ciphers (e.g., AES-256-GCM for FIPS 140-2 or organizational standards).

## Why GCMAES256?

AES-256-GCM (Galois/Counter Mode) is an **AEAD cipher** — it provides both confidentiality and integrity in a single operation, making it more efficient than traditional encrypt-then-MAC combinations (e.g., AES-CBC + HMAC-SHA256). Benefits include:

- **Higher throughput**: GCM leverages hardware AES-NI and PCLMULQDQ instructions, achieving near line-rate encryption on modern CPUs.
- **Reduced overhead**: No separate integrity hash computation; the authentication tag is generated alongside encryption.
- **Compliance alignment**: Recommended by NIST (SP 800-38D) and widely adopted in government and enterprise security policies.

## Architecture overview

The deployment creates two Azure VNets connected by an IPsec VPN. The Azure VPN Gateway operates in **active-active** mode (two public IPs, two BGP endpoints), while the NVA establishes **two independent IKEv2 tunnels** — one to each gateway instance. This provides redundancy: if one gateway instance undergoes maintenance, traffic fails over to the other tunnel via BGP.

[![1]][1]

The NVA uses **XFRM interfaces** (`ipsec0`, `ipsec1`) rather than policy-based selectors. XFRM interfaces decouple IPsec encryption from routing decisions — any traffic routed to an XFRM interface is encrypted by the SA bound to that interface's `if_id`. This enables:

- **Route-based VPN**: Arbitrary traffic patterns (not limited to specific subnet pairs).
- **BGP over the tunnel**: The XFRM interfaces carry BGP sessions to the VPN Gateway BGP endpoints.
- **Standard Linux routing**: Routes can be managed via FRR, static routes, or any routing daemon.

[![2]][2]

Both tunnels use custom IPsec/IKE policy:

- IKE:  GCMAES256 / SHA256(PRF) / DHGroup14
- ESP:  GCMAES256 / PFS2048

### Traffic flow

1. **vm1** sends a packet to **vm2** (10.2.0.x) — the VPN Gateway encrypts it via the IPsec SA and sends it to the NVA's public IP.
2. The NVA receives the ESP packet on `eth0`, decrypts it via the XFRM SA, and delivers the plaintext packet through the `ipsec0` or `ipsec1` interface.
3. Standard Linux routing forwards the packet to `vm2` on the local subnet.
4. Return traffic follows the reverse path — the NVA encrypts via XFRM and sends to the VPN Gateway.



## Custom IPsec/IKE policy

The VPN connections use a custom IPsec/IKE policy with **GCMAES256** (AES-256-GCM) encryption:

| Parameter | Azure VPN Gateway value | strongSwan equivalent |
|-----------|------------------------|----------------------|
| **IKE Encryption** | GCMAES256 | `aes256gcm16` (AES-256-GCM with 128-bit ICV) |
| **IKE Integrity** | SHA256 (used as PRF only when GCM is IKE encryption) | `prfsha256` |
| **DH Group** | DHGroup14 | `modp2048` (2048-bit MODP) |
| **IPsec Encryption** | GCMAES256 | `aes256gcm16` |
| **IPsec Integrity** | GCMAES256 (must match IPsec encryption for GCM) | implicit (GCM is AEAD) |
| **PFS Group** | PFS2048 | `modp2048` |
| **SA Lifetime** | 3600 seconds | `rekey_time = 3600` |
| **SA Data Size** | 102400000 KB | — |

> **Note:** When using GCMAES for IPsec encryption, Azure requires setting IPsec integrity to the same GCMAES algorithm and key length. In strongSwan, GCM is an AEAD cipher (Authenticated Encryption with Associated Data), so no separate integrity algorithm is needed — authentication is built into the cipher.

### strongSwan swanctl.conf proposals

```
# IKE (Phase 1) — single proposal matching Azure custom policy
proposals = aes256gcm16-prfsha256-modp2048

# ESP (Phase 2 / Child SA) — AEAD cipher + PFS group
esp_proposals = aes256gcm16-modp2048
```

## Network topology

| Component | Details |
|-----------|---------|
| **vnet1** (10.1.0.0/24) | Azure VPN Gateway (active-active, VpnGw2AZ, ASN 65010) + vm1 |
| **vnet2** (10.2.0.0/24) | NVA (Ubuntu 24.04, strongSwan, dual NIC, ASN 65020) + vm2 |
| **IPsec tunnels** | 2 x IKEv2 tunnels (one per GW instance) with XFRM interfaces, custom policy: GCMAES256 |
| **BGP** | FRR on NVA peers with both VPN Gateway instances |

### NVA NIC layout

| NIC | Subnet | Private IP | Public IP | Purpose |
|-----|--------|-----------|-----------|--------|
| eth0 (external) | nvaExternalSubnet (10.2.0.0/27) | 10.2.0.10 | Yes | SSH management + IPsec tunnel endpoint |
| eth1 (internal) | nvaInternalSubnet (10.2.0.32/27) | 10.2.0.40 | No | Decrypted transit traffic to/from VM2 |

### XFRM interfaces

| Interface | XFRM if_id | BGP source IP | Peers with GW instance | GW BGP IP |
|-----------|------------|---------------|------------------------|-----------|
| ipsec0    | 41         | 192.168.0.1   | instance 0             | 10.1.0.5  |
| ipsec1    | 42         | 192.168.0.2   | instance 1             | 10.1.0.4  |

XFRM interfaces provide **route-based VPN**: traffic routed to `ipsec0`/`ipsec1` is automatically encrypted by the matching IPsec SA (identified by `if_id`). Unlike policy-based VPN, this allows BGP and dynamic routing over the tunnel.

## Project files

| File | Description |
|------|-------------|
| `init.json` | Input parameters file (subscription, resource group, location, VM credentials) |
| `01_azvpn.json` | ARM template that deploys the full infrastructure: vnet1 with VPN Gateway (active-active), vnet2 with NVA (dual NIC) and vm2, NSGs, route tables, and public IPs |
| `01_azvpn.ps1` | PowerShell script to deploy the `01_azvpn.json` ARM template |
| `02_vpnconnections.json` | ARM template that creates local network gateways and VPN connections with custom IPsec/IKE policy (GCMAES256) |
| `02_vpnconnections.ps1` | PowerShell script to deploy the `02_vpnconnections.json` ARM template |
| `03_collect-values.ps1` | PowerShell script that queries Azure for deployment outputs (public IPs, BGP settings, shared keys) and auto-populates `configure-nva.sh` with live values |
| `configure-nva.sh` | Bash script to run on the NVA — installs and configures strongSwan, XFRM interfaces, FRR BGP, and all routing (reboot-persistent) |
| `values.txt` | Reference file with collected deployment values |

## Deployment steps

### Step 1: Deploy Azure infrastructure

Edit `init.json` with your subscription, resource group, and credentials, then run:

```powershell
.\01_azvpn.ps1
```

This deploys: vnet1, vnet2, VPN Gateway (active-active), NVA VM (dual NIC), vm1, vm2, NSGs, and route tables.

Note the deployment outputs: `gw_pubIP1`, `gw_pubIP2`, `gw_BGPIP1`, `gw_BGPIP2`, `nvaPubIP`.

### Step 2: Create VPN connections

```powershell
.\02_vpnconnections.ps1
```

This creates local network gateways (pointing to NVA public IP with BGP addresses 192.168.0.1 and 192.168.0.2) and two BGP-enabled VPN connections with **custom IPsec/IKE policy** (GCMAES256 encryption, DHGroup14, PFS2048).

Note the deployment output: `sharedSecret_conn1` (the auto-generated PSK).

### Step 3: Configure the NVA (reboot-persistent)

SSH to the NVA public IP (`nvaPubIP`), then:

1. Copy `configure-nva.sh` to the NVA
2. Edit the variables at the top with values from Steps 1-2
3. Run:

```bash
sudo bash configure-nva.sh
```

The script installs and configures everything **persistently**:

| What                              | Persistence mechanism                    |
|-----------------------------------|------------------------------------------|
| sysctl (ip_forward, no redirects, rp_filter) | `/etc/sysctl.d/60-vpn.conf`   |
| XFRM interfaces + routes          | `vpn-xfrm.service` (systemd oneshot)     |
| strongSwan IPsec tunnels          | `/etc/swanctl/swanctl.conf` + `ipsec.service` |
| charon (install_routes=no)        | `/etc/strongswan.d/charon.conf`          |
| swanctl auto-load on boot         | `ipsec.service.d/swanctl-autoload.conf` dropin |
| FRR BGP peering                   | `/etc/frr/frr.conf` + `frr.service`      |

### Boot-time service ordering

```
network-online.target --> vpn-xfrm.service --> ipsec.service (+ swanctl --load-all) --> frr.service
```

### Sysctl settings for IPsec with XFRM interfaces

The file `/etc/sysctl.d/60-vpn.conf` configures:

| Setting | Value | Reason |
|---------|-------|--------|
| `net.ipv4.ip_forward` | 1 | Enable packet forwarding (transit traffic between tunnels and local subnets) |
| `net.ipv4.conf.all.accept_redirects` | 0 | Prevent ICMP redirects from altering the NVA routing table |
| `net.ipv4.conf.default.accept_redirects` | 0 | Same as above but for interfaces created after sysctl loads (ipsec0/ipsec1) |
| `net.ipv4.conf.all.send_redirects` | 0 | Prevent NVA from sending ICMP redirects that would bypass the VPN |
| `net.ipv4.conf.default.send_redirects` | 0 | Same for dynamically-created interfaces |
| `net.ipv4.conf.all.rp_filter` | 0 | Disable reverse-path filtering — strict mode drops decapsulated packets on XFRM interfaces |
| `net.ipv4.conf.default.rp_filter` | 0 | Same for interfaces created later (ipsec0/ipsec1) |

> **Note:** Both `conf.all` and `conf.default` variants are required. `all` applies to existing interfaces at load time; `default` applies to interfaces created *after* sysctl runs — which includes the XFRM interfaces created by `vpn-xfrm.service`.

## Verification

```bash
# XFRM interfaces
ip link show ipsec0
ip link show ipsec1
ip addr show dev ipsec0
ip addr show dev ipsec1

# Routes
ip route
ip route show table 220

# IPsec status
sudo ipsec status
sudo swanctl --list-sas
sudo swanctl --list-conn

# BGP
sudo vtysh -c 'show bgp summary'
sudo vtysh -c 'show ip bgp'

# Initiate tunnels manually (if needed)
sudo swanctl --initiate --ike gw0 --child s2s0
sudo swanctl --initiate --ike gw1 --child s2s1

# run in vm2 for connectivity test 
while true; do curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" http://10.1.0.68; sleep 1; done
```

### Bring down and up a single IPsec tunnel

Check all IPsec tunnels status:

```bash
# This shows all active IKE and CHILD SAs with state, rekey timers, and traffic counters
sudo swanctl --list-sas

# summary of the IPsec
sudo ipsec status
```

> **Note:** Since `start_action = start` is configured in swanctl.conf, using `--terminate` alone will cause the tunnel to immediately re-initiate. To keep a single tunnel down, you must first change `start_action` to `none` for that connection.

Bring down tunnel gw0 and keep it down:
```bash
# 1. Edit swanctl.conf: change start_action from 'start' to 'none' for the target connection (gw0/s2s0)
sudo sed -i '/^   gw0 {/,/^   }/s/start_action = start/start_action = none/' /etc/swanctl/swanctl.conf

# 2. Reload connections (applies the change without restarting the service)
sudo swanctl --load-conns

# 3. Terminate the tunnel
sudo swanctl --terminate --ike gw0
```

Bring tunnel gw0 back up:
```bash
# 1. Restore start_action to 'start'
sudo sed -i '/^   gw0 {/,/^   }/s/start_action = none/start_action = start/' /etc/swanctl/swanctl.conf

# 2. Reload connections (start_action = start triggers automatic initiation)
sudo swanctl --load-conns
```

> The tunnel auto-initiates on `--load-conns` because `start_action = start`. No manual `--initiate` is needed.

Bring down all tunnels:
```bash
sudo systemctl stop ipsec
```

Bring all tunnels back up:
```bash
sudo systemctl start ipsec
```
The tunnels auto-initiate on start (via `swanctl --load-all` ExecStartPost + `start_action = start`).

### BGP network advertisement and RIB requirement

FRR's `network <prefix>` command only originates a BGP advertisement if the **exact prefix** exists in the kernel routing table (RIB). The NVA has connected routes for `/27` subnets (nvaExternalSubnet + nvaInternalSubnet + subnetApp), but not for the aggregate `10.2.0.0/24`. Without an explicit RIB entry, BGP will silently refuse to advertise the prefix.

The FRR config includes a **blackhole static route** to satisfy this requirement:

```
ip route 10.2.0.0/24 blackhole
```

This installs a null route in the RIB so that the `network 10.2.0.0/24` statement has a matching entry and BGP will originate the prefix to the Azure VPN Gateway peers.

To verify that BGP is correctly advertising the prefix:
```bash
sudo vtysh -c 'show ip bgp'          # should show 10.2.0.0/24 with status *> (best/valid)
sudo vtysh -c 'show ip bgp neighbors 10.1.0.5 advertised-routes'
sudo vtysh -c 'show ip bgp neighbors 10.1.0.5 received-routes'
sudo vtysh -c 'show ip route static' # should show 10.2.0.0/24 as blackhole (B>*)
```

If the blackhole route is missing, `show ip bgp` will either not list the prefix or show it without the `*>` flags — BGP silently refuses to originate it (no error, no log message).

> **Note:** The `no bgp ebgp-requires-policy` statement disables FRR's RFC 8212 default that blocks eBGP advertisements without an explicit route-map. With this setting, no route-map is needed for the `network` command to advertise to peers.

## Troubleshooting

```bash
# System
sysctl net.ipv4.ip_forward               # Check IP forwarding
ip a                                     # All interfaces
ip -c address                            # Coloured output
ip route show table all                  # All routing tables
ip -4 route show table 220               # strongSwan table 220

# IPsec
systemctl status ipsec                   # strongSwan daemon status
sudo ipsec statusall                     # Detailed IPsec status
sudo ip xfrm state                       # XFRM SA state
sudo ip xfrm policy                      # XFRM policies
cat /proc/net/xfrm_stat                  # XFRM counters
ifconfig ipsec0                          # Interface counters

# swanctl
sudo swanctl -l                          # List active SAs (short)
sudo swanctl -L                          # List loaded connections (detailed)

# FRR / BGP
sudo vtysh -c 'show bgp neighbors'
sudo vtysh -c 'show ip bgp'
sudo vtysh -c 'show ip route'

# Services
systemctl status vpn-xfrm.service
systemctl status ipsec.service
systemctl status frr.service
journalctl -u vpn-xfrm.service
journalctl -u ipsec.service -n 50
```

## Key configuration files on NVA

| File | Purpose |
|------|---------|
| `/etc/swanctl/swanctl.conf` | IPsec tunnel definitions and PSK |
| `/etc/strongswan.d/charon.conf` | charon daemon settings |
| `/etc/sysctl.d/60-vpn.conf` | Kernel parameters (ip_forward, no redirects, rp_filter) |
| `/usr/local/bin/vpn-xfrm-setup.sh` | XFRM interface creation script |
| `/usr/local/bin/vpn-xfrm-teardown.sh` | XFRM interface removal script |
| `/etc/systemd/system/vpn-xfrm.service` | Systemd unit for XFRM lifecycle |
| `/etc/systemd/system/ipsec.service.d/swanctl-autoload.conf` | Auto-load swanctl on boot |
| `/etc/frr/frr.conf` | FRR BGP configuration |
| `/etc/frr/daemons`  | FRR daemon enable flags |

## swanctl.conf reference

`swanctl.conf` is the modern strongSwan configuration file (replacing the legacy `ipsec.conf`/`ipsec.secrets`). It uses a structured `connections {}` / `secrets {}` syntax and is managed by the `swanctl` command-line tool. The file is loaded at runtime via `swanctl --load-all` (or selectively with `--load-conns`, `--load-creds`) — changes take effect without restarting the `ipsec` daemon.

The file `/etc/swanctl/swanctl.conf` defines two IKEv2 connections (one per VPN Gateway instance):

```
connections {
   gw0 {
        local_addrs  = <nva_external_ip>
        remote_addrs = <vpngw_pip0>
        version = 2
        proposals = aes256gcm16-prfsha256-modp2048
        keyingtries = 0
        encap = yes
        local {
            auth = psk
            id = <nva_public_ip>
        }
        remote {
            auth = psk
            id = <vpngw_pip0>
            revocation = relaxed
        }
        children {
            s2s0 {
                local_ts = 0.0.0.0/0
                remote_ts = 0.0.0.0/0
                esp_proposals = aes256gcm16-modp2048
                dpd_action = restart
                close_action = restart
                start_action = start
                rekey_time = 3600
            }
        }
        if_id_in = 41
        if_id_out = 41
   }
   gw1 {
        ...same structure with vpngw_pip1 and if_id 42...
   }
}
secrets {
   ike-1 {
        id-0 = <vpngw_pip0>
        id-1 = <vpngw_pip1>
        secret = "<psk>"
   }
}
```

Key settings:
- **`start_action = start`**: tunnels are initiated immediately (required for BGP to work without manual intervention)
- **`close_action = restart`**: automatically re-establish if peer closes the SA
- **`dpd_action = restart`**: automatically re-establish on Dead Peer Detection
- **`if_id_in / if_id_out`**: binds the SA to the XFRM interface with the matching ID
- **`encap = yes`**: force UDP encapsulation (NAT-T), needed when behind Azure NAT

## IPsec authentication hardening

The swanctl configuration includes several settings to restrict authentication of remote public IPs beyond the standard PSK + identity check:

| Setting | Value | Purpose |
|---------|-------|--------|
| `mobike = no` | Disabled | Prevents the remote peer from migrating to a different IP address after IKE_SA establishment. Without this, a peer could authenticate from the expected IP and then switch to a different address mid-session (MOBIKE, RFC 4555). Disabling it ensures the tunnel only works from the originally authenticated public IP for its entire lifetime. |
| `reauth_time = 28800` | 8 hours | Forces full IKE re-authentication (not just rekeying) every 8 hours. During re-authentication, the peer must re-prove its identity with the PSK — if the remote IP has changed or the secret has been revoked, the SA will not be re-established. This is stricter than `rekey_time` which only refreshes keys without re-verifying identity. |
| Separate secrets per peer | `ike-gw0` / `ike-gw1` | Each PSK secret is bound to exactly one remote identity (one VPN Gateway public IP). If one gateway instance's secret were compromised, it could not be used to impersonate the other instance. This provides secret isolation between peers. |

### How identity validation works

strongSwan validates the remote peer at multiple levels:

1. **`remote_addrs`** — Only accepts IKE_INIT from the specified IP address (packet-level filter).
2. **`remote { id = <IP> }`** — Validates the IKE identity (IDr payload) matches the expected VPN Gateway public IP.
3. **`secrets { id-0 = <IP> }`** — The PSK is only offered to a peer presenting a matching identity.
4. **`mobike = no`** — Blocks post-authentication IP migration.
5. **`reauth_time`** — Periodically re-validates all of the above.

Together, these ensure that only the two known Azure VPN Gateway public IPs can establish and maintain tunnels, and each gateway's credential is cryptographically isolated from the other.

## Annex: throw routes in table 220

strongSwan uses routing table 220 for internal policy routing. Adding `throw` routes for the VPN Gateway public IPs prevents routing loops where encrypted packets would be re-matched by strongSwan policies:

```bash
ip route add throw <vpngw_pip>/32 table 220
```

The `throw` route type causes a route lookup to fail in that table, returning control to the routing policy database (RPDB) to continue with the next rule.

## Annex: Linux multiple routing tables

Linux supports up to 256 routing tables (0-255). Key tables:

| ID | Name | Purpose |
|----|------|---------|
| 255 | local | Maintained by kernel (local/broadcast addresses) |
| 254 | main | Default table used by `ip route` |
| 253 | default | Post-processing rules |
| 220 | - | Used by strongSwan |
| 0 | unspec | Unspecified |

Custom tables are defined in `/etc/iproute2/rt_tables`. The routing policy database (RPDB) controls lookup order via `ip rule`. Rules are evaluated by priority (0-32767).

```bash
ip route list table main         # show main table routes
ip route list table 220          # show strongSwan table routes
ip rule show                     # show routing policy rules
```

## Annex: Dual-NIC routing for IPsec

With dual NICs, the NVA separates concerns: eth0 (external) handles SSH and IPsec, while eth1 (internal) handles decrypted transit traffic to/from VM2.

### Inbound IPsec traffic (VPN Gateway → NVA)

Azure VPN Gateway sends IKE/ESP packets to the NVA's public IP (`nva-pubIP`). This public IP is bound to eth0 (external NIC) in the ARM template. Azure fabric translates `nva-pubIP → 10.2.0.10` and delivers the packet directly to eth0.

### Outbound IPsec traffic (NVA → VPN Gateway)

The `vpn-xfrm-setup.sh` script adds explicit host routes via the external NIC gateway:
```bash
ip route add <VPNGW_PIP0>/32 via 10.2.0.1   # external subnet gateway
ip route add <VPNGW_PIP1>/32 via 10.2.0.1
```
Gateway `10.2.0.1` is in eth0's connected subnet (nvaExternalSubnet 10.2.0.0/27). Azure then NATs the source from `10.2.0.10 → nva-pubIP`, which is what the VPN Gateway expects as the peer address.

### Transit traffic (decrypted, via internal NIC)

Decrypted traffic destined for VM2 (subnetApp 10.2.0.64/27) is forwarded via the internal NIC gateway:
```bash
ip route add 10.2.0.64/27 via 10.2.0.33 dev eth1   # internal subnet gateway
```
The UDR on subnetApp routes return traffic (destined for vnet1) back to the NVA's internal NIC IP (10.2.0.40), which then encrypts it via the XFRM interface and sends it out eth0.

### Why dual NIC improves the design

1. **Separation of concerns** — External NIC handles only IPsec/SSH (public-facing); internal NIC handles only transit traffic (private).
2. **Better NSG granularity** — External NIC NSG allows IKE/ESP/SSH; internal NIC NSG allows only VNet transit. No need for a single permissive NSG.
3. **Clearer traffic flow** — IPsec-encrypted traffic never shares the same interface as decrypted transit traffic.
4. **strongSwan binds to the external NIC** — `local_addrs = 10.2.0.10` in swanctl.conf matches eth0's private IP; XFRM interfaces are also bound to eth0.

## References

- [Configure custom IPsec/IKE connection policies for S2S VPN & VNet-to-VNet: Azure portal - Azure VPN Gateway](https://learn.microsoft.com/en-us/azure/vpn-gateway/ipsec-ike-policy-howto)
- [About cryptographic requirements and Azure VPN gateways](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-compliance-crypto)
- [strongSwan IKEv2 Cipher Suites](https://docs.strongswan.org/docs/5.9/config/IKEv2CipherSuites.html) — proposal syntax reference (`aes256gcm16`, `prfsha256`, `modp2048`, etc.)
- [strongSwan route-based VPN (XFRM interfaces)](https://docs.strongswan.org/docs/5.9/features/routeBasedVpn.html)
- [strongSwan swanctl.conf reference](https://docs.strongswan.org/docs/5.9/swanctl/swanctlConf.html)

---

**Tags:** Azure VPN, Site-to-Site VPN, strongSwan <br>
**Updated:** 22-06-2026

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/tunnels.png "site-to-site VPN tunnels"

<!--Link References-->
