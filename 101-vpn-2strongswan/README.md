<properties
   pageTitle="site-to-site VPN between two strongSwan gateways in Azure"
   description="configuration of a VPN IPSec tunnel between two strongSwan in two different Azure Virtual Networks"
   services=""
   documentationCenter="na"
   authors="fabferri"
   manager=""
   editor=""/>

<tags
   ms.service="Configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="na"
   ms.date="31/05/2017"
   ms.author="fabferri" />

#  Site-to-site VPN with two strongSwan gateways in Azure
Strongswan is an open source implementation of IPsec protocol that supports Internet Keying Exchange (IKE) V1 & V2. Strongswan stands for strong Secure WAN (strongS/WAN). 
In this article, the strongSwan gateways are deployed in two Azure VMs attached to  different Virtual Networks (VNets). An IPSec tunnel is created between two sites, site A (left side) and site B (right side) using a preshared key.

##  <span style="color:darkblue">Network topology with two strongSwan</span>
Here the network topology in use in the setup:

[![0]][0]

The figure shows the placement of a strongSwan based VPN gateway; a secure communication channel is established between the two private networks 10.0.1.0/24 and 10.0.2.0/24.

### code/script snippet

- **azuredeploy.json**: azure template to deploy a VNet with a CentOS Virtual Machine
- **azuredeploy1.parameters.json**: azure template file to feed the ARM template with custom value. It creates the deployment in Site A (left side). Set the values of user anem of the administrator and password of strongSwan in the side A.  
- **azuredeploy2.parameters.json**: azure template file to feed the ARM template with custom value. It creates the deployment in Site B (right side). Set the values of user anem of the administrator and password of strongSwan in the side B.  
- **azureSite.ps1**: powershell script used to deploy the azuredepoy.json template. Before running the powershell, customize the input parameters with your Azure subscription name and deployment names
- **SiteA_ipsec.conf**: file ipsec.conf of the strongSwan in side A.
- **SiteB_ipsec.conf**: file ipsec.conf of the strongSwan in side B.
- **logs.txt**: log file related to the IPSec tunnel between the side A and side .B

## <span style="color:darkblue">strongSwan installation in CentOS 7 </span>
Binary packages (rpm ) of strongswan are available in  Extra Packages for Enterprise Linux (EPEL) repository. After the EPEL is enabled, we can install StrongSwan:

**sudo yum update**

**sudo yum install epel-release**
   
**sudo yum install strongswan openssl**

## <span style="color:darkblue">Routing setup </span>
It is important to make sure the routing of Strongswan VPN Gateways; an Azure Virtual Machine (VM) from the side A need to communicate with an Azure VM in the network of site B.
To allow forwarding in the Linux kernel, add to the file **/etc/sysctl.conf** the following entries:

**sudo vi /etc/sysctl.conf**

	net.ipv4.ip_forward=1
	net.ipv4.conf.all.accept_redirects = 0
	net.ipv4.conf.all.send_redirects = 0
 
Save the file, then apply the change:
**sudo sysctl -p**


## <span style="color:darkblue">Check the firewall </span>
Using the CentOs in Azure market place, the VM is created withfirewall daemon disabled. It is a good practise to check the list of rules in iptables:
	
<pre><b>$    sudo iptables -L</b>
	Chain INPUT (policy ACCEPT)
	target     prot opt source               destination

	Chain FORWARD (policy ACCEPT)
	target     prot opt source               destination

	Chain OUTPUT (policy ACCEPT)
	target     prot opt source               destination
</pre>
and the status of the firewall

<pre><b>$ sudo systemctl list-unit-files | grep firewalld</b>
firewalld.service                             disabled
</pre>
## <span style="color:darkblue">strongSwan ipsec.conf file</span>
The main ipsec configuration file of strongSwan is located in  **/etc/strongswan/ipsec.conf**. 

**ipsec.conf** configuration file consists of three different section types:

- **config** setup defines general configuration parameters. it starts a global configuration section. Most of the VPN configuration is attached to a specific connection block, but this session contains parameters set globally.
	
	charondebug="all" # log all the encryption and authentication  

	uniqueids=no      # Allow more than one connection from a given user/endpoint

- **conn <name>** defines a connection
- **ca <name>** defines a certification authority.In current setup **ca** session won't be used.

