<properties
pageTitle= 'ARM template to create two hub-spoke VNets connected by VNet peering'
description= "Two hub-spoke VNets connected by VNet pering with Azure load balancer in HA ports in the hub VNets"
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
   ms.date="27/07/2019"
   ms.author="fabferri" />

# Two hub-spoke VNets connected by VNet peering with load balancer in HA ports in the hub VNets
The article depicts two hub-spoke vnets in different regions interconnected by VNets in peering.
* In each hub vnet are present two linux VMs (nva11, nva12 in hub1 and nva21,nva21 in hub2) configured with ip forwarding. 
* In each hub VNet is deployed an internal standard load balancer (ILB) configured with HA ports. The presence of ILB provides a configuration in HA on the flow in transit through the NVA VMs.

The network diagram is reported below:

[![1]][1]

The ARM template creates all the environment; the ip forwarding in nva11,nva12, nva21, nva22 needs to be enabled manually in the OS.


> [!NOTE]
>
> Before spinning up the ARM template you should:
> * set the Azure subscription name in the file **2hubspoke-ilb.ps1**
> * set the administrator username and password in the file **2hubspoke-ilb.ps1**
>


#### <a name="EnableIPForwarding"></a>1. Enable ip forwarding in nva11, nva12, nva21, nva22
In nva11, nva12, nva21, nva22:

```
sed -i -e '$a\net.ipv4.ip_forward = 1' /etc/sysctl.conf
systemctl restart network.service
sysctl net.ipv4.ip_forward
```

#### <a name="EnableHTTPdaemon"></a>2. Install and enable httpd daemon in nva11, nva12, nva21, nva22
The Azure internal load balancers (ilb1 and ilb2) require the presence of custom port on the VMs in the backend pool to make healtcheck. In our ATM template the probes have been defined to TCP port 80. httpd needs to be installed and activated on the nva11, nva12, nva21, nva22:

```
yum -y install httpd
systemctl enable httpd
systemctl start httpd
systemctl status httpd
```

#### <a name="UDR"></a>3.UDRs applied to the subnets

[![3]][3]

#### <a name="installnginx"></a>3. comunication flows between VNets
Run tcpdump on the nva11,nva12, nva21, nva22 to verify the traffic transit in symmetric way through the VMs

[![4]][4]


<!--Image References-->

[1]: ./media/network-diagram-overview.png "network diagram: overview"
[2]: ./media/network-diagram.png "network diagram"
[3]: ./media/udr.png "User Defined Routes"
[4]: ./media/flows1.png "flows"

<!--Link References-->

