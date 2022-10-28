<properties
pageTitle= 'Virtual WAN: traffic branches to VNets with transit through a firewall in spoke vnet'
description= "Virtual WAN: traffic branches to VNets with transit through a firewall in spoke vnet"
documentationcenter: na
services=""
documentationCenter="github repository"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service = "configuration-Example-Azure-Virtual WAN"
   ms.devlang = "na"
   ms.topic = "article"
   ms.tgt_pltfrm = "Azure"
   ms.workload = "Virtual WAN"
   ms.date = "21/10/2022"
   ms.author="fabferri" />

## Virtual WAN: traffic branches to VNets with transit through a firewall in spoke vnet and internet breakout

The article describes a virtual WAN configuration with spoke VNets (fwvnet, spoke1, spoke2, nvavnet) and one branch (site1) connected in site-to-site VPN to the virtual hub1. Below the network diagram:

[![1]][1]

### Design
* traffic spokes vnets to branch (site1) is routed through the two VMs **fw0**, **fw1** in **fwvnet**. The **fw0** and **fw1** have the IP forwarding enabled. In the **fwvnet** is configured an internal Load Balancer in HA ports guarantees the resilience of the firewall. The health probe message of load balancer is configured on HTTP port 80. The traffic incoming in the frontend IP of the load balancer is forward to the **fw0** and **fw1** only when those VMs answer to the health probe messages.
* traffic spoke vnet to spoke vnet doesn't transit through **fw0** and **fw1**
* the configuration allows to the **spoke1** and **spoke2** to break out in internet through the **fw0** and **fw1**. The vm1 and vm2 can initialize a connection to internet through the firewalls in fwvnet.
* the security rules in **fw0** and **fw1** are implemented through linux iptables
* the firewalls **fw0** **fw1** accept inbound TCP connections from internet with destination TCP port 8081 and 8082:
   * the inbound traffic from internet with destination port 8081 is NATTED and forwarded to the **vm1** in the **spoke1** 
   * the inbound traffic from internet with destination port 8081 is NATTED and forwarded to the **vm2** in th **spoke2**  


### Setup
* **fwvnet** is associated with routing table **RT_SHARE** and propagated to the hub routing tables **RT_SHARE**, **RT_SPOKE**
* **spoke1** is associated with routing table **RT_SPOKE** and propagated to the hub routing tables **RT_SPOKE**,**RT_SHARE**
* **spoke2** is associated with routing table **RT_SPOKE** and propagated to the hub routing tables **RT_SPOKE**,**RT_SHARE**
* **nvavnet** is associated with routing table **RT_SPOKE** and propagated to the hub routing tables **RT_SPOKE**,**RT_SHARE**
* the connection **fwvnetconn** have the default route (0.0.0.0/0) disabled: **"enableInternetSecurity": false**
* the connection **nvaconn** have the default route (0.0.0.0/0) disabled: **"enableInternetSecurity": false**. The VMs in **nvavnet** break out in internet without transit through the firewalls **fw0** and **fw1**.
* the connection **spoke1conn** have the default route (0.0.0.0/0) enabled: **"enableInternetSecurity": true**. This is required to **spoke1** vnet to access in internet through the firewalls **fw0** and **fw1**.
* the connection **spoke2conn** have the default route (0.0.0.0/0) enabled: **"enableInternetSecurity": true**. This is required to **spoke2** vnet to access in internet through the firewalls **fw0** and **fw1**.

<br>

|Routing Configuration for the connection **fwvnetconn** ||   
| -------------------- |:------------------------------ | 
| associateRouteTable  | **RT_SHARED**                  | 
| propagateRouteTable  | **RT_SHARED**, **RT_SPOKE**    | 

Static routes configured in the connection **fwvnetconn**: 
| Route name  | Destination type | Destination Prefix                    | Next-hop  |
| ----------- |:---------------- | ------------------------------------- | --------- |
| to-spokes   | CIDR             | 10.0.1.0/24,10.0.2.0/24,10.0.20.0/24  |10.0.10.50 |
| to-site1    | CIDR             | 10.11.0.0/24                          |10.0.10.50 |
| to-internet | CIDR             | 0.0.0.0/0                             |10.0.10.50 |

<br>

|Routing Configuration for the connections: <br> **spoke1conn**, **spoke2conn** and **nvavnetconn**||
| -------------------- |:---------------------------- | 
| associateRouteTable  | **RT_SPOKE**                 | 
| propagateRouteTable  | **RT_SPOKE**, **RT_SHARED**  | 

