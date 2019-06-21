<properties
pageTitle= 'IPv6 in Azure Virtual Network'
description= "IPv6 in Azure Virtual Network with ARM template"
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
   ms.date="19/06/2019"
   ms.author="fabferri" />

## Example of Azure Virtual Network deployment with IPv6

The article talks through a deployment of Azure VNet with IPv6 by ARM template. An overview of network diagram is shown below.

[![1]][1]

The configuration is based on:
* single Azure Virtual Network with IPv4 10.0.0.0/24 and IPv6 ace:cab:deca::/48 address space
* in the VNet are configured three subnets **subnet1, subnet2, subnet3**, each with IPv4 and IPv6 networks
* all the VMs run un dual stack IPv4 and IPv6
* two VMs **vm11, vm12** connected to the **subnet1** with Windows 2019 and IIS
* an external basic load balancer is configured with IPv6 frontend and a backend pool associated with the NIC of **vm11, vm12**
* a vm **nva** connected to the **subnet3**, configured with IPv6 forwarding
* two UDRs **RT-subnet1, RT-subnet2** applied respectively to the **subnet1** and **subnet2** to enforce the IPv6 traffic to transit through the **nva**
* a NSG applied to the NICs of vm11, vm12 to filter the IPv6 traffic in ingress and egress from/to the VMs

A network diagram with IPv6 UDRs is shown underneath:

[![2]][2]


The ARM template assigns static IPv4 and IPv6 addresses to the VMs:

| *VM*         | *IPv4*                 | *IPv6                          |
| :----------- | :--------------------- |:------------------------------ |
| **vm11**     | **10.0.0.4 (Dynamic)** | ace:cab:deca:deea::4 (Dynamic) |
| **vm12**     | **10.0.0.5 (Dynamic)** | ace:cab:deca:deea::5 (Dynamic) |
| **nva**      | **10.0.0.90 (Static)** | ace:cab:deca:deec::90 (Static) |
| **h2**       |**10.0.0.50 (Static)**  | ace:cab:deca:deeb::50 (Static) |

In the UDR **RT-subnet1** only a single IPv6 route is required:
* the destination network is the IPv6 network **ace:cab:deca:deeb::/64** assigned to the subnet2
* the next-hop IP  is the static IPv6 address **ace:cab:deca:deec::90** of the nva

In the UDR **RT-subnet2**, only a single IPv6 route is required:
* the destination network is the IPv6 network **ace:cab:deca:deea::/64** assigned to the subnet1
* the next-hop IP is the static IPv6 address **ace:cab:deca:deec::90** of the nva

The ARM template installs the VMs with the following OS:
* **vm11,vm12**: Windows Server 2019
* **h2**: CentOS 7.5
A customization with diffferent OS can be done by changing the values of variables: "imagePublisher", "imageOffer", "OSVersion" in the ARM template.

List of scripts:
* **ipv6.ps1**: powershell command to run the ARM template ipv6.json. you can run the script by command:
  ipv6.ps1 -adminUsername <USERNAME_ADMINISTRATOR_VMs> -adminPassword <PASSWORD_ADMINISTRATOR_VMs>
* **ipv6.json**: ARM template
* **nsg-logs.ps1**: powershell to create the NSG logs
* **PowerBI_FlowLogs_Storage_Template.pbit**: power BI template to pickup the NSG log from a storage account
* **logs.txt**: IPv6 address of few VMs
* folder **vm11**: it holds the HTML homepage for IIS on vm11
* folder **vm12**: it holds the HTML homepage for IIS on vm12

After running the ARM template, some further steps are required to complete the setup.


###<a name="IPv6"></a> 2. Enable IPv6 DHCP client in the **nva** and **h2** VMs
Add the following entries in the files:

| *file*                                        | *entry to add*          |
| :-------------------------------------------- | :---------------------- |
| **/etc/sysconfig/network**                    | **NETWORKING_IPV6=yes** |
| **/etc/sysconfig/network-scripts/ifcfg-eth0** | **IPV6INIT=yes**        |
| **/etc/sysconfig/network-scripts/ifcfg-eth0** | **DHCPV6C=yes**         |

The **/etc/sysconfig/network** file specifies additional information that is valid to all network interfaces on the system.
when the entries are added to the files, force the eth0 interface to renew the ip address:
```
**sudo ifdown eth0 && sudo ifup eth0**
```

###<a name="IPv6"></a> 3. Enable IPv6 forwarding on the **nva**
If you want to apply a temporary IPv6 forwarding:

