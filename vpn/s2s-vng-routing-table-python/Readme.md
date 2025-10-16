<properties
pageTitle= 'Azure VPN Gateway Routing and Connection by Azure library for Python'
description= "Azure VPN Gateway Routing and Connection by Azure library for Python"
services="Azure VPN Gateway, Python"
documentationCenter="https://github.com/fabferri"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="howto-Azure-examples"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="Azure VPN Gateway, Python"
   ms.date="08/09/2025"
   ms.review=""
   ms.author="fabferri" />

# Azure VPN Gateway Routing and Connection by Azure library for Python

A comprehensive Python tool for analyzing Azure Virtual Network Gateway (VPN Gateway) routing information, connections, and BGP peer status. This tool provides detailed information on connection health, BGP peer status, and route exchange in clean, readable tabular format. <br>
This tool is built using the Azure SDK for Python and provides professional-grade network analysis capabilities.

 ## Quick Overview

This code collects details about Azure VPN Gateways and provides:

### **Connection Management** 
- **VPN Connections Table**: Tabular display of all site-to-site VPN connections with status, types, and remote gateway IPs
- **Connection Statistics**: Summary of total connections, connected vs. disconnected counts
- **Provisioning Status**: Shows provisioning state alongside connection status for better troubleshooting
- **Shared Key Status**: inference of shared key configuration without exposing sensitive values

### **BGP Analysis** 
- **BGP Peer Table**: Tabular format showing peer IP, state, status, message statistics, and connection duration
- **Peer Health Monitoring**: Detailed metrics including messages sent/received, routes received, and uptime
- **Connection Statistics**: Quick overview of total BGP peers and connected peer counts
- **Troubleshooting Guidance**: Contextual tips automatically displayed for disconnected or unknown peers

### **Routing Information**
- **Learned Routes**: Routes learned from BGP peers with full path information
- **Advertised Routes**: Routes being advertised to connected BGP peers
- **Route Details**: Network prefixes, next hops, AS paths, origins, and weights

## Installation

1. **Create a Python virtual environment** (recommended):

   ```bash
   python -m venv .venv
   .venv\Scripts\activate  # Windows
   # or
   source .venv/bin/activate  # Linux/Mac
   ```

As an alternative, a Python virtual environment can be set up through Visual Studio Code.

2. **Install required dependencies**:

   ```bash
   pip install -r requirements.txt
   ```

## Configuration

**Configuration Files Structure**

```
├── .env                   # Azure subscription ID
├── config.json            # VPN Gateway configuration  
├── vng-routing-table.py   # Main script
└── requirements.txt       # Dependencies
```

1. **Set up environment variables** in `.env` file:

   ```env
   AZURE_SUBSCRIPTION_ID="your-subscription-id-here"
   ```

2. **Configure gateway details** in `config.json` file:

   ```json
   {
     "RESOURCE_GROUP_NAME": "your-resource-group-name",
     "VPN_GATEWAY_NAME": "your-vpn-gateway-name"
   }
   ```

3. **Authenticate with Azure**:

   ```bash
   az login
   az account set --subscription "your-subscription-name"
   az account show
   ```

## how to run the script to collect VPN Gateway information

   ```bash
   python vng-routing-table.py
   ```

### Sample Output

The tool provides comprehensive output in a structured tabular format:

1. **VPN Gateway Information** - Basic gateway properties and configuration
2. **VPN Connections Table** - Professional table showing all site-to-site connections with status, provisioning state, and remote gateway IPs
3. **BGP Peer Status Table** - Clean tabular display of BGP peers with state, statistics, and connection metrics
4. **Learned Routes Table** - Routes learned from BGP peers with complete path information
5. **Advertised Routes Table** - Routes being advertised to connected peers
6. **Summary Report** - Quick overview with connection and BGP peer statistics

### New Tabular Format Features

This version introduces significantly improved tabular displays:

