<properties
pageTitle= 'Virtual WAN: route traffic through an NVA in BGP peering with virtual hub'
description= "Virtual WAN: route traffic through an NVA in BGP peering with virtual hub"
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
   ms.date="30/08/2021"
   ms.author="fabferri" />

# Virtual WAN: route traffic through an NVA in BGP peering with virtual hub

This article walks you through a configuration with two virtual hubs with NVAs in spoke VNets. Two spoke VNets have NVAs (nva2 and nva4) with BGP configured in peering with the Virtual Router in the hub. Below the network diagram:

[![1]][1]

- The purpose of configuration is establishing a any-to-any communication between VNets and between VNets and branches. 
- The vnet2 and vnet4 are spoke vnets with NVA with BGP functionalities. The nva2 in vnet2 is configured with AS 65002 and the nva4 in vnet4 is configured with AS 65004.
- the nva2 in vnet2 advertises through BGP to the virtual router in hub1, the address space of the vnet5 (10.0.5.0/24) and vnet6 (10.0.6.0/24) 
- the nva4 in vnet4 advertises through BGP to the virtual router in hub2, the address space of the vnet7 (10.0.7.0/24) and vnet8 (10.0.8.0/24) 
- the NVAs in vnet2 and vnet4 are configured as IP forwarding the traffic to addresses different from they own IPs. 
- The VNets vnet1, vnet2,vnet3, vnet4 and are associated and propagated to the **defaultRouteTable**.
- The site-to-site connection of branch1 and branch2 are associated and propagated to the **defaultRouteTable**.
- The configuration does not require any static route in the virtual hubs. A UDR is required to be applied to the subnets in vnet5, vnet6, vnet7 vnet8 to allow to the traffic to be routed through the NVAs.



## <a name="UDR"></a>1. UDRs applied to the spoke VNets not directed connected to the virtual hubs
The configuration does not require any static route in the virtual hubs, but a UDR is applied to the subnets in vnet5, vnet6, vnet7 vnet8 to allow to the traffic to be routed through the NVAs. 
<br>

The UDRs applied to those VNets can be based on single default entry:
***
 ```console
 0.0.0.0/0     Next-hop-type: Virtual Appliance, Next-hop: <IP address nva>
```
***

or better a list of major private IPv4 networks:
***
```console
10.0.0.0/8     Next-hop-type: Virtual Appliance, Next-hop: <IP address nva>
192.168.0.0/16 Next-hop-type: Virtual Appliance, Next-hop: <IP address nva>
172.16.0.0/12  Next-hop-type: Virtual Appliance, Next-hop: <IP address nva>
```
***

The list of major private IPv4 networks in UDRs work as expected, if all the VNets and branches use private IPv4 address space.

[![2]][2]

## <a name="List of files"></a>2. List of ARM templates and scripts

| file                        | description                                                                |       
| --------------------------- |:-------------------------------------------------------------------------- |
| **01-vwan.json**            | ARM template to create virtual WAN the virtual hubs, VNets, routing table and connections between VNets and virtual hubs  |
| **01-vwan.ps1**             | powershell script to deploy the ARM template **01-vwan.json**              |
| **02-bgp-peering.json**     | ARM template to create the bgp peering between the hub1 and nva2 <br>and<br> the bgp peering between hub2 and nva4  |
| **02-bgp-peering.ps1**      | powershell script to deploy the ARM template **02-bgp-peering.json**       |
| **03-vpn.json**             | ARM template to create the branch1 and branch2<br> The ARM template create  vnet, VPN gateway and one VM in each branch. |
| **03-vpn.ps1**              | powershell script to deploy the ARM template **03-vpn.json**               |
| **04-vwan-site.json**       | create in the hub1 a site-to-site connections with the branch1 and <br> in the hub2 a site-to-site connection with the branch2 |
| **04-vwan-site.ps1**        | powershell script to deploy the ARM template **04-vwan-site.json**         |
| **bgp-ip-foward-nva2.sh**   | bash script to run in nva2. Install and configure quagga. Enable IP forwarding. |
| **bgp-ip-foward-nva4.sh**   | bash script to run in nva4. Install and configure quagga. Enable IP forwarding. |

<br>

