# Azure Site-to-Site VPN with IPv4/IPv6 Dual-Stack using AZ CLI

This project contains PowerShell scripts to deploy an Azure Site-to-Site (S2S) VPN configuration with dual-stack (IPv4 and IPv6) support using active-active VPN gateways.

[![1]][1]

The deployment creates two Azure VPN Gateways (`gw1` and `gw2`) configured in active-active mode, connected via IPsec tunnels. Both gateways support IPv4 and IPv6 addressing, enabling dual-stack connectivity between VNets.

The diagram below illustrates the detailed network topology:

[![2]][2]

## Configuration

Before running the scripts, update the `init.json` file with your environment-specific values:

```json
{
    "subscriptionName": "YOUR_SUBSCRIPTION_NAME",
    "rgName": "YOUR_RESOURCE_GROUP_NAME",
    "location": "YOUR_AZURE_REGION",
    "adminUsername": "YOUR_ADMIN_USERNAME",
    "adminPassword": "YOUR_ADMIN_PASSWORD"
}
```

>  **Security Note**: Never commit `init.json` with real credentials to a public repository. Add it to your `.gitignore` file or use Azure Key Vault for sensitive information.

## Scripts

Run the scripts in numerical order:

| Script | Description |
|--------|-------------|
| `01_gw1_azcli.ps1` | Creates VNet1, GatewaySubnet, and VPN Gateway `gw1` in active-active mode with dual-stack support |
| `02_gw2_azcli.ps1` | Creates VNet2, GatewaySubnet, and VPN Gateway `gw2` in active-active mode with dual-stack support |
| `03_localNetGateway1_azcli.ps1` | Creates Local Network Gateways (`lng11`, `lng12`) representing `gw1` for use in `gw2` connections |
| `04_localNetGateway2_azcli.ps1` | Creates Local Network Gateways (`lng21`, `lng22`) representing `gw2` for use in `gw1` connections |
| `05_connection1_azcli.ps1` | Creates VPN connections from `gw1` to the Local Network Gateways |
| `06_connection2_azcli.ps1` | Creates VPN connections from `gw2` to the Local Network Gateways |
| `07_vms_azcli.ps1` | Creates test VMs in both VNets with dual-stack network interfaces |

## Network Address Space

### VNet1
- **IPv4**: `10.1.0.0/16`
- **IPv6**: `fd:0:1::/48`
- **GatewaySubnet**: `10.1.0.0/24`, `fd:0:1:e::/64`
- **Subnet1**: `10.1.1.0/24`, `fd:0:1:1::/64`

### VNet2
- **IPv4**: `10.2.0.0/16`
- **IPv6**: `fd:0:2::/48`
- **GatewaySubnet**: `10.2.0.0/24`, `fd:0:2:e::/64`
- **Subnet1**: `10.2.1.0/24`, `fd:0:2:1::/64`

## Usage

1. Update `init.json` with your configuration
1. Run scripts in order:
   ```powershell
   .\01_gw1_azcli.ps1
   .\02_gw2_azcli.ps1
   .\03_localNetGateway1_azcli.ps1
   .\04_localNetGateway2_azcli.ps1
   .\05_connection1_azcli.ps1
   .\06_connection2_azcli.ps1
   .\07_vms_azcli.ps1
   ```

> **Note**: VPN Gateway creation can take 30-45 minutes per gateway. Wait for each gateway to complete before running the Local Network Gateway scripts. **01_gw1_azcli.ps1** and **02_gw2_azcli.ps1** can run in parallel in two terminal becasue are indipendent.

## Features

- **Active-Active VPN Gateways**: High availability with two public IP addresses per gateway
- **Dual-Stack Support**: Both IPv4 and IPv6 connectivity across the VPN tunnels
- **Automated Shared Key Generation**: Deterministic shared key based on subscription and resource group
- **Idempotent Scripts**: Scripts check for existing resources before creating new ones

`Tag: Site-to-Site VPN, dual-stack, IPv6` <br>
`date: 23-01-2026`

<!--Image References-->

[1]: ./media/network-diagram.png "high level network diagram"
[2]: ./media/network-diagram-details.png "full network diagram"

<!--Link References-->
