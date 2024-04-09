<properties
pageTitle= 'Azure standard internal load balancer with multiple frontend IPs and multiple backend address pools'
description= "ARM template to deploy an Azure standard load balancer with multiple frontend IPs and backend address pools"
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
   ms.date="15/04/2020"
   ms.author="fabferri" />

# Azure standard internal load balancer with multiple frontend IPs and multiple backend address pools
The ARM template aims to create one VNet with multiple subnets and an internal standard load balancer with multiple frontend IPs and multiple backend address pools.
The network diagram is reported below:

[![1]][1]

> [!NOTE1]
> Before spinning up the ARM template you should:
> * set the Azure subscription name in the file **ilb-multiple-fe-be.ps1**
> * set the administrator username and password in the file **ilb-multiple-fe-be.ps1**
>

The internal load balancer is configured to serve multiple services running in the backend VMs.
The configuration creates multiple LB rules with the following mapping:

```console
[frontend-IP4, tcp port 80]-> [backend-pool4, tcp port 80] 
[frontend-IP5, tcp port 80]-> [backend-pool5, tcp port 8085] 
[frontend-IP6, tcp port 80]-> [backend-pool6, tcp port 8086] 
[frontend-IP7, tcp port 80]-> [backend-pool7, tcp port 8087] 
...
[frontend-IP253, tcp port 80]-> [backend pool7, tcp port 8333] 
```
Each backend pool includes the two NICs of backend VMs:

```console
config(nic-vm1-backend): [priv-subnet2[10.0.2.4], backend-pool4]
config(nic-vm2-backend): [priv-subnet2[10.0.3.4], backend-pool4]

config(nic-vm1-backend): [priv-subnet2[10.0.2.5], backend-pool5]
config(nic-vm2-backend): [priv-subnet2[10.0.3.5], backend-pool5]

config(nic-vm1-backned): [priv-subnet2[10.0.2.6], backend-pool6]  
config(nic-vm2-backend): [priv-subnet2[10.0.3.6], backend-pool6]
...
config(nic-vm1-backend): [priv-subnet2[10.0.2.253], backend-pool253]
config(nic-vm2-backend): [priv-subnet2[10.0.3.253], backend-pool253]

```

The backend VMs are configured with apache httpd with virtual host; in each VM are configured 254 virtual hosts each served from a private IP and custom port:

```console
nic-vm1-backend: {virtual interface: [eth0:4, IP:10.0.2.4], httpd-virtual host: 10.0.2.4:80, homepage: /var/www/html/www4.com/index.html }
nic-vm1-backend: {virtual interface: [eth0:4, IP:10.0.2.5], httpd-virtual host: 10.0.2.5:8085, homepage: /var/www/html/www5.com/index.html }
nic-vm1-backend: {virtual interface: [eth0:4, IP:10.0.2.6], httpd-virtual host: 10.0.2.6:8086, homepage: /var/www/html/www6.com/index.html }
...
nic-vm1-backend: {virtual interface: [eth0:253, IP:10.0.2.253], httpd-virtual host: 10.0.2.253:8333,, homepage: /var/www/html/www253.com/index.html }
```

The heatlprobes are configured on the same tcp port of data traffic:

```console
[backend-pool4, tcp port 80]    - [healthprobe, source: 168.63.129.16, tcp port 80]
[backend-pool5, tcp port 8085]  - [healthprobe, source: 168.63.129.16, tcp port 8085]
[backend-pool6, tcp port 8086]  - [healthprobe, source: 168.63.129.16, tcp port 8086]
[backend-pool7, tcp port 8087]  - [healthprobe, source: 168.63.129.16, tcp port 8087]
...
[backend pool7, tcp port 8333]  - [healthprobe, source: 168.63.129.16, tcp port 8333]
```
All load balancer health probes originate from the IP address 168.63.129.16 as their source. 


The apache httpd virtual hosts can be configured by bash script **virtualhost.sh**. You can run the script in each backend VM. Before running the bash script check the network assigned to the nic:
* the first VM, with nic attached to the subnet, has IPs in the range 10.0.2.X
* the first VM, with nic attached to the subnet, has IPs in the range 10.0.3.X

The script has been verified with CentOS 8 VMs.
The manual steps to create httpd virtual host are reported in ANNEX.

The diagram below shows the internal load balancer rule:  

[![2]][2]

The Azure VMs in the backend of the ILB run with httpd daemon listen on different IP addresses and port as shown in the diagram:

[![3]][3]

To create multiple frontend IPs and backend address pools is used a copy element iteration on variables.
The copy element iteration has the following structure:

