<properties
pageTitle= 'IPv6 in Azure hub-spoke VNets'
description= "IPv6 in Azure with hub-spoke VNets"
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
   ms.date="02/09/2019"
   ms.author="fabferri" />

## Example of Azure hub-spoke Virtual Network with IPv6

The article talks through a deployment of Azure VNet (Virtual Network) with IPv6 by ARM template. 
An overview of network diagram is shown below.

[![1]][1]

The configuration is based on:
* the Azure VNets are configured in dual-stack IPv4 and IPv6
* configuration is based on three VNets: one hub VNet and two spoke VNets
* an Azure hub VNet with IPv4 10.0.0.0/24 and IPv6 ace:cab:deca::/48 address space. In the hub VNet are configured three subnets **subnet1, subnet2, subnet3**
* an Azure Spoke1 VNet with IPv4 10.0.0.0/24 and IPv6 ace:cab:deca::/48 address space
* an Azure Spoke2 VNet with IPv4 10.0.0.0/24 and IPv6 ace:cab:deca::/48 address space
* a Spoke1 VNet is in peering with hub VNet
* a Spoke2 VNet is in peering with hub VNet 
* the VNets are all deployed in different Azure regions
* all the VMs run un dual stack IPv4 and IPv6
* two VMs **h11, h12** connected to the **subnet1** run with Windows 2019 and IIS
* in the hub VNet is configured an external basic load balancer with frontend IPv6 and IPv4 and a backend pool associated with the NIC of **h11, h12**
* an **nva** VM is connected to the **subnet3**, configured with IPv6 forwarder
* two UDRs **RT-subnet1, RT-subnet2** are applied respectively to the **subnet1** and **subnet2** to enforce the IPv6 traffic to transit through the **nva**
* a UDR **RT-spoke1** is applied to the spoke1 VNet to force the traffic to trasit through the **nva** VM
* a UDR **RT-spoke2** is applied to the spoke2 VNet to force the traffic to trasit through the **nva** VM
* an NSG is applied to each subnet to filter the traffic in ingress
* the ARM template **ipv6.json** creates hub, spoke1 and spoke2 VNets with all Azure VMs
* the ARM template **ipv6.json** use custom script extensions to make some VM setup at boostrap. In particular, a bash script **enableipv6withforwarding.sh** is invoked after the boostrap of **nva** VM to enable the ipv6 forwarding. 
* the ARM template **ipv6-standaloneVM.json** creates a VNet5 with single standone VM
The ARM template **ipv6.json** installs the VMs with the following OS:
* **h11**, **h12**: Windows Server 2019
* **h2**, **nva**, **s1**, **s2**: CentOS 7.6

In the ARM template **ipv6.json** two arrays **vmArraywithLB** and **vmArray** define the specs of the VMs:
* the **vmArraywithLB** array contains the specs of the VMs with NIC associated to the backend pool of Azure load balancer.
* the **vmArray** array contains the specs of the VMs not associated with the Azure load balacer
A customization with different OS can be done by changing the values of variables: "imagePublisher", "imageOffer", "OSVersion" in the ARM template. After running the ARM template, some further steps are required to complete the setup.

A network diagram with IPv6 UDRs is shown underneath:

[![2]][2]

Example of traffic in transit through the **nva**:

[![3]][3]

Effective routes in the NIC of **s1** and **h2** VMs:
[![4]][4]

IPv6 traffic through the external load balacer:

[![5]][5]

How to use TCPdump to track the transit of iperf traffic through the **nva**:
[![6]][6]


### <a name="IPv6"></a>1. Annex: setup of mysql in s1 VM
```console
yum -y update
wget https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm
rpm -ivh mysql80-community-release-el7-3.noarch.rpm
yum -y install mysql-server
yum -y update
systemctl enable mysqld
systemctl start mysqld
```

* Get your generated random **root** rassword:
```bash
grep 'A temporary password is generated for root@localhost' /var/log/mysqld.log |tail -1
```

```console
mysql_secure_installation
  Securing the MySQL server deployment.
  Enter password for user root:

  The existing password for the user account root has expired. Please set a new password.
  New password:

  Using existing password for root.
  Estimated strength of the password: 100
  Change the password for root ? No
  Remove anonymous users? Y
  Disallow root login remotely? Y
  Remove test database and access to it? No
  Reload privilege tables now? Y
  All done!
```
* Check you are able to login in mysql:
```console
mysql -u root -p
```
NOTE
> When you omit the ENGINE option, the default storage engine is used. In MySQL 8.0 the default engine is InnoDB.
> The command to set the storage engine is NOT required:
> set storage_engine = InnoDB;


* Create a text file (i.e. **myfile.sql**) with SQL instructions to create table and load data in the tables.
```console
mysql> source myfile.sql
```

* Login in mysql:
mysql -u root -p   

* check login in mysql through IPv6:

```console
mysql -u root -p --bind-address=abc:abc:abc:abc::5
```
* create a user and add GRANT privilege:
```console
mysql> CREATE USER 'New_Username_mysql'@'%' IDENTIFIED BY 'Password_for_New_Username';

mysql> GRANT ALL PRIVILEGES ON *.* TO 'New_Username_mysql'@'%' WITH GRANT OPTION;
```
Note
> *New_Username_mysql*: it is the new username to access remolty to mysql
> *Password_for_New_Username*: it is the password associated with the new user *New_Username_mysql*

* check the login with the new account 'New_Username_mysql'
```console
mysql -u New_Username_mysql -p
password: Password_for_New_Username
```

### <a name="IPv6"></a>2. Annex: setup of mysql client in s2 VM
```console
yum -y update
wget https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm
rpm -ivh mysql80-community-release-el7-3.noarch.rpm
yum -y install mysql
yum -y update
```

* check the remote login from s2 to mysql in s1:
```console
mysql --host=abc:abc:abc:abc::5 --user=New_Username_mysql --password=Password_for_New_Username
```
* show connection information: 
```console
mysql> STATUS
```

* check the transit of communication between mysql server and mysql client through nva:
```bash
tcpdump -i eth0 -nn -qq 'ip6 and net abc:abc:abc:abc::/64 and net cab:cab:cab:cab::/64'
```

<!--Image References-->

[1]: ./media/network-diagram.png "network overview"
[2]: ./media/network-diagram-with-udr.png "network diagram with UDR"
[3]: ./media/flows.png "communication flows"
[4]: ./media/effective-routes.png "effective routes"
[5]: ./media/elb.png "access from internet to elb"
[6]: ./media/iperf.png "iperf"

<!--Link References-->

