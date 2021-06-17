<properties
pageTitle= 'configuration with hub and spoke of spoke vnets'
description= "configuration with hub and spoke of spoke vnets"
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
   ms.date="15/06/2021"
   ms.author="fabferri" />

# Configuration with hub and spoke of spoke vnets with summarization

The article walks you through a network configuration with hub-spoke vnets with the variant to have spoke vnets as leaves of spoke vnets.

Let discuss the principles with simple level network diagram:

[![1]][1]

The high-level diagram shows only the routing and does not address NVAs high availability requirements.

All the NVAs in the diagram work as "ip fowarder" (router), to route the traffic to a destination different from their own IP address.

The vnet peering between hub-spoke are created without "allow gateway transit" and "use remote gateway transit"; the address space of spoke vnets (spoke01, spoke61) are not advertised from the ExpressRoute Gateways to on-premises.

In the network design two factors have a fundamental role: network summarization and Azure Route Server in the hub vnet.

In our specific case the NVAs in the hub00 advertise via BGP to the Azure route server, the two major networks: 10.0.0.0/16 and 10.1.0.0/16
- the major network 10.0.0.0/16 includes the range [HostMin: 10.0.0.1, HostMax: 10.0.255.254 ]
- the major network 10.1.0.0/16 includes the range [HostMin: 10.1.0.1, HostMax: 10.1.255.254 ]

Those major networks are then advertised by the ExpressRoute Gateway to ExpressRoute circuit and into the on-premises network.

In the hub vnet only the NVAs know how to reach out those major network 10.0.0.0/16 and 10.1.0.0/16

The spoke01 has address space 10.0.1.0/24 that is part of the major network 10.0.0.0/16, but this is not an issue because in the system routing table azure match the longest prefixes match (the network 10.0.1.0/24 is more specific). The system routing table in hub00 is able to reach out the 10.0.1.0/24 through the vnet peering.

Each of spoke vnet in leaf vnet has address space belonging to the major networks 10.0.0.0/16 and 10.1.0.0/16  The architecture works as expected only when: 
- **the spoke vnets in the leaves have address space that belong to the major networks (summary networks)**
- **there are no vnets with address in overlapping**

Let's discuss the traffic from on-premises with destination address in the spoke04 (**_left_** side); the traffic has the following path:
- the on-premises edge routes know the network 10.0.0.0/16; the traffic is routed to the ExpressRoute circuit and reach out the ExpressRoute gateway in the **hub00**
- the ExpressRoute Gateway routes the traffic in the hub00 vnet; a UDR in the gateway subnet forward the traffic to the NVA1
- the NVA1 is configured as ip fowarder and the traffic incoming is routed in egress
- the traffic in egress in NVA1 is sent, by UDR applied to NVA1 subnet, to the NVA2 in spoke01 vnet in the mid layer
- the traffic enters in NVA2 and gets out from the same interface
- the system route table in spoke01 learned the network 10.0.4.0/24 of spoke04 from the vnet peering; the traffic in egress from the NVA2 is routed to the spoke04  

The traffic from spoke04 to on-premises follows the path:
- a UDR with default route 0.0.0.0/0 is applied to spoke04 pointed out to the NVA2
- the traffic in ingress on NVA2 is forwarded in egress
- a UDR with major 10.0.0.0/8 is applied to the NVA2 subnet, to forward the traffic to the NVA1 in the hub vnet
- the NVA1 routes the incoming traffic in egress 
- the system routing table in hub00 learned the on-premises network from the ExpressRoute Gateway; the traffic is sent to on-premises


The network diagram with all the details is shown below:

[![2]][2]

A name convention is used to map the name with the network prefix: i.e. hub**60** -> 10.**6.0**.0/24, spoke**04** -> 10.**0.4**.0/24, and so on.

In summary, the convention name follows the rule: 

name**XY**

where 
- "name" is the vnet name
- **X** is the second octet of the address space
- **Y** is the third octet of the address space


