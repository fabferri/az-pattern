<properties
pageTitle= 'Traffic between two subnets through Linux nva controlled by iptables'
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

# Traffic between two subnets through Linux nva controlled by iptables
The network diagram is shown below:

[![1]][1]

The vnet1 has three subnets: 
- **clientSubnet**: it is the consumer subnet
- **nvafeSubnet**: it is the frontend subnet of the **nva**
- **nvabesubnet**: it is the backend subnet of the **nva**
- **appSubnet**: it is the application subnet where is attached the **vmApp1** VM with install nginx configure with server blocks, that allows to host multiple websites on one server. 
- **AzureBastionSubnet**: it is the Azure bastion subnet
<br>

The nva is configured with two virtual NICs with ip forwarding to route the traffic between the two network interfaces: eth0 and eth1. A custom script extension configures in nva:
- ip forwarding
- a static route to reach out the appSubnet through the outgoing interface eth1. 

```bash
sed -i -e '$a\net.ipv4.ip_forward = 1' /etc/sysctl.conf && sysctl -p

sed -i '/set-name: eth1/a\
            routes:\
            - to: 10.0.0.48\/28\
              via: 10.0.0.33' /etc/netplan/50-cloud-init.yaml

sed -i '/set-name: eth1/a\\            routes:\\n            - to: 10.0.0.48\\/28\\n              via: 10.0.0.33' /etc/netplan/50-cloud-init.yaml
netplan try
netplan apply
```
NOTE: to split the long **sed** expression into multiple lines, you can use the backslash \\.

In nva, the iptables are used to filter the traffic between the **clientSubnet** and the **appSubnet**.
<br>

The iptables chains in nva are configured to allow the following traffics: <br>

**[vmClient1 (source VM)] -> [nva eth0] -> DEST NAT-> forwarding -> SOURCE NAT -> [nva eth1] -> [vmApp1 (dest VM)]** <br>
Traffic to the  vmApp1:
   - HTTP, dest port:80
   - HTTP, dest port:8081
   - HTTP, dest port:8082
   - HTTP, dest port:8083
   - HTTP, dest port:8084

[![2]][2]


## <a name="iptables configurations"></a>1. iptables configuration in nva 

```console
iptables -I INPUT 1 -i lo -j ACCEPT
iptables -A INPUT -p tcp --dport ssh -j ACCEPT
iptables -A INPUT -p tcp -s 168.63.129.16 --dport 8080 -j ACCEPT
iptables -A INPUT -p tcp --match multiport --dport 8081,8082,8083,8084 -j ACCEPT

iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -j DROP
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -t nat -A PREROUTING  -i eth0 -d 10.0.0.20/32 -p tcp --dport 80 -j DNAT --to-destination 10.0.0.60:80
iptables -t nat -A POSTROUTING -o eth1 -d 10.0.0.60/32 -p tcp --dport 80 -j SNAT --to-source 10.0.0.40 --random

iptables -t nat -A PREROUTING  -i eth0 -d 10.0.0.20/32 -p tcp --dport 8081 -j DNAT --to-destination 10.0.0.60:8081
iptables -t nat -A POSTROUTING -o eth1 -d 10.0.0.60/32 -p tcp --dport 8081 -j SNAT --to-source 10.0.0.40 --random

iptables -t nat -A PREROUTING  -i eth0 -d 10.0.0.20/32 -p tcp --dport 8082 -j DNAT --to-destination 10.0.0.60:8082
iptables -t nat -A POSTROUTING -o eth1 -d 10.0.0.60/32 -p tcp --dport 8082 -j SNAT --to-source 10.0.0.40 --random

iptables -t nat -A PREROUTING  -i eth0 -d 10.0.0.20/32 -p tcp --dport 8083 -j DNAT --to-destination 10.0.0.60:8083
iptables -t nat -A POSTROUTING -o eth1 -d 10.0.0.60/32 -p tcp --dport 8083 -j SNAT --to-source 10.0.0.40 --random

iptables -t nat -A PREROUTING  -i eth0 -d 10.0.0.20/32 -p tcp --dport 8084 -j DNAT --to-destination 10.0.0.60:8084
iptables -t nat -A POSTROUTING -o eth1 -d 10.0.0.60/32 -p tcp --dport 8084 -j SNAT --to-source 10.0.0.40 --random
```