```json
"copy": {
  "name": "<name-of-loop>",
  "count": <number-of-iterations>,
  "mode": "serial" <or> "parallel",
  "batchSize": <number-to-deploy-serially>
}
```
In our case the iteration is used to create a load balancer configuration variable for the two NIC of backend VMs:
```json
"copy": [
            {
                "name": "ipConf-nic0",
                "count": "[variables('ipconfigNum')]",
                "input": {
                    "name": "[concat('IpConf-', string(add(variables('offset'),copyIndex('ipConf-nic0'))) )]",
                    "properties": {
                        "primary": "[if(equals(copyIndex('ipConf-nic0'), 0), bool('true'), bool('false'))]",
                        "privateIPAllocationMethod": "Static",
                        "privateIPAddress": "[concat('10.0.2.', string(add(variables('offset'),copyIndex('ipConf-nic0')))  )]",
                        "publicIPAddress": "[if(equals(copyIndex('ipConf-nic0'), 0), variables('pipObject1'), json('null'))]",
                        "subnet": {
                            "id": "[resourceId('Microsoft.Network/virtualNetworks/subnets', variables('vNet1').name, variables('vNet1').subnet2Name)]"
                        },
                        "loadBalancerBackendAddressPools": [
                            {
                                "id": "[resourceId('Microsoft.Network/loadBalancers/backendAddressPools', variables('lbName'), concat( variables('lbBackEndPoolName') ,add(variables('offset'),copyIndex('ipConf-nic0')) ) )]"
                            }
                        ]
                    }
                }
            },
            {
                "name": "ipConf-nic1",
                "count": "[variables('ipconfigNum')]",
                "input": {
                    "name": "[concat('IpConf-', string(add(variables('offset'),copyIndex('ipConf-nic1'))) )]",
                    "properties": {
                        "primary": "[if(equals(copyIndex('ipConf-nic1'), 0), bool('true'), bool('false'))]",
                        "privateIPAllocationMethod": "Static",
                        "privateIPAddress": "[concat('10.0.3.', string(add(variables('offset'),copyIndex('ipConf-nic1')))  )]",
                        "publicIPAddress": "[if(equals(copyIndex('ipConf-nic1'), 0), variables('pipObject2'), json('null'))]",
                        "subnet": {
                            "id": "[resourceId('Microsoft.Network/virtualNetworks/subnets', variables('vNet1').name, variables('vNet1').subnet2Name)]"
                        },
                        "loadBalancerBackendAddressPools": [
                            {
                                "id": "[resourceId('Microsoft.Network/loadBalancers/backendAddressPools', variables('lbName'), concat( variables('lbBackEndPoolName') , add(variables('offset'),copyIndex('ipConf-nic1'))  )  )]"
                            }
                        ]
                    }
                }
            },
        ...
]
```
but also to create an iteration on frontend configuration, backend configuration and rule configuration of the internal load balancer:

```json
"copy": [
            {
                "name": "lbFrontEndConf",
                "count": "[variables('ipconfigNum')]",
                "input": {
                    "name": "[concat( variables('lbFrontEndName') , add(variables('offset'),copyIndex('lbFrontEndConf')) )]",
                    "properties": {
                        "subnet": {
                            "id": "[variables('lbSubnetRef')]"
                        },
                        "privateIPAddress": "[concat('10.0.1.', add(variables('offset'), copyIndex('lbFrontEndConf')) )]",
                        "privateIPAllocationMethod": "Static"
                    }
                }
            },
            {
                "name": "lbBackEndPoolConf",
                "count": "[variables('ipconfigNum')]",
                "input": {
                    "name": "[concat( variables('lbBackEndPoolName') , add(variables('offset'), copyIndex('lbBackEndPoolConf')) )]"

                }
            },
            {
                "name": "lbRules",
                "count": "[variables('ipconfigNum')]",
                "input": {
                    "name": "[concat( variables('lbRuleName') , add(variables('offset'),copyIndex('lbRules')) )]",
                    "properties": {
                        "frontendIPConfiguration": {
                            "id": "[resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', variables('lbName'), concat( variables('lbFrontEndName') , add(variables('offset'),copyIndex('lbRules')) ) )]"
                        },
                        "backendAddressPool": {
                            "id": "[resourceId('Microsoft.Network/loadBalancers/backendAddressPools', variables('lbName'), concat( variables('lbBackEndPoolName') , add(variables('offset'),copyIndex('lbRules')) ) )]"
                        },
                        "probe": {
                            "id": "[resourceId('Microsoft.Network/loadBalancers/probes', variables('lbName'), concat(variables('lbprobeName'),  add(variables('offset'),copyIndex('lbRules')) )  )]"
                        },
                        "protocol": "Tcp",
                        "frontendPort": 80,
                        "backendPort": "[if(  equals(copyIndex('lbRules'), 0), 80, add(8080, add(variables('offset'),copyIndex('lbRules')) )  )]",
                        "loadDistribution": "Default",
                        "enableFloatingIP": false,
                        "idleTimeoutInMinutes": 4
                    }
                }
            },
]            
```
the copy() iteration for all variable has a "count" value set to the [variables('ipconfigNum')].  