The diagram is similar to the previous one, with the only difference of presence of internal load balancers (ILB) in HA to have a good resilience: 
- the VMs nva1 and nva2 in the backend pool of the ILB run with Ubuntu OS and are configured with **ip forwarding** to route the traffic to a destination different from their own IP address. In the nva1 and nva2 is installed nginx to answer to the ILB health probe on port 80.
- each hub vnet hub00 has an Azure Route Server to establish BGP peering with the Azure VMs nva1 and nva2 of the backend pool of the of the load balancer.
- the router server in hub00 needs to know the IPs are to establish the peering. Usage of Virtual Machine Scale Set (VMSS) for the NVAs is good idea to scale up in throughput and number of flows, but it isn't great to establish a deterministic BGP peering with the Route Server becasue the internal IPs assigment is not deterministic.
- in spoke01 the ILB is configured with two Virtual Machine Scale Set in different availability zones.
The same consideration are valid for the **_right_** side. Below a network diagram with BGP peering between the nva1, nva2 and route server in hub00.
 

[![3]][3]

In the network diagram the communication path between spoke leaves vnets connected to different hubs:

[![4]][4]

<br>

## <a name="ARM templates"></a>2. ARM templates and scripts to make the full setup

Scripts and ARM templates are stored in two folders:
- the script in **_left_** folder creates the deployment: hub00, spoke01, spoke04, spoke05
- the script in **_right_** folder creates the deployment: hub60, spoke61, spoke64, spoke65

The **_left_** side and **_right_** side use different Azure resource group in the same Azure subscription.

Due to symmetrical nature of the design, the **_right_** and **_left_** deployment are identical. The scripts  in the **left** and **right** folders are different only in the resources name.

All the scripts (with related ARM templates) need to run in sequence; the order is established with the first two digit of the filename. The files are enumerated in the table below with short description.

**Files:**
| File name                           | Description                                                       |
| ----------------------------------- | ----------------------------------------------------------------- |
| **01-hub.json**                     | hub vnet with internal load balancer and NVAs with ip forwarding  |
| **01-hub.ps1**                      | powershell script to run **01-hub.json**                          |
| **02-er-gtw.json**                  | deployment of ExpressRoute gateway and connection                 |
| **02-er-gtw.ps1**                   | powershell script to run **02-er-gtw.json**                       |
| **03-rs.json**                      | deployment of Azure Route server with BGP peering with NVAs       |
| **03-rs.ps1**                       | powershell script to run **03-rs.json**                           |
| **04-spoke1.json**                  | ARM template to deploy the spoke vnet in the mid layer (between the hub and the spoke in the leaves ) |
| **04-spoke1.ps1**                   | powershell script to run **04-spoke1.json**                       |
| **05-vnetpeering-hub-spoke.json**   | deployment of vnet peering between hub and spoke vnet             |
| **05-vnetpeering-hub-spoke.ps1**    | powershell script to run **05-vnetpeering-hub-spoke.json**        |
| **06-spoke-spoke.json**             | ARM template to create the spoke vnet in the leaves               |
| **06-spoke-spoke.ps1**              | powershell script to run **06-spoke-spoke.json**                  |
| **07-vnetpeering-spoke-spoke.json** | ARM template to create vnet peering between the spoke in the mid and the spoke in the leaves|
| **07-vnetpeering-spoke-spoke.ps1**  | powershell script to run **07-vnetpeering-spoke-spoke.json**      |
| **init.txt**                        | text file contains:<br> the name of Azure subscription <br> the name of the resource group<br> the name of the Azure location|
| **cloud-init.txt**                  | cloud-init file to install nginx in the NVAs and enable ip forwarding |
| **config-quagga-hub00-nva1.txt**    | bash script to install quagga in the nva1 (in the hub) and configure BGP peering with Route Server |
| **config-quagga-hub00-nva2.txt**    | bash script to install quagga in the nva2 (in the hub) and configure BGP peering with Route Server |
| **Route-Server-getting-routes.ps1** | powershell script to fetch the route table of the Azure Route Server |

To make the full setup, run the scripts in the **left** and **right** folder.

The folder **vnet-peering-hub-to-hub** contains the ARM template to create the vnet peering between the vnets **hub00** and **hub60**. The script requires the presence of **hub00** and **hub60** to run successful. The script fails if the **hub00** (**_left_** side) and **hub60** (**_right_** side) are not present.

