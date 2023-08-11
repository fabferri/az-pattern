<properties
pageTitle= 'Virtual WAN with two secure hubs and Private Traffic Routing Policy'
description= "vWAN with two secure hubs and Private Traffic Routing Policy"
documentationcenter: na
services="Azure Virtual WAN"
documentationCenter="na"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="na"
   ms.date="09/08/2023"
   ms.author="fabferri" />

# Virtual WAN with two secure hubs and Private Traffic Routing Policy
This article describes a Virtual WAN configuration with two secure virtual hubs, **hub1** and **hub2**, with **Private Traffic Routing Policy** and  **Internet Traffic Routing Policy** applied to both.<br>
Below the high-level network diagram:

[![1]][1]

The network diagram with IP addresses: 

[![2]][2]

As the documentation says:<br>

**Private Traffic Routing Policy**: When a Private Traffic Routing Policy is configured on a Virtual WAN hub, all branch and Virtual Network traffic in and out of the Virtual WAN Hub including inter-hub traffic will be forwarded to the Next Hop Azure Firewall resource that was specified in the Private Traffic Routing Policy.<br>
When an Internet Traffic Routing Policy is configured on a Virtual WAN hub, the Virtual WAN advertises a default (0.0.0.0/0) route to all spokes, Gateways and Network Virtual Appliances (deployed in the hub or spoke).<br>
In other words, when a Private Traffic Routing Policy is configured on the Virtual WAN Hub, all branch-to-branch, branch-to-virtual network, virtual network-to-branch and inter-hub traffic is sent via Azure Firewall, Network Virtual Appliance or SaaS solution deployed in the Virtual WAN Hub.


**Internet Traffic Routing Policy**: When an Internet Traffic Routing Policy is configured on a Virtual WAN hub, all branch (Remote User VPN (Point-to-site VPN), Site-to-site VPN, and ExpressRoute) and Virtual Network connections to that Virtual WAN Hub forwards Internet-bound traffic to the Azure Firewall, Third-Party Security provider, Network Virtual Appliance or SaaS solution specified as part of the Routing Policy.

- **hub1 configuration**: Private Traffic Policy with next hop azfw_hub1
- **hub2 configuration**: Private Traffic Policy with next hop azfw_hub2 


The configuration allows the following traffic flows:

| From          | To | hub1 VNets              | hub1 branches           | hub2 VNets              | hub2 branches           | Internet     |
| ------------- | -- | ----------------------- | ----------------------- | ----------------------- | ----------------------- | ------------ |
| hub1 VNets    | →  | azfw_hub1               | azfw_hub1               | azfw_hub1 and azfw_hub2 | azfw_hub1 and azfw_hub2 | azfw_hub1    |
| hub1 Branches | →  | azf1                    | azfw_hub1               | azfw_hub1 and azfw_hub2 | azfw_hub1 and azfw_hub2 | azfw_hub1    |
| hub2 VNets    | →  | azfw_hub2 and azfw_hub1 | azfw_hub2 and azfw_hub1 | azfw_hub2               | azfw_hub2               | azfw_hub2    |
| hub2 Branches | →  | azfw_hub2 and azfw_hub1 | azfw_hub2 and azfw_hub1 | azfw_hub2               | azfw_hub2               | azfw_hub2    |

A representation of traffic flows with **Private Traffic Routing Policy** is reported in the diagram:

[![3]][3]

A representation of traffic flows with **Internet Traffic Routing Policy** is reported in the diagram:

[![4]][4]

The security policies in Azure firewalls are "weak", because the intent is not to define policies for production but for testing context only. <br>
For this reason, the network rules rule in security policy allows transit through the firewalls (**azfw_hub1**, **azfw_hub2**) from/to vnets and branches:

|Source IP Group                                    | Destination IP Group                               | Protocol    | Port |
| ------------------------------------------------- | -------------------------------------------------- | ----------- | ---- |
|AddrList_branches, AddrList_onprem, AddrList_vnets | AddrList_branches, AddrList_onprem, AddrList_vnets | TCP, ICMP   | *    |

Networks in IP Groups:
- AddrList_branches: 192.168.1.0/24,192.168.w.0/24 
- AddrList_onprem: 10.1.34.0/25
- AddrList_vnets: 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24, 10.0.4.0/24