```bash
sysctl -w net.ipv6.conf.all.forwarding=1
sysctl -w net.ipv6.conf.eth0.accept_ra=2
sysctl -p /etc/sysctl.conf
```
the configuration is removed with vm reboot.

To make persistent changes:

| *file*                    | *entry to add*                     |
| :------------------------ | :--------------------------------- |
| **/etc/sysctl.conf**      | **net.ipv6.conf.all.forwarding=1** |
| **/etc/sysctl.conf**      | **net.ipv6.conf.eth0.accept_ra=2** |
| **/etc/sysconfig/network**| **IPV6FORWARDING=yes**             |


After the changes in the file, restart the network:

```
systemctl restart network.service
```

if instead to use an editor to change the parameters in /etc/sysctl.conf, you want to make by script:
```bash
sed -i \
    -e '/^\(net.ipv6.conf.all.forwarding=\).*/{s//\11/;:a;n;ba;q}' \
    -e '$anet.ipv6.conf.all.forwarding=1' /etc/sysctl.conf

sed -i \
    -e '/^\(net.ipv6.conf.eth0.accept_ra=\).*/{s//\12/;:a;n;ba;q}' \
    -e '$anet.ipv6.conf.eth0.accept_ra=2' /etc/sysctl.conf
```

The option **net.ipv6.conf.eth0.accept_ra=2** on the interface is used when you want to use ipv6 forwarding and also use ipv6 Stateless autoconfiguration (SLAAC). This option overrules the forwarding behaviour; it accepts Router Advertisements (and do autoconfiguration) even if forwarding is enabled.

> NOTE
> if in renew the IP of eth0 (**sudo ifdown eth0 && sudo ifup eth0**) you should get the message:
> Determining IP information for eth0... done.
> ERROR     : [/etc/sysconfig/network-scripts/ifup-ipv6] Global IPv6 forwarding is disabled in configuration, but not  currently disabled in kernel
> you should add to the file **/etc/sysconfig/network** the variable: **IPV6FORWARDING=yes**

###<a name="IPv6"></a> 4. install IIS in **vm11, vm12**
IIS can be installed in Windows 2019 VMs by powershell command:

```powershell
Install-WindowsFeature -name Web-Server -IncludeManagementTools
```
Login in vm11 and vm12 and check IIS answers by HTTP requests on IPv6 loopback interface:
**http://[::1]**

The load balancer provides access via HTTP to the web sites in vm11 and vm12. It is useful make a customization of the homepage of IIS with different colours to make out the landing server (two simple IIS homepage are reported in the project; rename the file **iisstart.htm** and copy it in the IIS home folder: **%SystemDrive%\inetpub\wwwroot**)


####<a name="IPv6"></a> 5. install and start NGINX in **h2** VM
Add the CentOS EPEL package:

```console
yum -y install epel-release
```
Install nginx:
```console
yum -y install nginx
```
Start nginx:
```console
systemctl start nginx
```
Verify the status of nginx service:
```console
systemctl status nginx
```
Configure the server to start nginx upon reboot:
```console
systemctl enable nginx
```
To enable IPv6 in nginx, check in the configuration file  **/etc/nginx/nginx.conf** the presence of following lines:

```console
# listen to all IPv4 and IPv6 interfaces for port 80
server {
        listen   80;
        listen   [::]:80;
}
```
Reload the NGINX service:
```console
systemctl reload nginx
```

To verify that both IPv6 and IPv4 are working:
```console
netstat -tulpna | grep nginx
```

###<a name="IPv6"></a> 6. Install iperf3 in vm11, vm12, h2
iperf3 is flexible tool to generate IPv6 traffic flows on custom ports.
To install iperf3 on h2 (CentOS):

```console
yum -y install iperf3
```
To install iperf3 on vm11 and vm12 (windows 2019) download the binary in a local folder.

###<a name="IPv6"></a> 7. Check out IPv6

####<a name="IPv6"></a> 7.1 verify IPv6 addresses in the VMs
| *OS*        | *command*                             |*description              *|
| :---------- | :------------------------------------ |---------------------------|
| **linux**   | **ip -6 addr**                        | show IPv6 IP addresses    |
| **linux**   | **route -n -A inet6**                 | default IPv6 routing table|
| **windows** | **netsh interface ipv6 show address** | show IPv6 addresses       |
| **windows** | **netsh interface ipv6 show route**   | show IPv6 routing table   |



####<a name="IPv6"></a> 7.2 Connection from internet to the IIS running in vm11, vm21
From a host in internet with IPv6, connect to the frontend public IPv6 of the external load balancer:

[![3]][3]

* by web browser: **http://[2603:1020:700::1e9]**
* by curl command: **curl -g -6 "http://[2603:1020:700::1e9]/"**

