<properties
   pageTitle="Examples of Azure ARM templates and scripts"
   description="Examples of Azure ARM templates and scripts"
   services="Azure VNet, Azure Load Balancer, Azure VNet peering, Azure VPN"
   documentationCenter="na"
   authors="fabferri"
   manager=""
   editor=""/>

<tags
   ms.service="Configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="na"
   ms.date="21/11/2016"
   ms.author="fabferri" />

# Fab's Azure repository


- Azure Load balancer
  - [Load Balancer in HA ports - basic config](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/ilb-ha-ports-1vnet)
  - [Load Balancer in HA ports with VNet peering](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/ilb-ha-ports-vnetpeering)
  - [load Balancer in HA ports with transit through VNet peering](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/ilb-multiple-fe-be-benchmark)
  - [Load Balancer in HA ports with two backend pools](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/ilb-ha-ports-2backendpools-nva)
  - [Load Balancer in HA ports with two frontend IPs and two backend pools](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/ilb-ha-ports-2frontend-2backendpools)
  - [Load Balancer with multiple frontend IPs and multiple backend address pools](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/ilb-multiple-fe-be)
  - [External Load Balancer](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/lb)

- Azure S2S VPN
  - [Site-to-Site VPN between two VPN Gateways by ARM template](https://github.com/fabferri/az-pattern/tree/master/vpn/s2s-vng-vng-active-active-bgp-arm-template) [date: 11-02-2024]
  - [Site-to-Site VPN between two VPN Gateways by powershell](https://github.com/fabferri/az-pattern/tree/master/vpn/s2s-vng-vng-active-active-bgp-powershell) [date: 15-01-2025]
  - [Site-to-Site VPN between two VPN Gateways by Terraform](https://github.com/fabferri/az-pattern/tree/master/vpn/s2s-vng-vng-active-active-bgp-terraform) [date: 09-01-2025]
  - [Site-to-Site VPN between two VPN Gateways with NAT](https://github.com/fabferri/az-pattern/tree/master/vpn/s2s-vng-vng-NAT)
  - [Azure ARM templates to create Site-to-Site VPN by FQDN](https://github.com/fabferri/az-pattern/tree/master/vpn/s2s-vng-vng-fqdn)
  - [Site-to-Site VPN connection over vnet peering using VPN Gateway private IP addresses](https://github.com/fabferri/az-pattern/tree/master/vpn/s2s-vng-vng-private-ip-transit-vnetpeering) [date: 21-11-2024]
  - [Site-to-Site VPN between Azure VPN Gateways with transit through ExpressRoute private peering](https://github.com/fabferri/az-pattern/tree/master/vpn/s2s-vng-vng-private-ip-transit-er) [date: 22-11-2024]
  - [Multiple VNet-to-VNet connections with VPN Gateways in a Partial Mesh configuration](https://github.com/fabferri/az-pattern/tree/master/vpn/vpn-vnet-2-vnet) [date: 25-11-2024]
  - [Single Site-to-Site IPsec tunnel between Azure VPN Gateway and Juniper vSRX](https://github.com/fabferri/az-pattern/tree/master/vpn/s2s-vng-srx-1-tunnel) [date: 26-11-2024]
  - [Two Site-to-Site IPsec tunnels between Azure VPN Gateway and Juniper vSRX](https://github.com/fabferri/az-pattern/tree/master/vpn/s2s-vng-srx-2-tunnels) [date: 28-11-2024]
  - [Site-to-Site IPsec tunnels between Azure VPN Gateway and Cisco Catalyst 8000v](https://github.com/fabferri/az-pattern/tree/master/vpn/s2s-vng-catalyst-ipv4) [date: 02-07-2025]

- Azure P2S VPN
  - [P2S VPN - authetication with digital certificates](https://github.com/fabferri/az-pattern/tree/master/vpn/p2s) [date: 15-04-2024]

- ExpressRoute 
  - [ExpressRoute configurations](https://github.com/fabferri/az-pattern/tree/master/expressroute)

- Azure DNS
  - [Configuration with Azure DNS private resolver](https://github.com/fabferri/az-pattern/tree/master/dns-private-resolver)

- Azure KeyVault
  - [Azure ARM template to create a Key Vault with list of secrets](https://github.com/fabferri/az-pattern/tree/master/key-vault/key-vault-write-list-secrets) [date: 28-08-23]
  - [Azure ARM template to create multiple Key Vaults in different resouce groups](https://github.com/fabferri/az-pattern/tree/master/key-vault/key-vaults-in-resource-groups)

- Ubuntu VM with UX
  - [Ubuntu VM with GNOME desktop, Visual Studio Code and dotnet SDK](https://github.com/fabferri/az-pattern/tree/master/ubuntu-vm-desktop-gnome) [date: 21-11-2023]
  - [Ubuntu VM with GNOME desktop, Python and Visual Studio Code](https://github.com/fabferri/az-pattern/tree/master/ubuntu-vm-vscode-python-dev) [date: 20-11-2023]

- Private endpoint and private link service
  - [Private endpoints with Azure SQL and Azure storage account](https://github.com/fabferri/az-pattern/tree/master/private-link-and-private-endpoint/private-endpoint-sql-storage)
  - [configuration with private service link and ExpressRoute](https://github.com/fabferri/az-pattern/tree/master/private-link-and-private-endpoint/private-link-1)
  - [Private Link service in HA configuration through Azure Application Gateway](https://github.com/fabferri/az-pattern/tree/master/private-link-and-private-endpoint/private-link-high-availability-balancing) [date: 05-04-23]
  - [Azure Private Link service in HA configuration through Azure functions](https://github.com/fabferri/az-pattern/tree/master/private-link-and-private-endpoint/private-link-high-availability-hot-standby) [date: 31-03-23]

- hub-spoke vnet configurations
  - [How to create two hub-spoke VNets interconnected by VNet peering (basic config)](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/vnet-peering-2hubspoke)
  - [Simple hub-spoke vnet with Route Server and ExpressRoute Gateway](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/hub-spoke-er-rs-101) [date: 25-08-23]
  - [Hub-spoke vnets with Azure firewalls and Route Servers - config1](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/hub-spoke-azfw-rs-er-1) [date: 27-06-23]
  - [Hub-spoke vnets with Azure firewalls and Route Servers - config2](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/hub-spoke-azfw-rs-er-2) [date: 02-07-23]
  - [Network policies for Private Endpoints with UDR and NSG](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/hub-spoke-netw-policies-pe) [date: 28-08-23]
  - [Hub-spoke vnets with site-to-site VPN tunnels between the hubs](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/hub-spoke-s2s-vpn) [date: 03-07-23]

- NAT
  - [Traffic between two subnets through Linux nva controlled by iptables](https://github.com/fabferri/az-pattern/tree/master/nat/nat-iptables-1)
  - [iptables to control traffic inbound and outbound Azure VMs](https://github.com/fabferri/az-pattern/tree/master/nat/nat-iptables-2) [date: 30-10-22]

- Azure Virtual Network Manager
  - [AVNM with hub-spoke-static membership](https://github.com/fabferri/az-pattern/tree/master/azure-virtual-network-manager/hub-spoke-static-membership-01) [date: 05-05-2024]
  - [AVNM with hub-spoke-dynamic membership](https://github.com/fabferri/az-pattern/tree/master/azure-virtual-network-manager/hub-spoke-dynamic-membership-01) [date: 06-05-2024]

- Managed Service Identity
  - [System-assigned managed identity to access to Azure Storage](https://github.com/fabferri/az-pattern/tree/master/managed-identity/system-identity-access-to-storage) [date: 29-05-2022]
  - [User-assigned managed identity to access to Azure Storage](https://github.com/fabferri/az-pattern/tree/master/managed-identity/user-identity-access-to-storage) [date: 28-05-2024]

- [Azure Virtual Datacenter deployment through ARM templates](https://github.com/fabferri/az-pattern/tree/master/virtual-datacenter) [date: 24-05-23]
- [System-assigned managed identity to access to Azure Storage](https://github.com/fabferri/az-pattern/tree/master/vm-msi) [date: 29-05-2022]
- [Azure NetApp Files service](https://github.com/fabferri/az-pattern/tree/master/anf) [date: 22-09-2022]
- [MongoDB in Azure VM](https://github.com/fabferri/az-pattern/tree/master/no-sql-db/mongodb-in-az-vm) [date: 28-12-22]