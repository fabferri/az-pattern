<properties
pageTitle= 'Iptables to control traffic inbound and outbound Azure VMs'
description= "Linux nva with iptables"
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
   ms.date="07/02/2021"
   ms.author="fabferri" />

# Iptables to control traffic inbound and outbound Azure VMs
The network diagram is shown below:

[![1]][1]

- The virtual network **vnet1** is in peering with **vnet2** and **vnet3**
- The VMs **nva1** and **nva2** work as NVA, with IP forwarding enabled to route the IP packets and iptables to control the the traffic inbound and outbound internet  
- the iptables in **nva1** and **nva2** are configured with destination NAT and source NAT to accept the inbound traffic from internet on port 8081 and 8081. The traffic inbound to the port 8081 is changed to be forwarded to the **vmApp2**. The inbound traffic to the port 8082 is changed to be forwarded to the **vmApp3**.
- in the **vnet1** is configured an internal load balancer in HA ports to balance the traffic between **nva1** and **nva2**
- A UDR is applied to the **appSubnet** of **vnet2** and **vnet3** to force the traffic to pass through the frontend IP of the internet load balancer.
- in each VM is installed nginx on HTTP port 80, with simple custom homepage with VM name. The nginix in **nva1** and **nva2** are required to answer to the load balancer health probes set on port 80.
- the traffic outbound from **vmApp2** and **vmApp3** to internet is source NAT (POSTROUTING chain) by iptables NAT masquerade function

<br>

The diagram below shows the inbound traffic to **nva1** on destination port 8081:

[![2]][2]

The diagram below shows the inbound traffic to **nva1** on destination port 8082:
[![3]][3]


The Azure load balancer supports the following distribution modes for routing connections to instances in the backed pool:
* session persistence: None,                    REST API: **"loadDistribution":"Default"**
* session persistence: Client IP,               REST API: **"loadDistribution":SourceIP**
* session persistence: Client IP and protocol,  REST API: **"loadDistribution":SourceIPProtocol**
<br>

In our setup, the ARM template the load balancer distribution mode is set to: **"loadDistribution":SourceIP**

## <a name="IP forwarding"></a>1. IP forwarding in NVAs
The IP forwarding in **nva1** and **nva2** is configured by adding the line **net.ipv4.ip_forward=1** in the file **/etc/sysctl.conf**:
```bash
sed -i -e '/^\(net.ipv4.ip_forward=\).*/{s//\11/;:a;n;ba;q}' -e '$anet.ipv4.ip_forward=1' /etc/sysctl.conf; sysctl -p
```
The bah command:
```bash
sed \
    -e '/^\(option=\).*/{s//\1value/;:a;n;ba;q}' \
    -e '$aoption=value' filename
```
check the presence of "option=value" in the file. If doesn't exist, it would add it to the bottom of the file.


## <a name="iptables configurations"></a>2. iptables configuration in NVAs
The iptables diagram shows how the tables and chains are traversed:

[![4]][4]

Below the Iptables rules in use in **nva1**:
```console
iptables -I INPUT 1 -i lo -j ACCEPT;
iptables -A INPUT -p tcp --dport ssh -j ACCEPT;
iptables -A INPUT -p tcp -s 168.63.129.16 --dport 80 -j ACCEPT;
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT;
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT;
iptables -A INPUT -j DROP;
iptables -P FORWARD ACCEPT;
iptables -P OUTPUT ACCEPT;
iptables -t nat -A PREROUTING  -i eth0  -j DNAT -p tcp -d 10.1.0.10/32 --dport 8081  --to-destination 10.2.0.10:80;
iptables -t nat -A POSTROUTING -o eth0  -j SNAT -p tcp -d 10.2.0.10/32 --dport 80  --to-source 10.1.0.10;
iptables -t nat -A PREROUTING  -i eth0 -j DNAT -p tcp -d 10.1.0.10/32 --dport 8082  --to-destination 10.3.0.10:80;
iptables -t nat -A POSTROUTING -o eth0 -j SNAT -p tcp -d 10.3.0.10/32 --dport 80  --to-source 10.1.0.10;
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE;
```

Let's discuss briefly the logic of iptables configuration.<br>
To allow traffic to localhost, type this command:
```console
iptables -A INPUT -i lo -j ACCEPT
```
we use **lo** or loopback interface. The command makes sure that the connections between applications inside the same machine are working properly.

To accept SSH incoming connection in nva:
```console
iptables -A INPUT -p tcp --dport ssh -j ACCEPT
```

A rule that uses connection tracking to accept in INPUT only the packets that are associated with an established connections:
```console
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```
To accept incoming ping:
```console
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
```

The DROP target on INPUT chain should be added after defining –dport rules. This will prevent an unauthorized connection from accessing to the target VM via other open ports:
```console
iptables -A INPUT -j DROP
```

Let's discuss the NAT rules.<br>
**Destination NAT** is done in the <ins>PREROUTING</ins> chain, just as the packet comes in.<br>
**-i** option identify the incoming interface<br>
Destination NAT is specified using `-j DNAT`, and the `--to-destination` option specifies an IP address, a range of IP addresses, and an optional port or range of ports (for UDP and TCP protocols only).
The <ins>PREROUTING</ins> chain in NAT specifies a destination IP address and port where incoming packets requesting a connection to your internal service can be forwarded. For example, if you wanted to forward incoming HTTP requests from internet with destination port 8081 to your internal nginx HTTP Server at 10.2.0.10 on destination port 80, run the following command:<br>
**iptables -t nat -A PREROUTING  -i eth0  -j DNAT -p tcp -d 10.1.0.10/32 --dport 8081 --to-destination 10.2.0.10:80**