Before spinning up the powershell scripts, you should edit the file **init.json** and customize the values:
The structure of **init.json** file is shown below:
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "subscriptionName": "AzureDemo",
    "ResourceGroupName": "vwan1-grp",
    "hub1location": "westus2",
    "hub2location": "westus2",
    "branch1location": "westus2",
    "branch2location": "westus2",
    "hub1Name": "hub1",
    "hub2Name": "hub2",
    "sharedKey": "SHARED_SECRET_SITE_TO_SITE_VPN",
    "mngIP": "PUBLIC_MANAGEMENT_IP_TO_CONNECT_TO_THE_VMs",
    "RGTagExpireDate": "09/30/2021",
    "RGTagContact": "user1@contoso.com",
    "RGTagNinja": "user1",
    "RGTagUsage": "vWAN: route through NVAs in BGP peering with the hubs"
}
```
<br>

Meaning of the variables:
- **adminUsername**: administrator username of the Azure VMs
- **adminPassword**: administrator password of the Azure VMs
- **subscriptionName**: Azure subscription name
- **ResourceGroupName**: name of the resource group
- **hub1location**: Azure region of the virtual hub1
- **hub2location**: Azure region of the virtual hub2
- **branch1location**: Azure region to deploy the branch1
- **branch2location**: Azure region to deploy the branch2
- **hub1Name**: name of the virtual hub1
- **hub2Name**: name of the virtual hub2
- **sharedKey**: VPN shared secret
- **mngIP**: public IP used to connect to the Azure VMs in SSH
- **RGTagExpireDate**: tag assigned to the resource group. It is used to track the expiration date of the deployment in testing.
- **RGTagContact**: tag assigned to the resource group. It is used to email to the owner of the deployment
- **RGTagNinja**: alias of the user
- **RGTagUsage**: short description of the deployment purpose

The file **init.json** guarantees a consistency by assignment of same input parameters across all the ARM templates.
<br>

## <a name="how to run the deployment"></a>3. How to run the deployment
Deployment needs to be carried out in sequence:
- _1st step_: customize the values in **init.json**
- _2nd step_: run the script **01-vwan.ps1**
- _3rd step_: run the script **02-bgp-peering.ps1**
- _4rd step_: run the script **03-vpn.ps1**
- _5th step_: run the script **04-vwan-site.ps1**
- _6th step_: connect in SSH to the nva2 in vnet2 and run the bash script **ip-foward-nva2.sh**
- _7th step_: connect in SSH to the nva4 in vnet4 and run the bash script **ip-foward-nva4.sh**

**NOTE**<br>
Before running the bash scripts **bgp-ip-foward-nva2.sh** and **bgp-ip-foward-nva4.sh**, check the right assignment of IP addresses of virtual router in hub1 and hub2, i.e. by powershell:
```powershell
(Get-AzVirtualHub -ResourceGroupName $rgName -Name hub1).VirtualRouterIps
10.10.0.69
10.10.0.68

(Get-AzVirtualHub -ResourceGroupName $rgName -Name hub2).VirtualRouterIps
10.11.0.69
10.11.0.68
```
The IPs of the virtual routers are used in the bash scripts **bgp-ip-foward-nva2.sh**,**bgp-ip-foward-nva4.sh** in the variables: **virtualrouter_IP1, virtualrouter_IP2** 

<br>

After running the bash script on nva2 and nva4 check the BGP routing table by quagga command line:
```console
show ip bgp
```

- The nva2 advertises in BGP the network 10.0.5.0/24 and 10.0.6.0/24 to the hub2.
- The networks of the branch1 (192.168.1.0/24) and branch2 (192.168.2.0/24) are advertised from the virtual router (10.10.0.68, 10.10.0.69) to the nva2.
```console
nva2# show ip bgp
BGP table version is 0, local router ID is 10.0.2.10
Status codes: s suppressed, d damped, h history, * valid, > best, = multipath,
              i internal, r RIB-failure, S Stale, R Removed
Origin codes: i - IGP, e - EGP, ? - incomplete

   Network          Next Hop            Metric LocPrf Weight Path
   10.0.1.0/24      10.10.0.69                             0 65515 i
                    10.10.0.68                             0 65515 i
   10.0.2.0/24      10.10.0.69                             0 65515 i
                    10.10.0.68                             0 65515 i
   10.0.3.0/24      10.10.0.69                             0 65515 65520 65520 e
                    10.10.0.68                             0 65515 65520 65520 e
   10.0.4.0/24      10.10.0.69                             0 65515 65520 65520 e
                    10.10.0.68                             0 65515 65520 65520 e
