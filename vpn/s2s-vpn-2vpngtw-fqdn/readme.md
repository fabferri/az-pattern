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

| file          | description   |       
| ------------- |:-------------:|
| **vpn1.json**     |ARM template to create two VNets in two different regions with VPN Gateways |
| **vpn1.ps1**      | powershell script to deploy the ARM template **vpn1.json**|
| **vpn2.json**     |ARM template to create local networks and connections |
| **vpn2.ps1**      | powershell script to deploy the ARM template **vpn2.json**|


The network configuration is reported in the diagram:

[![1]][1]

Each Azure VPN Gateway is configured in active-active.

> **NOTE**
>
> **The ARM templates requires as mandatory Azure region with avaiablity zone** 

The configuration of VPN Gateway is reported in the diagram below:

[![2]][2]

Each connctions use FQDN of public IP of remove VPN Gateway.

> **NOTE**
>
> Before deploying the ARM template you should:
> 1. set the name of your Azure subscription in the files **vpn1.ps1** and **vpn2.ps1**
> 2. in **vpn1.ps1**:  
>     * the administrator username is specified in variable 
> **$adminUsername** 
>     * the administrator password is specified in variable 
> **$adminPassword**
> 3. The text file **init.txt** set the name of the resource group and the Azure regions of two VNets
> 4. the powershell scripts **vpn1.ps1** and **vpn2.ps1** needs to be run in sequence: first run the **vpn1.ps1** and only when is completed run the second script **vpn2.ps1**



<!--Image References-->

[1]: ./media/network-diagram.png "network diagram1"
[2]: ./media/vpn-config.png "network diagram2"

<!--Link References-->

