<properties
pageTitle= 'Configuration with Azure firewall Basic SKU'
description= "Configuration with Azure firewall Basic SKU"
documentationcenter: na
services=""
documentationCenter="na"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="na"
   ms.date="11/01/2019"
   ms.author="fabferri" />

## Configuration with Azure firewall basic SKU

The article describes a configuration with Azure firewall in single VNet; the network diagram is reported below.

[![1]][1]

The Azure deployment can be done by ARM template. The ARM template: 
* creates a virtual network vnet1
* the Azure firewall Basic SKU
* two Azure VMs **vmapp1** and **vmapp2** attached to different subnets. **vmapp1** and **vmapp2** are deployed without public IP
* Azure Bastion allows login to the **vmapp1** and **vmapp2** 
* the traffic between the two VMs pass through the Azure firewall
* two UDRs are applied to **subnetApp1** and **subnetApp2** to force the traffic to passthrough the Azure firewall 
* a default route (0.0.0.0/0) is present in the UDRs to breakout in internet through the Azure firewall
* the firewall applies DNAT policy to accept inbound connections:
   * the TCP traffic inbound on destination port 8091 is translated in port 80; the traffic can reach out the **vmapp1**
   * the TCP traffic inbound on destination port 8092 is translated in port 80; the traffic can reach out the **vmapp2** 



### <a name="inter-vnets"></a>1. **intercommunication between VMs with transit through the azure firewall**
Network rule is mechanism in Azure firewall to control access between networks. The filtering criteria in network rule is based on source address, protocol, destination port, and destination address. In the deployment, the network rules are configured to enable the communication between **subnetApp1** and **subnetApp2** on any protocol

[![2]][2]

### <a name="inbound traffic"></a>2. **inbound DNAT traffic**
Inbound connectivity can be enabled by Destination Network Address Translation (DNAT). In the deployment the DNAT rules enable incoming HTTP connection on port 8091 and 8092 through the public IP of the firewall.

[![3]][3]

**DNAT translation:**
[![4]][4]

### <a name="breakout in internet"></a>3. **ApplicationRulesCollection in Azure firewall to allow outbound traffic**
In Azure firewall the application rules provide a mechanism FQDN based, to control outbound network access from an Azure subnets to external networks. In our setup the **applicationRuleCollections** contain the rules to enable to the VMs in the subnets to access in HTTP and HTTPS to selected web sites in internet.

[![5]][5]

`Tags: azure firewall` <br>
`date: 04-11-22`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/communication-vnets.png "communication between VNets with transit through the Azure firewall"
[3]: ./media/dnat1.png "network rules collection in Azure firewall"
[4]: ./media/dnat2.png "network rules collection in Azure firewall"
[5]: ./media/application-rules.png "application rules to allow breakout in internet on HTTP and HTTPS"

<!--Link References-->

