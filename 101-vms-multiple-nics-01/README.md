<properties
pageTitle= '101 ARM template to deploy multiple VMs with multiple NICs'
description= "simple ARM template to deploy multiple VMs with multiple NICs"
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
   ms.date="17/07/2018"
   ms.author="fabferri" />

# Configuration Azure VMs with multiple NICs
This ARM template allows to you to create a deployment with multiple Azure VMs, with multiple NICs, in single Azure VNet.

The network configuration is reported in the diagram:

[![1]][1]

The ARM template set UDRs in every subnet to force the traffic to transit in the Azure vm1.

* **vm1**: linux VM with three NICs.
   * The role of this VM is to simulate an NVA; ip fowarding need to be enabled in the CentOS.
   * vm1 doesn't have public IP; you can login to the vm1 by jump in vm3

* **vm2**: linux VM with two NICs.
   * primary NIC1 is attached to the subnet2.
   * secondary NIC is attached to the subnet1. The traffic with destination address tjat do not belong to subnet2 and subnet3 is sent out through the NIC1.
   * vm2 doesn't have public IP; you can login to the vm1 by jump in vm3

* **vm3**: it works as jumpbox to reach out the VMs vm1 and vm2.

* **vm4**: it is attached to the subnet1. Traffic flows from/to vm4 transit through vm1.

If you change the address space assign to the Azure subnets, you have to change in consistent way the static IP assigned to the VMs otherwise the script will fail.

Before deploying the ARM template you should:
* set the Azure subscription name in the file **vms-multiple-nics.ps1**
* set the username and password in the file **vms-multiple-nics.json**


## Enable ip forwarding in vm1
vm1 simulates an NVA; the ip forwarding needs to be enable in the Linux VM.

Make the change on-the fly: **# sysctl -w net.ipv4.ip_forward=1**

To make the change permanent:
* edit the file **/etc/sysctl.conf** and add the line: **net.ipv4.ip_forward = 1**
* restart the network: **# systemctl restart network.service**


## Routing tables in vm1 and vm2
In the vm1, the traffic to 0.0.0.0/0 is forward to the eth0:

    [root@vm1 ~]# route -n
    Kernel IP routing table
    Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
    0.0.0.0         10.0.1.1        0.0.0.0         UG    0      0        0 eth0
    10.0.1.0        0.0.0.0         255.255.255.0   U     0      0        0 eth0
    10.0.2.0        0.0.0.0         255.255.255.0   U     100    0        0 eth1
    10.0.3.0        0.0.0.0         255.255.255.0   U     100    0        0 eth2
    168.63.129.16   10.0.1.1        255.255.255.255 UGH   0      0        0 eth0
    169.254.0.0     0.0.0.0         255.255.0.0     U     1002   0        0 eth0
    169.254.169.254 10.0.1.1        255.255.255.255 UGH   0      0        0 eth0


In the vm2, the traffic to 0.0.0.0/0 is forward to the eth0:

    [root@vm2 ~]# route -n
    Kernel IP routing table
    Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
    0.0.0.0         10.0.2.1        0.0.0.0         UG    0      0        0 eth0
    10.0.2.0        0.0.0.0         255.255.255.0   U     0      0        0 eth0
    10.0.3.0        0.0.0.0         255.255.255.0   U     100    0        0 eth1
    168.63.129.16   10.0.2.1        255.255.255.255 UGH   0      0        0 eth0
    169.254.0.0     0.0.0.0         255.255.0.0     U     1002   0        0 eth0
    169.254.169.254 10.0.2.1        255.255.255.255 UGH   0      0        0 eth0


## Checking the traffic path
The traffic path in transit through vm1 can be verified using tcpdump:

**vm2 ping vm4**

    [root@vm2 ~]# ping 10.0.1.10
    PING 10.0.1.10 (10.0.1.10) 56(84) bytes of data.
    64 bytes from 10.0.1.10: icmp_seq=1 ttl=63 time=1.40 ms
    64 bytes from 10.0.1.10: icmp_seq=2 ttl=63 time=1.28 ms
    ...


