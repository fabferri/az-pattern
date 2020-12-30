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
   * [create multiple VNets and VMs in different Azure regions](./00-basic-examples/02-multiple-vnets-vms)
* [Azure Load Balancer](./loadbalancer/)
   * [Standard load balancer in HA ports](./loadbalancer/ilb-ha-ports-1vnet)
   * [Standard load balancer in HA ports with VNet peering](./loadbalancer/ilb-ha-ports-vnetpeering)
   * [Standard load balancer in HA ports with two frontend IPs and two backend pools](./loadbalancer/ilb-ha-ports-2frontend-2backendpools)
   * [Standard internal load balancer with multiple frontend IPs and backend address pools](./loadbalancer/ilb-multiple-fe-be)
*  [hub-spoke VNets](./hub-spoke-vnets)
   * [Two hub-spoke VNets interconnected by global VNet peering](./hub-spoke-vnets/vnet-peering-2hubspoke)
   * [Two hub-spoke VNets connected by VNet-to-VNet with load balancer in HA ports in the hub VNets](./hub-spoke-vnets/vnet-peering-2hubspoke-ilb-vpn)
   * [Two hub-spoke VNets connected by VNet peering with load balancer in HA ports in the hub VNets](./hub-spoke-vnets/vnet-peering-2hubspoke-ilb-vpn-2)
* [IPv6](./ipv6)
   * [IPv6 in single VNet](./ipv6/ipv6-single-vnet)
   * [IPv6 in single VNet and load balancer](./ipv6/ipv6-single-vnet-lb)
   * [IPv6 with hub-spoke VNet](./ipv6/ipv6-vnet-peering)
* [VPN](./vpn)
   * [site-to-site VPN between VNets](./vpn/s2s-vpn-vnets)
   * [Site-to-site VPN between a Cisco CSR 1000v and Azure VPN Gateway](./vpn/vpn-gtw-cisco-csr)
   * [Site-to-site VPN between two Juniper vSRX in Azure](./vpn/vpn-juniper-srx)
   * [Multiple VNet-to-VNet connection with two hub VNets](./vpn/vpn-vnet-2-vnet)
* [VNet peering](./vnet-peering)
   * [VNet peering-basic](./vnet-peering/vnet-peering-basic)
   * [VNets peering between VNets in different Azure subscriptions](./vnet-peering/vnet-peering-different-subscriptions)
* [Multiple VNets and VMs in different Azure regions](./02-multiple-vnets-vms/)
* [Azure VMs with multiple NICs](./02-vms-multiple-nics-01/README.md)
* [Interconnection of two Azure hub-spoke VNets through site-to-site VPN with libreswan](./vpn-libreswan/)
* [powershell script to get the list of BGP communities in ExpressRoute Microsoft peering](./expressroute-ms-peering-bgp-community/)
* [Powershell script to capture Windows system counters](./win-sys-counters/)