Let's discuss briefly the logic.<br>
To allow traffic on localhost, type this command:
```console
iptables -A INPUT -i lo -j ACCEPT
```
we use **lo** or loopback interface. The command makes sure that the connections between applications on the same machine are working properly.

To accept SSH incoming connection in nva:
```console
iptables -A INPUT -p tcp --dport ssh -j ACCEPT
```
To accept incoming connections on multiple destination TCP ports 8081, 8082, 8083, 8084:
```console
iptables -A INPUT -p tcp --match multiport --dport 8081,8082,8083,8084 -j ACCEPT
```

A rule that uses connection tracking to accept in INPUT only the packets that are associated with an established connection:
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

Let's discuss NAT rules.<br>
**Destination NAT** is done in the <ins>PREROUTING</ins> chain, just as the packet comes in.<br>
**-i** option identify the incoming interface<br>
Destination NAT is specified using `-j DNAT`, and the `--to-destination` option specifies an IP address, a range of IP addresses, and an optional port or range of ports (for UDP and TCP protocols only).
The <ins>PREROUTING</ins> chain in NAT specifies a destination IP address and port where incoming packets requesting a connection to your internal service can be forwarded. For example, if you wanted to forward incoming HTTP requests to your nginx HTTP Server at 10.0.0.60 on destination port 8081, run the following command:<br>
**iptables -t nat -A PREROUTING  -i eth0 -d 10.0.0.20/32 -p tcp --dport 8081 -j DNAT --to-destination 10.0.0.60:8081**

**Source NAT** changes the source address of connections to something different. This is done in the <ins>POSTROUTING</ins> chain, just before it is finally sent out. This is an important detail, since it means that anything else on the Linux box itself (routing, packet filtering) will see the packet unchanged. It also means that the `-o` (outgoing interface) option can be used.
Source NAT is specified using `-j SNAT`, and the `--to-source` option specifies an IP address, a range of IP addresses, and an optional port or range of ports (for UDP and TCP protocols only). <ins>POSTROUTING</ins> chain allows packets to be altered as they are leaving the nva outgoing eth1 interface.

```console
iptables -t nat -A PREROUTING  -i eth0 -d 10.0.0.20/32 -p tcp --dport 8081 -j DNAT --to-destination 10.0.0.60:8081
iptables -t nat -A POSTROUTING -o eth1 -d 10.0.0.60/32 -p tcp --dport 8081 -j SNAT --to-source 10.0.0.40 --random
```

SNAT accepts a **--random** option. If option **−−random** is used then port mapping will be randomized through a hash-based algorithm (kernel >= 2.6.21) <br>

[![3]][3]

**NOTE: if you want to keep permanet across reboot the iptables configurations, you need to add at the end the command: iptables-save** <br>
The iptables configuration is applied to the nva by ARM template with **Managed Run** command (in preview).
[Run scripts in your Linux VM by using managed Run Commands](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/run-command-managed)

## <a name="NGINX server blocks"></a>2. Bash script to configure the NGINX server blocks in appVM

