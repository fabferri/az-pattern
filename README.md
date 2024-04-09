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

- Azure KeyVault
  - [Azure ARM template to create a Key Vault with list of secrets](https://github.com/fabferri/az-pattern/tree/master/key-vault/key-vault-write-list-secrets) [update: 28-08-23]
  - [Azure ARM template to create multiple Key Vaults in different resouce groups](https://github.com/fabferri/az-pattern/tree/master/key-vault/key-vaults-in-resource-groups)

- Azure Load balancer
  - [Load Balancer in HA ports](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/ilb-ha-ports-1vnet)
  - [Load Balancer in HA ports with two NVA pools](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/ilb-ha-ports-2backendpools-nva)
  - [Load Balancer in HA ports with two frontend IPs and two backend pools](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/ilb-ha-ports-2frontend-2backendpools)
  - [Load Balancer in HA ports with VNet peering](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/ilb-ha-ports-vnetpeering)
  - [load Balancer in HA with transit through VNet peering](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/ilb-multiple-fe-be-benchmark)
  - [Load Balancer with multiple frontend IPs and backend address pools](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/ilb-multiple-fe-be)
  - [external Load Balancer](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/lb)

- Azure S2S VPN
  - [Single ARM template to create Site-to-Site VPN between two VPN Gateways](https://github.com/fabferri/az-pattern/tree/master/vpn/s2s-azvpn-ip) [updated: 11-02-2024]
  - [Connection between two VNets through site-to-site VPN with NAT](https://github.com/fabferri/az-pattern/tree/master/vpn/s2s-azvpn-NAT)
  - [Azure ARM templates to create site-to-site VPN by FQDN](https://github.com/fabferri/az-pattern/tree/master/vpn/s2s-azvpn-fqdn)
  
- ExpressRoute 
  - [Expressroute configurations](https://github.com/fabferri/az-pattern/tree/master/expressroute)



- Azure DNS
  - [Configuration with Azure DNS private resolver](https://github.com/fabferri/az-pattern/tree/master/dns-private-resolver)

- [Azure Virtual Datacenter deployment through ARM templates](https://github.com/fabferri/az-pattern/tree/master/virtual-datacenter) [updated: 24-05-23]
- [System-assigned managed identity to access to Azure Storage](https://github.com/fabferri/az-pattern/tree/master/vm-msi)