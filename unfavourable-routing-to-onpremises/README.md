<properties
pageTitle= 'Azure VNet traffic with transit through on-premises network'
description= "Azure VNet traffic with transit through an on-premises network"
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
   ms.date="21/05/2010"
   ms.author="fabferri" />

# Azure VNet traffic with transit through on-premises network

The article walks through an inexpedient network configuration doesn't follow the best practices. Some customers want to controll traffic between Azure VMs, forcing the traffic to transit through a device (firewall/proxy firewall) on-premises. 
The network diagram reports a network diagram showing the communication betwween two VMs, VM1 and VM2, connected to the same Azure VNet:

[![1]][1]

The configuration doesn't follow the best pratice, due to following limitations:
* _higher latency_: hairpinning traffic, Azure VNet-> On-premisies-> Azure VNet, has longer path and increase latency between Azure VMs
* _complex configuration_: for the presence of 4 devices, two NVAs in Azure and two VPN concentrators on-premises
* _complex governance_: any VNet configuration change, i.e. add/remove subnets or add/remove VNet in peering, requires a change in routing in VPN device1 and NVA2
* a failure of single IPSec tunnel casue out of service in the communication between Azure VMs
* _higher cost_: due to additional NVA and VPN device 

A recommended approach, to avoid inefficiency and complexity, is to inspect traffic between Azure VMs through a firewall (i.e. Azure firewall or NVAs) in the Azure VNet.

[![2]][2]

Regardless of **inadvisable architecture**, the article brings you in the configuration details.


## <a name="NetworkDiagram"></a>1. Network Diagram
The implementation network diagram is shown below:

[![3]][3]

The network diagram shows two sites, both running in Azure: 
* left site named **siteA**, implemented through the **vnet1**
* right site named **siteB**, implemented through the **vnet2**. The **sideB** is a simulation of on-premisies network.

* The NVAs run with Cisco CSR1000v. Each NVA has two interfaces: 
   * GigabitEthernet1 is the external untrusted interface with associated a public IP
   * GigabitEthernet2 is the internal trusted interface
* The Azure VMs run with CentOS 7.7
* the communication between siteA and siteB is established by two different site-to-site VPN tunnels:
   * an IPSec tunnel between csr11-siteA and csr12-siteB
   * an IPSec tunnel between csr12-siteA and csr22-siteB 

A more precise diagram is reported below:

[![4]][4]

The diagram includes:
* IP addresses of **vti1** (Virtual Tunnel Interface), loopback interfaces (**lo0**)
* network address space 10.0.1/24 assigned to the vnet1 (siteA)
* network address space 10.0.2/24 assigned to the vnet2 (siteB)
* network prefixes assigned to the subnets
* UDRs associated with the vnet1-subnet4, vnet1-subnet5, vnet2-subnet2, vnet2-subnet3
* static routes in csr12, csr21, vm2


## <a name="filesdescription"></a>2. Steps to build the environment

|file                           |	description                                     |	
| ----------------------------- |:------------------------------------------------|
|**init.json**                  |	json file with all paramenters                  |	
|**siteA.json**                 |	ARM template to deploy siteA                    |	
|**siteB.json**                 |	ARM template to deploy siteB 	                  |
|**siteA.ps1**                  |	powershell script to run siteA.json	            |
|**siteB.ps1**                  |	powershell script to run siteB.json		          |
|**csr11-generate-config.ps1**  |	powershell script to generate the configuration for csr11	|
|**csr12-generate-config.ps1**  |	powershell script to generate the configuration for csr12	|
|**csr21-generate-config.ps1**  |	powershell script to generate the configuration for csr21	|
|**csr22-generate-config.ps1**  |	powershell script to generate the configuration for csr22	|
|**get-csr-images.ps1**         |	powershell script to check the available csr images in Azure marketplace	|

The sequence of actions to make the deployment:
1. fill out the parameters in **init.json**
2. run **siteA.ps1** and **siteB.ps1**
3. run **csr11-generate-config.ps1, csr12-generate-config.ps1, csr21-generate-config.ps1, csr22-generate-config.ps1**
3. connect to the **csr11** and in router config mode of the csr11, paste the content of the file **csr11-IOSXE-cfg.txt**
4. connect to the **csr12** and in router config mode of the csr12, paste the content of the file **csr12-IOSXE-cfg.txt**
5. connect to the **csr21** and in router config mode of the csr21, paste the content of the file **csr21-IOSXE-cfg.txt**
6. connect to the **csr22** and in router config mode of the csr22, paste the content of the file **csr22-IOSXE-cfg.txt**