No static routes are configured in the connections **spoke1conn**, **spoke2conn** and **nvavnetconn**.
<br>

|Routing Configuration of VPN connection                      ||
| -------------------- |:------------------------------------ | 
| associateRouteTable  | **defaultRouteTable**                | 
| propagateRouteTable  | **defaultRouteTable**, **RT_SHARED** | 

No static routes are configured in the VPN connection
<br>

To establish a communication are required static routes in the following routing tables:

* static routes added to the routing table **defaultRouteTable**:

| Route name  | Destination type | Destination Prefix | Next Hop     |
| ----------- |:---------------- | ------------------ | ------------ |
| to-spoke1   | CIDR             | 10.0.1.0/24        |**fwvnetconn**|
| to-spoke2   | CIDR             | 10.0.2.0/24        |**fwvnetconn**|
| to-nva      | CIDR             | 10.0.20.0/24       |**fwvnetconn**|
<br>

* static routes added to the routing table **RT_SPOKE**:

| Route name  | Destination type | Destination Prefix | Next-hop       |
| ----------- |:---------------- | ------------------ | -------------- |
| to-site1    | CIDR             | 10.11.0.0/24       | **fwvnetconn** |
| to-internet | CIDR             | 0.0.0.0/0          | **fwvnetconn** |

No static routes are required in the routing table **RT_SHARED**


The diagram shows the routing tables and connections:

[![2]][2]


### <a name="List of files"></a>1. List of files 

| file                     | description                                                            |       
| ------------------------ |:---------------------------------------------------------------------- |
| **init.json**            | file with the value of variables used across the ARM templates         |
| **01-vwan.json**         | ARM template to create virtual WAN the virtual hub, VNets, routing tables, connections between VNets and virtual hubs and VMs |
| **01-vwan.ps1**          | powershell script to deploy the ARM template **01-vwan.json**          |
| **02-vpn.json**          | ARM template to create site1                                           |
| **02-vpn.ps1**           | powershell script to deploy the ARM template **02-vpn.json**           |
| **03-vwan-site.json**    | ARM template to create sites connection and site link with site1       |
| **03-vwan-site.ps1**     | powershell script to deploy the ARM template **03-vwan-site.json**     |
| **04-nsg-iptables.json** | ARM template to add security entries to the NSG applied to the firewall and apply the iptables security rules | 
| **04-nsg-iptables.ps1**  | powershell script to deploy the ARM template **04-nsg-iptables.json**  | 
<br>
 
Before spinning up the powershell scripts, you should edit the file **init.json** and customize the values of input variables in use across all the ARM templates.

The ARM templates use custom script extension to install nginx on port 80 on all VMs: **fw0, fw1, vm1, vm2, nva,vm-branch**.
In the firewalls **fw0** and **fw1** run the nginx on port 80, to answer to the health probe of the internal Load Balancer configured in HA ports.
<br>

Meaning of the variables:
```json
{
    "subscriptionName": "AZURE_SUBSCRITION_NAME",
    "ResourceGroupName": "NAME_OF_RESOURCE_GROUP",
    "vwanName": "NAME_OF_THE_VIRTUAL_WAN",
    "hub1location": "LOCATION_HUB1",
    "branch1location": "LOCATION_BRANCH1",
    "hub1Name": "NAME_HUB1",
    "sharedKey": "SHARED_KEY_Site-to-site_VPN_between_hub1_and_branch",
    "mngIP": "PUBLIC_IP used to filter the SSH inbound to the Azure VMs. It can be set empty if you do not want to limit access from a specific IP",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD"
}
```
<br>

### <a name="iptables"></a>2. iptables security policy in fw0 and fw1
Traffic in transit through **fw0** and **fw1** is filtered by iptables. The security policy in **fw0** is shown below:
```console
iptables -I INPUT 1 -i lo -j ACCEPT;
iptables -A INPUT -p tcp --dport ssh -j ACCEPT;
iptables -A INPUT -p tcp -s 168.63.129.16 --dport 80 -j ACCEPT;
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT;
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT;
iptables -A INPUT -j DROP;
iptables -P FORWARD ACCEPT;
iptables -P OUTPUT ACCEPT;
iptables -t nat -A PREROUTING  -i eth0 -d 10.0.10.10/32 -p tcp --dport 8081 -j DNAT --to-destination 10.0.1.10:80;
iptables -t nat -A PREROUTING  -i eth0 -d 10.0.10.10/32 -p tcp --dport 8082 -j DNAT --to-destination 10.0.2.10:80;
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE;
```
The PREROUTING chain in NAT table allows to appy to the traffic inbound from internet the following the NAT rule: <br>
[sourceIP: pubIPInternet, sourcePort: N, destIP: **10.0.10.10**, destPort:**8081**] is translated into [sourceIP: pubIPInternet, sourcePort: N1, destIP:**10.0.1.10**, destPort: **80**]