## <a name="List of files"></a>1. List of ARM templates and scripts

| file                           | description                                                                |       
| ------------------------------ |:-------------------------------------------------------------------------- |
| **init.json**                  | file with value of input variables. The file **init.json** guarantees a consistency of same input values across all the ARM templates.  |
| **01-vwan.json**               | ARM template to create virtual WAN the virtual hubs, VNets, routing table and connections between VNets and virtual hubs  |
| **01-vwan.ps1**                | powershell script to deploy the ARM template **01-vwan.json**              |
| **02-vpn.json**                | ARM template to create the branch1 and branch2<br> The ARM template create  vnet, VPN gateway and one VM in each branch. |
| **02-vpn.ps1**                 | powershell script to deploy the ARM template **02-vpn.json**               |
| **03-vwan-site.json**          | create in the hub1 a site-to-site connections with the branch1 and <br> in the hub2 a site-to-site connection with the branch2 |
| **03-vwan-site.ps1**           | powershell script to deploy the ARM template **03-vwan-site.json**         |
| **04-routing-intent-hub1.json** | ARM template to set the *Private Traffic Routing Policy** and **Internet Traffic Routing Policy** in **hub1**|
| **04-routing-intent-hub2.json** | ARM template to set the *Private Traffic Routing Policy** and **Internet Traffic Routing Policy** in **hub2**|
| **04-routing-intent-hub1.ps1**  | powershell script to deploy the ARM template **04-routing-intent-hub1.json** |
| **04-routing-intent-hub2.ps1**  | powershell script to deploy the ARM template **04-routing-intent-hub2.json** |
| **04-er.json**                  | create in the hub1 a ExpressRoute connections in hub1                      |
| **04-er.ps1**                   | powershell script to deploy the ARM template **04-er.json**                |


<br>

Before spinning up the powershell scripts, you should edit the file **init.json** and customize the values. The structure of **init.json** file is shown below:
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "subscriptionName": "NAME_AZURE_SUBSCRIPTION",
    "ResourceGroupName": "NAME_RESOURCE_GROUP",
    "hub1location": "AZURE_REGION_HUB1",
    "hub2location": "AZURE_REGION_HUB2",
    "branch1location": "AZURE_REGION_BRANCH1_VNET",
    "branch2location": "AZURE_REGION_BRANCH2_VNET",
    "hub1Name": "NAME_HUB1_VIRTUAL_WAN",
    "hub2Name": "NAME_HUB2_VIRTUAL_WAN",
    "ercircuitId": "EXPRESSROUTE_CIRCUIT_ID",
    "authorizationKey": "878020f0-f6aa-4a8d-9739-a45aacd7f152",
    "er1AddressPrefix": "10.1.34.0/25"
}
```
The file **init.json** guarantees a consistency of input parameters across all the ARM templates. At running time, all the powershell scripts grab the value of input variables from this file.

<br>

**NOTE** <br>
The ARM template **06-er.json** requires access to an existing ExpressRoute circuit through the ExpressRoute circuit ID and the authorization key. The variable **ercircuitId** in **init.json** file has the following format:
```console
/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP_NAME>/providers/Microsoft.Network/expressRouteCircuits/<EXPRESSROUTE_CIRCUIT_NAME>
```

In the following diagrams are shown the deployments related to each ARM template:  

[![5]][5]

[![6]][6]

[![7]][7]

[![8]][8]

[![9]][9]

## <a name="routing intent"></a>2. Routing intent in the hub1 and hub2
The ARM template **04-routing-intent.json** defines the **Private Traffic Routing Policy** and **Internet Traffic Routing Policy** in **hub1** and **hub2**. <br>
Below the json snippet from **04-routing-intent.json** to deploy the **Private Traffic Routing Policy** and **Internet Traffic Routing Policy** in **hub1**:
```json
{
            "type": "Microsoft.Network/virtualHubs/routingIntent",
            "name": "[concat(variables('hub1Name'),'/','hub1-routingintent')]",
            "apiVersion": "2022-05-01",
            "location": "[variables('hub1location')]",
            "dependsOn": [],
            "properties": {
                "routingPolicies": [
                    {
                        "name": "PrivateTrafficPolicy",
                        "destinations": [ "PrivateTraffic" ],
                        "nextHop": "[concat('/subscriptions/',subscription().subscriptionId,'/resourceGroups/',resourceGroup().name,'/providers/Microsoft.Network/azureFirewalls/',variables('hub1fwName') )]"
                    },
                    {
                        "name": "InternetTrafficPolicy",
                        "destinations": [ "Internet" ],
                        "nextHop": "[concat('/subscriptions/',subscription().subscriptionId,'/resourceGroups/',resourceGroup().name,'/providers/Microsoft.Network/azureFirewalls/',variables('hub1fwName') )]"
                    }
                ]
            }
        },
