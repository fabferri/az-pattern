<properties
pageTitle= 'IPv6 in Azure Virtual Network'
description= "IPv6 in Azure Virtual Network with ARM template"
services=""
documentationCenter="na"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="english"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="IPv6"
   ms.date="11/12/2019"
   ms.author="fabferri" />

## Example of Azure Virtual Network deployment with IPv6 by ARM templates

The article talks through a deployment of Azure VNet with IPv6, deployed by ARM template. An overview of network diagram is shown below.

[![1]][1]

The configuration is based on:
* single Azure Virtual Network **vnet1** with IPv4 10.0.0.0/24 and IPv6 ``abc:abc:abc::/48`` address space
* in the VNet are configured three subnets **subnet1, subnet2, subnet3**, each with IPv4 and IPv6 networks
* all the VMs run un dual stack IPv4 and IPv6
* **vm1** is a Windows VM attached to the **subnet1**. By Azure powershell script extension, IIS is installed in the VM.
* **vm2** is a Windows VM attached to the **subnet2**. By Azure powershell script extension, IIS is installed in the VM.
* **nva** is a CentOS VM attached to the **subnet3**. By Azure custom script extension the VM is configured with IPv6 forwarding
* **RT-subnet1** is a UDR applied to the **subnet1**
* **RT-subnet2** is a UDR applied to the **subnet2**
* By UDRs **RT-subnet1, RT-subnet2** the IPv6 traffic between **vm1** and **vm2** is forced to transit through the **nva**
* a NSG-network security group is to each subnet to filter the IPv6 traffic in ingress and egress from/to the VMs
* **nsg1** is the network security group applied to the **subnet1**
* **nsg2** is the network security group applied to the **subnet2**
* **nsg3** is the network security group applied to the **subnet3**
* **vm5** is a standalone Azure VM, deployed in different VNet, and it is used only to generate traffic to the public IPv6 of VMs in **vnet1**  

A network diagram with IPv6 UDRs is shown underneath:

[![2]][2]

The ARM template assigns static IPv4 and IPv6 addresses to the VMs:

| *VM*       | *private IPv4*            | *private IPv6*                 |
| :--------- | :------------------------ |:------------------------------ |
| **vm1**    | **10.0.0.10 (static IP)** | ``abc:abc:abc:abc1::a`` (static)   |
| **vm2**    | **10.0.0.40 (static IP)** | ``abc:abc:abc:abc2::a`` (static)   |
| **nva**    | **10.0.0.80 (static IP)** | ``abc:abc:abc:abc3::a`` (Static)   |
| **vm5**    | **10.5.0.10 (static IP)** | ``ace:ace:ace:ace::a``  (static)   |

In the UDR **RT-subnet1** only a single IPv6 route is required:
* the destination network is the IPv6 network ``abc:abc:abc:abc2::/64`` assigned to the subnet2
* the next-hop IP  is the static IPv6 address ``abc:abc:abc:abc3::a`` of the nva

In the UDR **RT-subnet2**, only a single IPv6 route is required:
* the destination network is the IPv6 network ``abc:abc:abc:abc1::/64`` assigned to the subnet1
* the next-hop IP is the static IPv6 address ``abc:abc:abc:abc3::a`` of the nva


List of scripts:
* **01-ipv6.ps1**: powershell script to run the ARM template **ipv6.json**. Tou can run the script by command:
  ipv6.ps1 -adminUsername <USERNAME_ADMINISTRATOR_VMs> -adminPassword <PASSWORD_ADMINISTRATOR_VMs>
  or set the username and password inside the script
* **02-single-vm.ps1**: powershell script to run the ARM template **single-vm.json**
* **get-ips.ps1**: powershell script to grab the list of private and public IPv4 and IPv6 associated with the VMs deployed in a specific reosurce group 

List of ARM templates:
* **ipv6.json**: ARM template to deploy all the objects in **vnet1**
* **single-vm.json**: ARM templat eto deploye the standalone **vm5**


**NOTE1**
The full deployment needs to be done in two steps: 
* step1: run the powershell **01-ipv6.ps1**
* step2: at the end of step 1,  you can run the powershell **02-single-vm.ps1**


**NOTE2**
Before running the step2, check inside the ARM template the variable: **"resourceGrpPublicIP6PrefixesRange"** 
the variable needs to be set with the resource group name created in the step1
 

**ipv6.json** use "Public IP Prefix" to allocate a block of 8 consecutive public IPv6 addresses. 
This block of consecutive public IPs are asigned to the **vm1**,**vm2**,**nva**,**vm5**, 
 
[![3]][3]


#### <a name="IPv6"></a>Check the traffic through the public IPv6
From **vm5** make http queries to the vm1 and catch the traffic by tcpdump:

[![4]][4]

* by web browser: **http://[vm1-pubIPv6]**
* by curl command: **curl -g -6 "http://[vm1-pubIPv6]/"**



#### <a name="IPv6"></a>Check the traffic in transit through the nva
From **vm1**  send http queries to the web server in **vm2** and run tcpdump in **nva** to capture the traffic in transit through:

[![5]][5]


* by web browser in vm1: **http://[``abc:abc:abc:abc2::a``]**
* by curl command in vm1: **curl -g -6 "http://[``abc:abc:abc:abc2::a``]/"**


<!--Image References-->

[1]: ./media/network-diagram.png "network overview"
[2]: ./media/udr.png "network diagram with UDR"
[3]: ./media/public-ip-prefix.png "public ip prefix"
[4]: ./media/traffic-public-ip.png "traffic through public IPv6"
[5]: ./media/traffic-private-ip.png "traffic through private IPv6"

<!--Link References-->