**Source NAT** changes the source address of connections to something different. This is done in the <ins>POSTROUTING</ins> chain, just before it is finally sent out. This is an important detail, since it means that anything else on the Linux box itself (routing, packet filtering) will see the packet unchanged. It also means that the `-o` (outgoing interface) option can be used.
Source NAT is specified using `-j SNAT`, and the `--to-source` option specifies an IP address, a range of IP addresses, and an optional port or range of ports (for UDP and TCP protocols only). <ins>POSTROUTING</ins> chain allows packets to be altered as they are leaving the nva outgoing eth0 interface. <br>
**iptables -t nat -A POSTROUTING -o eth0  -j SNAT -p tcp -d 10.2.0.10/32 --dport 80  --to-source 10.1.0.10**

Below the network diagram with visualization of inbound traffic from internet to **vmApp2**:
[![5]][5]

Below the network diagram with visualization of inbound traffic from internet to **vmApp3**:
[![6]][6]

The traffic from the **vmApp2** and **vmApp3** can access to internet by:
```
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE;
```
The rule uses the NAT packet matching table (-t nat) and specifies the built-in POSTROUTING chain for NAT (-A POSTROUTING) on the nva external networking device (-o eth0). POSTROUTING allows packets to be altered as they are leaving the firewall's external device. The -j MASQUERADE target is specified to mask the private IP address of a node with the external IP address of the nva.

### iptables configuration persistent to the VM reboot
In order to make your iptables rules persistent after reboot, install the **iptables-persistent** package using the apt package manager:
```bash
apt install iptables-persistent
```
The current iptables rules can be saved to the corresponding IPv4 and IPv6 files below:
```bash
/etc/iptables/rules.v4
/etc/iptables/rules.v6
```
In our setup we use only IPv4 rules.

After a rule change, to make changes permanent after reboot, run **iptables-save** command:
```bash
sudo /sbin/iptables-save > /etc/iptables/rules.v4
OR
sudo /sbin/ip6tables-save > /etc/iptables/rules.v6
```

### NOTE
Installing **iptables-persistent** on ubuntu without manual input requires the setting of flags in **debconf-set-selections**
```
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
sudo apt-get -y install iptables-persistent
```

You can verify these fields by installing debconf-utils and searching for iptables values:
```
sudo apt install debconf-utils
sudo debconf-get-selections | grep iptables
```

## <a name="List of files"></a>3. List of files 
| file                  | Description                                                  | 
| --------------------- |------------------------------------------------------------- | 
| **init.json**         | input parameter file defining: Azure subscription, Resource group name, Azure region, administrator credential|
| **az.json**           | ARM template to deploy load balancers and VMs                |
| **az.ps1**            | powershel script to deploy **az.ps1**                        |


**NOTE:** 
- **Before running the ARM template, customize the values of input variables in init.json file**
- **To deploy the full solution, run "az.json"**
- installation of nginx in all VMs, configuration of ip fowarding and iptables in NVA is executed through custom script extension

<br>

Meaning of variables in **init.json**:
```json
{
    "subscriptionName": "NAME_OF_AZURE_SUBSCRIPTION",
    "ResourceGroupName": "NAME_OF_RESOURCE_GROUP",
    "location": "AZURE_LOCATION_NAME",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "authenticationType": "password",
    "adminPasswordOrKey": "ADMINISTRATOR_PASSWORD"
}
```

## <a name="check"></a>4. Check of flows through NVAs
Using tcpdump is easy to verify the NAT and symmetrical transit through the NVAs:

```bash
root@nva1:~# tcpdump -n host 10.2.0.10 or host 10.3.0.10
root@nva2:~# tcpdump -n host 10.2.0.10 or host 10.3.0.10
```
By curl the vmClient1 can query the nginx server blocks in vmApp1:
```bash
root@vmApp1:~# curl http://www.microsoft.com
root@vmApp1:~# curl 10.3.0.10
```


## <a name="iptables"></a>5. ANNEX: iptables commands 

### How to show the current rules
```console
iptables -nvL
```
**-L** option is used to list all the rules <br>
**-v** option is for showing the info in a more detailed format <br>

List rules inclusive of line number:
```console
iptables -n -L -v --line-numbers
```
```console
iptables -t nat -L
iptables -t nat -L -nv
iptables --list --line-numbers
```

### How to flush and reset the iptables to the default  
```console
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -t raw -F
iptables -t raw -X
iptables -t security -F
iptables -t security -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
```
**-F** command with no arguments flushes all the chains in its current table. <br>
**-X** deletes all empty non-default chains in a table

**iptables -t nat -F**       &nbsp;&nbsp;&nbsp;flush the nat table <br>
**iptables -t mangle -F**    &nbsp;&nbsp;&nbsp;flush the mangle table <br>
**iptables -F**              &nbsp;&nbsp;&nbsp;flush all chains <br>
**iptables -X**              &nbsp;&nbsp;&nbsp;delete all non-default chains <br>
**iptables -Z**              &nbsp;&nbsp;&nbsp;clear the counters for all chains and rules <br>


`Tags: iptables` <br>
`date: 30-10-22`

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram with inbound traffic from internet to the vmApp2"
[3]: ./media/network-diagram3.png "network diagram with inbound traffic from internet to the vmApp3"
[4]: ./media/iptables.png "iptables: flow of packets through the chains"
[5]: ./media/nat1.png "NAT applied to the traffic inbound from internet to vmApp2"
[6]: ./media/nat2.png "NAT applied to the traffic inbound from internet to vmApp3"

<!--Link References-->

