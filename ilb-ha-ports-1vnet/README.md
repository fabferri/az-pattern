<properties
pageTitle= 'Azure ARM template to create a standard load balancer in HA ports'
description= "Azure standard load balancer in HA ports"
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
   ms.date="20/07/2018"
   ms.author="fabferri" />

# How-to create Azure standard load balancer in HA ports
This ARM template aims to create one VNet with an internal standard load balancer in HA ports.
The network diagram is reported below:

[![1]][1]

> [!NOTE1]
> Before spinning up the ARM template you should:
> * set the Azure subscription name in the file **ilb-ha-ports.ps1**
> * set the administrator username and password in the file **ilb-ha-ports.ps1**
>

### Enable ip forwarding in nva1, nva2 VMs
In the CentOS VMs permanent ip forwarding can be enabled by command:

```bash
# sed -i -e '$a\net.ipv4.ip_forward = 1' /etc/sysctl.conf
# systemctl restart network.service
```

Check the ip forwarding by command:

```bash
# sysctl  net.ipv4.ip_forward
```

### Install and enable apache daemon in nva1, nva2
Health probe of the load balancer is set on the HTTP. A daemon is required to answer to HTTP request to check the status of nva1 and nva2. Load balacer will forward the traffic to the nva1 and nva2 only if they answer to HTTP requests.

``` bash
# yum -y install httpd
# systemctl enable httpd.service    (enable the httpd daemon)
# systemctl restart httpd.service   (start the httpd daemon)
```
### Install the iperf3 in vm1 and vm2

```bash
# yum -y install
```

### Run iperf client in vm1 and iperf server in vm3
To create multiple tcp flows from vm1 to vm2:

```bash
[root@vm1 ~]# iperf3 -P 80 -c 10.0.3.10 -t 60 -i 1 -f m -p 5020
[root@vm2 ~]# iperf3 -s -p 5020
```

the parameters **-P** determine the number of simultaneous flows.
Below the TCP flows generated with iperf, in transit through the standard load balancer.

[![2]][2]

[![3]][3]

The UDR set in the subnet2 and subnet 2 forces the traffic to pass through the frontend IP of the standard load balancer.

### How to check the traffic in transit though the nva1 and nva2
tcpdump helps to check the traffic balancing between nva1 and nva2.
Run the iperf commands in vm1 and vm2, and get the tcp captures in nva1 and nva2:

```bash
[root@nva1 ~]# tcpdump -n -i eth0 -q -t host 10.0.3.10 > cap1.txt
[root@nva2 ~]# tcpdump -n -i eth0 -q -t host 10.0.3.10 > cap2.txt
```

You need to trigger the event where the TCP sessions will be slit up between nva1 and nva2.
When capture file on nva1 and nva2 are both not empty, use the grep command to check the source port of the TCP flows.
A TCP flow passes through the same nva.

To verify a specific TCP flow is served only by a single nva:
- open one of cap file (i.e. cap1.txt),
- take note of one source port associated with the iperf client (10.0.2.10)
- run a search for the specific source port in cap1.txt and cap2.txt

The TCP flow with a specific source port should be mutually exclusive in nva1 or nva2.

```bash
[root@nva1 ~]# grep "34720" cap1.txt
[root@nva2 ~]# grep "34720" cap2.txt
```

> [!NOTE]
> iperf is a good tool to generate traffic on custom port. 
> One other simple option to generate multiple flows on HTTP port is through the command
> **curl -s "http://10.0.3.10?[1-10000]"**
>

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/flow1.png "tcp flow transit from vm1 to vm2"
[3]: ./media/flow2.png "tcp flow transit from vm2 to vm1"

<!--Link References-->

