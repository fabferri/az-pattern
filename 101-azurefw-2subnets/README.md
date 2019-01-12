<properties
pageTitle= 'Configuration with Azure firewall'
description= "ARM template to deploy a basic configuration with Azure firewall in single VNet"
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

## A VNet with Azure firewall

The article describes a configuration with Azure firewall in single VNet; the network diagram is reported below.

[![1]][1]

The Azure deployment can be done by ARM template. The ARM template: 
* creates a virtual network with 3 subnets: jumpboxSubnet, AzureFirewallSubnet and serverSubnet 
* a jumpbox VM with public IP
* an Azure firewall with a static public IP address
* a server VM with only a private IP
* two UDRs, one applied to the jumpboxSubnet and one to the ServerSubnet, to force the traffic to passthrough the Azure Firewall

> [!NOTE]
> 
> In the .ps1 script replace the value of variable **$subscriptionName** with the name of your Azure subscription ID.
> 
> Run the deployed by powershell:
> 
> .\azfw.ps1 -adminUsername ADMIN_USERNAME -adminPassword ADMIN_PASSWORD
> 
> where:
> ADMIN_USERNAME: it is the administrator username of the Azure VMs
> ADMIN_PASSWORD: it is the administrator password of the Azure VMs
> 

In the next paragraphs are discused by diagrams the security policy rules assicated to the Azure firewall.

#### <a name="iperf3"></a>1. **ApplicationRulesCollection** in Azure firewall to allow outbound traffic
In Azure firewall the application rules provide a meachnims FQDN based,to control outbound network access from an Azure subnets to external networks.
In our setup the **applicationRuleCollections** contain the rules to enable to the VMs in the subnets to access in HTTP and HTTPS to any web site out of the VNet (internet).
A snipet of **applicationRuleCollections** defined in teh ARM template is reported below:

```console
"applicationRuleCollections": [
   {
     ...
     ...
     "action": {"type": "Allow" },
     "rules": [
        {
           "name": "appRule-HTTP-HTTPS",
           "protocols": [
               {
                  "port": "80", "protocolType": "http"
               },
               {
                  "port": "443", "protocolType": "https"
               }
           ],
           "targetFqdns": ["*"]
        }
     ]
]
````

[![2]][2]

#### <a name="iperf3"></a>2. Network Rule Collections in Azure firewall to control the traffic between ServerSubnet and JumpboxSubnet
Network rule is mechanism in Azure firewall to control access between networks. The filtering cirteria in network rule is based on source address, protocol, destination port, and destination address.
In the deployment, the network rules are configured to enable the communication between the **ServersSubnet** and **JumpboxSubnet** only for specific TCP ports:[22,80,6000-6999].

```console
"networkRuleCollections": [
   ...
   ...
  "action":  { "type":  "Allow"},
  "rules": [
    {
      "name": "netRule1",
      "protocols": ["TCP"],
      "sourceAddresses": ["10.0.0.0/24"],
      "destinationAddresses": ["10.0.2.0/24"],
      "destinationPorts": ["22","80","6000-6999" ]
   },
   {
      "name": "netRule2",
      "protocols": ["TCP"],
      "sourceAddresses": ["10.0.2.0/24"],
      "destinationAddresses": ["10.0.0.0/24"],
      "destinationPorts": ["22","80","6000-6999"]
   }
  ]
]
```
[![3]][3]


[![4]][4]

By iperf3 check out the behaviour with TCP traffic on custom port 4001; the traffic doesn't pass through the firewall, becasue the port 4001 is out of allowed range: ["22","80","6000-6999"].

[![5]][5]

#### <a name="iperf3"></a>3. NAT Rule Collections in Azure firewall to accept incoming traffic from internet
Inbound connectivity can be enabled by configuring Destination Network Address Translation (DNAT).
In the deployment the DNAT rules enable incoming SSH connection through the public IP of the firewall. Two DNAT rules are define to reach out the Server and jubmbox VMs. A snipet of ARM template and a diagram clarify how work the DNAT rules.

```json
"natRuleCollections":[
  ...
  ...
 "action": {
    "type":  "Dnat"},
    "rules":[
       {
          "name": "Rule-ssh-jumpbox",
          "sourceAddresses": ["*"],
          "destinationAddresses": ["104.45.188.130"],
          "destinationPorts": ["5000"],
          "protocols": [ "TCP"],
          "translatedAddress": "10.0.0.5",
          "translatedPort": "22"
       },
       {
          "name": "Rule-ssh-server",
          "sourceAddresses": ["*"],
          "destinationAddresses": ["[104.45.188.130"],
          "destinationPorts": ["5001"],
          "protocols": [ "TCP"],
          "translatedAddress": "10.0.2.5",
          "translatedPort": "22"
      }
    ]
 }
]
```


[![6]][6]

The diagram below shows the DNAT for incoming SSH connection through the public IP of the firewall on custom port 5000.
The Azure firewall map the incoming TCP traffic with destination port 5000 into destination port 22. The traffic is routed to the jumpbox.

[![7]][7]

The diagram below shows the DNAT for incoming SSH connection through the public IP of the firewall on custom port 5001.
The Azure firewall change the incoming TCP traffic with destination port 5001 into destination port 22. The traffic is routed to the  server.

[![8]][8]

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/application-rules.png "application rules collection in Azure firewall"
[3]: ./media/network-rules1.png "network rules collection in Azure firewall"
[4]: ./media/network-rules2.png "network rules collection in Azure firewall"
[5]: ./media/network-rules-deny.png "network rules collection in Azure firewall"
[6]: ./media/dnat-rules.png "NAT rules collection in Azure firewall"
[7]: ./media/dnat1.png "NAT rules collection in Azure firewall"
[8]: ./media/dnat2.png "NAT rules collection in Azure firewall"
<!--Link References-->

