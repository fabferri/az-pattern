<properties
pageTitle= 'VXLAN between two Azure VMs in the same vnet'
description= "VXLAN between two Azure VMs in the same vnet"
documentationcenter: na
services="networking"
documentationCenter="https://github.com/fabferri"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="ARM template"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="Azure networking"
   ms.date="25/10/2021"
   ms.author="fabferri" />

## VXLAN between two Azure VMs in the same vnet

The ARM template spins up two ubuntu VMs in the same Azure VNet. the network diagram is shown below:

[![1]][1]

The goal is to create a simple point-to-point VXLAN tunnel between the two Azure VM. As shown in the following figure, only one VXLAN-type network interface is needed in the two VMs, and VXLAN-type interface VXLAN0 can be used as VTE.

[![2]][2]

For more information on [Virtual eXtensible Local Area Networking documentation](https://www.kernel.org/doc/Documentation/networking/vxlan.txt).

> [!NOTE]
> Before spinning up the ARM template, edit the file **vms.ps1** and set:
> * your Azure subscription name in the variable **$subscriptionName**
> * the administrator username and password of the Azure VMs in the variables **$adminUsername**, **$adminPassword**
>



## <a name="VXLAN"></a>1. Setting VXLAN in the two Ubuntu Azure VMs 

The dotted line in the diagram shows that the overlay Network and VXLAN Tunnel are both logical concepts.

[![3]][3]

The VMs are connected to the logical overlay network 172.16.0/24. A VXLAN Tunnel is built directly between the VTEP device, and directly linked the network interface.

<br> 

The VXLAN driver creates a virtual tunnel endpoint in a VXLAN segment.  A VXLAN segment is a virtual Layer 2 (Ethernet) network that is overlaid in a Layer 3 (IP/UDP) network.
Each VXLAN interface is created at runtime using interface cloning.
The VXLAN driver creates a pseudo Ethernet network interface that supports the usual network ioctl and is thus can be used with ifconfig like any other Ethernet interface.  The VXLAN interface encapsulates the Ethernet frame by prepending IP/UDP and VXLAN headers. Thus, the encapsulated (inner) frame is able to be transmitted over a routed, Layer 3 network to the remote host. 
<br>

The VXLAN interface may be configured in either **unicast** or **multicast mode**.
In unicast mode, the interface creates a tunnel to a single remote host, and all traffic is transmitted to that host. 

<br>

**In Azure VNet only unicast is supported.**

### <a name="VXLAN"></a>1.1 Configuration steps in the Azure vm1 
Create a unicast VXLAN interface:
```console
ip link add vxlan0 type vxlan id 10 dev eth0 dstport 0
```
The first command above creates a network interface of type VXLAN on Linux called vxlan0.
* id: The VNI identifier is 1.
* dstport: The specified destination port. When specified 0, use as UDP destination port the default 8472.
* dev: Specifies which physical device VTEP communicates through, here using eth0.

Create forwarding table entry for a connection to vm2:
```console
bridge fdb add 00:00:00:00:00:00 dev vxlan0 dst 10.0.0.5
```

Bring up the VXLAN and give it an IP address:
```console
ip addr add 172.16.0.1/24 dev vxlan0
ip link set up dev vxlan0
```

Repeat the same process for vm2:
```console
ip link add vxlan0 type vxlan id 10 dev eth0 dstport 0
bridge fdb add 00:00:00:00:00:00 dev vxlan0 dst 10.0.0.4
ip addr add 172.16.0.2/24 dev vxlan0
ip link set up dev vxlan0
```

Check the VXLAN device status:
```console
ip -d link show vxlan0
```

Delete VXLAN device:
```console
ip link delete vxlan0
```

### <a name="VXLAN"></a>1.2 VXLAN configuration summary with default destination port
Below the step with default destination UDP port (Linux use as default destination port 8472).

**vm1:**
```console
ip link add vxlan0 type vxlan id 10 dev eth0 dstport 0
bridge fdb add 00:00:00:00:00:00 dev vxlan0 dst 10.0.0.20
ip addr add 172.16.0.1/24 dev vxlan0
ip link set up dev vxlan0
```
<br>

**vm2:**
```console
ip link add vxlan0 type vxlan id 10 dev eth0 dstport 0
bridge fdb add 00:00:00:00:00:00 dev vxlan0 dst 10.0.0.10
ip addr add 172.16.0.2/24 dev vxlan0
ip link set up dev vxlan0
```

### <a name="VXLAN"></a>1.3 VXLAN configuration summary with custom destination port


**vm1**:
```console
ip link add vxlan0 type vxlan id 10 dev eth0 dstport 888
bridge fdb add 00:00:00:00:00:00 dev vxlan0 dst 10.0.0.20
ip addr add 172.16.0.1/24 dev vxlan0
ip link set up dev vxlan0
```
<br>

**vm2**:
```console
ip link add vxlan0 type vxlan id 10 dev eth0 dstport 888
bridge fdb add 00:00:00:00:00:00 dev vxlan0 dst 10.0.0.10
ip addr add 172.16.0.2/24 dev vxlan0
ip link set up dev vxlan0
```

### <a name="VXLAN"></a>1.4 Useful VXLAN commands

```console
ifconfig vxlan1
```

```console
bridge fdb show dev vxlan0
```

```console
ip -d link show vxlan0
```

### <a name="VXLAN"></a>1.5 Traffic capture by tcpdump
The traffic in the vm1 can be capture by reference of vxlan0 device:
```console
tcpdump -i vxlan0 -n host 172.16.0.2
```
<br>

Traffic capture of VXLAN UDP in vm1:
```console
tcpdump -i eth0 -n host 10.0.0.20
```

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram"
[3]: ./media/network-diagram3.png "network diagram"

<!--Link References-->