There can be only one **config** setup section, but an unlimited number of **conn** and **ca** sections. 

Connection descriptions are defined in terms of a left endpoint and a right endpoint. 
For example, the two parameters **leftid** and **rightid** specify *the identity of the left* and the *identity of the right* endpoint. For every connection description an attempt is made to figure out whether the local endpoint should act as the left or the right endpoint. This is done by matching the IP addresses defined for both endpoints with the IP addresses assigned to local network interfaces. If a match is found then the role (left or right) that matches is going to be considered "local". If no match is found during startup, "left" is considered "local".

Connections configured with **auto=start** will automatically be established when the daemon is started.

[![1]][1]
####  <span style="color:darkblue">h1 (strongSwan side A-the left side)</span>

	# ipsec.conf - strongSwan IPsec configuration file
	config setup
        charondebug="all"
        uniqueids=yes
        strictcrlpolicy=no

	# Add connections here.
	conn %default

	# Sample VPN connections
	conn s2stunnel
        left=192.168.1.5
        leftsubnet=10.0.1.0/24
        leftid=192.168.1.5
        right=52.178.221.22
        rightsubnet=10.0.2.0/24
        rightid=192.168.2.5
        ike=aes256-sha2_256-modp1024!
        esp=aes256-sha2_256!
        keyingtries=0
        ikelifetime=1h
        lifetime=8h
        dpddelay=30
        dpdtimeout=120
        dpdaction=clear
        authby=secret
        auto=start
        keyexchange=ikev2
        type=tunnel


####  <span style="color:darkblue">h1 (strongSwan side B-the right side)</span>

	# ipsec.conf - strongSwan IPsec configuration file
	config setup
        charondebug="all"
        uniqueids=yes
        strictcrlpolicy=no

	# Add connections here.
	conn %default

	# Sample VPN connections
	conn s2stunnel
        left=192.168.2.5
        leftsubnet=10.0.2.0/24
        leftid=192.168.2.5
        right=52.169.149.106
        rightsubnet=10.0.1.0/24
        rightid=192.168.1.5
        ike=aes256-sha2_256-modp1024!
        esp=aes256-sha2_256!
        keyingtries=0
        ikelifetime=1h
        lifetime=8h
        dpddelay=30
        dpdtimeout=120
        dpdaction=clear
        authby=secret
        auto=start
        keyexchange=ikev2
        type=tunnel


## <span style="color:darkblue">strongSwan ipsec.secrets file</span>
The users account and secrets  (shared keys, password of the private key) are stored in the **/etc/strongswan/ipsec.secrets** file.

	192.168.1.5 : PSK "test12345"
	192.168.2.5 : PSK "test12345"

in our configuration the strongSwan gateways have the same shared secrets file.

## <span style="color:darkblue"> Start the strongSwan deamon</span>
After setting up the config files [**ipsec.conf**,**ipsec.secrets**] on both sides (side A and side B), start the strongswan daemon (charon) using the following command:

**sudo strongswan start**

To check the status of tunnel on both machines, run the following command:

**sudo strongswan status**

**sudo  strongswan statusall**

**sudo strongswan status <NAME_TUNNEL>**

**sudo strongswan statusall <NAME_TUNNEL>**

XFRM ("transform")is  the Linux kernel's IP framework for transforming packets (such as encrypting their payloads). This Linux command shows the policies and states of IPsec tunnel:

<span style="color:rgb(139,0,139)">**sudo ip xfrm state**</span>

<span style="color:rgb(139,0,139)">**sudo ip xfrm policy**</span>


In case of change of the strongSwan configuration files, you can stop and start the daemon by command:

**sudo  strongswan restart**

 
#### Debug ###
The message logs provide a the most effective way to make troubleshooting with strongSwan.
The strongSwan's message logs generated by the daemon are written in the file: **/var/log/messages** ; to filter the logs use the command:

<span style="color:rgb(220, 20, 60)">**sudo cat /var/log/messages | grep charon**</span>

### REFERENCE
[https://wiki.strongswan.org/projects/strongswan/wiki/ConnSection](https://wiki.strongswan.org/projects/strongswan/wiki/ConnSection "ipsec.conf: conn")

<!--Image References-->
[0]: ./media/network-diagram.png "Network Diagram" 
[1]: ./media/ipsec.config.png "IPSec config files"

<!--Link References-->



