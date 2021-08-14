<properties
pageTitle= 'Traffic to internet through Uncomplicated firewall with NAT masquerade'
description= "Single ARM template to create Site-to-site VPN between two VPN Gateways"
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
   ms.date="14/08/2021"
   ms.author="fabferri" />

## Traffic to internet through Uncomplicated firewall with NAT masquerade

This article contains an ARM template to create to a vnet with three Ubuntu VMs ver 20.x:
* nva: VM with two NICs, eth0 used as external interface and eth1 as internal interface. Uncomplicated firewall is installed manually in this VM, and configured with NAT masquerade.
* vm3: VM connected to the subnet3. A UDR with default route (0.0.0.0/0) is applied to this subnet with next-hop IP address the internal interface eth1 of the nva.
* vm4: it is an Ubuntu VM connected to the subnet4. No UDR is applied to this subnet. The vm4 can be used as transit VM (jumpbox) to login to the vm3. 

<br>

[![1]][1]


The traffic from vm3 with destination internet (traffic matching the default route 0.0.0.0/0) is forwarded to the eth1 of the nva1. The nva1 applies NAT masquerade and forward the traffic to internet translated with the public IP associated with the interface eth0.

| file                | description                                                               |       
| ------------------- |:------------------------------------------------------------------------- |
| **vnet-vms.json**   | ARM template to create VNet and VMs                                       |
| **vnet-vms.ps1**    | powershell script to deploy the ARM template **vnet-vms.json**            |

The nva is deployed by the image:
```
"publisher": "canonical",
"offer": "0001-com-ubuntu-server-focal",
"sku": "20_04-lts",
"version": "latest",
```

> [!NOTE]
>
> Before spinning up the powershell script **vnet-vms.ps1** you should:
>
> 1. customize the values of variables stored in the **init.txt** file. Replace **YOUR_ADMINISTRATOR_PUBLIC_IP** with your public management IP. This IP is used to access in SSH to the Azure VMs.
> 2. edit the file **vms.ps1** and set the administrator _username_ and _password_ of the Azure VMs in the variables **$adminUsername**, **$adminPassword**
>

<br>

## <a name="Uncomplicated firewall"></a>1. Setup of Uncomplicated firewall in the nva 
Linux kernel includes the Netfilter subsystem, which is used to manage of the network traffic headed into or through the host. The default firewall configuration tool for Ubuntu is ufw, developed to facilitate the iptables firewall configuration.
The setup of IP Masquerading allows to the VMs in the VNet with private, to access the Internet through the VM doing the masquerading. Traffic from the VNet destined for the Internet must be manipulated for replies to be routable back to the VM that made the request. To do this, the kernel must modify the source IP address of each packet so that replies will be routed back to it.

### 1.1 Enable IP forwarding:

```console
sed -i -e '$a\net.ipv4.ip_forward = 1' /etc/sysctl.conf
sysctl --system
sysctl net.ipv4.ip_forward
```

###  1.2 Configuration of static route to communicate with vm3 through nva-eth1: 
Edit of the file **/etc/netplan/50-cloud-init.yaml** and add to the _routes:_ section the network associated with subnet3:

```
network:
    ethernets:
        eth0:
            dhcp4: true
            dhcp4-overrides:
                route-metric: 100
            dhcp6: false
            match:
                driver: hv_netvsc
                macaddress: 00:0d:3a:96:4a:15
            set-name: eth0
        eth1:
            dhcp4: true
            dhcp4-overrides:
                route-metric: 200
            dhcp6: false
            match:
                driver: hv_netvsc
                macaddress: 00:0d:3a:42:00:81
            set-name: eth1
            routes:
              - to: 10.0.1.64/27
                via: 10.0.1.33
                metric: 10
    version: 2
```
**NOTE: the structure of yaml file is indentation-oriented. Indentation is defined as space characters at the start of a line. If indentation is not properly netplan returns failures with the network configuration**

Apply the new network configuration:

```console
/usr/sbin/netplan apply
```
<br>
Check the routing table:

```console
ip -4 route
```


### 1.3 Set the ufw default policies for incoming and outgoing traffic
To see the firewall status, enter:
```console
ufw status
```
the command shows the ufw is inactive.
<br>



```console
ufw default allow outgoing
ufw default deny incoming
```

