# Linux XFRM Framework and IPsec Packet Flow

This document explains how the Linux kernel processes IPsec traffic under the hood — specifically the XFRM ("transform") framework that does the actual encryption and decryption. Understanding this helps troubleshoot tunnel issues and explains *why* the project configures things like XFRM interfaces, throw routes, and `rp_filter=0`.

**Sources:**

- [Linux XFRM Reference Guide for IPsec](https://pchaigno.github.io/xfrm/2024/10/30/linux-xfrm-ipsec-reference-guide.html) — Paul Chaignon
- [Nftables - Netfilter and VPN/IPsec packet flow](https://thermalcircle.de/doku.php?id=blog:linux:nftables_ipsec_packet_flow) — Andrej Stender

## The Big Picture: Who Does What

IPsec on Linux is a two-part system:

```
┌─────────────────────────────────────────────────────┐
│  USERSPACE — StrongSwan (charon daemon)             │
│                                                     │
│  • Runs IKEv2 handshake with Azure VPN Gateway      │
│  • Authenticates peers (X.509 certificates)         │
│  • Negotiates encryption algorithms and keys        │
│  • Creates/deletes Security Associations (SAs)      │
│    and Security Policies (SPs) in the kernel        │
│                                                     │
│  Configured via: /etc/swanctl/swanctl.conf          │
│  Control tool:   swanctl --load-all / --list-sas    │
├──────────────────────── Netlink ────────────────────┤
│  KERNEL — XFRM framework                            │
│                                                     │
│  • Encrypts + encapsulates outgoing packets (ESP)   │
│  • Decrypts + decapsulates incoming packets         │
│  • Decides which packets go through the tunnel      │
│    using Security Policies (SPs)                    │
│  • All crypto happens here, at wire speed           │
│                                                     │
│  Inspect with:   ip xfrm state / ip xfrm policy     │
└─────────────────────────────────────────────────────┘
```

**In this project:** StrongSwan on the NVA VM negotiates two IKEv2 tunnels with Azure VPN Gateway (active-active). Once the handshake completes, StrongSwan pushes the SAs and SPs into the kernel. From that point on, the kernel handles every packet autonomously — StrongSwan only steps in again for rekeying (`rekey_time = 3600`) or re-authentication (`reauth_time = 28800`).

## Security Associations and Security Policies

Two kernel databases drive all IPsec decisions:

### Security Associations (SAs) — the "how"

An SA contains everything needed to encrypt or decrypt one direction of traffic:

- Encryption algorithm and key (e.g., `aes256gcm16`)
- SPI (Security Parameter Index) — a 32-bit identifier in every ESP header
- Tunnel mode endpoints (outer source/destination IPs)
- Replay protection window

**In this project**, after tunnels come up you see four SAs — one pair per tunnel:

```bash
$ sudo ip xfrm state
src 10.2.0.10 dst <VPNGW_PIP0>           # outbound tunnel 0 (NVA → Azure)
    proto esp spi 0x... mode tunnel
    aead rfc4106(gcm(aes)) 0x... 128

src <VPNGW_PIP0> dst 10.2.0.10           # inbound tunnel 0 (Azure → NVA)
    proto esp spi 0x... mode tunnel
    aead rfc4106(gcm(aes)) 0x... 128

# ... and two more for tunnel 1 (VPNGW_PIP1)
```

### Security Policies (SPs) — the "what" and "which direction"

An SP tells the kernel which packets should be encrypted/validated:

| Direction | What it does | When it runs |
|-----------|-------------|-------------|
| `dir out` | "Encrypt this packet" — selects outgoing packets and links to an SA for encryption | Before the packet leaves the host |
| `dir in` | "This decrypted packet is allowed" — validates that incoming local-destined packets were properly decrypted | After decryption, for packets destined to this host |
| `dir fwd` | "This decrypted packet may be forwarded" — same validation but for packets being forwarded to another host | After decryption, for packets being routed onward |

```bash
$ sudo ip xfrm policy
src 0.0.0.0/0 dst 0.0.0.0/0
    dir out priority ... 
    if_id 41                              # linked to ipsec0
    tmpl src 10.2.0.10 dst <VPNGW_PIP0>
        proto esp reqid 1 mode tunnel
```

> The `if_id 41` in the policy is what connects it to the `ipsec0` XFRM interface. Only packets routed through `ipsec0` (which carries `if_id=41`) will match this policy.

### Policy Templates — Linking Policies to States

Each SP includes a **template** that points to the SA to use:

```
tmpl src 10.2.0.10 dst <VPNGW_PIP0>
    proto esp spi 0x00000003 reqid 1 mode tunnel
```

- On **egress**: the template tells the kernel "wrap this packet in ESP tunnel mode using these outer IPs and this SPI"
- On **ingress**: the template acts as a filter — "only accept this packet if it was decrypted by an SA matching these parameters"

## How Packets Actually Flow

### The Problem with Default XFRM (Policy-Based)

In a basic XFRM setup (without XFRM interfaces), the kernel uses Security Policies as traffic selectors. The packet flow is complex because encrypted and decrypted packets share the same physical interface — there is no virtual interface to tell them apart.

This creates two problems:
1. **Firewall rules are hard** — you cannot write `iptables -i ipsec0` because `ipsec0` does not exist
2. **Routing is limited** — you cannot use standard `ip route` to steer traffic into the tunnel

The [Netfilter packet flow diagram](https://upload.wikimedia.org/wikipedia/commons/3/37/Netfilter-packet-flow.svg) shows the full path including XFRM action points, and [Paul Chaignon's refined diagram](https://pchaigno.github.io/assets/netfilter-with-xfrm.png) corrects several details.

### How This Project Solves It: XFRM Interfaces

This project uses **XFRM interfaces** — virtual network devices that sit on top of the XFRM framework and make IPsec tunnels behave like regular network interfaces:

```bash
# Created by vpn-xfrm.service on boot:
ip link add ipsec0 type xfrm dev eth0 if_id 41    # tunnel to VPN GW instance 0
ip link add ipsec1 type xfrm dev eth0 if_id 42    # tunnel to VPN GW instance 1
```

The `if_id` is the glue between the XFRM interface and the IPsec tunnel:

```
swanctl.conf                    XFRM interface              Kernel XFRM
─────────────                   ──────────────              ───────────
gw0 {                           ipsec0                      SA/SP with
  if_id_in  = 41    ◄────────►  if_id = 41    ◄────────►   if_id = 41
  if_id_out = 41
}

gw1 {                           ipsec1                      SA/SP with
  if_id_in  = 42    ◄────────►  if_id = 42    ◄────────►   if_id = 42
  if_id_out = 42
}
```

With XFRM interfaces, the packet flow becomes much simpler:

#### Egress: NVA Sends a Packet to Azure VNet (10.1.0.0/16)

```
Packet from 10.2.1.4 → 10.1.1.10 arrives on eth0

1. Routing lookup → route says "10.1.0.0/16 via ipsec0" (learned via BGP)
2. Packet enters ipsec0 (if_id=41)
3. XFRM framework matches if_id=41 → finds the SA for tunnel 0
4. Encrypts packet, wraps in ESP + outer IP header:
   |eth|ip:10.2.0.10→VPNGW_PIP0|esp|ip:10.2.1.4→10.1.1.10|payload|
5. Outer packet routed via eth0 to Azure VPN Gateway
```

#### Ingress: NVA Receives a Packet from Azure VNet

```
ESP packet from VPNGW_PIP0 → 10.2.0.10 arrives on eth0

1. Outer dst IP = NVA's own IP → routed to INPUT chain
2. XFRM decode: looks up SA by SPI → decrypts → inner packet revealed:
   10.1.1.10 → 10.2.1.4
3. Decrypted packet re-injected at L2 on eth0
4. Second routing pass → forward to subnetApp via eth0
5. XFRM fwd policy check (if_id validates correct tunnel)
6. Packet forwarded to 10.2.1.4
```

> **Why `rp_filter=0`?** In step 3, the decrypted inner packet has source IP `10.1.1.10` but arrives on `eth0`. Strict reverse-path filtering (`rp_filter=1` or `2`) would check "can I reach 10.1.1.10 via eth0?" — the answer is no (it is reachable via ipsec0), so the packet gets dropped. Setting `rp_filter=0` disables this check. Linux uses `max(all, interface)`, so **both** `all.rp_filter` and `eth0.rp_filter` must be 0.

### Why Throw Routes in Table 220?

StrongSwan installs policies in routing table 220 by default. Without throw routes, the kernel could try to route VPN Gateway public IPs *through the tunnel itself*, creating a loop:

```bash
# These throw routes break the loop:
ip route replace throw <VPNGW_PIP0>/32 table 220
ip route replace throw <VPNGW_PIP1>/32 table 220

# And these host routes ensure GW PIPs go via the NVA's default gateway:
ip route replace <VPNGW_PIP0>/32 via <NVA_GW>
ip route replace <VPNGW_PIP1>/32 via <NVA_GW>
```

Without these routes, `ip route get <VPNGW_PIP>` might show `dev ipsec0` instead of `via <NVA_GW> dev eth0`, and StrongSwan would retransmit IKE packets forever.

## XFRM Interfaces vs VTI vs Default XFRM

Three approaches to IPsec on Linux, from oldest to newest:

| Approach | How traffic is selected | Routing | Firewall rules | Used in this project? |
|----------|------------------------|---------|----------------|----------------------|
| **Default XFRM** (policy-based) | Security Policies match src/dst CIDRs | Cannot use `ip route` for tunnel traffic | Must use nftables `ipsec` expressions or packet marks | No |
| **VTI** (`ip tunnel add ... mode vti`) | Virtual tunnel interface with routing | `ip route ... dev vti0` works | `iptables -i vti0` works | No (legacy) |
| **XFRM interface** (`ip link add type xfrm`) | Virtual interface linked by `if_id` to SA/SP | `ip route ... dev ipsec0` works | `iptables -i ipsec0` works | **Yes** |

XFRM interfaces (kernel 4.19+) are the modern choice because:

- **Standard routing** — `ip route add 10.1.0.0/16 dev ipsec0` steers traffic into the tunnel, just like any other interface
- **BGP works naturally** — FRR peers over `ipsec0`/`ipsec1` with `update-source`, learned routes point to the XFRM interfaces
- **Per-tunnel separation** — `if_id=41` and `if_id=42` keep the two active-active tunnels independent
- **Simple firewall rules** — match on `iif ipsec0` or `oif ipsec0` in iptables/nftables
- **No traffic selector restrictions** — `local_ts = 0.0.0.0/0` and `remote_ts = 0.0.0.0/0` in swanctl.conf (route-based, not policy-based)

## XFRM Error Counters

When tunnels are up but traffic is not flowing, XFRM error counters pinpoint the exact failure:

```bash
cat /proc/net/xfrm_stat
```

| Counter | What went wrong | Common cause in this project |
|---------|----------------|------------------------------|
| `XfrmInNoStates` | No SA found for incoming ESP packet | Tunnel not established, SPI mismatch, or SA expired |
| `XfrmInStateProtoError` | Decryption failed | Key mismatch (wrong certificate/key pair), corrupted packet |
| `XfrmInTmplMismatch` | Decrypted packet doesn't match policy template | `if_id` mismatch between swanctl.conf and XFRM interface |
| `XfrmInStateMismatch` | Decrypted packet doesn't match SA selector | Unexpected source/destination in decrypted packet |
| `XfrmInStateSeqError` | Anti-replay rejected the packet | Duplicate or out-of-order packet (network issue) |
| `XfrmInStateExpired` | SA hard-expired but not yet deleted | Rekeying failed, charon not running |
| `XfrmOutNoStates` | Packet matched OUT policy but no SA exists | Tunnel down, `swanctl --load-all` not run |
| `XfrmOutStateModeError` | Encrypted packet too large (MTU exceeded) | Path MTU issue, reduce inner MTU |
| `XfrmOutStateSeqError` | Sequence number overflow | Very long-lived SA without rekeying |
| `XfrmInNoPols` | No matching IN/FWD policy, default = block | Policy not loaded or `if_id` mismatch |
| `XfrmInPolBlock` | Packet matched a policy with `action block` | Explicit block policy installed |

**Quick check:** If all counters are zero and traffic still doesn't flow, the problem is outside XFRM — check routing (`ip route`), firewall rules, or Azure NSG rules (see README.md troubleshooting section 7).

We use XFRM interfaces, so traffic selection happens at the routing level (`ip route ... dev ipsec0`), not via XFRM policies matching source/destination CIDRs. This project does **not** use iptables — `enableSnat` is set to `false` in `init.json`, so no NAT rules are installed. Return traffic from the local subnet (subnetApp) back through the tunnel is handled by a UDR (route table on subnetApp pointing VNet1's address space to the NVA private IP), not by source NAT.
