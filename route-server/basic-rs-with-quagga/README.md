<properties
pageTitle= 'Azure route server in BGP peering with quagga'
description= "Azure route server in BGP peering with quagga"
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
   ms.date="29/03/2021"
   ms.author="fabferri" />

## Azure route server in BGP peering with quagga

The Azure route server allows to create BGP peering with NVA.
The article shows a simple configuration with an Azure Virtual Network (VNet), an Azure route server in  **"RouteServerSubnet"** and an Ubuntu VM with quagga deployed manually. 

The purpose of setup is shown interoperability between quagga and Azure route server. Quagga advertises in eBGP few networks to the route servers; the route server advertise to quagga the address space of the VNet. 

The network diagram is reported below:

[![1]][1]


**Files:**
| File name           | Folder name              |Description                                                |
| ------------------- | ------------------------ |---------------------------------------------------------- |
| **rs.json**         | quagga-manual-setup      | deploy a VNet with route server and a Ubuntu VM           |
| **rs.ps1**          | quagga-manual-setup      | powershell script to run **rs.json**                      |
| **quagga.sh**       | quagga-manual-setup      | bash script to install and setup quagga                   |
| **rs.json**         | quagga-cloud-init-setup  | deploy a VNet with route server and a Ubuntu VM           |
| **rs.ps1**          | quagga-cloud-init-setup  | powershell script to run **rs.json**                      |
| **cloud-init.txt**  | quagga-cloud-init-setup  | cloud-init file to automatically install and setup quagga |
 
> **[!NOTE]**
>
> Before spinning up the ARM template you should edit the file **rs.ps1** and customize the variables:
> * **$subscriptionName**: name of your Azure subscription 
> * **$adminUsername**: the administrator username of the Azure VM 
> * **$adminPassword**: the administrator password of the Azure VM 
> * **$mngIP**: the management public IP address to connect to the Azure VM in SSH
> 

The ARM template  **rs.json** creates the Azure VNet, the route server and configure the BGP connection in route server an Ubuntu 20.04 VM.

## <a name="quagga"></a>1. Manual installation of quagga in ubuntu VM
 Check dependencies of quagga package:
 ```bash
 apt-cache depends quagga
 ```
To install quagga:
```bash
apt update
apt -y install quagga
```

Enable IP forwarding on ubuntu VM:
```bash
echo "net.ipv4.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.conf 
echo "net.ipv4.conf.default.forwarding=1" | sudo tee -a /etc/sysctl.conf 
sysctl -p
```
Setting is permanently saved in **/etc/sysctl.conf** file.

Create a folder for the quagga logs:
```bash
sudo mkdir -p /var/log/quagga && sudo chown quagga:quagga /var/log/quagga
touch /var/log/zebra.log
chown quagga:quagga /var/log/zebra.log
```


Create the configuration files for Quagga daemon:
```bash
## Create the configuration files
## ==============================
touch /etc/quagga/babeld.conf
touch /etc/quagga/bgpd.conf
touch /etc/quagga/isisd.conf
touch /etc/quagga/ospf6d.conf
touch /etc/quagga/ospfd.conf
touch /etc/quagga/ripd.conf
touch /etc/quagga/ripngd.conf
touch /etc/quagga/vtysh.conf
touch /etc/quagga/zebra.conf
```

User quagga is created in Ubuntu during package installation.
```bash
cat /etc/passwd | grep quagga
quagga:x:113:122:Quagga routing suite,,,:/run/quagga/:/usr/sbin/nologin
```

Quagga daemon run under user quagga therefore change the ownership and permission for configuration files, under /etc/quagga folder:

```bash
## Change the owner and the mode of the configuration files
## ========================================================
chown quagga:quagga /etc/quagga/babeld.conf && chmod 640 /etc/quagga/babeld.conf
chown quagga:quagga /etc/quagga/bgpd.conf && chmod 640 /etc/quagga/bgpd.conf
chown quagga:quagga /etc/quagga/isisd.conf && chmod 640 /etc/quagga/isisd.conf
chown quagga:quagga /etc/quagga/ospf6d.conf && chmod 640 /etc/quagga/ospf6d.conf
chown quagga:quagga /etc/quagga/ospfd.conf && chmod 640 /etc/quagga/ospfd.conf
chown quagga:quagga /etc/quagga/ripd.conf && chmod 640 /etc/quagga/ripd.conf
chown quagga:quagga /etc/quagga/ripngd.conf && chmod 640 /etc/quagga/ripngd.conf
chown quagga:quaggavty /etc/quagga/vtysh.conf && chmod 660 /etc/quagga/vtysh.conf
chown quagga:quagga /etc/quagga/zebra.conf && chmod 640 /etc/quagga/zebra.conf
```
Some initial startup configuration for Quagga are required. We do this by changing the **/etc/quagga/daemons** file to reflect the services we would like to start:

