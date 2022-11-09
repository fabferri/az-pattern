<properties
pageTitle= 'Virtual WAN: traffic branches to VNets with transit through an NVA'
description= "Virtual WAN: traffic branches to VNets with transit through an NVA"
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

## Virtual WAN: traffic branches to VNets with transit through an NVA

The article describes a virtual WAN configuration with spoke VNets (fwvnet,spoke1, spoke2, nvavnet) and one branch (site1) connected in site-to-site VPN to the virtual hub1. In fwvnet is deployed an two VMs fw0 and fw1 with IP forwarding enabled. Below the network diagram:

[![1]][1]

**Design**
* Virtual networks (spokes) to branch (site1) traffic is routed through the VMs **fw0**, **fw1** in **fwvnet**. The **fw0** and **fw1** have the IP forwarding enabled to route the IP packets. an internal Load balancers configured in HA ports guaratees the resilence of IP routing. The health probe message of load balancer is configured on HTTP port 80. The traffic incoming the LB frontend IP is forward to the **fw0** and **fw1** only when those VMs answer to the health probe messages.
* spoke to spoke traffic doesn't transit through **fw0**, **fw1**


### Setup
* **fwvnet** is associated with routing table **RT_SHARE** and propagated to the hub routing tables **RT_SHARE** 
* **spoke1** is associated with routing table **RT_SPOKE** and propagated to the hub routing table **RT_SPOKE**,**RT_SHARE**
* **spoke2** is associated with routing table **RT_SPOKE** and propagated to the hub routing table **RT_SPOKE**,**RT_SHARE**
* **nvavnet** is associated with routing table **RT_SPOKE** and propagated to the hub routing table **RT_SPOKE**,**RT_SHARE**
* the connection to **vnet3** is associated with routing table **RT_VNET** and propagated to the hub routing table **RT_VNET**,**RT_NVA**
* the connection to **vnet4** is associated with routing table **RT_VNET** and propagated to the hub routing table **RT_VNET**,**RT_NVA**
<br>

|Routing Configuration of **fwvnet**                ||   
| -------------------- |:-------------------------- | 
| associatedRouteTable | **RT_SHARED**              | 
| propagatedRouteTable | **RT_SHARED**              | 

<br>

|Routing Configuration of **spoke1, spoke2, nvavnet** ||
| -------------------- |:---------------------------- | 
| associatedRouteTable | **RT_SPOKE**                 | 
| propagatedRouteTable | **RT_SPOKE**, **RT_SHARED**  | 

<br>

|Routing Configuration of VPN connections                     ||
| -------------------- |:------------------------------------ | 
| associatedRouteTable | **defaultRouteTable**                | 
| propagatedRouteTable | **defaultRouteTable**, **RT_SHARED** | 

<br>

To establish a communication are required static routes in each routing table:

* Static routes configured on fwvnet Connection **fwvnetconn**:

| Route name  | Destination type | Destination Prefix                    | Next-hop  |
| ----------- |:---------------- | ------------------------------------- | --------- |
| to-spokes   | CIDR             | 10.0.1.0/24,10.0.2.0/24,10.0.20.0/24  |10.0.10.50 |
| to-site1    | CIDR             | 10.11.0.0/24                          |10.0.10.50 |


<br>

* static routes added to the routing table **RT_SPOKE**:

| Route name  | Destination type | Destination Prefix | Next-hop       |
| ----------- |:---------------- | ------------------ | -------------- |
| to-site1    | CIDR             | 10.11.0.0/24       | **fwvnetconn** |

<br>

* static routes added to the routing table **defaultRouteTable**:

| Route name  | Destination type | Destination Prefix | Next Hop     |
| ----------- |:---------------- | ------------------ | ------------ |
| to-spoke1   | CIDR             | 10.0.1.0/24        |**fwvnetconn**|
| to-spoke2   | CIDR             | 10.0.2.0/24        |**fwvnetconn**|
| to-nva      | CIDR             | 10.0.20.0/24       |**fwvnetconn**|
<br>

The diagram shows the routing tables and connections:

[![2]][2]


### <a name="List of files"></a>1. List of files 

| file                   | description                                                         |       
| ---------------------- |:------------------------------------------------------------------- |
| **init.json**          | file with the value of variables used across the ARM templates      |
| **01-vwan.json**       | ARM template to create virtual WAN the virtual hub, VNets, routing tables, connections between VNets and virtual hubs and VMs |
| **01-vwan.ps1**        | powershell script to deploy the ARM template **01-vwan.json**       |
| **02-vpn.json**        | ARM template to create site1                                        |
| **02-vpn.ps1**         | powershell script to deploy the ARM template **02-vpn.json**        |
| **03-vwan-site.json**  | ARM template to create sites connection and site link with site1    |
| **03-vwan-site.ps1**   | powershell script to deploy the ARM template **03-vwan-site.json**  |
<br>
 
Before spinning up the powershell scripts, you should edit the file **init.json** and customize the values of input variables in use across all the ARM templates.

<br>

Meaning of the variables:
```json
{
    "subscriptionName": "AZURE_SUBSCRITION_NAME",
    "ResourceGroupName": "NAME_OF_RESOURCE_GROUP",
    "vwanName": "NAME_OF_THE_VIRTUAL_WAN",
    "hub1location": "LOCATION_HUB!",
    "branch1location": "LOCATION_BRANCH1",
    "hub1Name": "NAME_HUB1",
    "sharedKey": "SHARED_KEY_S2S_VPN",
    "mngIP": "PUBLIC_IP used to connect to the Azure VMs in SSH",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD"
}
```
<br>


### <a name="traffic between branch and vnet"></a>2. Traffic branch-to-vnet 

To generate HTTP traffic between VMs, in the branch VM run the command:
```bash
root@vm-branch1:~# for i in `seq 1 2000`; do curl http://10.0.1.10; done
```

To monitor the transit through the firewall fw0, fw1 run the command:
```bash
root@fw0:~#  tcpdump -n host 10.0.20.10 or host 10.0.1.10 or host 10.0.2.10
root@fw1:~#  tcpdump -n host 10.0.20.10 or host 10.0.1.10 or host 10.0.2.10
```
By tcpdump is recommended check the traffic branch-vnet passes through the fw0, fw1 with symmetric transit.

[![3]][3]

If you wish to send the traffic incoming in the LB to a single backend VM, e.g. **fw0**, it is enough stop the nginx on the VM you don't want receive traffic:
```bash
root@fw1:~#  systemctl stop nginx
```

### <a name="List of files"></a>2. NOTE

The ARM templates **01-vwan.json**,**02-vpn.json** use the customer script extension to install nginx in each VM and set a simple custom web page with the name of the VM. <br>
In the **fw0** and **fw1** is further to the nginx installation, the IP forwarding is enabled on the NIC and in the Linux OS. <br>
The custom script extension runs on each vm when in the variables('vmArray') the cmd is not empty:
```console
"condition": "[greater(length(variables('vmArray')[copyIndex()].cmd), 0)]",
```

The ARM template **01-vwan.json** deploy the VPN Gateway in the hub only the first time. If the VPN Gateway already exist in the hub vnet, the creation of VPN Gateway is skipped. 

`Tags: Virtual WAN, vWAN` <br>
`Testing date: 28-10-22`

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "implementation details including of route tables and static routes"
[3]: ./media/network-diagram3.png "traffic between branch and spoke vnet with transit through the LB and firewall"


<!--Link References-->

