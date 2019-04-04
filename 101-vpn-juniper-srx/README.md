<properties
   pageTitle="site-to-site VPN between two Juniper vSRX in Azure"
   description="configuration of  site-to-site VPN between two Juniper vSRX in Azure"
   services=""
   documentationCenter="na"
   authors="fabferri"
   manager=""
   editor=""/>

<tags
   ms.service="Configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="na"
   ms.date="04/04/2019"
   ms.author="fabferri" />
#  Site-to-site VPN between two Juniper vSRX in Azure

The article reports the powrrshell, ARM templates and configuration file to create a site-to-site VPN between two Azure Virtual Networks (VNets). The network diagram is reported below.

[![1]][1]

The topology is based to sites:
* site1, deployed in VNet1
* site2, deployed in VNet2

The two VNets can be deployed on the same Azure regions or different Azure regions.


| powershell script | Description                    |
| :---------------- | :----------------------------- |
|  **srx1.ps1**     | - Create the full deployment of site1<br>- Create a VNet1 <br>- Create a VM named srx1, with juniper srx image <br>- Create a VM (vm2) attached to the trusted subnet of srx1 |
|  **srx1.json**   | - ARM template to create the full deployment of site2 |
|  **srx2.ps1**     | - Create the full deployment of site1<br>- Create a VNet2 <br>- Create a VM named srx2, with juniper srx image <br>- Create a VM (vm2) attached to the trusted subnet of srx2 |
|  **srx2.json**   | - ARM template to create the full deployment of site2 |
|  **Create-srx1-config.ps1**   | - script to generate the configuration of srx1 in site1<br>The script is cpied in the clipboard and in a text file "config-srx1.txt" |
|  **Create-srx2-config.ps1**   | - script to generate the configuration of srx1 in site1<br>The script is cpied in the clipboard and in a text file "config-srx2.txt" |
|  **check.txt1**   | - routing tables and connectivity check  |




> #### Note
>
> Before running the powershel scrips **Create-srx1-config.ps1**, **Create-srx2-config.ps1** check out the variables in the headers of the script.
> The values of variables need to match with the naming convention used in the **srx1.json**,**srx2.json**

<!--Image References-->

[1]: ./media/network-diagram.png "network overview"

<!--Link References-->



