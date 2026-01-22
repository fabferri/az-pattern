# Azure IPv6 Site-to-Site VPN Deployment

This project deploys an Azure Site-to-Site (S2S) VPN connection between two Virtual Networks (VNets) with **IPv4 and IPv6 dual-stack** support using ARM templates.

## Architecture Overview

The following diagram illustrates the network topology:

[![1]][1]

The deployment creates:

- **Two VNets (hub1 and hub2)** with dual-stack addressing (IPv4 + IPv6)
- **Two VPN Gateways (gw1 and gw2)** configured for active-active mode with BGP
- **Two Site-to-Site VPN connections** between the two gateways
- **Two Ubuntu VMs (vm1 and vm2)** for testing connectivity

### Network Address Spaces

| VNet | IPv4 Address Space | IPv6 Address Space |
|------|--------------------|-------------------|
| hub1 | 10.1.0.0/24        | fd:0:1::/48 |
| hub2 | 10.2.0.0/24        | fd:0:2::/48 |

### Subnet Configuration

| VNet | Subnet        | IPv4 Range    | IPv6 Range    |
|------|---------------|---------------|---------------|
| hub1 | subnet1       | 10.1.0.0/27   | fd:0:1:1::/64 |
| hub1 | GatewaySubnet | 10.1.0.224/27 | fd:0:1:e::/64 |
| hub2 | subnet1       | 10.2.0.0/27   | fd:0:2:1::/64 |
| hub2 | GatewaySubnet | 10.2.0.224/27 | fd:0:2:e::/64 |

### BGP Configuration

- gw1 is configured with ASN: 65001
- gw2 is configured with ASN: 65002

## Files

| File               | Description |
|--------------------|-------------|
| `az-ipv6.ps1`      | PowerShell deployment script |
| `az-ipv6.json`     | ARM template defining all Azure resources |
| `init.json`        | Configuration parameters (subscription, resource group, credentials) |
| `address-IPv6.txt` | Reference file with IPv6 addressing schemes |

## Configuration

Before deploying, update the `init.json` file with your values:

```json
{
    "subscriptionName": "<your-subscription-name>",
    "rgName": "<resource-group-name>",
    "locationvnethub1": "uksouth",
    "locationvnethub2": "uksouth",
    "adminUsername": "<vm-admin-username>",
    "adminPassword": "<vm-admin-password>"
}
```

- `subscriptionName`: Azure subscription name
- `rgName`: Resource group name
- `locationvnethub1`: Azure region for hub1
- `locationvnethub2`: Azure region for hub2
- `adminUsername`: VM administrator username
- `adminPassword`: VM administrator password


## Deployment

Run the deployment script:
   ```powershell
   .\az-ipv6.ps1
   ```

## Resources Deployed

- **Virtual Networks**: hub1, hub2
- **VPN Gateways**: gw1, gw2 (VpnGw2AZ SKU, Zone-redundant)
- **Public IP Addresses**: 4 static IPs for active-active VPN configuration
- **Local Network Gateways**: 4 local network gateways for BGP peering
- **VPN Connections**: 4 IPsec Connections (active-active)
- **Virtual Machines**: vm1 (in hub1), vm2 (in hub2)
- **Network Security Groups**: NSGs for VMs
- **Network Interfaces**: NICs with dual-stack configuration

## Gateway SKU

The deployment uses **VpnGw2AZ** by default, which supports:
- Zone redundancy (Availability Zones 1, 2, 3)
- Active-active configuration
- BGP routing
- IPv6 support

## Testing Connectivity

After deployment, you can test IPv6 connectivity between the VMs:

```bash
# From vm1, ping vm2's IPv6 address
vm2:~$ping6 <vm2-ipv6-address>
vm2:~$ ping6 fd:0:1:1::4
vm2:~$ ping -6 fd:0:1:1::4

# Test TCP connectivity
nc -6 -zv <vm2-ipv6-address> 22

# test iperf3
vm1:~$ iperf3 -6 -s 

vm2:~$ iperf3 -6 -c fd:0:1:1::4 -t 600
```

## Useful Links

- [Azure VPN Gateway IPv6 documentation](https://aka.ms/vpnipv6portal)
- [IPv6 CIDR Calculator](https://iplocation.io/ipv6-cidr-to-range)

## Notes

- The VPN gateways use BGP for route exchange
- Both gateways are configured in active-active mode for high availability
- The shared key for IPsec is auto-generated using the resource group ID


`Tags: Azure VPN, Site-to-Site VPN, IPv6, dual-stack` <br>
`date: 23-07-2025` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"

<!--Link References-->