*> 10.0.5.0/24      0.0.0.0                  0         32768 i
*> 10.0.6.0/24      0.0.0.0                  0         32768 i
   10.0.7.0/24      10.10.0.68                             0 65515 65520 65520 65004 e
                    10.10.0.69                             0 65515 65520 65520 65004 e
   10.0.8.0/24      10.10.0.68                             0 65515 65520 65520 65004 e
                    10.10.0.69                             0 65515 65520 65520 65004 e
   10.10.0.0/23     10.10.0.69                             0 65515 i
                    10.10.0.68                             0 65515 i
   192.168.1.0      10.10.0.69                             0 65515 65010 i
                    10.10.0.68                             0 65515 65010 i
   192.168.2.0      10.10.0.69                             0 65515 65520 65520 65011 e
                    10.10.0.68                             0 65515 65520 65520 65011 e
```

- The nva4 advertises to the virtual router in hub2, the network 10.0.7.0/24 and 10.0.8.0/24:
```console
nva4# show ip bgp
BGP table version is 0, local router ID is 10.0.4.10
Status codes: s suppressed, d damped, h history, * valid, > best, = multipath,
              i internal, r RIB-failure, S Stale, R Removed
Origin codes: i - IGP, e - EGP, ? - incomplete

   Network          Next Hop            Metric LocPrf Weight Path
   10.0.1.0/24      10.11.0.69                             0 65515 65520 65520 e
                    10.11.0.68                             0 65515 65520 65520 e
   10.0.2.0/24      10.11.0.69                             0 65515 65520 65520 e
                    10.11.0.68                             0 65515 65520 65520 e
   10.0.3.0/24      10.11.0.69                             0 65515 i
                    10.11.0.68                             0 65515 i
   10.0.4.0/24      10.11.0.69                             0 65515 i
                    10.11.0.68                             0 65515 i
   10.0.5.0/24      10.11.0.69                             0 65515 65520 65520 65002 e
                    10.11.0.68                             0 65515 65520 65520 65002 e
   10.0.6.0/24      10.11.0.69                             0 65515 65520 65520 65002 e
                    10.11.0.68                             0 65515 65520 65520 65002 e
*> 10.0.7.0/24      0.0.0.0                  0         32768 i
*> 10.0.8.0/24      0.0.0.0                  0         32768 i
   10.11.0.0/23     10.11.0.69                             0 65515 i
                    10.11.0.68                             0 65515 i
   192.168.1.0      10.11.0.69                             0 65515 65520 65520 65010 e
                    10.11.0.68                             0 65515 65520 65520 65010 e
   192.168.2.0      10.11.0.69                             0 65515 65011 i
                    10.11.0.68                             0 65515 65011 i