```bash
#!/bin/bash
#
# Nginx - new server blocks
# Variables
NGINX_AVAILABLE_VHOSTS='/etc/nginx/sites-available'
NGINX_ENABLED_VHOSTS='/etc/nginx/sites-enabled'
WEB_DIR='/var/www'
WEB_USER='www-data'
NGINX_LOG='/var/log/nginx'
#
WEB_ARRAY_NAME=("web101" "web102" "web103" "web104")
WEB_ARRAY_PORT=("8081" "8082" "8083" "8084")

for i in ${!WEB_ARRAY_NAME[@]}; do
    # Create folders 
    if [ -d "$WEB_DIR/${WEB_ARRAY_NAME[$i]}/html" ]; then
      echo "folder $WEB_DIR/${WEB_ARRAY_NAME[$i]}/html already exists"
    else
      mkdir -p $WEB_DIR/${WEB_ARRAY_NAME[$i]}/html
    fi
done


for i in ${!WEB_ARRAY_NAME[@]}; do
   # Assign ownership
   chown -R $USER:$USER $WEB_DIR/${WEB_ARRAY_NAME[$i]}/html
done

# Grant reading permission to all the files inside the /var/www directory
sudo chmod -R 755 $WEB_DIR

for i in ${!WEB_ARRAY_NAME[@]}; do
   # Reassign ownership of the web directories to NGINX user (www-data):
   chown -R www-data:www-data $WEB_DIR/${WEB_ARRAY_NAME[$i]}/html
done

for i in ${!WEB_ARRAY_NAME[@]}; do
# Create the content you want to display on the websites hosted on Nginx server 
cat <<EOF > $WEB_DIR/${WEB_ARRAY_NAME[$i]}/html/index.html
<html>
    <head> <title>Welcome to ${WEB_ARRAY_NAME[$i]}</title> </head>
    <body>
        <h1>${WEB_ARRAY_NAME[$i]} server block is working!</h1>
    </body>
</html>
EOF
done

# Inside the  file /etc/nginx/nginx.conf check the two lines:
#    include /etc/nginx/conf.d/*.conf;
#    include /etc/nginx/sites-enabled/*;
# The line include /etc/nginx/sites-enabled/*.conf instructs NGINX to check the sites-enabled directory.

for i in ${!WEB_ARRAY_NAME[@]}; do
# Create the server blocks for the site web101
cat <<EOF > /etc/nginx/sites-available/${WEB_ARRAY_NAME[$i]}.conf
server {
        listen ${WEB_ARRAY_PORT[$i]};
        listen [::]:${WEB_ARRAY_PORT[$i]};
        server_name  ${WEB_ARRAY_NAME[$i]}.local;

        root $WEB_DIR/${WEB_ARRAY_NAME[$i]}/html;
        index index.html index.htm;
        location / {
                try_files \$uri \$uri/ =404;
        }
        access_log /var/log/nginx/${WEB_ARRAY_NAME[$i]}/access.log;
	    error_log /var/log/nginx/${WEB_ARRAY_NAME[$i]}/error.log;
}
EOF
done

# Enable the new server block files, by creating symbolic links:
for i in ${!WEB_ARRAY_NAME[@]}; do

   web_link="/etc/nginx/sites-enabled/${WEB_ARRAY_NAME[$i]}.conf"
   if [ -L ${web_link} ] ; then
     if [ -e ${web_link} ] ; then
        echo "symbolic link already exists: /etc/nginx/sites-enabled/${WEB_ARRAY_NAME[$i]}.conf"
     else
        echo "symbolic link  /etc/nginx/sites-enabled/${WEB_ARRAY_NAME[$i]}.conf is broken"
     fi
   elif [ -e ${web_link} ] ; then
     echo " /etc/nginx/sites-enabled/${WEB_ARRAY_NAME[$i]}.conf is NOT a symbolic link "
   else
     echo "Create symbolic link: /etc/nginx/sites-enabled/${WEB_ARRAY_NAME[$i]}.conf"
     ln -s /etc/nginx/sites-available/${WEB_ARRAY_NAME[$i]}.conf /etc/nginx/sites-enabled/
   fi
done

for i in ${!WEB_ARRAY_NAME[@]}; do
   # Create the folders for the logs:
   mkdir -p /var/log/nginx/${WEB_ARRAY_NAME[$i]}/
   chown -R www-data:adm /var/log/nginx/${WEB_ARRAY_NAME[$i]}/
done

# Check errors in nginx configuration:
sudo nginx -t

# Restart NGINX:
sudo systemctl restart nginx
```

## <a name="List of files"></a>3. List of files 
| file                  | Description                                                  | 
| --------------------- |------------------------------------------------------------- | 
| **init.json**         | input parameter file defining: Azure subscription, Resource group name, Azure region, administrator credential|
| **az.json**           | ARM template to deploy load balancers and VMs                |
| **az.ps1**            | powershel script to deploy **az.ps1**                        |
| **managed-run.json**  | ARM template to configure iptables in **nva** and nginx server blocks in **vmApp1** by the **managed Run Command** |
| **managed-run.ps1**   | powershel script to deploy **managed-run.json**              |
| **nginx-serverblocks.sh** |  bash script to configure the nginx server blocks        |

