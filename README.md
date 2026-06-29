# Fab's Azure Networking patterns
[fabferri/az-pattern: Azure ARM templates and scripts](https://github.com/fabferri/az-pattern/tree/master)

## Basic examples

- [How to generate traffic between two Azure VMs](https://github.com/fabferri/az-pattern/tree/master/00-basic-examples/00-traffic-between-2vms) [date: 18-08-2018]
- [ARM template to create a single VNet with three subnets and a VM working as ip forwarder](https://github.com/fabferri/az-pattern/tree/master/00-basic-examples/01-ip-forwarding)
- [Simple hub-spoke VNets configuration with VNet peering and UDR](https://github.com/fabferri/az-pattern/tree/master/00-basic-examples/01-rt-hub-spokes)
- [Azure Bastion to access to Azure VMs](https://github.com/fabferri/az-pattern/tree/master/00-basic-examples/az-bastion)
- [Azure VMs with multiple NICs](https://github.com/fabferri/az-pattern/tree/master/02-vms-multiple-nics-01) [date: 17-07-2018]
- [Conditional deployment of Azure VMs](https://github.com/fabferri/az-pattern/tree/master/03-vms-conditional-deployment) [date: 25-11-2016]

## Azure Load Balancer

- [Load Balancer in HA ports - basic config](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/ilb-ha-ports-1vnet)
- [Load Balancer in HA ports with VNet peering](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/ilb-ha-ports-vnetpeering)
- [Load Balancer in HA ports with transit through VNet peering](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/ilb-multiple-fe-be-benchmark)
- [Load Balancer in HA ports with two backend pools](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/ilb-ha-ports-2backendpools-nva)
- [Load Balancer in HA ports with two frontend IPs and two backend pools](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/ilb-ha-ports-2frontend-2backendpools)
- [Load Balancer with multiple frontend IPs and multiple backend address pools](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/ilb-multiple-fe-be)
- [External Load Balancer](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/lb)
- [Load balancing HTTP traffic by NGINX](https://github.com/fabferri/az-pattern/tree/master/loadbalancer/nginx-lb) [date: 18-07-2022]

## ExpressRoute

- [ARM template to create two Azure VNets connected to an ExpressRoute circuit in different Azure subscription](https://github.com/fabferri/az-pattern/tree/master/expressroute/er-circuit-2vnets) [date: 29-09-2019]
- [ARM template to create a VNet with ExpressRoute gateway](https://github.com/fabferri/az-pattern/tree/master/expressroute/er-gw) [date: 21-02-2021]
- [Traffic of Azure management portal across ExpressRoute Microsoft peering](https://github.com/fabferri/az-pattern/tree/master/expressroute/er-ms-peering-azure-mng-portal) [date: 21-07-2021]
- [ExpressRoute Microsoft peering: how to retrieve the list of prefixes associated with BGP community](https://github.com/fabferri/az-pattern/tree/master/expressroute/er-ms-peering-bgp-community) [date: 05-01-2018]
- [Azure IoT Hub with transit across ExpressRoute Microsoft peering](https://github.com/fabferri/az-pattern/tree/master/expressroute/er-ms-peering-iot-hub) [date: 28-08-2020]
- [Routing between Azure VPN Gateway with site-to-site VPN and ExpressRoute Gateway connected to an ExpressRoute circuit](https://github.com/fabferri/az-pattern/tree/master/expressroute/er-rs-vpn-transitive) [date: 07-08-2023]
- [ExpressRoute Gateway and Azure VPN Gateway in coexistence](https://github.com/fabferri/az-pattern/tree/master/expressroute/er-vpn-coexistence) [date: 26-09-2021]
- [ExpressRoute Direct port pair](https://github.com/fabferri/az-pattern/tree/master/expressroute/er-direct-port-pair)

## Azure DNS

- [Configuration with Azure DNS private resolver](https://github.com/fabferri/az-pattern/tree/master/dns-private-resolver)

## Azure Firewall

- [Configuration with Azure firewall Basic SKU](https://github.com/fabferri/az-pattern/tree/master/az-fw/azfw-basic) [date: 11-01-2019]

## Azure KeyVault

- [Azure ARM template to create a Key Vault with list of secrets](https://github.com/fabferri/az-pattern/tree/master/key-vault/key-vault-write-list-secrets) [date: 28-08-2023]
- [Azure ARM template to create multiple Key Vaults in different resource groups](https://github.com/fabferri/az-pattern/tree/master/key-vault/key-vaults-in-resource-groups)

## Ubuntu VM

- [Ubuntu VM with GNOME desktop, Visual Studio Code and dotnet SDK](https://github.com/fabferri/az-pattern/tree/master/ubuntu-vm-desktop-gnome) [date: 21-11-2023]
- [Ubuntu VM with GNOME desktop, Python and Visual Studio Code](https://github.com/fabferri/az-pattern/tree/master/ubuntu-vm-vscode-python-dev) [date: 20-11-2023]
- [Azure ubuntu VM deployed with custom script extension through Azure Python SDK](https://github.com/fabferri/az-pattern/tree/master/ubuntu-vm-custom-script-extension-python) [date: 17-09-2025]

## Private endpoint and private link service

- [Private endpoints with Azure SQL and Azure storage account](https://github.com/fabferri/az-pattern/tree/master/private-link-and-private-endpoint/private-endpoint-sql-storage)
- [Private endpoint for Azure storage account by powershell](https://github.com/fabferri/az-pattern/tree/master/private-link-and-private-endpoint/private-endpoint-storage-powershell)
- [Configuration with private service link and ExpressRoute](https://github.com/fabferri/az-pattern/tree/master/private-link-and-private-endpoint/private-link-1)
- [Private Link service in HA configuration through Azure Application Gateway](https://github.com/fabferri/az-pattern/tree/master/private-link-and-private-endpoint/private-link-high-availability-balancing) [date: 05-04-2023]
- [Azure Private Link service in HA configuration through Azure functions](https://github.com/fabferri/az-pattern/tree/master/private-link-and-private-endpoint/private-link-high-availability-hot-standby) [date: 31-03-2023]

## Hub-spoke VNet configurations

- [How to create two hub-spoke VNets interconnected by VNet peering (basic config)](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/vnet-peering-2hubspoke)
- [Two hub-spoke VNets connected by VNet-to-VNet with load balancer in HA ports in the hub vnets](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/vnet-peering-2hubspoke-ilb-vpn) [date: 27-07-2018]
- [Two hub-spoke VNets connected by VNet peering with load balancer in HA ports in the hub VNets](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/vnet-peering-2hubspoke-ilb-vpn-2) [date: 27-07-2019]
- [Configuration with hub and spoke of spoke vnets with summarization](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/vnet-peering-summarization) [date: 15-06-2021]
- [Configuration hub-spoke with large number of spoke vnets](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/hub-spoke-high-number-spokes) [date: 28-07-2021]
- [Hub-spoke vnets with Route Server and FRR](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/hub-spoke-rs) [date: 28-06-2022]
- [Hub-spoke vnets with Azure Bastion in one hub vnet - config1](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/single-bastion-hub-spoke-2) [date: 18-07-2022]
- [Hub-spoke vnets with Azure Bastion in one hub vnet - config2](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/single-bastion-hub-spoke-3) [date: 24-07-2022]
- [Hub-spoke vnets configuration with ExpressRoute connection in failover through a transit vnet](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/hub-spoke-rs-er-alternative-path-onprem) [date: 14-02-2023]
- [Hub-spoke vnets with Route Server in hub and in the spoke vnets and centralized routing control through NVA](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/hub-spokes-rs-nva-routingcontrol) [date: 16-02-2023]
- [Hub-spoke vnets with Azure firewalls and Route Servers - config1](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/hub-spoke-azfw-rs-er-1) [date: 27-06-2023]
- [Hub-spoke vnets with Azure firewalls and Route Servers - config2](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/hub-spoke-azfw-rs-er-2) [date: 02-07-2023]
- [Hub-spoke vnets with site-to-site VPN tunnels between the hubs](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/hub-spoke-s2s-vpn) [date: 03-07-2023]
- [Simple hub-spoke vnet with Route Server and ExpressRoute Gateway](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/hub-spoke-er-rs-101) [date: 25-08-2023]
- [Network policies for Private Endpoints with UDR and NSG](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/hub-spoke-netw-policies-pe) [date: 28-08-2023]
- [Hub-spoke vnets with Route Server in hub and in the firewall vnet](https://github.com/fabferri/az-pattern/tree/master/hub-spoke-vnets/hub-spokes-rs-nva-fw-routingcontrol) [date: 24-10-2024]

## Azure Route Server

- [Azure route server in BGP peering with FRR](https://github.com/fabferri/az-pattern/tree/master/route-server/basic-rs-frr-cloud-init) [date: 29-03-2021]
- [Azure route server in BGP peering with quagga](https://github.com/fabferri/az-pattern/tree/master/route-server/basic-rs-with-quagga) [date: 29-03-2021]
- [Dual-homed network with Azure Route Server and ExpressRoute](https://github.com/fabferri/az-pattern/tree/master/route-server/rs-dualhome-2er-circuits) [date: 29-03-2021]
- [Dual-homed network with Azure Route Server and site-to-site VPNs](https://github.com/fabferri/az-pattern/tree/master/route-server/rs-dualhome-s2s-vpn) [date: 29-04-2021]
- [Linux firewall for Internet-bound traffic and VNet with Azure Route Server](https://github.com/fabferri/az-pattern/tree/master/route-server/rs-firewall) [date: 11-08-2021]
- [BGP peering through an internal load balancer](https://github.com/fabferri/az-pattern/tree/master/route-server/bgp-ilb) [date: 18-11-2021]

## NAT

- [Traffic between two subnets through Linux nva controlled by iptables](https://github.com/fabferri/az-pattern/tree/master/nat/nat-iptables-1)
- [iptables to control traffic inbound and outbound Azure VMs](https://github.com/fabferri/az-pattern/tree/master/nat/nat-iptables-2) [date: 30-10-2022]
- [Traffic to internet through Uncomplicated firewall with NAT masquerade](https://github.com/fabferri/az-pattern/tree/master/nat/nat-uncomplicated-firewall) [date: 14-08-2021]

## VNet NAT

- [Azure ARM template to deploy and test VNet NAT](https://github.com/fabferri/az-pattern/tree/master/vnet-nat) [date: 26-02-2020]

## Azure Virtual Network Manager

- [AVNM with hub-spoke-static membership](https://github.com/fabferri/az-pattern/tree/master/azure-virtual-network-manager/hub-spoke-static-membership-01) [date: 05-05-2024]
- [AVNM with hub-spoke-dynamic membership](https://github.com/fabferri/az-pattern/tree/master/azure-virtual-network-manager/hub-spoke-dynamic-membership-01) [date: 06-05-2024]

## Managed Service Identity

- [System-assigned managed identity to access to Azure Storage](https://github.com/fabferri/az-pattern/tree/master/managed-identity/system-identity-access-to-storage) [date: 29-05-2022]
- [User-assigned managed identity to access to Azure Storage](https://github.com/fabferri/az-pattern/tree/master/managed-identity/user-identity-access-to-storage) [date: 28-05-2024]
- [User-assigned managed identity to access to Azure Keyvault](https://github.com/fabferri/az-pattern/tree/master/managed-identity/user-identity-access-to-keyvault) [date: 28-05-2024]
- [Assign a user-assigned managed identity to an existing VM](https://github.com/fabferri/az-pattern/tree/master/managed-identity/user-identity-associated-to-vm-powershell) [date: 11-06-2024]

## Azure Virtual WAN

- [Virtual WAN: simple configuration with isolating VNets](https://github.com/fabferri/az-pattern/tree/master/vwan/01-vwan-isolating-vnets-2hubs) [date: 30-08-2021]
- [Virtual WAN: configuration with isolating VNets](https://github.com/fabferri/az-pattern/tree/master/vwan/01-vwan-isolating-vnets-3hubs) [date: 30-08-2021]
- [Virtual WAN: configuration with site-to-site VPN](https://github.com/fabferri/az-pattern/tree/master/vwan/01-vwan-s2s-1hub) [date: 30-08-2021]
- [Virtual WAN: isolation VNets and site-to-site VPN](https://github.com/fabferri/az-pattern/tree/master/vwan/02-vwan-isolating-vnets-with-s2s) [date: 30-08-2021]
- [Virtual WAN: route to shared services VNet](https://github.com/fabferri/az-pattern/tree/master/vwan/02-vwan-route-to-shared-services-vnet) [date: 30-08-2021]
- [Virtual WAN: route traffic through an NVA in BGP peering with virtual hub](https://github.com/fabferri/az-pattern/tree/master/vwan/03-vwan-route-through-nva-bgp-1) [date: 30-08-2021]
- [Virtual WAN: firewall - custom traffic transit](https://github.com/fabferri/az-pattern/tree/master/vwan/03-vwan-azfw-b2v) [date: 03-09-2021]
- [Virtual WAN: route traffic through NVAs by static routing in hubs](https://github.com/fabferri/az-pattern/tree/master/vwan/03-vwan-route-through-nva-static-routing) [date: 03-09-2021]
- [Virtual WAN: BGP peering with virtual hubs](https://github.com/fabferri/az-pattern/tree/master/vwan/03-vwan-route-through-nva-bgp-2) [date: 03-10-2021]
- [Virtual WAN with virtual hub in BGP peering with Juniper Session Smart Router](https://github.com/fabferri/az-pattern/tree/master/vwan/vwan-juniper-ssr) [date: 23-01-2021]
- [Virtual WAN: VNet to VNet (V2V) with transit through Azure firewall](https://github.com/fabferri/az-pattern/tree/master/vwan/03-vwan-azfw-v2v) [date: 03-02-2022]
- [Virtual WAN: traffic branches to VNets with transit through an NVA](https://github.com/fabferri/az-pattern/tree/master/vwan/03-vwan-nva-b2v-1hub) [date: 03-02-2022]
- [Virtual WAN: traffic branches to VNets with transit through an NVA](https://github.com/fabferri/az-pattern/tree/master/vwan1/nva-b2v) [date: 21-10-2022]
- [Virtual WAN: traffic branches to VNets with transit through a firewall in spoke vnet and internet breakout](https://github.com/fabferri/az-pattern/tree/master/vwan1/nva-b2v-internetbreakout) [date: 21-10-2022]
- [Virtual WAN: communication of a shared vnet with isolating vnets and branch](https://github.com/fabferri/az-pattern/tree/master/vwan1/shared-vnet-er) [date: 02-02-2023]
- [Virtual WAN with two secure hubs and Private Traffic Routing Policy](https://github.com/fabferri/az-pattern/tree/master/vwan1/2hubs-routing-intent) [date: 09-08-2023]
- [Azure Virtual WAN two virtual hubs with spoke VNets and child spoke VNets](https://github.com/fabferri/az-pattern/tree/master/vwan1/vwan-hubs-spoke-and-child-spoke-s2s)
- [Virtual WAN: VNet isolation with S2S VPN and Azure Virtual Network Manager](https://github.com/fabferri/az-pattern/tree/master/vwan1/vwan-isolating-vnets-with-s2s-avnm)
- [Azure vWAN with Point-To-Site connections configured with user groups and multiple address pool](https://github.com/fabferri/az-pattern/tree/master/vwan1/vwan-multiple-address-pool)
- [Azure Virtual WAN single hub with two spoke VNets and Palo Alto cloud NGFW](https://github.com/fabferri/az-pattern/tree/master/vwan1/vwan-palo-alto) [date: 28-08-2025]
- [Azure Virtual WAN Secure Hubs with Parent Spokes and Child Spokes](https://github.com/fabferri/az-pattern/tree/master/vwan1/vwan-securehubs-spoke-and-child-spoke-s2s)

## VNet peering

- [VNet peering basic configuration](https://github.com/fabferri/az-pattern/tree/master/vnet-peering/vnet-peering-basic)
- [Azure VNets peering between VNets in different Azure subscriptions](https://github.com/fabferri/az-pattern/tree/master/vnet-peering/vnet-peering-different-subscriptions) [date: 08-04-2020]
- [Resize the address space of Azure vnets that are peered](https://github.com/fabferri/az-pattern/tree/master/vnet-peering/resize-vnet-peering) [date: 20-09-2022]
- [Migration of a spoke vnet peering between two hub vnets](https://github.com/fabferri/az-pattern/tree/master/vnet-peering/vnet-peering-migration) [date: 22-05-2022]

## IPv6

- [Azure Virtual Network deployment with IPv6](https://github.com/fabferri/az-pattern/tree/master/ipv6/ipv6-single-vnet) [date: 11-12-2019]
- [Azure Virtual Network deployment with IPv6 and Load Balancer](https://github.com/fabferri/az-pattern/tree/master/ipv6/ipv6-single-vnet-lb) [date: 19-06-2019]
- [Azure hub-spoke Virtual Network with IPv6](https://github.com/fabferri/az-pattern/tree/master/ipv6/ipv6-vnet-peering) [date: 02-09-2019]

## Monitoring

- [Azure Connection Monitor across private link](https://github.com/fabferri/az-pattern/tree/master/monitor/connection-monitor-private-endpoint) [date: 30-04-2022]
- [Monitor with OMS agent and network watcher agent](https://github.com/fabferri/az-pattern/tree/master/monitor/oms-agent-and-network-watcher-agent) [date: 30-04-2022]
- [Azure Traffic Analytics](https://github.com/fabferri/az-pattern/tree/master/monitor/traffic-analytics) [date: 30-04-2022]
- [Packet captures in Virtual Machine Scale Sets with Azure Network Watcher](https://github.com/fabferri/az-pattern/tree/master/monitor/vmss-packet-capture) [date: 31-08-2022]

## Benchmarks

- [ARM template to deploy CyPerf controller and agents in Azure VMs](https://github.com/fabferri/az-pattern/tree/master/benchmarks/cyperf) [date: 10-01-2023]

## Terraform

- [Deployment of Azure VMs with transit through Azure Firewall using Terraform](https://github.com/fabferri/az-pattern/tree/master/terraform/1vnet-azfw-bastion) [date: 18-07-2022]

## Juniper vSRX

- [Juniper vSRX: basic configuration to allow traffic in transit between two VMs](https://github.com/fabferri/az-pattern/tree/master/srx-101) [date: 30-01-2023]
- [Overlay network between two VNets connected through IPsec by Juniper SRX](https://github.com/fabferri/az-pattern/tree/master/overlay-network-srx) [date: 30-07-2020]

## Other configurations

- [Azure Virtual Datacenter deployment through ARM templates](https://github.com/fabferri/az-pattern/tree/master/virtual-datacenter) [date: 07-02-2023]
- [Azure NetApp Files service](https://github.com/fabferri/az-pattern/tree/master/anf) [date: 22-09-2022]
- [MongoDB in Azure VM](https://github.com/fabferri/az-pattern/tree/master/no-sql-db/mongodb-in-az-vm) [date: 28-12-2022]
- [Azure ARM template and powershell to deploy Azure SQL server with databases](https://github.com/fabferri/az-pattern/tree/master/azure-sql-db) [date: 19-02-2020]
- [Deploy an ARM template in a PowerShell runbook](https://github.com/fabferri/az-pattern/tree/master/automation) [date: 23-02-2021]
- [VXLAN between two Azure VMs in the same vnet](https://github.com/fabferri/az-pattern/tree/master/vxlan) [date: 25-10-2021]
- [BGP between two Windows Server 2019 VMs in Azure VNet](https://github.com/fabferri/az-pattern/tree/master/windows-bgp) [date: 12-03-2021]
- [Azure VNet traffic with transit through on-premises network](https://github.com/fabferri/az-pattern/tree/master/unfavourable-routing-to-onpremises)
- [SFTP in Azure Blob Storage with access through private endpoint](https://github.com/fabferri/az-pattern/tree/master/sftp-storageblob) [date: 08-04-2022]
- [UDR with service tags](https://github.com/fabferri/az-pattern/tree/master/service-tag-udr) [date: 28-06-2021]
- [Azure Resource Graph queries in powershell](https://github.com/fabferri/az-pattern/tree/master/resource-graph) [date: 22-05-2021]
- [How to deploy Azure resources through REST APIs](https://github.com/fabferri/az-pattern/tree/master/rest-api) [date: 07-03-2022]
- [Powershell script to capture Windows system counters](https://github.com/fabferri/az-pattern/tree/master/win-sys-counters)
- [Azure Resource Manager API versions](https://github.com/fabferri/az-pattern/tree/master/api-ver)

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
   ms.date="29/06/2026"
   ms.author="fabferri" />