## Check the health probes traffic 
All load balancer health probes originate from the IP address 168.63.129.16 as their source.
To check the health probe traffic we can run tcpdump in the backend VMs associated with the ILB backend pool:

```console
[root@backendVM1 ~]# tcpdump -n host 168.63.129.16 and host 10.0.2.5
[root@backendVM2 ~]# tcpdump -n host 168.63.129.16 and host 10.0.3.5
```
the tcpdump commands shows the health probe messages associated with the health probe 5 (port 8085) received on the backend VMs. 


## Queries all the web sites

In one of VMs in vnet4, vnet5 or vnet6 run the bash command:

```bash
[root@vm4 ~]# for i in {4..253}; do echo -e "\033[1;32m"; curl 10.0.1.$i:80; done; echo -e "\033[0m"
```
where:
* "\033[1;32m": terminal green colour  
* "\033[0m"   : no colour

The traffic can be checked the backend VMs running the tcpdump:
```
[root@backendVM1 ~]# tcpdump -nn -q -i any host 10.0.4.10
[root@backendVM2 ~]# tcpdump -nn -q -i any host 10.0.4.10
```

The parameters:
* -nn: don’t resolve hostnames or port names
* -q: be less verbose (quiet) with output. it shows less protocol information.


[![4]][4]

## Caveats
*   The template works fine when a network /24 to the subnet1 and a network /23 to the subnet2. In fact, the subnet2 required a network /23 to allocate 250 private IP addresses for the nic-backendVM1 and 250 private IP addresses nic-backendVM2. 
*   The bash script to create the virtual hosts in backend VMs works correctly if a network /23 is assigned to subnet2. for larger range of IPs the ARM template and bash shell need to be reviewed and adapted. 

## ANNEX: create Apache Virtual Hosts for different ports in CentOS 8
Apache Virtual Hosts allows you to run more than one website on a single VM. With Virtual Hosts, you can specify the site document root (the directory containing the website files). The document root is the directory in which the website files for a domain name are stored and served in response to requests.

### Setup multiple IPs in the same network adapter

The virtual interfaces of the physical interface eth0 can have the names eth0:0, eth0:1, eth0:2 and so on.
For CentOS the directory responsible for permanent IP address assignment is /etc/sysconfig/network-scripts. In this directory you need to create a file corresponding to your new virtual interface.
Navigate to the network scripts folder:

```console
cd /etc/sysconfig/network-scripts
```
List the related ifcfg files:

```console
ls ifcfg-*
```
For each IP configuration, create a configuration file:

```console
touch ifcfg-eth0:5
vi ifcfg-eth0:5
```
Add content to the file,

```console
DEVICE=eth0:5
NAME=eth0:5
BOOTPROTO=static
ONBOOT=yes
TYPE=Ethernet
IPADDR=10.0.2.5
NETMASK=255.255.255.0
NM_CONTROLLED=yes
```
Note that the device's name will be changed to the name of the virtual interface (eth0:5 here), and the hardware address will remain the same (because physical device is the same). The NAME and DEVICE attributes have to match the virtual interface eth0:5

To reload a new setting:

```console
systemctl restart NetworkManager
nmcli networking off; nmcli networking on
```
or

```console
nmcli networking off; nmcli networking on
```

Make sure the changes are successful and the new (aliased) interfaces are ready:

```
ifconfig
```



### Install Apache on CentOS 8

```console
dnf -y update
```

Use dnf command to install httpd package:

```console
dnf -y install httpd
```

Enable the Apache webserver to start after reboot, start httpd daemon and check the status:

```console
systemctl enable httpd
systemctl start httpd
systemctl status httpd
```
 Create a directory where you will keep all your website’s files:


### Set up multiple instances of Apache

The **Listen** directive instructs Apache httpd to accept incoming requests on the specified port or address-and-port combination; by default, it responds to requests on all IP interfaces. If only a port number is specified, the server listens to the given port on all interfaces. If an IP address is given as well as a port, the server will listen on the given port and interface.
**Listen** is now a required directive (mandatory). If it is not in the config file **/etc/httpd/conf/httpd.conf**, the server will fail to start.
Multiple **Listen** directives may be used to specify several addresses and ports to listen to.
For example, to make the server accept connections on both port 80 and port 8080:

```console
Listen 80
Listen 8080
```

To make the httpd accept connections on two specified IP addresses and port numbers, i.e. listen for IP address 10.0.2.4 on port 80 and for IP address 10.0.2.5 on port 8080:

```console
vi /etc/httpd/conf/httpd.conf
```

Add/edit the following lines:

```console
Listen 10.0.2.4:80
Listen 10.0.2.5:8080
```
Restart Apache httpd to make these changes take effect:
 
 ```
 systemctl restart httpd
 ```

 ### Create the directory structure
 Make a directory structure which will hold the web pages. This directory is known as "document root" for the domain.
 By default Apache document root directory is /var/www/html/
 Create two folders for websites www4.com and www5.com in the default Apache document root directory:

```console 
mkdir -p /var/www/html/www4.com
mkdir -p /var/www/html/www5.com
```

### Create test web pages for each virtual host
you need to create an index.html file for each website which will identify that specific domain.


vi /var/www/html/www4.com/index.html
with following content:

```html
<html>
<head>
  <title>www4.com</title>
</head>

<body>
  <h1>the virtual host www4.com is working!</h1>
</body>
</html>
```
vi /var/www/html/www5.com/index.html

```html
<html>

<head>
  <title>www5.com</title>
</head>

<body>
  <h1>The virtual host www5.com is working!</h1>
</body>
</html>
```

### Set up ownership and permissions
change the ownership of these two virtual directories to apache, so that Apache can read and write data.

```console
chown -R apache:apache /var/www/html/www4.com
chown -R apache:apache /var/www/html/www5.com
```

You should also make the Apache document root /var/www/html directory world readable, so that everyone can read files from that directory.

```console
chmod -R 755 /var/www/html
```
### Create virtual host files
There are a few ways to set up a virtual host. You can either add all Virtual Host Directives in a single file or create a new configuration file for each Virtual Host Directive. Generally, you should prefer the second approach, which is more maintainable. By default, Apache is configured to load all configuration files that ends with **.conf** from the **/etc/httpd/conf.d/** directory.
For each website has to be created a virtual host configuration file. The name of each configuration file must end with **.conf**

```console
vi /etc/httpd/conf.d/www4.com.conf
```
Add the following content:

```console
<VirtualHost 10.0.2.4:80>

ServerName www4.com
ServerAlias www4.com
DocumentRoot /var/www/html/www4.com
ErrorLog /var/log/httpd/www4.com-error.log
CustomLog /var/log/httpd/www4.com-access.log combined

</VirtualHost>
```

Create a virtual host file for website www5.com.
```console
vi /etc/httpd/conf.d/www5.com.conf
```

Add the following content:

```console
<VirtualHost 10.0.2.5:8085>

ServerName www5.com
ServerAlias www5.com
DocumentRoot /var/www/html/www5.com
ErrorLog /var/log/httpd/www5.com-error.log
CustomLog /var/log/httpd/www5.com-access.log combined

</VirtualHost>
```
 
 You can check the syntax of files with the following command:
 
 ```console
 apachectl configtest
```

### SELinux
SELinux is enable by default in CentOS8. Because of SELinux policy, a service is normally allowed to run on a restricted list of well-known ports. In the case of the Apache httpd service, this list is 80, 443, 488, 8008, 8009, 8443

To check the status and the mode in which SELinux is running:
```console
sestatus
```
To get the **semanage** command install:

```console
dnf install -y setroubleshoot-server
```
Installation of package **selinux-policy-devel** is only required to get the **sepolicy** command (not required in this case).

```
# semanage port -l | grep http
http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
http_cache_port_t              udp      3130
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
pegasus_https_port_t           tcp      5989
```

To assign a range of ports numbers for httpd  and assign to a specific port, use the command:
```console
semanage port -a -t http_port_t -p tcp 8085-8091
```
Command is slow; be patient and wait for the execution!

The options:
    -a option is to add a new port, 
    -t option specifies the SELinux type, 
    -p option is to specify the protocol to use (in this case tcp).

To see the list (-l option) of all ports with customizations (-C option):
```console
# semanage port -lC
SELinux Port Type              Proto    Port Number

http_port_t                    tcp      8085-8091
```


### Test the virtual hosts
Open your web browser and go to the URLs

http://10.0.2.4:80  

http://10.0.2.5:8085



<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/ilb-rule.png "internal load balancer rule"
[3]: ./media/httpd.png "httpd listen on different IP and ports"
[4]: ./media/http-traffic.png "http traffic"


<!--Link References-->