**tcpdump in vm1**

    [root@vm1 ~]# tcpdump -n -i eth0 icmp
    11:00:05.774976 IP 10.0.2.10 > 10.0.1.10: ICMP echo request, id 36398, seq 1, length 64
    11:00:05.775647 IP 10.0.1.10 > 10.0.2.10: ICMP echo reply, id 36398, seq 1, length 64
    11:00:06.776172 IP 10.0.2.10 > 10.0.1.10: ICMP echo request, id 36398, seq 2, length 64
    ...


    [root@vm1 ~]# tcpdump -n -i eth1 icmp
    11:20:19.990946 IP 10.0.2.10 > 10.0.1.10: ICMP echo request, id 37159, seq 1, length 64
    11:20:19.991884 IP 10.0.1.10 > 10.0.2.10: ICMP echo reply, id 37159, seq 1, length 64
    11:20:20.992908 IP 10.0.2.10 > 10.0.1.10: ICMP echo request, id 37159, seq 2, length 64
    11:20:20.993516 IP 10.0.1.10 > 10.0.2.10: ICMP echo reply, id 37159, seq 2, length 64
    ...

tcpdump gives a proof that traffic is symmetric (follow the same path in both directions):

**vm2(eth0)-> [vm1(eth1) ->vm1(eth0)] -> vm4(eth0)**
**vm4(eth0)-> [vm1(eth0) ->vm1(eth1)] -> vm2(eth0)**


[![2]][2]


## Set a static route in vm2
By default the linux routing table in vm2 sends the traffic to 0.0.0.0/0 out of the interface eth0.
Let's set a static route to force the traffic to the destination network 10.0.1.0/24 in egress from eth1:

    [root@vm2 ~]# route add -net 10.0.1.0 netmask 255.255.255.0 gw 10.0.3.1 dev eth1

    [root@vm2 ~]# route -n
    Kernel IP routing table
    Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
    0.0.0.0         10.0.2.1        0.0.0.0         UG    0      0        0 eth0
    10.0.1.0        10.0.3.1        255.255.255.0   UG    0      0        0 eth1
    10.0.2.0        0.0.0.0         255.255.255.0   U     0      0        0 eth0
    10.0.3.0        0.0.0.0         255.255.255.0   U     100    0        0 eth1
    168.63.129.16   10.0.2.1        255.255.255.255 UGH   0      0        0 eth0
    169.254.0.0     0.0.0.0         255.255.0.0     U     1002   0        0 eth0
    169.254.169.254 10.0.2.1        255.255.255.255 UGH   0      0        0 eth0

Let's ping the ip address of the vm4:

    [root@vm2 ~]# ping 10.0.1.10
    PING 10.0.1.10 (10.0.1.10) 56(84) bytes of data.
    64 bytes from 10.0.1.10: icmp_seq=1 ttl=63 time=1.39 ms
    64 bytes from 10.0.1.10: icmp_seq=2 ttl=63 time=1.63 ms


The traffic through passthrough the interface eth2 of vm1:

    [root@vm1 ~]# tcpdump -n -i eth2 icmp
    tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
    listening on eth2, link-type EN10MB (Ethernet), capture size 262144 bytes
    11:56:15.116697 IP 10.0.3.10 > 10.0.1.10: ICMP echo request, id 38490, seq 1, length 64
    11:56:15.117380 IP 10.0.1.10 > 10.0.3.10: ICMP echo reply, id 38490, seq 1, length 64
    11:56:16.118289 IP 10.0.3.10 > 10.0.1.10: ICMP echo request, id 38490, seq 2, length 64
    11:56:16.119110 IP 10.0.1.10 > 10.0.3.10: ICMP echo reply, id 38490, seq 2, length 64


The ping command in vm2 sends out packets with the source IP 10.0.3.10 of the egress interface eth1.

[![3]][3]

The traffic from vm4 (10.0.1.10) to the vm2- eth1 (10.0.3.10) flows correctly in both directions.
the traffic from vm4 to vm2-eth0 doesn't flow right anymore.

[![4]][4]

This is due to the static route set inside the vm2.

Two different possibile alternative paths can be established between the vm2 and vm4:

* *case 1*: static route with egress interface **eth0** of the vm2 (or default)

	**[root@vm2 ~]# route add -net 10.0.1.0 netmask 255.255.255.0 gw 10.0.2.1 dev eth0**

    The traffic in egress for the destination 10.0.1.0/24 is routed through the eth1 of the vm1.


* *case 2*: static route with egress interface **eth1** of the vm2

    **[root@vm2 ~]# route add -net 10.0.1.0 netmask 255.255.255.0 gw 10.0.3.1 dev eth1**

    The traffic in egress for the destination 10.0.1.0/24 is routed through the eth2 of the vm1.

[![5]][5]

[![6]][6]

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/flow1.png "traffic flows"
[3]: ./media/flow2.png "traffic flows"
[4]: ./media/flow3.png "traffic flows"
[5]: ./media/flow4.png "traffic flows"
[6]: ./media/flow5.png "traffic flows"

<!--Link References-->

