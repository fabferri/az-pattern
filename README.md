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
List of Azure ARM templates and scripts:
* [Basic examples](./00-basic-examples)
   * [How to generate traffic between two Azure VMs](./00-basic-examples/00-traffic-between-2vms)
   * [Azure VMs with custom script extension](./00-basic-examples/00-vm-script-extension)
   * [Communication between Azure VMs through an IP forwarder](./00-basic-examples/01-ip-forwarding)
   * [Create multiple VNets and VMs in different Azure regions](./00-basic-examples/02-multiple-vnets-vms)
* [ExpressRoute](./expressroute/)
   * [VNet with ExpressRoute gateway](./expressroute/er-gw)
   * [Two Azure VNets connected to an ExpressRoute circuit](./expressroute/er-circuit-2vnets)
   * [BGP communities in ExpressRoute Microsoft peering](./expressroute/er-ms-peering-bgp-community)
   * [Azure management portal across ExpressRoute Microsoft peering](./expressroute/er-ms-peering-azure-mng-portal)
* [Azure Load Balancer](./loadbalancer/)
   * [Standard load balancer in HA ports](./loadbalancer/ilb-ha-ports-1vnet)
   * [Standard load balancer in HA ports with VNet peering](./loadbalancer/ilb-ha-ports-vnetpeering)
   * [Standard load balancer in HA ports with two frontend IPs and two backend pools](./loadbalancer/ilb-ha-ports-2frontend-2backendpools)
   * [Standard internal load balancer with multiple frontend IPs and backend address pools](./loadbalancer/ilb-multiple-fe-be)
*  [hub-spoke VNets](./hub-spoke-vnets)
   * [Two hub-spoke VNets interconnected by global VNet peering](./hub-spoke-vnets/vnet-peering-2hubspoke)
   * [Two hub-spoke VNets connected by VNet-to-VNet with load balancer in HA ports in the hub VNets](./hub-spoke-vnets/vnet-peering-2hubspoke-ilb-vpn)
   * [Two hub-spoke VNets connected by VNet peering with load balancer in HA ports in the hub VNets](./hub-spoke-vnets/vnet-peering-2hubspoke-ilb-vpn-2)
   * [Configuration hub-spoke with large number of spoke vnets](./hub-spoke-vnets/hubspoke-high-number-spokes)
* [Route Server](./route-server)
   * [Azure route server in BGP peering with quagga](./route-server/basic-rs-with-quagga)
   * [dual-homed network with Azure Route Server and ExpressRoute](./route-server/rs-dualhome-2er-circuits)
   * [dual-homed network with Azure Route Server and site-to-site VPNs](./route-server/rs-dualhome-s2s-vpn)
* [private link and private endpoint](./private-link-and-private-endpoint)
   * [private endpoints Azure SQL Db and Storage](./private-link-and-private-endpoint/private-endpoint-sql-storage)
   * [private endpoints Storage](./private-link-and-private-endpoint/private-endpoint-storage-powershell)
   * [private service link](./private-link-and-private-endpoint/private-link-1)
* [IPv6](./ipv6)
   * [IPv6 in single VNet](./ipv6/ipv6-single-vnet)
   * [IPv6 in single VNet and load balancer](./ipv6/ipv6-single-vnet-lb)
   * [IPv6 with hub-spoke VNet](./ipv6/ipv6-vnet-peering)
* [VPN](./vpn)
   * [site-to-site VPN between VNets](./vpn/s2s-vpn-vnets)
   * [Site-to-site VPN between a Cisco CSR 1000v and Azure VPN Gateway](./vpn/vpn-gtw-cisco-csr)
   * [Site-to-site VPN between two Juniper vSRX in Azure](./vpn/vpn-juniper-srx)
   * [Multiple VNet-to-VNet connection with two hub VNets](./vpn/vpn-vnet-2-vnet)
   * [Interconnection of two Azure hub-spoke VNets through site-to-site VPN with libreswan](./vpn/vpn-libreswan/)
* [VNet peering](./vnet-peering)
   * [VNet peering-basic](./vnet-peering/vnet-peering-basic)
   * [VNets peering between VNets in different Azure subscriptions](./vnet-peering/vnet-peering-different-subscriptions)
* [service tag in UDR](./service-tag-udr)
* [Deploy an ARM template in a PowerShell runbook](./automation)
* [Azure VMs with multiple NICs](./02-vms-multiple-nics-01/README.md)
* [Powershell script to capture Windows system counters](./win-sys-counters/)