```
the field "destinations" is fixed and takes the value"
- **<ins>"PrivateTraffic"</ins>** for **Private Traffic Routing Policy**
- **<ins>"Internet""</ins>** for **Internet Traffic Routing Policy**

Routing Intent simplifies routing and configuration by managing route associations and propagations of all connections in a hub.
Once routing intent is configured in **hub1**, <ins>static routes</ins> corresponding to the configured routing policies are created automatically in the **defaultRouteTable**:

| Route name                    | Destination type | Destination prefix                      | Next hop  |
| ----------------------------- | ---------------- | --------------------------------------- | --------- |
| _policy_PrivateTrafficPolicy  | CIDR             | 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 | azFw_hub1 |
| _policy_InternetTrafficPolicy | CIDR             | 0.0.0.0/0                               | azFw_hub1 |


Once routing intent is configured in **hub2**, <ins>static routes</ins> corresponding to the configured routing policies are created automatically in the **defaultRouteTable**:

| Route name                    | Destination type | Destination prefix                      | Next hop  |
| ----------------------------- | ---------------- | --------------------------------------- | --------- |
| _policy_PrivateTrafficPolicy  | CIDR             | 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 | azFw_hub2 |
| _policy_InternetTrafficPolicy | CIDR             | 0.0.0.0/0                               | azFw_hub2 |


Once routing intent is configured in **hub1**, the table describes the associated route table and propagated route table of virtual connections:

| Name  | Associated to          | Propagating to      |
| ----- | ---------------------- | ------------------- |
| vnet1 | hub1/defaultRouteTable | hub1/noneRouteTable |
| vnet2 | hub1/defaultRouteTable | hub1/noneRouteTable |


Once routing intent is configured in **hub2**, the table describes the associated route table and propagated route table of virtual connections:

| Name  | Associated to          | Propagating to      |
| ----- | ---------------------- | ------------------- |
| vnet3 | hub2/defaultRouteTable | hub2/noneRouteTable |
| vnet4 | hub2/defaultRouteTable | hub2/noneRouteTable |

The Route tables in **hub1**:
| Name              | Labels  | Associated connections | Propagating connections |
| ----------------- | ------- | ---------------------- | ----------------------- |
| defaultRouteTable | default | 4                      | 0                       |
| None              | none    | 0                      | 4                       |

The connections in **hub1** are in total 4:
- connection with vnet1
- connection with vnet2
- connection with branch1
- connection with ExpressRoute circuit

When the routing intent is configured, the propagation of all connection is created automatically in **None** routing table.

The Route tables in **hub2** 
| Name              | Labels  | Associated connections | Propagating connections |
| ----------------- | ------- | ---------------------- | ----------------------- |
| defaultRouteTable | default | 3                      | 0                       |
| None              | none    | 0                      | 3                       |

The connections in **hub2** are in total 3:
- connection with vnet3
- connection with vnet4
- connection with branch2

## <a name="effective routing"></a>3. Effective routing tables

Effective routing table in **vm1-NIC**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.1.0/24      | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.10.0.0/23     | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active | 192.168.0.0/16   | Virtual network gateway | 10.10.0.132         | \-                      |
| Virtual network gateway | Active | 0.0.0.0/0        | Virtual network gateway | 10.10.0.132         | \-                      |
| Virtual network gateway | Active | 10.0.0.0/8       | Virtual network gateway | 10.10.0.132         | \-                      |
| Virtual network gateway | Active | 172.16.0.0/12    | Virtual network gateway | 10.10.0.132         | \-                      |

where:
- 10.0.1.0/24: **vnet1** address space 
- 10.10.0.132: private IP of **azfw_hub1**
- 10.10.0.0/23: address space **hub1**

Effective routing table in **vm3-NIC**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.3.0/24      | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.11.0.0/23     | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active | 192.168.0.0/16   | Virtual network gateway | 10.11.0.132         | \-                      |
| Virtual network gateway | Active | 0.0.0.0/0        | Virtual network gateway | 10.11.0.132         | \-                      |
| Virtual network gateway | Active | 10.0.0.0/8       | Virtual network gateway | 10.11.0.132         | \-                      |
| Virtual network gateway | Active | 172.16.0.0/12    | Virtual network gateway | 10.11.0.132         | \-                      |

where:
- 10.0.3.0/24: **vnet3** address space 
- 10.11.0.0/23: **hub2** address space 
- 10.11.0.132: private IP of **azfw_hub2**


Effective routing table in **vm-branch1-nic**:
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
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 192.168.2.0/24   | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 192.168.2.0/24   | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.0.4.0/24      | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.0.4.0/24      | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 0.0.0.0/0        | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 0.0.0.0/0        | Virtual network gateway | 192.168.1.229       | \-                      |
| Virtual network gateway | Active | 10.1.34.0/25     | Virtual network gateway | 192.168.1.228       | \-                      |
| Virtual network gateway | Active | 10.1.34.0/25     | Virtual network gateway | 192.168.1.229       | \-                      |

where:
- 192.168.1.228: BGP peering address VPN Gateway in branch1
- 192.168.1.229: BGP peering  address VPN Gateway in branch1
- 192.168.1.0/24: **branch1** address space 
- 192.168.2.0/24: **branch2** address space 
- 10.0.1.0/24: **vnet1** address space
- 10.0.2.0/24: **vnet2** address space
- 10.0.3.0/24: **vnet3** address space
- 10.0.4.0/24: **vnet4** address space
- 10.1.34.0/25: on-premises network advertised from the customer's edge routers to the ExpressRoute circuit

Effective routing table in **vm-branch2-nic**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 192.168.2.0/24   | Virtual network         | \-                  | \-                      |
| Virtual network gateway | Active | 0.0.0.0/0        | Virtual network gateway | 192.168.2.228       | \-                      |
| Virtual network gateway | Active | 0.0.0.0/0        | Virtual network gateway | 192.168.2.229       | \-                      |
| Virtual network gateway | Active | 10.0.4.0/24      | Virtual network gateway | 192.168.2.228       | \-                      |
| Virtual network gateway | Active | 10.0.4.0/24      | Virtual network gateway | 192.168.2.229       | \-                      |
| Virtual network gateway | Active | 10.11.0.13/32    | Virtual network gateway | 192.168.2.228       | \-                      |
| Virtual network gateway | Active | 10.11.0.13/32    | Virtual network gateway | 192.168.2.229       | \-                      |
| Virtual network gateway | Active | 10.1.34.0/25     | Virtual network gateway | 192.168.2.228       | \-                      |
| Virtual network gateway | Active | 10.1.34.0/25     | Virtual network gateway | 192.168.2.229       | \-                      |
| Virtual network gateway | Active | 10.11.0.12/32    | Virtual network gateway | 192.168.2.228       | \-                      |
| Virtual network gateway | Active | 10.11.0.12/32    | Virtual network gateway | 192.168.2.229       | \-                      |
| Virtual network gateway | Active | 10.11.0.0/23     | Virtual network gateway | 192.168.2.228       | \-                      |
| Virtual network gateway | Active | 10.11.0.0/23     | Virtual network gateway | 192.168.2.229       | \-                      |
| Virtual network gateway | Active | 192.168.1.0/24   | Virtual network gateway | 192.168.2.228       | \-                      |
| Virtual network gateway | Active | 192.168.1.0/24   | Virtual network gateway | 192.168.2.229       | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 192.168.2.228       | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 192.168.2.229       | \-                      |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 192.168.2.228       | \-                      |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 192.168.2.229       | \-                      |
| Virtual network gateway | Active | 10.0.1.0/24      | Virtual network gateway | 192.168.2.228       | \-                      |
| Virtual network gateway | Active | 10.0.1.0/24      | Virtual network gateway | 192.168.2.229       | \-                      |


Routing table in ExpressRoute circuit - private peering:
| Network        | Next hop      | LocPrf | Weight | Path                      |
| -------------- | ------------- | ------ | ------ | ------------------------- |
| 0.0.0.0/8      | 10.10.0.14    |        | 0      | 65515                     |
| 0.0.0.0/8      | 10.10.0.15\*  |        | 0      | 65515                     |
| 10.0.1.0/24    | 10.10.0.14    |        | 0      | 65515                     |
| 10.0.1.0/24    | 10.10.0.15\*  |        | 0      | 65515                     |
| 10.0.2.0/24    | 10.10.0.14    |        | 0      | 65515                     |
| 10.0.2.0/24    | 10.10.0.15\*  |        | 0      | 65515                     |
| 10.0.3.0/24    | 10.10.0.14    |        | 0      | 65515 65520 65520 e       |
| 10.0.3.0/24    | 10.10.0.15\*  |        | 0      | 65515 65520 65520 e       |
| 10.0.4.0/24    | 10.10.0.14    |        | 0      | 65515 65520 65520 e       |
| 10.0.4.0/24    | 10.10.0.15\*  |        | 0      | 65515 65520 65520 e       |
| 10.1.34.0/25   | 192.168.34.17 |        | 0      | 65020                     |
| 10.10.0.0/23   | 10.10.0.14    |        | 0      | 65515                     |
| 10.10.0.0/23   | 10.10.0.15\*  |        | 0      | 65515                     |
| 192.168.1.0/24 | 10.10.0.14    |        | 0      | 65515 65010               |
| 192.168.1.0/24 | 10.10.0.15\*  |        | 0      | 65515 65010               |
| 192.168.2.0/24 | 10.10.0.14    |        | 0      | 65515 65520 65520 65011 e |
| 192.168.2.0/24 | 10.10.0.15\*  |        | 0      | 65515 65520 65520 65011 e |

## <a name="how to run the deployment"></a>4. How to run the deployment and runtime
Deployment needs to be carried out in sequence:
- _1st step_: customize the values in **init.json**
- _2nd step_: run the script **01-vwan.ps1**. The runtime is 1 hour and 5 minutes (_estimated time_).
- _3rd step_: run the script **02-vpn.ps1**. The runtime is 20 minutes (_estimated time_).
- _4rd step_: run the script **03-vwan-site.ps1**. the runtime is 5 minutes (_estimated time_).
- _5th step_: run the script **04-er.json**. The runtime is 30 minutes (_estimated time_).

Estimation time to deploy ARM templates:

| ARM template              | runtime              |
| ------------------------- |:-------------------- |
| **01-vwan.json**          | ~ 50 minutes         |
| **02-vpn.json**           |  ~ 20 minutes        |
| **03-vwan-site.json**     |  ~  8 minutes        |
| **04-routing-intent-hub1.json** |  ~ 8 minutes   |
| **04-routing-intent-hub1.json** |  ~ 8 minutes   |
| **05-azfw-logs.json**     |  ~ 25 minutes        |
| **06-er.json**            |  ~ 30 minutes        |


<!--Image References-->

[1]: ./media/network-diagram01.png "high level network diagram"
[2]: ./media/network-diagram02.png "network diagram with IP addresses"
[3]: ./media/network-diagram03.png "traffic flows with Private Traffic Routing Policy"
[4]: ./media/network-diagram04.png "traffic flows with Internet Traffic Routing Policy"
[5]: ./media/network-diagram05.png "deployment of the ARM templates 01-vwan.json and 02-vpn.json"
[6]: ./media/network-diagram06.png "deployment of the ARM templates 03-vwan-site.json"
[7]: ./media/network-diagram07.png "deployment of the ARM templates 04-routing-intent-hub1.json and 04-routing-intent-hub2.json"
[8]: ./media/network-diagram08.png "deployment of the ARM template 05-azfw-logs.json"
[9]: ./media/network-diagram09.png "deployment of the ARM template 06-er.json"

<!--Link References-->

