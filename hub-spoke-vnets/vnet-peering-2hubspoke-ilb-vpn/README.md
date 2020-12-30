<properties
pageTitle= 'ARM template to create two hub-spoke VNets connected by VNet-to-VNet'
description= "Two hub-spoke VNets connected by VNet-to-VNet with load balancer in HA ports in the hub VNets"
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

# Two hub-spoke VNets connected by VNet-to-VNet with load balancer in HA ports in the hub vnets
The article describes two hub-spoke vnets in two different regions with VNet-to-VNet interconnection.
A vnet-to-vnet interconnection provides an encrypted IPsec communication between the two hub vnets.
In each hub vnet are present two linux VMs (nva11, nva12 in hub1 and nva21,nva21 in hub2) configured with ip forwarding. 
In each hub VNet is deployed an internal standard load balancer (ILB) configured with HA ports. The presence of ILB provides a configuration in HA on the flow in transit through the NVA VMs.
The network diagram is reported below:

[![1]][1]

The ARM template creates all the environment; the ip forwarding in nva11,nva12, nva21, nva22 needs to be enabled manually in the OS.


> [!NOTE]
>
> Before spinning up the ARM template you should:
> * set the Azure subscription name in the file **2hubspoke.ps1**
> * set the administrator username and password in the file **2hubspoke.json**
>


#### <a name="EnableIPForwarding"></a>1. Enable ip forwarding in nva11, nva12, nva21, nva22

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

#### <a name="installnginx"></a>3. Install nginx on vm1, vm2, vm3, vm4
In CentOS VMs nginx is available in EPEL repository:

```
yum install epel-release
yum -y install nginx
systemctl enable nginx
systemctl start nginx
systemctl status nginx
curl 127.0.0.1
```

#### <a name="installGNUparallel"></a>4. Install GNU parallel in vm1, vm2, vm3, vm4
To run HTTP queries in parallel, it can be used GNU parallel. In CentOS GNU parallel is in EPEL repository:

```
yum -y install parallel
```
In Annex is reported the procedure to increase the total number of open files in the OS (optional step).

#### <a name="bashScritForHTTP"></a>5. Write a bash script in vm1, vm2, vm3, vm4 to run HTTP queries in parallel
vi client.sh

```
vi client.sh
#!/bin/bash
#redirect stdout to the device /dev/null
mycurl() {
    START=$(date +%s)
    curl -s "http://some_url_here/"$1  1>/dev/null
    END=$(date +%s)
    DIFF=$(( $END - $START ))
    echo "It took $DIFF seconds"
}
export -f mycurl
seq 100000 | parallel -j0 mycurl
```


#### <a name="iperf3"></a>6. Generate traffic between vm1, vm2, vm3, vm4

| client.sh     | nginx server  | check by tcpdump the flows in the VMs | tcpdump command|
| ------------- |:-------------:|:------------------------|:---------------------------:|
| vm1-10.0.11.10| vm2-10.0.12.10| nva11,nva12, nva21,nva22 | tcpdump -nqt host 10.0.11.10|
| vm1-10.0.11.10| vm3-10.0.3.10 | nva11,nva12              | tcpdump -nqt host 10.0.11.10|
| vm1-10.0.11.10| vm4-10.0.4.10 | nva11,nva12, nva21,nva22 | tcpdump -nqt host 10.0.11.10|
| vm2-10.0.12.10| vm3-10.0.3.10 | nva11,nva12, nva21,nva22 | tcpdump -nqt host 10.0.12.10|
| vm2-10.0.12.10| vm4-10.0.4.10 |              nva21,nva22 | tcpdump -nqt host 10.0.12.10|
| vm3-10.0.3.10 | vm4-10.0.12.10| nva11,nva12, nva21,nva22 | tcpdump -nqt host 10.0.3.10 |

#### <a name="trafficTransit"></a>7. Example of flows transit between VMs in different VNets
Path from vm3 to vm4:

[![2]][2]

Path from vm1 to vm2:

[![3]][3]

#### <a name="installGNUparallel"></a>ANNEX. Increase the number of simultaneous open files in vm1, vm2, vm3, vm4
This is optional configuration (you can skip it if you do not have interest to increase the system parameters).
CentOS has a limit on max number of simultaneously open file:

```
ulimit -Hn
4096
```
Show max file:
```
cat /proc/sys/fs/file-max
88766
```
Change the limit vi **/etc/sysctl.conf** :
```
fs.file-max = 200500
```
increase hard and soft limits **vi /etc/security/limits.conf**:
```
* soft nproc 65535
* hard nproc 65535
* soft nofile 65535
* hard nofile 65535
```
check files under **/etc/security/limits.d**:
```
cd /etc/security/limits.d
cat 20-nproc.conf
```
content of file **20-nproc.conf**:
```
# Default limit for number of user's processes to prevent
# accidental fork bombs.
# See rhbz #432903 for reasoning.
*          soft    nproc     unlimited
root       soft    nproc     unlimited
```
run the command:
```
sysctl -p
```
the command shows the new value: **fs.file-max = 200500**

Logout and then relogin in the system to get the new values.

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/flow1.png "network diagram"
[3]: ./media/flow2.png "network diagram"


<!--Link References-->