```bash
## Edit which routing protocols have to run
## =======================================
echo 'zebra=yes' > /etc/quagga/daemons
echo 'bgpd=yes' >> /etc/quagga/daemons
echo 'ospfd=yes' >> /etc/quagga/daemons
echo 'ospf6d=yes' >> /etc/quagga/daemons
echo 'ripd=yes' >> /etc/quagga/daemons
echo 'ripngd=yes' >> /etc/quagga/daemons
echo 'isisd=yes' >> /etc/quagga/daemons
echo 'babeld=yes' >> /etc/quagga/daemons
```
In our case, the required daemons are Zebra, and BGP:
```bash
echo 'zebra=yes' > /etc/quagga/daemons
echo 'bgpd=yes' >> /etc/quagga/daemons
echo 'ospfd=no' >> /etc/quagga/daemons
echo 'ospf6d=no' >> /etc/quagga/daemons
echo 'ripd=no' >> /etc/quagga/daemons
echo 'ripngd=no' >> /etc/quagga/daemons
echo 'isisd=no' >> /etc/quagga/daemons
echo 'babeld=no' >> /etc/quagga/daemons
``` 
Different daemons of quagga suite will run on TCP protocol and listening ports will be from 2600-2800:

```bash
cat /etc/services | grep zebra
zebrasrv        2600/tcp                        # zebra service
zebra           2601/tcp                        # zebra vty
ripd            2602/tcp                        # ripd vty (zebra)
ripngd          2603/tcp                        # ripngd vty (zebra)
ospfd           2604/tcp                        # ospfd vty (zebra)
bgpd            2605/tcp                        # bgpd vty (zebra)
ospf6d          2606/tcp                        # ospf6d vty (zebra)
isisd           2608/tcp                        # ISISd vty (zebra)
```

Run the necessary services:
```bash
systemctl start zebra 
systemctl status zebra 
systemctl start bgpd 
systemctl status bgpd 
```

Check whether the services start at system startup:
```bash
systemctl is-enabled zebra.service
systemctl is-enabled bgpd.service
systemctl enable zebra.service
systemctl enable bgpd.service
```

Connect to the vtysh, bgpd and zebra terminal as follows:
```bash
vtysh
telnet localhost 2605
telnet localhost 2601
```

Manual configuration of routing in quagga can be done through the **vtysh** shell.

## <a name="quagga"></a>2. Routing configuration in quagga
The quagga configuration can be saved by command **write**. 

The **write** operation automatically split up the configuration in two different files: **/etc/quagga/zebra.conf** and **/etc/quagga/bgpd.conf**

```console
!
! Zebra configuration saved from vty
!   2021/03/29 10:26:03
!
!
interface eth0
!
interface lo
!
ip forwarding
!
!
line vty
!
```

```console
!
! Zebra configuration saved from vty
!   2021/03/29 10:26:03
!
!
router bgp 65001
 bgp router-id 10.10.4.10
 network 10.0.1.0/24
 network 10.0.2.0/24
 network 10.0.3.0/24
 neighbor 10.10.1.4 remote-as 65515
 neighbor 10.10.1.4 soft-reconfiguration inbound
 neighbor 10.10.1.5 remote-as 65515
 neighbor 10.10.1.5 soft-reconfiguration inbound
!
 address-family ipv6
 exit-address-family
 exit
!
line vty
!
```

To check the network prefixes inside quagga vtysh shell:
```console
vm1# show ip bgp neighbors 10.10.1.4 advertised-routes
BGP table version is 0, local router ID is 10.10.4.10
Status codes: s suppressed, d damped, h history, * valid, > best, = multipath,
              i internal, r RIB-failure, S Stale, R Removed
Origin codes: i - IGP, e - EGP, ? - incomplete

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.1.0/24      10.10.4.10               0          32768 i
*> 10.0.2.0/24      10.10.4.10               0          32768 i
*> 10.0.3.0/24      10.10.4.10               0          32768 i

Total number of prefixes 3

vm1# show ip bgp neighbors 10.10.1.4 received-routes
BGP table version is 0, local router ID is 10.10.4.10
Status codes: s suppressed, d damped, h history, * valid, > best, = multipath,
              i internal, r RIB-failure, S Stale, R Removed
Origin codes: i - IGP, e - EGP, ? - incomplete

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.10.0.0/16     10.10.1.4                              0 65515 i

Total number of prefixes 1
```

The route server advertises to quagga VM only the address space 10.10.0.0/16 of the vnet.
As double check, by powershell we can query the route server: 