```

## <a name="routing table association"></a>4. Routing Table and association of the connections  

The network diagram below shows the **defaultRoutingTable** in hub1 and hub2:

[![3]][3]

**defaultRoutingTable** in hub1:
| Prefix         | Next Hop Type              | Next Hop       | Origin         | AS path           |
| -------------- | -------------------------- | -------------- | -------------- | ----------------- |
| 192.168.1.0/24 | VPN\_S2S\_Gateway          | hub1\_S2SvpnGW | hub1\_S2SvpnGW | 65010             |
| 10.0.1.0/24    | Virtual Network Connection | vnet1\_conn    | vnet1\_conn    |                   |
| 10.0.2.0/24    | Virtual Network Connection | vnet2\_conn    | vnet2\_conn    |                   |
| 10.0.5.0/24    | HubBgpConnection           | bgp\_nva2      | bgp\_nva2      | 65002             |
| 10.0.6.0/24    | HubBgpConnection           | bgp\_nva2      | bgp\_nva2      | 65002             |
| 10.0.7.0/24    | Remote Hub                 | hub2           | hub2           | 65520-65520-65004 |
| 10.0.8.0/24    | Remote Hub                 | hub2           | hub2           | 65520-65520-65004 |
| 192.168.2.0/24 | Remote Hub                 | hub2           | hub2           | 65520-65520-65011 |
| 10.0.3.0/24    | Remote Hub                 | hub2           | hub2           | 65520-65520       |
| 10.0.4.0/24    | Remote Hub                 | hub2           | hub2           | 65520-65520       |


**defaultRoutingTable** in hub2:
| Prefix         | Next Hop Type              | Next Hop       | Origin         | AS path           |
| -------------- | -------------------------- | -------------- | -------------- | ----------------- |
| 192.168.2.0/24 | VPN\_S2S\_Gateway          | hub2\_S2SvpnGW | hub2\_S2SvpnGW | 65011             |
| 10.0.4.0/24    | Virtual Network Connection | vnet4\_conn    | vnet4\_conn    |                   |
| 10.0.3.0/24    | Virtual Network Connection | vnet3\_conn    | vnet3\_conn    |                   |
| 192.168.1.0/24 | Remote Hub                 | hub1           | hub1           | 65520-65520-65010 |
| 10.0.1.0/24    | Remote Hub                 | hub1           | hub1           | 65520-65520       |
| 10.0.2.0/24    | Remote Hub                 | hub1           | hub1           | 65520-65520       |
| 10.0.5.0/24    | Remote Hub                 | hub1           | hub1           | 65520-65520-65002 |
| 10.0.6.0/24    | Remote Hub                 | hub1           | hub1           | 65520-65520-65002 |
| 10.0.7.0/24    | HubBgpConnection           | bgp\_nva4      | bgp\_nva4      | 65004             |
| 10.0.8.0/24    | HubBgpConnection           | bgp\_nva4      | bgp\_nva4      | 65004             |

<br>

The diagram below reports the vnet1 and vnet2 connection to the hub1:

[![4]][4]

<br>

The diagram below reports the vnet3 and vnet4 connection to the hub2:

[![5]][5]

<br>

The effective routes in nva2:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.2.0/24      | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.0.5.0/24      | VNet peering            | \-                  | \-                      |
| Default                 | Active | 10.0.6.0/24      | VNet peering            | \-                  | \-                      |
| Default                 | Active | 10.10.0.0/23     | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 20.69.82.100        | \-                      |
| Virtual network gateway | Active | 192.168.2.0/24   | Virtual network gateway | 20.69.82.100        | \-                      |
| Virtual network gateway | Active | 192.168.1.0/24   | Virtual network gateway | 10.10.0.12          | \-                      |
| Virtual network gateway | Active | 192.168.1.0/24   | Virtual network gateway | 10.10.0.13          | \-                      |
| Virtual network gateway | Active | 10.0.1.0/24      | Virtual network gateway | 20.69.82.100        | \-                      |
| Virtual network gateway | Active | 10.0.8.0/24      | Virtual network gateway | 20.69.82.100        | \-                      |
| Virtual network gateway | Active | 10.0.7.0/24      | Virtual network gateway | 20.69.82.100        | \-                      |
| Virtual network gateway | Active | 10.0.4.0/24      | Virtual network gateway | 20.69.82.100        | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |

- 10.10.0.12: BGP IP address of the site-to-site VPN-instance0 in hub1
- 10.10.0.13: BGP IP address of the site-to-site VPN-instance1 in hub1


Effective routes in vm-branch1:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 192.168.1.0/24   | Virtual network         | \-                  | \-                      |
| Virtual network gateway | Active | 10.10.0.12/32    | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.10.0.12/32    | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.10.0.13/32    | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.10.0.13/32    | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.10.0.0/23     | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.10.0.0/23     | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.0.1.0/24      | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.0.1.0/24      | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 192.168.2.0/24   | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 192.168.2.0/24   | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.0.4.0/24      | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.0.4.0/24      | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.0.5.0/24      | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.0.5.0/24      | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.0.6.0/24      | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.0.6.0/24      | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.0.7.0/24      | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.0.7.0/24      | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.0.8.0/24      | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.0.8.0/24      | Virtual network gateway | 192.168.1.229       | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |

- 192.168.1.228: BGP IP address of the site-to-site VPN-instance0 in branch1
- 192.168.1.229: BGP IP address of the site-to-site VPN-instance1 in branch1



## <a name="estimated deployment time"></a>5. Estimated deployment time
Estimated time of deployment:

- **01-vwan.json**: 35 minutes
- **02-bgp-peering.json**: 2 minutes
- **03-vpn.json**: 15-20 minutes
- **04-vwan-site.json**: 5 minutes

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/udr.png "UDR"
[3]: ./media/network-diagram2.png "network diagram"
[4]: ./media/network-diagram3.png "network diagram"
[5]: ./media/network-diagram4.png "network diagram"

<!--Link References-->

