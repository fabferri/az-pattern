<properties
pageTitle= 'Virtual WAN: route traffic through an NVAs by static routing in hubs'
description= "Virtual WAN: route traffic through an NVAs by static routing in hubs"
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
   ms.date="03/09/2021"
   ms.author="fabferri" />

# Virtual WAN: route traffic through an NVAs by static routing in hubs
This article walks you through a configuration with two virtual hubs with NVAs in spoke VNets. Below the network diagram:

[![1]][1]

- The purpose of configuration is establishing a any-to-any communication between VNets and between VNets and branches. 
- The vnet1, vnet2,vnet3, vnet4 and are associated and propagated to the **defaultRouteTable**.
- The site-to-site connection of branch1 and branch2 are associated and propagated to the **defaultRouteTable**.
- the two spoke VNets, vnet2 and vnet4, have nva2 and nva4 configured with IP forwarding to route traffic to destination addresses different from they own IPs.
- To reach out the spoke VNets (vnet5, vnet6, vnet7, vnet8) do not connected to the hubs, static routes are required in the virtual hub1 and hub2  
- A UDR is required to be applied to the subnets in vnet5, vnet6, vnet7 vnet8 to allow to the traffic to be routed through the NVAs.



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

If all the VNets and branches use private IPv4 address space, the list of major private IPv4 networks in UDRs will work as expected. 

[![2]][2]

## <a name="List of files"></a>2. List of ARM templates and scripts

| file                        | description                                                                |       
| --------------------------- |:-------------------------------------------------------------------------- |
| **01-vwan.json**            | ARM template to create virtual WAN the virtual hubs, VNets, routing table and connections between VNets and virtual hubs  |
| **01-vwan.ps1**             | powershell script to deploy the ARM template **01-vwan.json**              |
| **02-vpn.json**             | ARM template to create the branch1 and branch2<br> The ARM template create  vnet, VPN gateway and one VM in each branch. |
| **02-vpn.ps1**              | powershell script to deploy the ARM template **02-vpn.json**               |
| **03-vwan-site.json**       | create in the hub1 a site-to-site connections with the branch1 and <br> in the hub2 a site-to-site connection with the branch2 |
| **03-vwan-site.ps1**        | powershell script to deploy the ARM template **03-vwan-site.json**         |
| **gettingvalues.json**      | ARM template to fetch the IP addresses of route server and site-to-site VPN in hub1 and hub2 |
| **gettingvalues.ps1**       | powershell script to run **gettingvalues.json**                            |

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
- _3rd step_: run the script **02-vpn.ps1**
- _4rd step_: run the script **03-vwan-site.ps1**
- _5th step_: connect in SSH to the nva2 and nva2 and enable IP forwarding. This is mandatory step to have the right communication any-to-any.


**NOTE**<br>
To enable IP forwarding in linux VM run with root privileges the commands:
```bash
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p
```

<br>



## <a name="routing table association"></a>4. Routing Table and association of the connections  

The network diagram below shows the **defaultRoutingTable** in hub1:
[![3]][3]

<br>

The network diagram below shows the **defaultRoutingTable** in hub2:
[![4]][4]


<br>

The effective routes in nva2:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.2.0/24      | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.0.5.0/24      | VNet peering            | \-                  | \-                      |
| Default                 | Active | 10.0.6.0/24      | VNet peering            | \-                  | \-                      |
| Default                 | Active | 10.10.0.0/23     | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active | 10.0.8.0/24      | Virtual network gateway | 52.250.76.61        | \-                      |
| Virtual network gateway | Active | 10.0.7.0/24      | Virtual network gateway | 52.250.76.61        | \-                      |
| Virtual network gateway | Active | 10.0.1.0/24      | Virtual network gateway | 52.250.76.61        | \-                      |
| Virtual network gateway | Active | 192.168.1.0/24   | Virtual network gateway | 10.10.0.13          | \-                      |
| Virtual network gateway | Active | 192.168.1.0/24   | Virtual network gateway | 10.10.0.12          | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 52.250.76.61        | \-                      |
| Virtual network gateway | Active | 192.168.2.0/24   | Virtual network gateway | 52.250.76.61        | \-                      |
| Virtual network gateway | Active | 10.0.4.0/24      | Virtual network gateway | 52.250.76.61        | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |

- 10.0.1.0/24: address space of the vnet1
- 10.0.2.0/24: address space of the vnet2
- 10.0.3.0/24: address space of the vnet3
- 10.0.4.0/24: address space of the vnet4
- 10.0.5.0/24: address space of the vnet5
- 10.0.6.0/24: address space of the vnet6
- 10.0.7.0/24: address space of the vnet7
- 10.0.8.0/24: address space of the vnet8
- 192.168.1.0/24: address space of the vnet in branch1
- 192.168.2.0/24: address space of the vnet in branch2
- 10.10.0.12: BGP IP address of the site-to-site VPN-instance0 in hub1
- 10.10.0.13: BGP IP address of the site-to-site VPN-instance1 in hub1


