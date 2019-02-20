<properties
pageTitle= 'ARM template to create a standard load balancer in HA ports with two NVA pools'
description= "ARM template to create a standard load balancer in HA ports with two frontend IPs and two backend pools and two NVA pools"
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
   ms.date="20/02/2019"
   ms.author="fabferri" />

# Standard load balancer in HA ports with two NVA pools
This ARM template aims to create a  VNet with an internal standard load balancer (ILB) in HA ports to create a configuration with NVAs in high avaiability.  
For resiliency, the Azure VMs associated with every backend pool have an assigned availability set.


The network diagram is reported below:

[![1]][1]

The nva1, nva2, nva3, nva4 run with linux VMs, with ip forwarding enabled. The replacement of NVAs with simple linux VMs is useful for to troubleshooting to verify the traffic flows rights through the NVAs.
Internal load balancer with frontend IPs and backend pools is show above:

[![2][2]


> [!NOTE]
>
> * Before spinning up the ARM template you should set the Azure subscription name in the file **ilb-ha.ps1**
>* Deploy the ARM template by following powershell command: 
> 
>**ilb-ha.ps1 -adminUsername _YOUR_ADMIN_USERNAME_ -adminPassword _YOUR_ADMIN_PASSWORD_**
>


#### <a name="EnableIPForwarding"></a>1. Setup in nva1, nva2, nva3 and nva4 VMs
Enable ip forwarding on nva1, nva2, nva3, nva4:

```bash
    # sed -i -e '$a\net.ipv4.ip_forward = 1' /etc/sysctl.conf
    # systemctl restart network.service
```

The ARM template set two heath check probes on port 80. Install and enable apache daemon on nva1, nva2, nva3, nva4:

```bash
    # yum -y install httpd
    # systemctl enable httpd.service    (enable the httpd daemon for the next reboot)
    # systemctl restart httpd.service   (start the httpd daemon)
```

#### <a name="Iperf3"></a>2. Install the iperf3 in vm3, vm4, vm5 and vm4

```bash
     # yum -y install iperf3
```


#### <a name="Iperf3"></a>3.1 Checking the TCP flows transit between vm3 and vm4

To generate the TCP flows from vm3 to vm4:

```bash
    [root@vm3 ~]# iperf3 -P 80 -c 10.0.3.10 -t 60 -i 1 -f m -p 6001       (iperf client)
    [root@vm4 ~]# iperf3 -s -p 6001                                       (iperf server)
```

Based on the static routes (UDRs) set in the subnet3,subnet4 the following flows transit are established:

**vm3 -> FrontEndIP1 -> nva1 (OR nva2) -> FrontEndIP2 -> nva3 (or nva4) -> vm4**


[![3]][3]


**vm4 -> FrontEndIP2 -> nva3 (OR nva4) -> FrontEndIP1 -> nva1 (or nva2) -> vm3**

[![4]][4]

The traffic in transit in NVAs can be verified with tcpdump:

```bash
     tcpdump -nn -qt -i eth0 port 6001
```

#### <a name="Iperf3"></a>3.2 Checking the TCP flows transit between vm3 and vm5

**vm3 -> FrontEndIP1 -> nva1 (OR nva2) -> FrontEndIP2 -> nva3 (or nva4) -> vm5**
[![5]][5]

**vm5 -> FrontEndIP2 -> nva1 (OR nva2) -> FrontEndIP2 -> nva3 (or nva4) -> vm3**
[![6]][6]


#### <a name="Iperf3"></a>3.3 Checking the TCP flows transit between vm4 and vm5

**vm4 -> FrontEndIP2 -> nva3 (OR nva4) -> vm5**
[![7]][7]

**vm5 -> FrontEndIP2 -> nva3 (OR nva4) -> vm4**
[![8]][8]



<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/ilb.png "standard internal load balancer with two FrontEnd IPs and two backend pools"
[3]: ./media/flow-vnet3-2-vnet4.png "tcp flow transit from vm3 to vm4"
[4]: ./media/flow-vnet4-2-vnet3.png "tcp flow transit from vm4 to vm3"
[5]: ./media/flow-vnet3-2-vnet5.png "tcp flow transit from vm3 to vm5"
[6]: ./media/flow-vnet5-2-vnet3.png "tcp flow transit from vm5 to vm3"
[7]: ./media/flow-vnet4-2-vnet5.png "tcp flow transit from vm4 to vm5"
[8]: ./media/flow-vnet5-2-vnet4.png "tcp flow transit from vm5 to vm4"


<!--Link References-->