The file **init.json** has the following structure:
```json
{
 "siteA":{
   "subscriptionName": "AzureDemo",
   "adminUsername": "YOUR_ADMINISTRATOR_USERNAME",
   "adminPassword": "YOUR_ADMINISTRATOR_PASSWORD",
   "rgName": "siteA",
   "location":"eastus",
   "csr1_vmName":"csr11",
   "csr2_vmName":"csr12"
 },
 "siteB":{
   "subscriptionName": "AzureDemo",
   "adminUsername": "YOUR_ADMINISTRATOR_USERNAME",
   "adminPassword": "YOUR_ADMINISTRATOR_PASSWORD",
   "rgName": "siteB",
   "location":"eastus",
   "csr1_vmName":"csr21",
   "csr2_vmName":"csr22"
 }
}
```
Every powershell at starting point, read the file **init.json** to grap all the parameters.
The structure of **init.json** is self-descriptive:
* "subscriptionName": name of the Azure subscription
* "adminUsername": administrator username of CSRs and VMs in a specific site
* "adminPassword":  administrator passsword of CSRs and VMs in a specific site
* "rgName": resource group 
* "location": Azure region
* "csr1_vmName": name of the fist csr in a specific site
* "csr2_vmName": name of second csr in specific site

> [**NOTE**]
> Before spinning up the **siteA.ps1** and **siteB.ps1**, check the correct values in **init.json**
>

The scripts files **csr11-generate-config.ps1, csr12-generate-config.ps1, csr21-generate-config.ps1, csr22-generate-config.ps1** have to run <ins>only after finishing</ins> the deployment of siteA and siteB. Each of those files collects the values from **init.json** and creates a text file with the configuration of csr:
* **csr11-generate-config.ps1**, generates in output the file **csr11-IOSXE-cfg.txt** with the configuration of csr11
* **csr12-generate-config.ps1**, generates in output the file **csr12-IOSXE-cfg.txt** with the configuration of csr12
* **csr21-generate-config.ps1**, generates in output the file **csr21-IOSXE-cfg.txt** with the configuration of csr21
* **csr22-generate-config.ps1**, generates in output the file **csr22-IOSXE-cfg.txt** with the configuration of csr22

The full process to create the full environment is reported below:

[![5]][5]

## <a name="checkNIC"></a>3. Check the enable IP forwarding in the NICs of all CSRs and in the vm2

By Azure management portal, check out the IP forwarding flag in the configuration of NICs of all NVAs (csr11,csr12,csr21,csr22):

[![6]][6]

The setup will work only if the IP forwarding is <ins>enabled</ins>.

## <a name="checkIPSec"></a>4. Check IPSec tunnels and routing in CSRs
When the configuration of NVAs (csr11,csr12,csr21,csr22) are completed, you can login in each csr to check the status of IPSec tunnel:
```console
router# show crypto session
```
The status of session should be in ACTIVE state. if the IPSec tunnel is up, you can check the status of BGP:
```console
router# show ip bgp
router# show ip route
```

## <a name="configureSecondInterface"></a>5. Configure the second ethernet interface in vm2 and set static routes

In **/etc/sysconfig/network-scripts/** create a file named **ifcfg-eth1** to control the paramenter on eth1 interface:
```bash
vi /etc/sysconfig/network-scripts/ifcfg-eth1
```
paste in the file **ifcfg-eth1** the content:
```console
DEVICE=eth1
ONBOOT=yes
BOOTPROTO=dhcp
TYPE=Ethernet
USERCTL=no
IPV6INIT=no
NM_CONTROLLED=yes
PERSISTENT_DHCLIENT=yes
```
Restart the network by command **systemctl restart network**

The status of the interfaces managed by Network Manager:
```
[root@vm2 ~]# nmcli dev status
DEVICE  TYPE      STATE      CONNECTION
eth0    ethernet  connected  System eth0
eth1    ethernet  connected  System eth1
lo      loopback  unmanaged  --

[root@vm2 ~]# nmcli con show
NAME         UUID                                  TYPE      DEVICE
System eth0  5fb06bd0-0bb0-7ffb-45f1-d6edd65f3e03  ethernet  eth0
System eth1  9c92fad9-6ecb-3e6c-eb4d-8a47c6f50c04  ethernet  eth1
```

In vm2 are required two static routes to forward the traffic from eth0 to eth1.

Create a new file **/etc/sysconfig/network-scripts/route-eth1** with following content:
```bash
echo '10.0.1.96/27 via 10.0.2.65  dev eth1' >> /etc/sysconfig/network-scripts/route-eth1
echo '10.0.1.128/27 via 10.0.2.65 dev eth1' >> /etc/sysconfig/network-scripts/route-eth1
```
In vm2, restart the network:
```console
systemctl restart network
```