```powershell
PS C:\> Get-AzVirtualRouterPeerLearnedRoute -ResourceGroupName test-rs -VirtualRouterName routesrv1 -PeerName bgp-conn1 | ft

LocalAddress Network     NextHop    SourcePeer Origin AsPath Weight
------------ -------     -------    ---------- ------ ------ ------
10.10.1.4    10.0.1.0/24 10.10.4.10 10.10.4.10 EBgp   65001   32768
10.10.1.4    10.0.2.0/24 10.10.4.10 10.10.4.10 EBgp   65001   32768
10.10.1.4    10.0.3.0/24 10.10.4.10 10.10.4.10 EBgp   65001   32768
10.10.1.5    10.0.1.0/24 10.10.4.10 10.10.4.10 EBgp   65001   32768
10.10.1.5    10.0.2.0/24 10.10.4.10 10.10.4.10 EBgp   65001   32768
10.10.1.5    10.0.3.0/24 10.10.4.10 10.10.4.10 EBgp   65001   32768
```

> **NOTE**
> **A change in the configuration of quagga executed in vtysh shell is immediatly reflected in routing changes.** 
>
> **The routing configuration of quagga can be also applied by adding/removing the command statements in file /etc/quagga/bgpd.conf**
> **If a manual changed in the file /etc/quagga/bgpd.conf is applied, a restart of quagga daemon is required.**
>

## <a name="quagga"></a>2. installation and setup of quagga in ubuntu VM by bash script
So far, we have discussed how to install manually quagga. The installation and setup of routing in quagga can be done all together in one shot and faster by bash script **quagga.sh**


**NOTE:**

Before running the script **quagga.sh**, customize the values of variables suitable for your deployment. 
* **asn_quagga**: Autonomous system number assigned to quagga
* **bgp_routerId**: IP address of quagga VM
* **bgp_network1**: first network advertised from quagga to the router server (inclusive of subnetmask)
* **bgp_network2**: second network advertised from quagga to the router server (inclusive of subnetmask)
* **bgp_network3**: third network advertised from quagga to the router server (inclusive of subnetmask)
* **routeserver_IP1**: first IP address of the router server 
* **routeserver_IP2**: second IP address of the router server


To run **quagga.sh**:
* connect in SSH to the ubuntu VM
* rise the privilege by command: **sudo -i** (or **sudo su -**)
* copy the content of **quagga.sh** in ubuntu VM (i.e. in the folder /root)
* set executable attribute the bash script by command: **chown +x quagga.sh**
* run the script with root privilege

At the end the BGP session between the quagga and route server is created.
Check the BGP dvertisements inside **vtysh** quagga shell by the command:
```console
show ip bgp
```


## <a name="quagga"></a>ANNEX1: cloud-init file to install and setup quagga

