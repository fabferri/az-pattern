<properties
pageTitle= 'ARM template to create a single VNet with three subnet and a VM working as ip forwarder'
description= "ARM template to create a single VNet with three subnets and a VM working as ip forwarder"
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

## Single VNets with three subnets and one VM working as IP forwarder
The blog post presents a ARM template to create a VNet with three subnets named **subnet1**,**subnet2**,**subnet3**.
In every subnet runs a VM:

* in **subnet1** runs a VM with hostname **nva** configured as IP packet forwarder. A VM with IP forwarder enabled in the OS has a router behaviour: the VM is able to receive an IP packet with destination address different from its IP address and forwards (routes) the packet to another VM.
* in **subnet2** runs a Linux (or Windows) VM  with hostname **vm2**
* in **subnet3** runs a Linux (or Windows) VM with hostname **vm3**

The ARM template can be changed to customize VM size and OS.

The network diagram is shown below:

[![1]][1]

Two static routes (User Defined Routes), associated with the subnet2 and subnet3, force the traffic between vm2-vm3 to pass through the nva.

[![2]][2]


> [!NOTE]
> Before spinning up the ARM template you should:
> * edit the file **vnet-nva.json** and set your Azure subscription name
> * edit the file **vnet-nva.json** and set the administrator username and password of the Azure VMs 
>

Let's discuss the different way to set the IP forwarder in Linux and Windows.

#### <a name="EnableIPForwarding"></a>1. How to enable ip forwarding in Linux VM
To enable the ip forwarder in Linux vm run the command as root:

```console
sed -i -e '$a\net.ipv4.ip_forward = 1' /etc/sysctl.conf
systemctl restart network.service
sysctl net.ipv4.ip_forward
```

The sed command add the raw **net.ipv4.ip_forward = 1** to the file **/etc/sysctl.conf**
To check the setting of ip forwarding:

```console
cat /proc/sys/net/ipv4/ip_forward
```

or

```console
sysctl net.ipv4.ip_forward
```
the command return **1** if the ip forwarder is enabled.
the command return **0** if the ip forwarder is disabled.

[![3]][3]



> > [!NOTE]
> in a linux VM to enable the ip forwarder on the fly (++not persistent to the reboot++), use the command:
> **sysctl -w net.ipv4.ip_forward=1**
>



#### <a name="EnableIPForwarding"></a>2. How to enable ip forwarding in Windows VM

To enable the ip forwarder in windows vm, run the powershell as administrator:

``` powershell
Import-Module ServerManager
Add-WindowsFeature RemoteAccess, Routing, RSAT-RemoteAccess
Get-NetAdapter | Set-NetIPInterface -Forwarding Enabled
Set-Service remoteaccess -StartupType Automatic
Start-Service remoteaccess
```

[![4]][4]

#### <a name="tcpdump"></a>3. Check the traffic between vm2 and vm2 transit through nva

To check the traffic between the two VMs (vm2 and vm3) transit properly through nva, it can be used a sniffer in nva.
* if nva is a linux VM the natural choice is tcpdump
* if nva is a windows VM it can be used Wireshark. There is also an altenative solution free or change to run a compact portable version of tcmpdump in windows [Microolap TCPDUMP for Windows](http://www.microolap.com/products/network/tcpdump/download/)
to dump the traffic in transit in the nva:

```console
tcpdump -nq -ttt host 10.0.2.10 or host 10.0.3.10
```


<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/network-diagram-details.png "network diagram with details"
[3]: ./media/network-diagram-linux.png "ip forwarder in linux"
[4]: ./media/network-diagram-windows.png "ip forwardr in windows"

<!--Link References-->

