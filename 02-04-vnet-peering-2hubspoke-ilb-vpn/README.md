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
   ms.date="27/07/2018"
   ms.author="fabferri" />

# Two hub-spoke VNets connected by VNet peering with load balancer in HA ports in the hub VNets
The article depicts two hub-spoke vnets in different regions interconnected by VNetpeering.
the VNet peering betwen hub VNets provides intercommunication.
In each hub vnet are present two linux VMs (nva11, nva12 in hub1 and nva21,nva21 in hub2) configured with ip forwarding. 
In each hub VNet is deployed an internal standard load balancer (ILB) configured with HA ports. The presence of ILB provides a configuration in HA on the flow in transit through the NVA VMs.
The network diagram is reported below:

[![1]][1]

The ARM template creates all the environment; the ip forwarding in nva11,nva12, nva21, nva22 needs to be enabled manually in the OS.


> [!NOTE]
>
> Before spinning up the ARM template in the file **2hubspoke.ps1** you should:
> * set the Azure subscription name
> * set the administrator username. Replace ADMINISTRATOR_USERNAME with your administrator username
> * set the administrator password. Replace ADMINISTRATOR_PASSWORD with your administrator password
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

#### <a name="installnginx"></a>3. comunication flows between VNets
Run tcpdump on the nva11,nva12, nva21, nva22 to verify the traffic transit in summetric way through the VMs

[![2]][2]
[![2]][2]


| client.sh     | nginx server  | check by tcpdump the flows in the VMs | tcpdump command|
| ------------- |:-------------:|:------------------------|:---------------------------:|
| vm1-10.0.11.10| vm2-10.0.12.10| nva11,nva12, nva21,nva22 | tcpdump -nqt host 10.0.11.10|
| vm1-10.0.11.10| vm3-10.0.3.10 | nva11,nva12              | tcpdump -nqt host 10.0.11.10|
| vm1-10.0.11.10| vm4-10.0.4.10 | nva11,nva12, nva21,nva22 | tcpdump -nqt host 10.0.11.10|
| vm2-10.0.12.10| vm3-10.0.3.10 | nva11,nva12, nva21,nva22 | tcpdump -nqt host 10.0.12.10|
| vm2-10.0.12.10| vm4-10.0.4.10 |              nva21,nva22 | tcpdump -nqt host 10.0.12.10|
| vm3-10.0.3.10 | vm4-10.0.12.10| nva11,nva12, nva21,nva22 | tcpdump -nqt host 10.0.3.10 |



<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/flow1.png "network diagram"
[3]: ./media/flow2.png "network diagram"


<!--Link References-->