**NOTE:** 
- **Before running the ARM template, customize the values of input variables in init.json file**
- **To deploy the full solution, run before the "az.json" and then "managed-run.json"**
- Configuration of ip fowarding in nva and installation of nginx in nva and vmApp1 is done through custom script extension in **az.json**
- The **managed Run Command** feature uses the VM agent to scripts within an Azure Linux VM. <br>
 Configuration of iptables in **nva** and ngix server blocks in  **vmApp1** are executed both by **managed Run Command**. <br>
 Configuration of nginx server blocks is executed by the bash script **nginx-serverblocks.sh**; the **managed-run.json** required as input the full URL to the **nginx-serverblocks.sh**
<br>

Clarification of of meaning of variables in **init.json**:
```json
{
    "subscriptionName": "NAME_OF_AZURE_SUBSCRIPTION",
    "ResourceGroupName": "NAME_OF_RESOURCE_GROUP",
    "location": "AZURE_LOCATION_NAME",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "authenticationType": "password",
    "adminPasswordOrKey": "ADMINISTRATOR_PASSWORD",
    "nginxScriptURL": "FULL_URL_TO_THE_PUBLIC_SITE_WHERE_STORED_THE_SCRIPT_nginx-serverblocks.sh"
}
```

## <a name="check"></a>4. Check of flows through nva
Using tcpdump is easy to verify the NAT and symmetrical transit through the nva:

```bash
root@nva:~# tcpdump -i eth0 -n host 10.0.0.10
root@nva:~# tcpdump -i eth1 -n host 10.0.0.60
```
By curl the vmClient1 can query the nginx server blocks in vmApp1:
```bash
root@vmClient1:~# curl 10.0.0.20
root@vmClient1:~# curl 10.0.0.20:8081
root@vmClient1:~# curl 10.0.0.20:8082
root@vmClient1:~# curl 10.0.0.20:8083
root@vmClient1:~# curl 10.0.0.20:8084
```

## <a name="iptables"></a>5. ANNEX1: iptables overview 

The packet filtering mechanism provided by iptables is organized into three different kinds of structures: tables, chains and targets. 
There are four tables:
* The **filter table**: This is the **default** and perhaps the most widely used table. It is used to make decisions about whether a packet should be allowed to reach its destination.
* The **mangle table**: This table allows you to alter packet headers in various ways (e.g. changing TTL values).
* The **nat table**: This table allows you to apply NAT (Network Address Translation) networks by changing the source and destination addresses of packets.
* The **raw table**: iptables is a stateful firewall, which means that packets are inspected with respect to their "state". (For example, a packet could be part of a new connection, or it could be part of an existing connection.) The raw table allows you to work with packets before the kernel starts tracking its state. In addition, you can also exempt certain packets from connection tracking.

each of these tables are composed of a few default chains. These chains allow you to filter packets at various points. The list of chains iptables provides are:
* The **PREROUTING chain**: <ins>rules in this chain apply to packets as they just arrive on the network interface</ins>. This chain is present in the nat, mangle and raw tables.
* The **INPUT chain**: <ins>rules in this chain apply to packets just before they’re given to a local process</ins>. This chain is present in the mangle and filter tables.
* The **OUTPUT chain**: <ins>the rules here apply to packets just after they’ve been produced by a process</ins>. This chain is present in the raw, mangle, nat and filter tables.
* The **FORWARD chain**: <ins>the rules here apply to any packets that are routed through the current host</ins>. This chain is only present in the mangle and filter tables.
* The **POSTROUTING chain**: <ins>the rules in this chain apply to packets as they just leave the network interface</ins>. This chain is present in the nat and mangle tables.

The diagram below shows the flow of packets through the chains in various tables:

[![4]][4]

A network packet received on any interface traverses the traffic control chains of tables in the order shown in the flow chart.

### Showing the current rules
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
iptables -t nat -L -n -v
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

Set default policies to let everything in: <br>
**iptables -P INPUT   ACCEPT** <br>
**iptables -P OUTPUT  ACCEPT** <br>
**iptables -P FORWARD ACCEPT** <br>