### 1.4 allow incoming traffic for SSH port
Create a rule that explicitly allows SSH incoming connections:
```console
ufw allow ssh
```
To verify which rules were added:
```console
ufw show added
```
<br>

The general syntax to open a port is as follows:
```
ufw allow port_number/protocol
```

To open port ranges:
```
ufw allow start_port_number:end_port_number/protocol
```


### 1.5 configure ufw to allow forwarded packets
The default behaviour of the UFW Firewall is to block all incoming and forwarding traffic and allow all outbound traffic.
<br>

The default polices are defined in the **/etc/default/ufw** file.
<br>

Packet forwarding needs to be enabled in ufw:
* Edit **/etc/ufw/sysctl.conf** file and uncomment: **net/ipv4/ip_forward=1**
* Edit the file **/etc/default/ufw** locate the **DEFAULT_FORWARD_POLICY** key, and change the value from **DROP** to **ACCEPT**


### 1.6 set the default policy for the POSTROUTING chain in the nat table and the masquerade rule

IP Masquerading can be achieved using custom ufw rules. The rules files are in **/etc/ufw/*.rules**
```bash
root@nva1:~# ll /etc/ufw/*.rules
-rw-r----- 1 root root 1004 Aug 14 09:15 /etc/ufw/after.rules
-rw-r----- 1 root root  915 Aug 14 09:15 /etc/ufw/after6.rules
-rw-r----- 1 root root 2537 Apr  2  2020 /etc/ufw/before.rules
-rw-r----- 1 root root 6700 Apr  2  2020 /etc/ufw/before6.rules
-rw-r----- 1 root root 1370 Aug 14 09:17 /etc/ufw/user.rules
-rw-r----- 1 root root 1385 Aug 14 09:17 /etc/ufw/user6.rules
```
<br>

The rules are split into two different files, rules that should be executed _before_ ufw command line rules, and rules that are executed _after_ ufw command line rules.
<br>

To enable masquerading the NAT table needs to be configured. Add the following to the top of the **/etc/ufw/before.rules** file just after the header comments:

```console
#NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]

# Forward traffic through eth0 - the public network interface
-A POSTROUTING -o eth0 -j MASQUERADE

# don't delete the 'COMMIT' line or these rules won't be processed
COMMIT
```

The syntax is based on:
* -A POSTROUTING – the rule is to be appended (-A) to the POSTROUTING chain
* -o eth0 – the rule applies to traffic scheduled to be routed through the ethernet interface eth0
* -j MASQUERADE – traffic matching this rule is to "jump" (-j) to the MASQUERADE target to be manipulated 


### 1.7 enable the ufw
```console
ufw enable
```
Once UFW enabled, it runs across system reboots too. you can verify by the systemctl command:
```
systemctl status ufw.service
```

### 1.8 get a list of numbered rules

```console
ufw status numbered
```
<br>

To turn on/off the logging in ufw:
```console
ufw logging on
ufw logging off
```

To check if the log is active:
```console
ufw status verbose
```

Setting the logging level:
```console
ufw logging medium
```

- **low**:    logs  all  blocked packets not matching the defined policy (with rate limiting), as well as packets matching logged rules
- **medium**: log level low, plus all allowed  packets  not  matching  the  defined  policy,  all INVALID packets, and all new connections.  All logging is done with rate limiting.

The UFW logging is direct to the file **/var/log/syslog** and **/var/log/kern.log**
<br>

To redirect the entries for UFW to their own log file at **/var/log/ufw.log** 
- edit the file **/etc/rsyslog.d/20-ufw.conf** It contains at the bottom #& stop   ; remove the # in front of it to uncomment it 
- refresh rsyslog with the command **systemctl restart rsyslog** so that it takes in account the configuration change. 

All UFW entries are logged into /var/log/ufw.log file; use the tail command to view the ufw logs:
```console
tail -f /var/log/ufw.log
```



### 1.9 trace the traffic passing across nva:
Run tcpdump in nva to capture the traffic from/to the vm3 (10.0.1.70):
```
tcpdump -n -i eth1 host 10.0.1.70
```

From vm4, connect to the vm3 and run some curl queries to access to internet. 
```
curl https://twitter.com
```

By tcpdump in nva, you should see the bidirectional traffic passing through the nva.


## Reference
[Uncomplicated Firewall](https://ubuntu.com/server/docs/security-firewall)

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"

<!--Link References-->