The scripts **01-hub.json** **04-spoke1.json** deploy Ubuntu VMs with RSA key to authenticate and login.

The script **06-spoke-spoke.json** uses username and password to autheticate and login in the VMs.


Before spinning up the ARM template, you should edit the file **init.txt** and customize the variables:
- **subscriptionName**: name of your Azure subscription 
- **location**: Azure region
- **rgName**: resource group name
 
 In the powershell scripts **01-hub.ps1**, **04-spoke1.ps1** customize value for the variables:
- **ADMINISTRATOR_USERNAME**: replace with your administrator username 
- **SSH_PUBLIC_KEY**: replace with the value of public RSA key associated with the administrator

 In the powershell script **06-spoke-spoke.ps1** customize value for the variables:
- **ADMINISTRATOR_USERNAME**: replace with your administrator username 
- **ADMINISTRATOR_PASSWORD**: replace with the value of administrator password

 The value of tags  **$RGTagExpireDate**, **$RGTagContact**,**$RGTagNinja**, **$RGTagUsage** associated with the resource group are optionals and only used to identify the purpose of the project.


## <a name="BGP route table"></a>3. BGP routing table in on-premises edge router

BGP routing table in the customer's edge routers:
```
     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.0.0.0/24      192.168.13.18                          0 12076 i
 *>   10.0.0.0/16      192.168.13.18                          0 12076 i
 *>   10.1.0.0/16      192.168.13.18                          0 12076 i
 *>i  10.2.13.0/25     192.168.13.1                  100      0 i
 *>   10.6.0.0/24      192.168.13.18                          0 12076 i
 *>   10.6.0.0/16      192.168.13.18                          0 12076 i
 *>   10.7.0.0/16      192.168.13.18                          0 12076 i
```
192.168.13.18: IP address of network interface of customer's edge router

192.168.13.1: on-premises device advertising the on-premises network 10.2.13.0/25 to the ExpressRoute circuit

10.0.0.0/24: address space of the hub00

10.0.0.0/16, 10.1.0.0/16: major networks advertised from the ExpressRoute Gateway on the **_left_** side

10.6.0.0/24: address space of the hub60

10.0.0.0/16, 10.1.0.0/16: major networks advertised from the ExpressRoute Gateway on the **_left_** side

## <a name="route server"></a>4. Routing table in Azure route server
```console
routes advertised to nva1:
PS C:\> Get-AzVirtualRouterPeerAdvertisedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name
LocalAddress Network      NextHop    SourcePeer Origin AsPath            Weight
------------ -------      -------    ---------- ------ ------            ------
10.0.0.100   10.0.0.0/24  10.0.0.100            Igp    65515                  0
10.0.0.100   10.2.13.0/25 10.0.0.100            Igp    65515-12076-65021      0
10.0.0.100   10.6.0.0/24  10.0.0.100            Igp    65515-12076-12076      0
10.0.0.101   10.0.0.0/24  10.0.0.101            Igp    65515                  0
10.0.0.101   10.2.13.0/25 10.0.0.101            Igp    65515-12076-65021      0
10.0.0.101   10.6.0.0/24  10.0.0.101            Igp    65515-12076-12076      0


routes learned from nva1:
PS C:\> Get-AzVirtualRouterPeerLearnedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name
LocalAddress Network     NextHop   SourcePeer Origin AsPath Weight
------------ -------     -------   ---------- ------ ------ ------
10.0.0.100   10.0.0.0/16 10.0.0.85 10.0.0.85  EBgp   65000   32768
10.0.0.100   10.1.0.0/16 10.0.0.85 10.0.0.85  EBgp   65000   32768
10.0.0.101   10.0.0.0/16 10.0.0.85 10.0.0.85  EBgp   65000   32768
10.0.0.101   10.1.0.0/16 10.0.0.85 10.0.0.85  EBgp   65000   32768
```

