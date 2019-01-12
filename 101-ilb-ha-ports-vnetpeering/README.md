<properties
pageTitle= '101 Azure ARM template to create a standard load balancer in HA ports with VNet peering'
description= "Azure ARM template to create a standard load balancer in HA ports with VNet peering"
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

# Azure standard load balancer in HA ports with VNet peering
The article presents a configuration hub-spoke VNet, with an internal standard load balancer (ILB) in HA ports in the hub VNet.


The network diagram is reported below:

[![1]][1]

The UDRs applied to the subnets force the traffic to transit to the frontend IP address of the ILB.
The nva1 and nva2 run with linux VMs, with ip forwarding enabled.
The VNet peering configurations between hub-VNet and spoke-VNets are reported in the diagram shown below:

[![2]][2]

Internal load balancer in the hub VNet:
[![3]][3]


The ARM template creates all the Azure deployment.

> [!NOTE]
> Before spinning up the ARM template you should:
> * set the Azure subscription name in the file **ilb-ha-ports-vnetpeering.ps1**
> * set the administrator username and password in the file **ilb-ha-ports-vnetpeering.json**
>

After deployment of ARM template, there are few manual steps to complte the setup.

#### <a name="EnableIPForwarding"></a>1. Enable ip forwarding in nva1, nva2 VMs
Enable ip forwarding:
    # sed -i -e '$a\net.ipv4.ip_forward = 1' /etc/sysctl.conf
    # systemctl restart network.service

Check the ip forwarding:

    # sysctl net.ipv4.ip_forward

#### <a name="HTTPdaemon"></a>2. Install and enable apache daemon in nva1, nva2

    # yum -y install httpd
    # systemctl enable httpd.service    (enable the httpd daemon for the next reboot)
    # systemctl restart httpd.service   (start the httpd daemon)

A HTTP deamon is required on nva1 and nva2, because the ARM template set the heath check probe on port 80.

#### <a name="Iperf3"></a>3. Install the iperf3 in vm1, vm2, vm5, vm10

     # yum -y install iperf3

#### <a name="Iperf3"></a>4. Run iperf between vm5 (iperf client) and vm10 (iperf server)
To create multiple TCP flows from vm5 to vm10:

    [root@vm5 ~]# iperf3 -P 80 -c 10.0.10.10 -t 60 -i 1 -f m -p 5080       (iperf client)
    [root@vm10 ~]# iperf3 -s -p 5080                                       (iperf server)

the parameters **-P** determine the number of simultaneous flows.
Below the TCP flows generated with iperf, in transit through the standard load balancer.

[![4]][4]


Checking out the traffic in transit though the nva1 and nva2:

     [root@nva1 ~]# tcpdump -n -q -t -i eth0 host 10.0.10.10 > cap1.txt
     [root@nva2 ~]# tcpdump -n -q -t -i eth0 host 10.0.10.10 > cap2.txt

#### <a name="Iperf3"></a>4. Start TCP flows between vm10 and vm1

     [root@vm10 ~]# iperf3 -P 80 -c 10.0.2.10 -t 60 -i 1 -f m -p 5080
     [root@vm1 ~]# iperf3 -s -p 5080

Checking out the traffic in transit though the nva1 and nva2:

     [root@nva1 ~]# tcpdump -nqt -i eth0 host 10.0.10.10 > cap1.txt
     [root@nva2 ~]# tcpdump -nqt -i eth0 host 10.0.10.10 > cap2.txt

[![5]][5]


<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/vnet-peering.png "vnet peering"
[3]: ./media/ilb.png "Azure Internal Load Balancer-ILB"
[4]: ./media/flow1.png "tcp flow transit from vm1 to vm2"
[5]: ./media/flow2.png "tcp flow transit from vm2 to vm1"

<!--Link References-->

