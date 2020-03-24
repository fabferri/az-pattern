<properties
pageTitle= 'Traffic generation between two Azure VMs'
description= "Traffic generation between two Azure Virtual Machines"
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
   ms.date="18/08/2018"
   ms.author="fabferri" />

## Traffic generation between two Azure VMs

Traffic generation between Azure VMs is common in testing process.
The article shows few methods to generate traffic between two Azure VMs, vm1 and vm2, connected to the the same Azure subnet. The methods to generate traffic can be used between private and/or public IPs.

[![1]][1]



> [!NOTE]
> Before spinning up the ARM template you should edit the file **vms.ps1** and set:
> * your Azure subscription name in the variable **$subscriptionName**
> * the administrator username and password of the Azure VMs in the variables **$adminUsername**, **$adminPassword**
>



#### <a name="iperf3"></a>1. Linux and Windows VMs: iperf3
Iperf3 works in Linux and Windows (see: [iperf3](https://iperf.fr/))
Install iperf3 in Linux vm1 and vm2:

```bash
yum -y iperf3
yum -y iperf3
```

To run iperf3 as server in vm2:

```bash
iperf3 -s -p 6001
```

where -p specifices the listening TCP port

To run iperf3 as client in vm2:

```bash
iperf3 -c 10.0.2.10 -P 20 -p 6001 -i 1 -f M
```
where:
-P: _total number of simultaneos TCP flows_
-p: _TCP port_
-M: _formatting the output in Mbps_

#### <a name="netcat"></a>2. Linux VMs: netcat and urandom

In Linux VMs traffic can be generated  by **netcat** and **urandom** (the random number function in the linux kernel).

Install netcat (nc) in vm1 and vm2:

```bash
yum -y install nmap-ncat
yum -y install nmap-ncat
```
Write down two bash scripts: one for the server _(traffic receiver)_ and one for the client _(traffic sender)_.

file in vm1: **server.sh**

```bash
#!/bin/bash
#
val=true
while [ $val ]
do
 nc -l -p 9000 > /dev/null 2>&1
 wait
done
```
file in vm2: **client.sh**

```bash
#!/bin/bash
#
for i in {1..10};
do
  dd if=/dev/urandom bs=1M count=100 | nc 10.0.2.10 9000
  sleep 2
done
```
To send traffic from vm2 to vm1 run:

```bash
[root@vm1 ~]# ./server.sh
[root@vm2 ~]# ./client.sh
```

By tcpdump check the traffic:

```bash
[root@vm1 ~]# tcpdump -nqttt -i eth0 host 10.0.1.10 and host 10.0.1.20
```

To monitor the volume of traffic on vm1 and vm2 we can use a tool like **nload**:

```bash
yum install epel-release
yum -y install nload
```
##### <a name="ApacheBench"></a>4.3 How generate HTTP traffic by Apache Bench tool

Apache Bench tool is used to do simple load testing. Apache Bench is contained in the **httpd-tools** package.

```bash
yum install httpd-tools
ab -n 500 -c 20 10.0.1.10
```
where:
n: _total number of requests_
c: _number of concurrent requests_


##### <a name="curl"></a>4.4 generate HTTP traffic by curl
Run the bash command:

```bash
for i in `seq 1 20`; do curl http://10.0.2.10; done
```

##### <a name="curl"></a>4.4 generate HTTP traffic by curl and parallel
To run HTTP queries in parallel, it can be used GNU parallel. In CentOS GNU parallel is in EPEL repository:

```bash
yum install epel-release
yum -y install parallel
```

vi client.sh

```bash
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
Replace the _"some_url_here"_ with the IP address of web server.
-s option is for silent or quiet mode.

Same command with easier option :
```bash
 seq 5000 | parallel -n0 -j5 curl http://10.0.1.10/
```
do it 5000 times, but at 5 a time


##### <a name="HTTPpowershell"></a>4.5 generate HTTP traffic by powershell script

```powershell
$ipServer="10.0.2.10:80"

$url = "http://$ipServer"
while ($true) {
try {
  [net.httpWebRequest]
  $req = [net.webRequest]::create($url)
  $req.method = "GET"
  $req.ContentType = "application/x-www-form-urlencoded"
  $req.TimeOut = 60000

  $start = get-date
  [net.httpWebResponse] $res = $req.getResponse()
  $timetaken = ((get-date) - $start).TotalMilliseconds

  Write-Output $res.Content
  Write-Output ("{0} {1} {2}" -f (get-date), $res.StatusCode.value__, $timetaken)
  $req = $null
  $res.Close()
  $res = $null
} catch [Exception] {
Write-Output ("{0} {1}" -f (get-date), $_.ToString())
}
$req = $null

# uncomment the line below and change the wait time to add a pause between requests
#Start-Sleep -Seconds 1
}
```


### <a name="ANNEX"></a>ANNEX

#### <a name="iftop"></a>1. Bandwidth counters
Traffic counters in the VMs we can track by a tool like iftop

```bash
#yum -y install libpcap libpcap-devel ncurses ncurses-devel
#yum -y install epel-release
#yum -y install  iftop
```

#### <a name="EnableApacheWeb"></a>2. Install and enable apache httpd daemon
Install Apache:

```bash
yum -y install httpd
systemctl enable httpd
systemctl start httpd
systemctl status httpd
curl 27.0.0.1
```

#### <a name="installnginx"></a>3. Install and enable nginx
In CentOS nginx is available in EPEL repository:

```bash
yum install epel-release
yum -y install nginx
systemctl enable nginx
systemctl start nginx
systemctl status nginx
curl 127.0.0.1
```


<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"

<!--Link References-->