To generate multiple HTTP connections to the external load balancer:

```bash
for ((i=1;i<=100;i++)); do  curl "http://[2603:1020:700::1e9]/" 2>&1 | grep -E "Page 1|Page 2"; done
```
where:
* "Page 1" is the text included in the HTML homepage of vm11
* "Page 2" is the text included in the HTML homepage of vm21

The grep command filters the curl output and shows on which VMs (vm11 or vm21) the load balacer forwards the HTTP requests. The command works well also in git bash on Windows.

####<a name="IPv6"></a> 7.3 icmp traffic in transit through the nva
When the IPv6 forwarder is enabled and UDRs are applied to subnet1 and subnet2, it can be verified the transit through nva.

[![4]][4]

To visualize the traffic in transit in nva, run the tcpdump:
```console
tcpdump -i eth0 -nn -q 'ip6 and net ace:cab:deca:deea::/64 and net ace:cab:deca:deeb::/64'
```
The **net** command find packets going from/to a particular network. The command above shows up any traffic from/to subnet1 and any traffic from/to subnet2.

First test to check connectivity can be done with ping.
In h2:

```
ping6  ace:cab:deca:deea::4
ping6  ace:cab:deca:deea::5
ping6  ace:cab:deca:deec::90
```
In vm11 and vm12:
```
ping -6 -t ace:cab:deca:deeb::50
ping -6 -t ace:cab:deca:deec::90
```


####<a name="IPv6"></a> 7.4 iperf traffic in transit through the nva

One other test can be done by iperf3:

[![5]][5]

Run iperf as server in h2 (server listens on the default TCP port 5201):
```console
iperf3 -6 -s
```

In vn11 run the iperf3 client:

```console
iperf3 -6 -P 1 -c ace:cab:deca:deeb::50 -t 600 -i 1 -f m
```

####<a name="IPv6"></a> 7.5 generate http requests from h2 to vm11 and vm12
In h2 run the bash command to send HTTP requests to the vm11 and vm12:
```console
for ((i=1;i<=1000;i++)); do  wget -SO-  "http://[ace:cab:deca:deea::4]/" 2>&1 | grep -E "Page 1|Page 2"; done
for ((i=1;i<=1000;i++)); do  wget -SO-  "http://[ace:cab:deca:deea::5]/" 2>&1 | grep -E "Page 1|Page 2"; done
```

[![6][6]

####<a name="IPv6"></a> 5. NSG logging
Network Security Group (NSG) flow logs are a feature of Network Watcher.
* Network Watcher is a regional service
* Only one Network Watcher can be created per region per subscription
* Flow logs are written in JSON format
* Flow logs are stored only within a storage account with predefined fixed path
* NSG flow logging requires the **Microsoft.Insights** provider. Registration of the Microsoft.Insights provider can be done through powershell: **Register-AzResourceProvider -ProviderNamespace Microsoft.Insights**

To create the Network watcher and enable the NSG logs, run the powershell: **nsg-logs.ps1**
Follow the official documentation:
https://docs.microsoft.com/en-us/azure/network-watcher/network-watcher-visualize-nsg-flow-logs-power-bi
to view the nsg logs in powerbi desktop.
The file **PowerBI_FlowLogs_Storage_Template.pbit** is a power BI Desktop template to create a connection with storage account, downloads and parses the logs to provide a visual representation of the traffic that is logged by NSG.
If you need to manually view the contents you can rename the ".pbit" extension to ".zip" to create a .ZIP file and then extract the contents of the file.
A visualization of logs by power BI is reported below:

[![7]][7]

> Note
> When you enable Network Watcher using the portal, the name of the Network Watcher instance is automatically set to **NetworkWatcher_region_name** where** region_name** corresponds to the Azure region where the instance is enabled. For example, a Network Watcher enabled in the UK South region is named NetworkWatcher_uksouth.
> The Network Watcher instance is automatically created in a resource group named **NetworkWatcherRG**. The resource group is created if it does not already exist.
> By powershell is possible customize the name of a Network Watcher instance and the associated resource group.


<!--Image References-->

[1]: ./media/network-diagram.png "network overview"
[2]: ./media/network-diagram-with-udr.png "network diagram with UDR"
[3]: ./media/elb-access.png "access from internet to ELB"
[4]: ./media/communication-flows.png "communication flows"
[5]: ./media/iperf.png "communication flows"
[6]: ./media/h2-to-vm12.png "HTTP rwquests from h2 to vm12"
[7]: ./media/nsg-logs.png "NSG logs"

<!--Link References-->