## <a name="effective routes"></a>5. Effective routes
**Effective routes in hub00-nva1-NIC:** 
|Source                 |	State	| Address Prefixes|	Next Hop Type   |	Next Hop IP Address    | User Defined Route Name|
| --------------------- | ------ | ------------ | ------------------- |----------------------- |------------------------|
|Default	               |Active  |10.0.0.0/24	|Virtual network	    |-	|-|
|Default	               |Active	|10.0.1.0/24	|VNet peering	       |-	|-|
|Default	               |Active	|10.6.0.0/24	|VNet peering	       |-	|-|
|Virtual network gateway|Active	|10.2.13.0/25	|Virtual network gateway |10.3.129.67	|-|
|Virtual network gateway|Active	|10.2.13.0/25	|Virtual network gateway |10.3.129.66	|-|
|Virtual network gateway|Invalid	|10.0.0.0/16	|Virtual network gateway |10.0.0.85	|-|
|Virtual network gateway|Invalid	|10.0.0.0/16	|Virtual network gateway |10.0.0.86	|-|
|Virtual network gateway|Invalid	|10.1.0.0/16	|Virtual network gateway |10.0.0.85	|-|
|Virtual network gateway|Invalid	|10.1.0.0/16	|Virtual network gateway |10.0.0.86	|-|
|Default	               |Active	|0.0.0.0/0	   |Internet	          |-	|-|
|User	                  |Active	|10.0.0.0/16	|Virtual appliance	|10.0.1.5	|RT-majorNetwork1|
|User	                  |Active	|10.1.0.0/16	|Virtual appliance	|10.0.1.5	|RT-majorNetwork2|
|User	                  |Active	|10.6.0.0/15	|Virtual appliance	|10.6.0.68	|RT-majorRemote|
<br>

**There is no way to query the effective route table for a VMSS instance; the effective route table can't be fetched from the VMSS in the spoke01 and spoke61.**
<br>

**Effective routes in spoke04-vm1-NIC:**
|Source                 |	State	| Address Prefixes|	Next Hop Type   |	Next Hop IP Address    | User Defined Route Name|
| --------------------- | ------ | ------------ | ------------------- |----------------------- |------------------------|
|Default	               |Active	|10.0.4.0/24	|Virtual network	    |-	|-|
|Default	               |Active	|10.0.1.0/24	|VNet peering	       |-	|-|
|Default	               |Invalid	|0.0.0.0/0	   |Internet	          |-	|-|
|User	                  |Active	|0.0.0.0/0	   |Virtual appliance	 |10.0.1.5	|RT-Major10_0_0_0|

<br>

**Effective routes in hub60-nva1-NIC:**
|Source                 |	State	| Address Prefixes|	Next Hop Type   |	Next Hop IP Address    | User Defined Route Name|
| --------------------- | ------ | ------------ | ------------------- |----------------------- |------------------------|
|Default	               |Active	|10.6.0.0/24   |Virtual network	    |-	                    |-|
|Default	               |Active	|10.6.1.0/24   |VNet peering	       |-	                    |-|
|Default	               |Active	|10.0.0.0/24   |VNet peering	       |-	                    |-|
|Virtual network gateway|Active	|10.2.13.0/25	|Virtual network gateway|10.3.129.66	        |-|
|Virtual network gateway|Invalid	|10.6.0.0/16	|Virtual network gateway|10.6.0.85	           |-|
|Virtual network gateway|Invalid	|10.6.0.0/16	|Virtual network gateway|10.6.0.86	           |-|
|Virtual network gateway|Invalid	|10.7.0.0/16	|Virtual network gateway|10.6.0.85	           |-|
|Virtual network gateway|Invalid	|10.7.0.0/16	|Virtual network gateway|10.6.0.86	           |-|
|Default	               |Active	|0.0.0.0/0	   |Internet	           |-	                    |-|
|User	                  |Active	|10.6.0.0/16	|Virtual appliance	  |10.6.1.5	              |RT-majorNetwork1|
|User	                  |Active	|10.7.0.0/16	|Virtual appliance	  |10.6.1.5	              |RT-majorNetwork2|
|User	                  |Active	|10.0.0.0/15	|Virtual appliance	  |10.0.0.68	           |RT-remoteMajorNetwork|


<!--Image References-->
[1]: ./media/high-level-diagram.png "high level network diagram"
[2]: ./media/network-diagram.png "network diagram with details"
[3]: ./media/bgp.png "bgp peering between NVAs and the Azure route server"
[4]: ./media/transit.png "bgp peering between NVAs and the Azure route server"
<!--Link References-->