**VPN Connections Table:**
```
Connection Name          Type           Status         Remote Gateway IP   Provisioning    Shared Key     
--------------------------------------------------------------------------------------------------------
conn-to-onprem          IPsec          Connected      203.0.113.10        Succeeded       Configured     
conn-to-branch          IPsec          NotConnected   203.0.113.20        Succeeded       Set           
```

**BGP Peer Status Table:**
```
Peer IP        State       Status      Messages Sent  Messages Recv  Duration       Routes Recv
------------------------------------------------------------------------------------------------------------
192.168.1.1    Connected   CONNECTED   450            425            2d 14h 32.15s  25           
192.168.1.2    Unknown     UNKNOWN     0              0              -              0            
192.168.1.3    Connected   CONNECTED   123            98             1:23:45.67     12
```

**Enhanced Summary Section:**
- Total connection counts with connected/disconnected breakdown
- BGP peer statistics with connection status
- Quick health overview for troubleshooting

## Key Functions

### Core Functions

- **`initialize_azure_client()`** - Sets up Azure authentication and network management client
- **`get_vpn_gateway_info()`** - Retrieves VPN gateway properties and configuration
- **`get_vpn_connections()`** - Gets all VPN connections with full details and remote gateway IPs
- **`get_bgp_peers()`** - Analyzes BGP peer status with connection statistics and health metrics

### Routing Functions

- **`get_learned_routes()`** - Fetches routes learned from BGP peers
- **`get_advertised_routes()`** - Retrieves routes advertised to specific BGP peers
- **`get_local_network_gateway_ip()`** - Resolves remote gateway IP addresses from connection details

### Utility Functions

- **`print_vpn_connections()`** - Formats and displays VPN connections in professional tabular format with statistics
- **`print_bgp_peers()`** - Displays BGP peer information in clean tabular format with connection metrics
- **`print_routes_table()`** - Shows routing information with comprehensive details and path analysis
- **`print_troubleshooting_tips()`** - Provides contextual guidance for common connectivity issues

## Requirements

- **Python**: 3.7 or higher
- **Azure SDK**: azure-mgmt-network >= 25.0.0
- **Authentication**: azure-identity >= 1.15.0
- **Environment**: python-dotenv >= 1.1.1
- **Permissions**: Azure Reader or Network Contributor role on the VPN Gateway resource group

## Supported Gateway Types

- **Virtual Network Gateway** (VPN Gateway) - Fully supported
- **Virtual WAN VPN Gateway** - Not supported (it requires different API)

## BGP Peer States

The tool displays detailed BGP peer states with explanations:

- **Connected**: BGP session is established and routes are being exchanged
- **Unknown**: Peer may be initializing, experiencing connectivity issues, or in transition
- **Disconnected**: BGP session is not established

## Troubleshooting

If you encounter issues:

1. Verify gateway name and resource group are correct
2. Ensure proper permissions to read VPN gateway information  
3. Check if the VPN gateway is a Virtual Network Gateway (not Virtual WAN VPN Gateway)
4. Make sure BGP is enabled on the gateway to see learned routes
5. Verify BGP peers are connected to see advertised routes
6. Check Azure CLI authentication: `az login`
7. Confirm subscription access and network permissions

## Security Notes

- **Shared Key Protection**: The tool respects Azure security policies and does not expose PSK  shared key values
- **Key Status Inference**: Shared key status is intelligently inferred from connection states and provisioning status
- **Safe Authentication**: Uses Azure DefaultAzureCredential for secure, token-based authentication

## Dependencies

The tool uses the following Azure SDK packages:

```python
azure-identity>=1.15.0      # Azure authentication
azure-mgmt-network>=25.0.0  # Network management operations  
python-dotenv>=1.1.1        # Environment variable management
```

---

**Tags:** Azure VPN, Site-to-Site VPN Gateway, Python, Network Analysis  
**Updated:** October 16, 2025

<!--Image References-->

<!--Link References-->
