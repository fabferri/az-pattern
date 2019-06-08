<properties
pageTitle= 'ARM template to create a standard load balancer in HA ports with two frontend IPs and two backend pools'
description= "ARM template to create a standard load balancer in HA ports with two frontend IPs and two backend pools"
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
   ms.date="24/07/2018"
   ms.author="fabferri" />

# ARM template to create standard load balancer in HA ports with two frontend IPs and two backend pools
This ARM template aims to create a VNet with an internal standard load balancer in HA ports.
The standard ILB is configured with two frontend IPs and two backend pools. For resiliency, the Azure VMs associated with every backend pool have an assigned availability set.


The network diagram is reported below:

[![1]][1]

The nva1, nva2, nva3, nva4 run with linux VMs, with ip forwarding enabled. The replacement of NVAs with simple linux VMs is useful for to troubleshooting to verify the traffic flows rights through the NVAs.
Internal load balancer with frontend IPs and backend pools is show above:
[![2][2]


> [!NOTE]
> Before spinning up the ARM template you should:
> * set the Azure subscription name in the file **ilb-ha-ports-vnetpeering.ps1**
> * set the administrator username and password in the file **ilb-ha-ports-vnetpeering.json**
>


#### <a name="EnableIPForwarding"></a>1. Setup in nva1, nva2, nva3 and nva4 VMs
Enable ip forwarding:

    # sed -i -e '$a\net.ipv4.ip_forward = 1' /etc/sysctl.conf
    # systemctl restart network.service

The ARM template set two heath check probes on port 80. Install and enable apache daemon:

    # yum -y install httpd
    # systemctl enable httpd.service    (enable the httpd daemon for the next reboot)
    # systemctl restart httpd.service   (start the httpd daemon)

#### <a name="Iperf3"></a>2. Install the iperf3 in vm1, vm2, vm3 and vm4 VMs

     # yum -y install iperf3

#### <a name="Iperf3"></a>3. Checking the TCP flows transit from vm2 to vm3 and from vm3 to vm2
##### <a name="Iperf3"></a>3.1 Checking the TCP flows transit from vm2 to vm3
Based on the static routes (UDRs) set in the subnet2,subnet3,subnet4 the flows have to pass through nva1 and nva2.
TCP flows from vm2 to vm3:

    [root@vm2 ~]# iperf3 -P 80 -c 10.0.3.10 -t 60 -i 1 -f m -p 5551       (iperf client)
    [root@vm3 ~]# iperf3 -s -p 5551                                       (iperf server)

[![3]][3]

##### <a name="Iperf3"></a>3.2 Checking the TCP flows transit from vm3 to vm2
*TCP flows from vm3 to vm2:*

    [root@vm2 ~]# iperf3 -s -p 5551                                       (iperf server)
    [root@vm3 ~]# iperf3 -P 80 -c 10.0.2.10 -t 60 -i 1 -f m -p 5551       (iperf client)

[![4]][4]

The traffic in transit can be verified with tcpdump:

     [root@nva1 ~]# tcpdump -nqt -i eth0 host 10.0.2.10
     [root@nva2 ~]# tcpdump -nqt -i eth0 host 10.0.2.10
     [root@nva3 ~]# tcpdump -nqt -i eth0 host 10.0.2.10
     [root@nva4 ~]# tcpdump -nqt -i eth0 host 10.0.2.10

#### <a name="Iperf3"></a>4. Checking the TCP flows transit from vm2 to vm4 and from vm4 to vm2
##### <a name="Iperf3"></a>4.1 Checking the TCP flows transit from vm2 to vm4
*TCP flows from vm2 to vm4:*

    [root@vm2 ~]# iperf3 -P 80 -c 10.0.4.10 -t 60 -i 1 -f m -p 5551       (iperf client)
    [root@vm4 ~]# iperf3 -s -p 5551                                       (iperf server)

[![5]][5]

The traffic in transit can be verified with tcpdump:

     [root@nva1 ~]# tcpdump -nqt -i eth0 host 10.0.2.10
     [root@nva2 ~]# tcpdump -nqt -i eth0 host 10.0.2.10
     [root@nva3 ~]# tcpdump -nqt -i eth0 host 10.0.2.10
     [root@nva4 ~]# tcpdump -nqt -i eth0 host 10.0.2.10

##### <a name="Iperf3"></a>4.2 Checking the TCP flows transit from vm4 to vm2
*TCP flows from vm4 to vm2:*

    [root@vm2 ~]# iperf3 -s -p 5551                                       (iperf client)
    [root@vm4 ~]# iperf3 -P 80 -c 10.0.2.10 -t 60 -i 1 -f m -p 5551       (iperf server)

[![6]][6]



<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/ilb.png "standard internal load balancer with two FrontEnd IPs and two backend pools"
[3]: ./media/flow1.png "tcp flow transit from vm2 to vm3"
[4]: ./media/flow2.png "tcp flow transit from vm3 to vm2"
[5]: ./media/flow3.png "tcp flow transit from vm2 to vm4"
[6]: ./media/flow4.png "tcp flow transit from vm4 to vm2"


<!--Link References-->

