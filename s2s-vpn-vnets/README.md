<properties
pageTitle= 'Azure ARM template to create site-to-site VPN between VNets'
description= "Azure ARM template to create site-to-site VPN between VNets"
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
   ms.date="18/01/2020"
   ms.author="fabferri" />

# Azure ARM template to create site-to-site VPN between VNets
This post contains different ARM templates to create site-to-site VPN between Azure VNets.
The ARM templates are stored in different folders: 
* **s2s-vpn-2vpngtw-2tunnels**: contains ARM template to create site-to-site VPN between two VNets. The Azure VPN gateway are deployed in configuration active-active. The script creates two different VNets in two different Azure regions. In each gateway subnet is create a VPN Gateway. A total nuber of 2 IPSec tunnels are established between the Azure VPN Gateways. 
In each VNet is create a single Azure VM.
The network configuration is reported in the diagram:

[![1]][1]

* **s2s-vpn-3vpngtw-4tunnels**: contains ARM template to create site-to-site VPN between three VNets. The Azure VPN gateways are all deployed in configuration active-active. The script creates three different VNets in three Azure regions (specified in the ARM template as **location1, location2, location3**). In each gateway subnet is create a VPN Gateway.
   * a vpnGtw1 is created in a vnet1
   * a vpnGtw2 is created in a vnet2
   * a vpnGtw3 is created in a vnet3

Two IPSec tunnels are created between vpnGtw1-vpnGtw2 
Two IPSec tunnels are created between vpnGtw1-vpnGtw2 

The network configuration is reported in the diagram:

[![2]][2]

* **s2s-vpn-4vpngtw-6tunnels**: contains ARM template to create site-to-site VPN between four VNets. The Azure VPN gateways are all deployed in configuration active-active. The script creates three different VNets in three Azure regions (specified in the ARM template as **location1, location2, location3 and location4** ). In each gateway subnet is create a VPN Gateway.
   * a vpnGtw1 is created in a vnet1
   * a vpnGtw2 is created in a vnet2
   * a vpnGtw3 is created in a vnet3
   * a vpnGtw4 is created in a vnet4

Two IPSec tunnels are established between vpnGtw1-vpnGtw2 
Two IPSec tunnels are established between vpnGtw1-vpnGtw3 
Two IPSec tunnels are established between vpnGtw1-vpnGtw4

The network configuration is reported in the diagram:

[![3]][3]

In each folders are present the following files:
* **init.txt**: it contains a variable called "ResourceGroupName" assign the name of resource group. When the powershell script **vpn1.ps1** and **vpn2.ps1** start, the file init.txt is read the variable. 
* **vpn1.json**: ARM template to create NSGs, VNets, VPN Gateway and VMs 
* **vpn1.ps1**: powershell script to run the ARM template **vpn1.json** 
* **vpn2.json**: ARM template to create local networks and connections.
* **vpn2.ps1**: powershell script to run the ARM template **vpn2.json** 
* the resources defined in **vpn1.json** and **vpn2.json** are both deployed in the same resource group.

> [!NOTE]
>
> Before deploying the ARM template you should:
> 1. set the name of your Azure subscription in the files **vpn1.ps1** and **vpn2.ps1**
> 2. set in **vpn1.ps1**:  
>   * the administrator username in variable 
> **$adminUsername** 
>   * the administrator password in variable 
> **$adminPassword**
> 3. set the name of resouce group in the file **init.txt**
> 4. the powershell scripts **vpn1.ps1** and **vpn2.ps1** needs to be run in sequence: first run the **vpn1.ps1** and only when is completed run the second script **vpn2.ps1**

The network diagram with details related to the configuration with three VNets and three VPN gateways is reported below:

[![4]][4]

The network diagram with details related to the configuration with four VNets and four VPN Gateway is reported below:
 
[![5]][5]

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram1"
[2]: ./media/network-diagram2.png "network diagram2"
[3]: ./media/network-diagram3.png "network diagram3"
[4]: ./media/network-diagram2-details.png "network diagram2-details"
[5]: ./media/network-diagram3-details.png "network diagram3-details"
<!--Link References-->

