<properties
pageTitle= 'Generate IP traffic between two Azure VMs'
description= "Generate IP traffic between two Azure Virtual Machines"
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
   ms.date="27/11/2018"
   ms.author="fabferri" />

## Generate IP traffic between two Azure VMs

In testing process is common to use software to generate traffic between Azure VMs.
The article shows few methods to generate traffic between two Azure VMs, with hostname vm1 and vm2, connected to the the same Azure subnet. The methods can be extended in more complex configurations, with the only requirement of IP reachability between the VMs.

[![1]][1]



> [!NOTE]
> Before spinning up the ARM template you should:
> * edit the file **vms.json** and set your Azure subscription name
> * edit the file **vms.json** and set the administrator username and password of the Azure VMs
>



#### <a name="iperf3"></a>1. iperf3 (Linux and Windows)
[iperf3](https://iperf.fr/) works in Linux and Windows.
To install iperf3 in Linux vm1 and vm2:

```console
[root@vm1 ~]# yum -y iperf3
[root@vm2 ~]# yum -y iperf3
```

To run iperf3 as server in vm2:

```console
[root@vm1 ~]# iperf3 -s -p 6001
```

where **-p** specifices the listening TCP port (default port is TCP 5201).

To run iperf3 as client in vm2:

```console
[root@vm2 ~]# iperf3 -c 10.0.2.10 -P 20 -p 6001 -i 1 -f M
```

where:

    -c: IP Address of the iperf3 server
    -P: total number of simultaneos TCP flows
    -p: TCP port on server
    -M: formatting the output in Mbps

#### <a name="netcat"></a>2. netcat and urandom (Linux)

Traffic can be generated in Linux VMs by **netcat** and **urandom** (the random number function in the linux kernel).

Install netcat (nc) in vm1 and vm2:

```console
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
  dd if=/dev/urandom bs=2M count=100 | nc 10.0.2.10 9000
  sleep 2
done
```
The command creates a file of size **_count*bs_** bytes, which in the above case will be 200Mb.

To send traffic from **vm2** to **vm1** run:

```console
[root@vm1 ~]# ./server.sh
[root@vm2 ~]# ./client.sh
```

By tcpdump check the traffic:

```console
[root@vm1 ~]# tcpdump -nqttt -i eth0 host 10.0.1.10 and host 10.0.1.20
```

To monitor the volume of traffic on vm1 and vm2 we can use a tool like **nload**:

```console
yum install epel-release
yum -y install nload
```

#### <a name="ApacheBench"></a>3. Generate HTTP traffic

Install on both VMs apache httpd deamon or nginx (see annex).

##### <a name="ApacheBench"></a>3.1 How generate HTTP traffic by Apache Bench tool

Apache Bench tool can be used to do simple load testing. Apache Bench is contained in the **httpd-tools** package.

```console
yum install httpd-tools
ab -n 500 -c 20 10.0.1.10
```
where:
n: _total number of requests_
c: _number of concurrent requests_


##### <a name="curl"></a>3.2 generate HTTP traffic by curl
Run the bash command:

```bash
for i in `seq 1 20`; do curl http://10.0.2.10; done
```

##### <a name="curl"></a>3.3 Generate HTTP traffic by curl and parallel
GNU parallel is a great tool to run HTTP queries in parallel. In CentOS GNU parallel is in EPEL repository:

```console
yum -y install epel-release
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
Before running the script, replace the _"some_url_here"_ with the IP address of web server.



##### <a name="HTTPpowershell"></a>3.5 generate HTTP traffic by powershell

```powershell
$ipServer="10.0.1.10:80"

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
#### <a name="EnableWebServer"></a>1. Install and enable apache httpd daemon
Install Apache:

```console
yum -y install httpd
systemctl enable httpd
systemctl start httpd
systemctl status httpd
curl 27.0.0.1
```

#### <a name="installnginx"></a>2. Install and enable nginx
In CentOS, nginx is available in EPEL repository:

```console
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