Effective routes in vm-branch1:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 192.168.1.0/24   | Virtual network         | \-                  | \-                      |
| Virtual network gateway | Active | 10.10.0.13/32    | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.10.0.13/32    | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.0.8.0/24      | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.0.8.0/24      | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.0.7.0/24      | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.0.7.0/24      | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.10.0.12/32    | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.10.0.12/32    | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.0.6.0/24      | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.0.6.0/24      | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.10.0.0/23     | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.10.0.0/23     | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.0.1.0/24      | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.0.1.0/24      | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.0.5.0/24      | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.0.5.0/24      | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.0.4.0/24      | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.0.4.0/24      | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 192.168.2.0/24   | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 192.168.2.0/24   | Virtual network gateway | 192.168.1.229       | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |

- 10.10.0.12: BGP IP address of the site-to-site VPN-instance0 in hub1
- 10.10.0.13: BGP IP address of the site-to-site VPN-instance1 in hub1
- 192.168.1.228: BGP IP address of the site-to-site VPN-instance0 in branch1
- 192.168.1.229: BGP IP address of the site-to-site VPN-instance1 in branch1



## <a name="getting IPs"></a>5. How to get the IP addresses of route server and site-to-site VPN in the hub
the ARM template **gettingvalues.json** provides an easy way to fetch the IP addresses of route server and site-to-site VPN in hub1 and hub2.

```json
    "outputs": {
        "hub1VirtuaRouteIP1": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.Network/virtualHubs', variables('hub1Name')),'2020-11-01').virtualRouterIps[0]]"
        },
        "hub1VirtuaRouteIP2": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.Network/virtualHubs', variables('hub1Name')),'2020-11-01').virtualRouterIps[1]]"
        },
        "hub2VirtuaRouteIP1": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.Network/virtualHubs', variables('hub2Name')),'2020-11-01').virtualRouterIps[0]]"
        },
        "hub2VirtuaRouteIP2": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.Network/virtualHubs', variables('hub2Name')),'2020-11-01').virtualRouterIps[1]]"
        },
        "hub1vpn_ASN": {
            "type": "int",
            "value": "[reference(resourceId('Microsoft.Network/vpnGateways', format('{0}_S2SvpnGW', variables('hub1Name')) ),'2020-11-01').bgpSettings.asn]"
        },
        "hub1vpn_BGPpeer1": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.Network/vpnGateways', format('{0}_S2SvpnGW', variables('hub1Name')) ),'2020-11-01').bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]]"
        },
        "hub1vpn_BGPpeer2": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.Network/vpnGateways', format('{0}_S2SvpnGW', variables('hub1Name')) ),'2020-11-01').bgpSettings.bgpPeeringAddresses[1].defaultBgpIpAddresses[0]]"
        },
        "hub2vpn_ASN": {
            "type": "int",
            "value": "[reference(resourceId('Microsoft.Network/vpnGateways', format('{0}_S2SvpnGW', variables('hub2Name')) ),'2020-11-01').bgpSettings.asn]"
        },
        "hub2vpn_BGPpeer1": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.Network/vpnGateways', format('{0}_S2SvpnGW', variables('hub2Name')) ),'2020-11-01').bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]]"
        },
        "hub2vpn_BGPpeer2": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.Network/vpnGateways', format('{0}_S2SvpnGW', variables('hub2Name')) ),'2020-11-01').bgpSettings.bgpPeeringAddresses[1].defaultBgpIpAddresses[0]]"
        },

        "hub1vpn_pubIP1": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.Network/vpnGateways', format('{0}_S2SvpnGW', variables('hub1Name')) ),'2020-11-01').ipConfigurations[0].publicIpAddress]"
        },
        "hub1vpn_pubIP2": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.Network/vpnGateways', format('{0}_S2SvpnGW', variables('hub1Name')) ),'2020-11-01').ipConfigurations[1].publicIpAddress]"
        },
        "hub2vpn_pubIP1": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.Network/vpnGateways', format('{0}_S2SvpnGW', variables('hub2Name')) ),'2020-11-01').ipConfigurations[0].publicIpAddress]"
        },
        "hub2vpn_pubIP2": {
            "type": "string",
            "value": "[reference(resourceId('Microsoft.Network/vpnGateways', format('{0}_S2SvpnGW', variables('hub2Name')) ),'2020-11-01').ipConfigurations[1].publicIpAddress]"
        }
    }
```

To get the values, run the ARM template and then the powershell command:
```powershell
(Get-AzResourceGroupDeployment -ResourceGroupName $rgName  -Name NAME_GROUP_DEPLOYMENT).OutputsString
```

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/udr.png "UDR"
[3]: ./media/network-diagram2.png "network diagram"
[4]: ./media/network-diagram3.png "network diagram"
[5]: ./media/network-diagram4.png "network diagram"

<!--Link References-->