Verify the routing table:
```console
[root@vm2 ~]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         10.0.2.33       0.0.0.0         UG    100    0        0 eth0
10.0.1.96       10.0.2.65       255.255.255.224 UG    101    0        0 eth1
10.0.1.128      10.0.2.65       255.255.255.224 UG    101    0        0 eth1
10.0.2.32       0.0.0.0         255.255.255.224 U     100    0        0 eth0
10.0.2.64       0.0.0.0         255.255.255.224 U     101    0        0 eth1
168.63.129.16   10.0.2.33       255.255.255.255 UGH   100    0        0 eth0
169.254.169.254 10.0.2.33       255.255.255.255 UGH   100    0        0 eth0
```
The networks  10.0.1.96/27,10.0.1.128/27 are forwarded toward eth1.

## <a name="checkIPSec"></a>6. Set IP forwarding and Reverse Path filtering in vm2

The Linux **vm2** in **siteB** must work as router.
To enable a temporary IP forwarding, not persistent to the VM reboot:

```bash
sysctl -w net.ipv4.ip_forward=1
sysctl net.ipv4.ip_forward
```

To set a persistent IP forwarding:
```bash
sed -i -e '$a\net.ipv4.ip_forward = 1' /etc/sysctl.conf
systemctl restart network.service
sysctl net.ipv4.ip_forward
```

