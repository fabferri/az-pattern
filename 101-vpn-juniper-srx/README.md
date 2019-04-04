<properties
   pageTitle="site-to-site VPN between two Juniper vSRX in Azure"
   description="configuration of site-to-site VPN between two Juniper vSRX in Azure"
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

The article reports the powershell, ARM templates and configuration file to create a site-to-site VPN between two Azure Virtual Networks (VNets). The network diagram is reported below.

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
|  **Create-srx1-config.ps1**   | - script to generate the configuration of srx1 in site1<br>The script is copied in the clipboard and in a text file "config-srx1.txt" |
|  **Create-srx2-config.ps1**   | - script to generate the configuration of srx1 in site1<br>The script is copied in the clipboard and in a text file "config-srx2.txt" |
|  **check.txt1**   | - routing tables and connectivity check  |


> #### Note
>
> Before running the powershell scrips **Create-srx1-config.ps1**, **Create-srx2-config.ps1** check out the variables in the headers of the script.
> The values of variables need to match with the naming convention used in the **srx1.json**,**srx2.json**

####  NAT
The scripts **Create-srx1-config.ps1**, **Create-srx2-config.ps1** produce configurations without NAT.
The trust zone subnet can be configured to use NAT overload when sending traffic to the internet (i.e. the untrust zone).  This is a source NAT using the interface IP of the untrust zone.

on **srx1**:
```
set security nat source rule-set NAT-TRUST-TO-UNTRUST from zone trust
set security nat source rule-set NAT-TRUST-TO-UNTRUST to zone untrust
set security nat source rule-set NAT-TRUST-TO-UNTRUST rule TRUST-TO-INTERNET match source-address 10.0.2.0/24
set security nat source rule-set NAT-TRUST-TO-UNTRUST rule TRUST-TO-INTERNET match destination-address 0.0.0.0/0
set security nat source rule-set NAT-TRUST-TO-UNTRUST rule TRUST-TO-INTERNET then source-nat interface
```

on **srx2**:
```
set security nat source rule-set NAT-TRUST-TO-UNTRUST from zone trust
set security nat source rule-set NAT-TRUST-TO-UNTRUST to zone untrust
set security nat source rule-set NAT-TRUST-TO-UNTRUST rule TRUST-TO-INTERNET match source-address 10.1.2.0/24
set security nat source rule-set NAT-TRUST-TO-UNTRUST rule TRUST-TO-INTERNET match destination-address 0.0.0.0/0
set security nat source rule-set NAT-TRUST-TO-UNTRUST rule TRUST-TO-INTERNET then source-nat interface
```

As our existing security policy permits access from the trust zone to the untrust zone, this configuration is complete.

There is a way to verify the configuration:

* login in the srx1
* ssh from srx1 to the vm1
* from vm1 ping a public IP (i.e. 8.8.8.8)
* in another ssh sesession with srx1, run the command:


srx1# **run show security flow session nat source-prefix 10.0.2.0/24**

Session ID: 35, Policy name: default-permit/5, Timeout: 2, Valid

  In: 10.0.2.20/7 --> 8.8.8.8/3111;icmp, Conn Tag: 0x0, If: ge-0/0/1.0, Pkts: 1, Bytes: 84,
  Out: 8.8.8.8/3111 --> 10.0.1.10/18693;icmp, Conn Tag: 0x0, If: ge-0/0/0.0, Pkts: 1, Bytes: 84,

Session ID: 36, Policy name: default-permit/5, Timeout: 2, Valid

  In: 10.0.2.20/8 --> 8.8.8.8/3111;icmp, Conn Tag: 0x0, If: ge-0/0/1.0, Pkts: 1, Bytes: 84,
  Out: 8.8.8.8/3111 --> 10.0.1.10/17377;icmp, Conn Tag: 0x0, If: ge-0/0/0.0, Pkts: 1, Bytes: 84,

Session ID: 37, Policy name: default-permit/5, Timeout: 4, Valid
  
  In: **10.0.2.20**/9 --> 8.8.8.8/3111;icmp, Conn Tag: 0x0, If: ge-0/0/1.0, Pkts: 1, Bytes: 84,
  Out: 8.8.8.8/3111 --> **10.0.1.10**/31989;icmp, Conn Tag: 0x0, If: ge-0/0/0.0, Pkts: 1, Bytes: 84,

Total sessions: 3

The SRX output shows two flows for NAT. The "**In**" flow, which is how the packet is structured as the flow comes from the trust zone to the untrust zone. Then the "**Out**" flow, which is how the return flow looks. To read the output, you need to read the two lines as two separate flows. The highlighted IP addresses just help identify the translation.



<!--Image References-->

[1]: ./media/network-diagram.png "network overview"

<!--Link References-->