```yaml
#cloud-config
package_update: true
packages:
  - quagga
write_files:
  - path: /run/routertmp/zebraconf.txt
    owner: root:root
    permissions: '0664'
    content: |
      !
      interface eth0
      !
      interface lo
      !
      ip forwarding
      !
      line vty
      !
  - path: /run/routertmp/quaggaconf.txt
    owner: root:root
    permissions: '0664'
    content: |
      !
      router bgp 65001
      bgp router-id 10.10.4.10
      network 10.0.1.0/24
      network 10.0.2.0/24
      network 10.0.3.0/24
      neighbor 10.10.1.4 remote-as 65515
      neighbor 10.10.1.4 soft-reconfiguration inbound
      neighbor 10.10.1.5 remote-as 65515
      neighbor 10.10.1.5 soft-reconfiguration inbound
      !
      address-family ipv6
      exit-address-family
      exit
      !
      line vty
      !
runcmd:
  # Enable IP forward
  - [ sed, -i, -e, '$a\net.ipv4.ip_forward = 1', /etc/sysctl.conf]
  # Apply kernel parameters
  - [ sysctl, --system ]
  - [ apt, install, quagga, quagga-doc, -y ]
  - [ sh, -c, 'mkdir -p /var/log/quagga && sudo chown quagga:quagga /var/log/quagga' ]
  - [ sh, -c, 'touch /var/log/zebra.log' ]
  - [ sh, -c, 'chown quagga:quagga /var/log/zebra.log' ]
  - [ sh, -c, 'touch /etc/quagga/babeld.conf' ]
  - [ sh, -c, 'touch /etc/quagga/bgpd.conf' ]
  - [ sh, -c, 'touch /etc/quagga/isisd.conf' ]
  - [ sh, -c, 'touch /etc/quagga/ospf6d.conf' ]
  - [ sh, -c, 'touch /etc/quagga/ospfd.conf' ]
  - [ sh, -c, 'touch /etc/quagga/ripd.conf' ]
  - [ sh, -c, 'touch /etc/quagga/ripngd.conf' ]
  - [ sh, -c, 'touch /etc/quagga/vtysh.conf' ]
  - [ sh, -c, 'touch /etc/quagga/zebra.conf' ]
  - [ sh, -c, 'chown quagga:quagga /etc/quagga/babeld.conf && chmod 640 /etc/quagga/babeld.conf' ]
  - [ sh, -c, 'chown quagga:quagga /etc/quagga/bgpd.conf && chmod 640 /etc/quagga/bgpd.conf' ]
  - [ sh, -c, 'chown quagga:quagga /etc/quagga/isisd.conf && chmod 640 /etc/quagga/isisd.conf' ]
  - [ sh, -c, 'chown quagga:quagga /etc/quagga/ospf6d.conf && chmod 640 /etc/quagga/ospf6d.conf' ]
  - [ sh, -c, 'chown quagga:quagga /etc/quagga/ospfd.conf && chmod 640 /etc/quagga/ospfd.conf' ]
  - [ sh, -c, 'chown quagga:quagga /etc/quagga/ripd.conf && chmod 640 /etc/quagga/ripd.conf' ]
  - [ sh, -c, 'chown quagga:quagga /etc/quagga/ripngd.conf && chmod 640 /etc/quagga/ripngd.conf' ]
  - [ sh, -c, 'chown quagga:quaggavty /etc/quagga/vtysh.conf && chmod 660 /etc/quagga/vtysh.conf' ]
  - [ sh, -c, 'chown quagga:quagga /etc/quagga/zebra.conf && chmod 640 /etc/quagga/zebra.conf' ]
  - [ sh, -c, 'echo "zebra=yes" > /etc/quagga/daemons' ]
  - [ sh, -c, 'echo "bgpd=yes" >> /etc/quagga/daemons' ]
  - [ sh, -c, 'echo "ospfd=no" >> /etc/quagga/daemons' ]
  - [ sh, -c, 'echo "ospf6d=no" >> /etc/quagga/daemons' ]
  - [ sh, -c, 'echo "ripd=no" >> /etc/quagga/daemons' ]
  - [ sh, -c, 'echo "ripngd=no" >> /etc/quagga/daemons' ]
  - [ sh, -c, 'echo "isisd=no" >> /etc/quagga/daemons' ]
  - [ sh, -c, 'echo "babeld=no" >> /etc/quagga/daemons' ]
  - [ sh, -c, 'cat /run/routertmp/zebraconf.txt > /etc/quagga/zebra.conf' ]
  - [ sh, -c, 'cat /run/routertmp/quaggaconf.txt > /etc/quagga/bgpd.conf' ]
  - [ systemctl, enable, zebra.service ]
  - [ systemctl, enable, bgpd.service ]
  - [ systemctl, start, zebra ]
  - [ systemctl, start, bgpd ]
```

In cloud-init the recommended path to write temporary files is **/run/** 
cloud-init writes the quagga config files in temporary folder: **/run/routertmp/**
 

## <a name="quagga"></a>ANNEX2

```bash
Prevent a daemon from running:
sudo unlink /etc/systemd/system/multi-user.target.wants/bgpd.service
sudo unlink /etc/systemd/system/multi-user.target.wants/isisd.service
sudo unlink /etc/systemd/system/multi-user.target.wants/ospf6d.service
sudo unlink /etc/systemd/system/multi-user.target.wants/ospfd.service
sudo unlink /etc/systemd/system/multi-user.target.wants/pimd.service
sudo unlink /etc/systemd/system/multi-user.target.wants/ripd.service
sudo unlink /etc/systemd/system/multi-user.target.wants/ripngd.service
sudo unlink /etc/systemd/system/multi-user.target.wants/zebra.service

Reinstate a daemon to run:
sudo ln -st /etc/systemd/system/multi-user.target.wants /lib/systemd/system/bgpd.service
sudo ln -st /etc/systemd/system/multi-user.target.wants /lib/systemd/system/isisd.service
sudo ln -st /etc/systemd/system/multi-user.target.wants /lib/systemd/system/ospf6d.service
sudo ln -st /etc/systemd/system/multi-user.target.wants /lib/systemd/system/ospfd.service
sudo ln -st /etc/systemd/system/multi-user.target.wants /lib/systemd/system/pimd.service
sudo ln -st /etc/systemd/system/multi-user.target.wants /lib/systemd/system/ripd.service
sudo ln -st /etc/systemd/system/multi-user.target.wants /lib/systemd/system/ripngd.service
sudo ln -st /etc/systemd/system/multi-user.target.wants /lib/systemd/system/zebra.service

Restart the daemons:
sudo systemctl restart zebra.service
sudo systemctl restart bgpd.service
sudo systemctl restart pimd.service
sudo systemctl restart ripd.service
sudo systemctl restart ripngd.service
sudo systemctl restart ospf6d.service
sudo systemctl restart isisd.service
sudo systemctl restart ospfd.service
```



<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"

<!--Link References-->

