<properties
pageTitle= 'Azure ARM templates to create site-to-site VPN by FQDN'
description= "Azure ARM templates to create site-to-site VPN by FQDN"
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
   ms.date="28/01/2021"
   ms.author="fabferri" />

# Azure ARM templates to create site-to-site VPN by FQDN
This post contains two ARM templates to create site-to-site VPN between Azure VNets.

| file              | description                                                                 |       
| ----------------- |:--------------------------------------------------------------------------- |
| **vpn1.json**     | ARM template to create two VNets in two different regions with VPN Gateways |
| **vpn1.ps1**      | powershell script to deploy the ARM template **vpn1.json** |
| **vpn2.json**     | ARM template to create local networks and connections      |
| **vpn2.ps1**      | powershell script to deploy the ARM template **vpn2.json** |
| **s2s-vpn-2vpngtw-fqdn-full/vpn.json** | unique ARM template to deploy all: VPN Gateways, Local Network Gateways,Connections,VMs | 
| **s2s-vpn-2vpngtw-fqdn-full/vpn.ps1**  | powershell to deploy **s2s-vpn-2vpngtw-fqdn-full/vpn.json** | 

The network configuration is reported in the diagram:

[![1]][1]

Each Azure VPN Gateway is configured in active-active and BGP routing.

> [!NOTE]
>
> **The ARM templates require as mandatory Azure region with availability zone** 

The configuration of VPN Gateway is reported in the diagram below:

[![2]][2]

Each connection use the FQDN of public IP of the remote VPN Gateway.

> [!NOTE]
>
> Before deploying the ARM template, you should:
> 1. set the name of your Azure subscription in the files **vpn1.ps1** and **vpn2.ps1**
> 2. in **vpn1.ps1**:  
>     * the administrator username is specified in variable **$adminUsername** 
>     * the administrator password is specified in variable **$adminPassword**
> 3. The text file **init.txt** set the name of the resource group and the Azure regions of two VNets
> 4. the powershell scripts **vpn1.ps1** and **vpn2.ps1** needs to run in sequence: 
>    * 1st step: run the script **vpn1.ps1**   
>    * 2nd step: run the script **vpn2.ps1**
>

`Tag: Site-to-Site VPN` <br>
`date: 05-09-2024`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram1"
[2]: ./media/vpn-config.png "network diagram2"

<!--Link References-->