you may be able to reset the rules by loading a default rule set: 
```console
iptables-restore < /etc/iptables/empty.rules
```
### Persisting Changes  
The iptables rules that we have created are saved in memory. That means the rules are deleted on reboot. To make these changes persistent after restarting the host, you can use this command:
```console
/sbin/iptables-save
```
### Editing rules
Rules can be edited by: <br>
- **-A**: appending a rule at the end of the ruleset <br> 
- **-I** [rulenum]: inserting a rule at a specific position on the selected chain. If the rule number is 1, the rule or rules are inserted at the head of the chain. If you don't supply any rulenum, your rule is inserted at the very first position. <br>
- **-R**: replacing an existing rule <br> 
- **-D**: deleting rule (e.g. to delete the rule number 3 of the INPU chain: **iptables -D INPUT 3**)<br>


### Append a rule to a table  
Defining a rule means appending it to the chain. To do this, you need to insert the **-A** option (**Append**), like so:
```console
iptables -A
```
then, you can combine the command with other options, such as: <br>
-	**-i** (interface) — the network interface whose traffic you want to filter, such as eth0, eth1, lo, etc.
-	**-p** (protocol) — the network protocol where your filtering process takes place. It can be either tcp, udp, udplite, icmp, sctp, icmpv6, and so on. Alternatively, you can type **all** to choose every protocol.
-	**-s** (source) — the address from which traffic comes from. _You can add a hostname or IP address_.
-	**--dport** (destination port) — the destination port number of a protocol, such as 22 (SSH), 443 (https), etc.
-	**-j** (target) — the target name (**ACCEPT, DROP, RETURN**). You need to insert this every time you make a new rule.

### Modules
There are many modules which can be used to extend iptables such as **connlimit**, **conntrack**, **limit** and **recent**. These modules add extra functionality to allow complex filtering rules. <br>
**conntrack** module allows access to the connection tracking state for this packet/connection (stateful firewall facility). Connection tracking stores information about incoming connections. You can allow or deny access based on the following connection states:
- **NEW** meaning that the packet has started a new connection (such as an HTTP request), or otherwise associated with a connection which has not seen packets in both directions
- **ESTABLISHED** meaning that the packet is associated with a connection which has seen packets in both directions (a packet that is part of an existing connection)
- **RELATED** a packet that is requesting a new connection but is part of an existing connection. In other words, the packet is starting a new connection, but is associated with an existing connection. For example, FTP uses port 21 to establish a connection, but data is transferred on a different port (typically port 20). One other example is an ICMP error.

### Examples of Source NAT
Change source addresses to 1.2.3.4 <br>
**iptables -t nat -A POSTROUTING -o eth0 -j SNAT --to 1.2.3.4**

Change source addresses to 1.2.3.4, 1.2.3.5 or 1.2.3.6 <br>
**iptables -t nat -A POSTROUTING -o eth0 -j SNAT --to 1.2.3.4-1.2.3.6**

Change source addresses to 1.2.3.4, ports 1-1023 <br>
**iptables -t nat -A POSTROUTING -p tcp -o eth0 -j SNAT --to 1.2.3.4:1-1023**

### Examples of Destination NAT
Change destination addresses to 5.6.7.8 <br>
**iptables -t nat -A PREROUTING -i eth0 -j DNAT --to 5.6.7.8**

Change destination addresses to 5.6.7.8, 5.6.7.9 or 5.6.7.10 <br>
**iptables -t nat -A PREROUTING -i eth0 -j DNAT --to 5.6.7.8-5.6.7.10**

Change destination addresses of web traffic to 5.6.7.8, port 8080 <br>
**iptables -t nat -A PREROUTING -p tcp --dport 80 -i eth0 -j DNAT --to 5.6.7.8:8080**

see more information in [official doc](https://www.netfilter.org/documentation/HOWTO/NAT-HOWTO-6.html)


## <a name="file copy through Bastion"></a>6. ANNEX2: file copy  through Azure Bastion
Copy a file from a host in internet to the Azure VMs in the VNet through Azure Bastion:

```
az login
az account list
az account set --subscription "<subscription ID>"
az network bastion tunnel --name "<BastionName>" --resource-group "<ResourceGroupName>" --target-resource-id "<VMResourceId>" --resource-port "<TargetVMPort>" --port "<LocalMachinePort>"
scp -P <LocalMachinePort>  <local machine file path>  <username>@127.0.0.1:<target VM file path>
```

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/iptables-nat.png "destination ports in appVM served by nginx server blocks"
[3]: ./media/iptables2.png  "NAT with iptables"
[4]: ./media/iptables.png "iptables: flow of packets through the chains"


<!--Link References-->