Following the linux [kernel documentation](https://www.kernel.org/doc/Documentation/networking/ip-sysctl.txt) the Reverse Path filtering:


**rp_filter** - INTEGER

   **0** - No source validation.
   
   **1** - Strict mode as defined in RFC3704 Strict Reverse Path.
    Each incoming packet is tested against the FIB and if the interface is not the best reverse path the packet check will fail. By default failed packets are discarded.
   
   **2** - Loose mode as defined in RFC3704 Loose Reverse Path.
    Each incoming packet's source address is also tested against the FIB and if the source address is not reachable via any interface the packet check will fail.

Current recommended practice in RFC3704 is to enable strict mode to prevent IP spoofing from DDos attacks. If using asymmetric routing or other complicated routing, then loose mode is recommended.

The max value from conf/{all,interface}/rp_filter is used when doing source validation on the {interface}.

Reverse Path filtering can be temporary changed by:
```bash
sysctl -w net.ipv4.conf.all.rp_filter=2
sysctl -w net.ipv4.conf.eth0.rp_filter=2
sysctl -w net.ipv4.conf.eth1.rp_filter=2
````

To set the Reverse Path Forwarding, make changes permanent across a reboot:

```bash
echo 2 >  /proc/sys/net/ipv4/conf/all/rp_filter
echo 2 >  /proc/sys/net/ipv4/conf/eth0/rp_filter
echo 2 >  /proc/sys/net/ipv4/conf/eth1/rp_filter
````
> [**NOTE**]
> as reported in the linux kernel documentation the first command:
>
> **echo 2 >  /proc/sys/net/ipv4/conf/all/rp_filter**
>
> is enough to set the reverse path filtering to lose mode.
>

## <a name="csr-capture"></a>7. Troubleshootig
You might need to make troubleshooting to fix the issue(s). 
The best approach is proceeding by steps:

**1. SiteA**. Check out the consistency of UDRs applied to the _subnet4_ and _subnet5_ of siteA:

   _subnet4_:
   |Address Prefix   |	Next hop     |	
   | --------------- |:--------------|
   |10.0.1.96/27     |	10.0.1.50    |	
  

   _subnet5_:
   |Address Prefix   |	Next hop     |	
   | --------------- |:--------------|
   |10.0.1.96/27     |	10.0.1.50    |	
   

**2. siteA**. In csr11 verify the ipsec tunnel is up and active; ping the remote loopback (172.16.1.2) of csr21:

```console
csr11#show crypto session
Crypto session current status

Interface: Tunnel0
Profile: az-PROFILE1
Session status: UP-ACTIVE
Peer: 13.82.71.50 port 4500
  Session ID: 1
  IKEv2 SA: local 10.0.1.10/4500 remote 13.82.71.50/4500 Active
  IPSEC FLOW: permit ip 0.0.0.0/0.0.0.0 0.0.0.0/0.0.0.0
        Active SAs: 2, origin: crypto map

csr11#ping 172.16.1.2 source 172.16.1.1
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 172.16.1.2, timeout is 2 seconds:
Packet sent with a source address of 172.16.1.1
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 4/5/8 ms
```

**3. siteA**. In the csr11 verify the bgp routing table:

```console
csr11#show ip bgp
BGP table version is 4, local router ID is 172.16.1.1
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.0.1.96/27     172.16.1.2               0             0 65002 i
 *>   10.0.1.128/27    172.16.1.2               0             0 65002 i
 *>   10.0.2.0/27      172.16.1.2               0             0 65002 i
```
The csr11 receives via eBGP the networks [10.0.1.96/27, 10.0.1.128/27] from csr21. The ASN 65002 is associated to the csr21.

**4. siteB**. In csr22 verify the ipsec tunnel is up and active;  ping the remote loopback (172.16.1.1) and remote vti (192.168.0.1) of csr12: 

```console
csr22#show  crypto session
Crypto session current status

Interface: Tunnel0
Profile: az-PROFILE1
Session status: UP-ACTIVE
Peer: 40.117.213.221 port 4500
  Session ID: 1
  IKEv2 SA: local 10.0.2.11/4500 remote 40.117.213.221/4500 Active
  IPSEC FLOW: permit ip 0.0.0.0/0.0.0.0 0.0.0.0/0.0.0.0
        Active SAs: 2, origin: crypto map

csr22#ping 172.16.1.1 source 172.16.1.2
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 172.16.1.1, timeout is 2 seconds:
Packet sent with a source address of 172.16.1.2
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 4/4/6 ms
```

**5. siteB**. In the csr22 verify the bgp routing table:
```console
csr22#show ip bgp
BGP table version is 3, local router ID is 172.16.1.2
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.0.1.96/27     172.16.1.1               0             0 65001 i
 *>   10.0.1.128/27    172.16.1.1               0             0 65001 i
```

The csr22 receives via eBGP the networks [10.0.1.96/27, 10.0.1.128/27] from csr12. The ASN 65001 is associated to the csr12.

**6. siteB**. Through the Azure management protal check out the consistency of UDRs applied to the _subnet2_ and _subnet3_ of siteB:

   _subnet2_:
   |Address Prefix   |	Next hop     |	
   | --------------- |:--------------|
   |10.0.1.96/27     |	10.0.2.60    |	
   |10.0.1.128/27    |	10.0.2.60    |	

   _subnet3_:
   |Address Prefix   |	Next hop     |	
   | --------------- |:--------------|
   |10.0.1.96/27     |	10.0.2.90    |	
   |10.0.1.128/27    |	10.0.2.90    |	

**7.** From vm14 ping vm15 and verify that packets pass through the interface eth0 and eth1 of the vm2. In the vm2 run the following commands to pick up the traffic in  through the two NICs:

```bash
tcpdump -i eth0 host 10.0.1.100
tcpdump -i eth1 host 10.0.1.100
```
Packet capture in csr22 provides a good checkpoint. If the icmp packets send from vm14 to vm15 reach out the GigabitEthernet2 interface of csr22, you will be able to see a capture as reported below:

```console
csr22#show monitor capture CAP buffer brief
 ----------------------------------------------------------------------------
 #   size   timestamp     source             destination      dscp    protocol
 ----------------------------------------------------------------------------
   0   98    0.000000   10.0.1.100       ->  10.0.1.140       0  BE   ICMP
   1   98    0.008987   10.0.1.140       ->  10.0.1.100       0  BE   ICMP
   2   98    1.002990   10.0.1.100       ->  10.0.1.140       0  BE   ICMP
   3   98    1.013000   10.0.1.140       ->  10.0.1.100       0  BE   ICMP
   4   98    2.000992   10.0.1.100       ->  10.0.1.140       0  BE   ICMP
   5   98    2.011001   10.0.1.140       ->  10.0.1.100       0  BE   ICMP
   6   98    3.005996   10.0.1.100       ->  10.0.1.140       0  BE   ICMP
   7   98    3.013000   10.0.1.140       ->  10.0.1.100       0  BE   ICMP
  
```
For more informaton on how to activate the capture in Cisco CSR see the annex.

## <a name="csr-capture"></a>8. Annex: how to packets in transit through a Cisco CSR 
IOS XE command to capture the traffic through an interface:

```console
! capture the traffic in egress and ingres from the interface
monitor capture CAP interface GigabitEthernet2 both

! capure any traffic
monitor capture CAP match any      

! start the capture
monitor capture CAP start

! stop the capture
monitor capture CAP stop

! show the content of the capture buffer
show monitor capture CAP buffer brief

! show the content of capture buffer
show monitor capture CAP buffer detailed 

! delete the capture buffer
monitor capture CAP clear

! disable the capture
no monitor capture CAP
```
For more details on packet capture in cisco router, see the official [cisco documentation](https://www.cisco.com/c/en/us/support/docs/ios-nx-os-software/ios-embedded-packet-capture/116045-productconfig-epc-00.html) 

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram"
[3]: ./media/network-diagram3.png "network diagram-details"
[4]: ./media/network-diagram4.png "network diagram-details"
[5]: ./media/setup.png "setup steps"
[6]: ./media/nic-ip-forwarding.png "ip forwarding"

<!--Link References-->