[![3]][3]

The iptables configurations are deployed in **fw0** and **fw1** by using action Run Commands. <br>
**Run Command** feature uses the virtual machine (VM) agent to run scripts within an Azure Linux VM (in ARM template: **Microsoft.Compute/virtualMachines/runCommands**).

For troubleshooting action run command in Linux environments, refer to the handler log file typically located in the following directory: **/var/log/azure/run-command/handler.log** .



### <a name="traffic between branch and vnet"></a>3. Traffic branch-to-vnet 

To generate HTTP traffic between VMs, in the branch VM run the command:
```bash
root@vm-branch1:~# for i in `seq 1 2000`; do curl http://10.0.1.10; done
```

To monitor the transit through the firewall fw0, fw1 run the command:
```bash
root@fw0:~# tcpdump -n host 10.11.0.4
root@fw1:~# tcpdump -n host 10.11.0.4
```
By tcpdump is recommended check the traffic branch-vnet passes through the fw0, fw1 with symmetric transit.

[![4]][4]

If you wish to send the traffic incoming in the LB to a single backend VM, e.g. **fw0**, it is enough stop the nginx on the VM you don't want receive traffic:
```bash
root@fw1:~#  systemctl stop nginx
```

### <a name="traffic from/to internet"></a>3. Traffic spokes to internet and internet to spokes

A client in internet can initialize a connection to the spoke vnets, spoke1 and spoke2, specifying in a destination IP, the public IP of fw0 or  the public IP of fw1.

[![5]][5]

To generate inbound HTTP traffic from client in internet to the vm1 in spoke1 run the command:
```bash
root@client:~# for i in `seq 1 2000`; do curl http://10.0.10.10:8081; done
```
you can check out the transit through the firewall by tcpdump:
```
root@fw0:~# tcpdump -n host 10.0.1.10 or host 10.0.2.10
```

To generate inbound HTTP traffic from client in internet to the vm2 in spoke2 run the command:
```bash
root@client:~# for i in `seq 1 2000`; do curl http://10.0.10.10:8082; done
```

To generate outbound HTTP traffic from vm1 in spoke1 to internet:
```bash
root@vm1:~# curl http://www.microsoft.com
```

### <a name="List of files"></a>2. NOTE

The ARM templates **01-vwan.json**,**02-vpn.json** use the customer script extension to install nginx in each VM and set a simple custom web page with the name of the VM. <br>
In the **fw0** and **fw1** is further to the nginx installation, the IP forwarding is enabled on the NIC and in the Linux OS. <br>
The custom script extension runs on each vm when in the variables('vmArray') the cmd is not empty:
```console
"condition": "[greater(length(variables('vmArray')[copyIndex()].cmd), 0)]",
```

The ARM template **01-vwan.json** deploy the VPN Gateway in the hub only the first time. If the VPN Gateway already exist in the hub1 vnet, the creation of VPN Gateway is skipped. <br>
A check on presence of S2S VPN Gateway in hub1 is done through powershell **01-vwan.ps1**; the powershell set the value of variable **$deployVPNGtwS2S** to the following value:
* **$deployVPNGtwS2S = $false** if the VPN Gateway is already deployed in hub1 
* **$deployVPNGtwS2S = $true** in the case the VPN Gateway is not deployed in hub1.
The condition avoids the reset of the VPN configuration, when the ARM template **01-vwan.json** runs multiple times.

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "implementation details including of route tables and static routes"
[3]: ./media/network-diagram3.png "inboud NAT by iptables"
[4]: ./media/network-diagram4.png "traffic from internet to spoke vnets and from spoke vnet to internet"
[5]: ./media/network-diagram5.png "traffic from internet to spoke vnets and from spoke vnet to internet"

<!--Link References-->

