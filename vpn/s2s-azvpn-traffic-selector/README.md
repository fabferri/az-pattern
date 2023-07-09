<properties
pageTitle= 'Site-to-site VPN between Azure VNets with remote networks statically configured'
description= "Site-to-site VPN between Azure VNets with remote networks statically configured"
documentationcenter: na
services="Azure VPN"
documentationCenter="na"
authors="fabferri"
manager=""
editor="fabferri"/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="na"
   ms.date="26/05/2022"
   ms.author="fabferri" />

# Site-to-site VPN between Azure VNets with remote networks statically configured and traffic selector
This post contains ARM templates to create site-to-site VPNs between three Azure VNets.
The network configuration is shown in the diagram:

[![1]][1]



- The ARM template creates three different VNets in three Azure regions (specified in the ARM template with parameters **location1**, **location2**, and **location3**). 
- In each gateway subnet is create an Azure VPN Gateway:
   * a **vpnGtw1** is created in a vnet1
   * a **vpnGtw2** is created in a vnet2
   * a **vpnGtw3** is created in a vnet3
- The Azure VPN gateways are route-based and deployed in configuration active-active. 
- Two site-to-site IPsec tunnels are established between vpnGtw1-vpnGtw2 
- Two site-to-site IPsec tunnels are established between vpnGtw1-vpnGtw3 
- In each Azure VPN Gateway are configured static routes (in ARM is called **local network gateway**) to forward the IP packets to the remote vnets
- The configuration aims to create a communication between **vnet1 <-> vnet2** and between **vnet1 <-> vnet3** and forbidden the communication between **vnet2 <-> vnet3**. This is typical example happens when **vnet1** works as provider vnet, and the remote **vnet2** and **vnet3** are consumer networks. The remote virtual network **vnet2** and **vnet3** can belong to the same organization with different departments or different organizations that shouldn't communicate. The configuration works likewise for vnet2 and vnet3 replaced with on-premises networks. 
- In the **spoke2** and **spoke3**, in peering with **vnet1**, are deployed workloads to be used by consumer vnets. The project wants to guarantee.
- Azure firewall is created in vnet1 to access between vnet2, vnet3 and spoke2, spoke3. The security policy in azure firewall control the traffic between remote vnets and spokes: 
   - <ins>allow</ins> communication: **vnet2 <-> az firewall <-> spoke2**
   - <ins>allow</ins> communication: **vnet3 <-> az firewall <-> spoke3**
   - <ins>deny</ins> communication: **vnet2 <-> az firewall <-> spoke3**
   - <ins>deny</ins> communication: **vnet3 <-> az firewall <-> spoke2**


## <a name="List of files"></a>1. List of the project files

| file                  | description                                                                    |       
| --------------------- |:------------------------------------------------------------------------------ |
| **init.json**         | Define a list of input variables required for the project. The variables are used as input in all ARM templates |
| **01-vpn.json**       | ARM template to create vnet1,vnet2, vnet3 with Azure VPN Gateways in each vnet |
| **01-vpn.ps1**        | powershell script to deploy the ARM template **vpn1.json**                     |
| **02-vpn-connections.json**  | ARM template to configure local network gateways and Connections between vnet1-vnet2, vnet1-vnet3, vnet2-vnet3|
| **02-vpn-connections.ps1**  | powershell script to deploy the ARM template **02-vpn-connections.json**      |
| **03-spokes.json**    | ARM template to create the spoke2, spoke3 and the peering spoke2-vnet1, spoke3-vnet1|
| **03-spokes.sp1**     | powershell script to deploy the ARM template **03-spokes.json**                     |
| **04-vpn-update-connections.json** | ARM template to update the Local Networks in vpnGtw2 and vpnGtw3 and Connections in vpngGtw1 |
| **04-vpn-update-connections.ps1**  | powershell script to deploy the ARM template **04-vpn-update-connections.json** |
| **05-azfw.json**      | deployment of azure firewall with security policy              |
| **05-azfw.ps1**       | powershell script to deploy the ARM template **05-azfw.json**  |
| **06-udr.json**       | create UDRs to be applied to the subnets in spoke2, spoke3 and in the GatewaySubnet of vnet1 |
| **06-udr.ps1**        | powershell script to deploy the ARM template **06-udr.json**   |

Before running the deployment modify the input variables in the file **init.json** <br>
For a successful deployment, respect the sequence.



## <a name="S2S tunnels established"></a>2. S2S connections established
After deployment of **01-vpn.json**, **02-vpn-connections.json**, the network configuration is shown below:

[![2]][2]

At this stage, the deployment does NOT have yet the spoke2, spoke3 and Azure firewall in vnet1.

A more details about the S2S VPN tunnels between the Azure VPN Gateways **vpnGtw1**, **vpngGtw2**, **vpnGtw3** is shown below:

[![3]][3]


You can verify the following:
- communication <ins>allowed</ins>: **vnet1 <-> vnet2** 
- communication <ins>allowed</ins>: **vnet1 <-> vnet3**
- communication <ins>denied</ins>: **vnet2 <-> vnet3**  

Communication between vnets is shown in the diagram:

[![4]][4]

As reported in the Azure VPN documentation:
- traffic selectors can be defined via the **trafficSelectorPolicies** attribute on a connection
- the custom configured traffic selectors will be proposed **<ins>only when an Azure VPN gateway initiates the connection</ins>**
- the policy or traffic selectors for route-based VPNs are configured as any-to-any (or wild cards)

To deny the communication between **vnet2 <-> vnet3** are required two actions:
1. in the **vpnGtw1** connections specify a traffic selector with wished local networks and destination networks
2. in the **vpnGtw1** connections specify the **connectionMode** attribute as **InitiatorOnly**

[![5]][5]

The Local Networks in **vpngGtw2** shows an inclusion of network 10.0.3.0/24 that should not be present, because the traffic between **vnet2** and **vnet3** is not allowed. 

[![6]][6]

The Local Networks in **vpngGtw1** shows an inclusion of network 10.0.2.0/24 that should not be present, because the traffic between **vnet2** and **vnet3** is not allowed. 

Despite of the inclusion of wrong IP networks in Local Network objects, the traffic selector in the connections associated with **vpnGtw1** stops the wrong communications.

[![7]][7]

[![8]][8]

### <a name="verification traffic between vnets"></a>2.1 Verification traffic between vnet1, vnet2, vnet3
Connect in SSH to the **vm1** and run the curl commands:

```bash
vm1:~$ curl 10.0.2.10
<style> h1 { color: blue; } </style> <h1>
vm2
 </h1>
vm1:~$ curl 10.0.3.10
<style> h1 { color: blue; } </style> <h1>
vm3
 </h1>
```


Connect in SSH to the **vm2** and run the curl commands:
```bash
vm2:~$ curl 10.0.1.10
<style> h1 { color: blue; } </style> <h1>
vm1
 </h1>
vm2:~$ curl 10.0.3.10
```
The command curl 10.0.3.10 fails, as expected.


Connect in SSH to the **vm3** and run the curl commands:
```bash
vm3:~$ curl 10.0.1.10
<style> h1 { color: blue; } </style> <h1>
vm1
 </h1>
vm3:~$ curl 10.0.2.10
```
The command curl 10.0.2.10 fails, as expected.


To generate traffic you can use the cycle:
```bash
vm1:~$ for ((i=1;i<=10000;i++)); do  curl http://10.0.2.10; done
vm1:~$ for ((i=1;i<=10000;i++)); do  curl http://10.0.3.10; done
```
You can run the powershell **get-traffic-values.ps1** to get the traffic in the vpn Connections.

### <a name="effective routing tables"></a>2.2 Effective routing tables

Effective routing table in **vm1-nic**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.0.0/23      | Virtual network         | \-                  | \-                      |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 10.0.1.228          | \-                      |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 10.0.1.229          | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 10.0.1.228          | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 10.0.1.229          | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |

10.0.1.228, 10.0.1.229 are the internal IP address of the **vpnGtw1** in vnet1
10.0.2.228, 10.0.2.229 are the internal IP address of the **vpnGtw2** in vnet2
10.0.3.228, 10.0.3.229 are the internal IP address of the **vpnGtw3** in vnet3


Effective routing table in **vm2-nic**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.2.0/24      | Virtual network         | \-                  | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 10.0.2.228          | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 10.0.2.229          | \-                      |
| Virtual network gateway | Active | 10.0.0.0/23      | Virtual network gateway | 10.0.2.228          | \-                      |
| Virtual network gateway | Active | 10.0.0.0/23      | Virtual network gateway | 10.0.2.229          | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |

The **vm2** has a route to vnet3 (10.0.3.0/24); this is wrong setting that customer should not set in Local Network associated with connection in **vpnGtw2**. Nevertheless the communication between vnet2 and vnet3 is denied by traffic selector in **vpnGtw1**.

Effective routing table in **vm3-nic**:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.3.0/24      | Virtual network         | \-                  | \-                      |
| Virtual network gateway | Active | 10.0.0.0/23      | Virtual network gateway | 10.0.3.228          | \-                      |
| Virtual network gateway | Active | 10.0.0.0/23      | Virtual network gateway | 10.0.3.229          | \-                      |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 10.0.3.228          | \-                      |
| Virtual network gateway | Active | 10.0.2.0/24      | Virtual network gateway | 10.0.3.229          | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |

## <a name="deployment of spoke vnets"></a>3. Deployment of spoke vnets
Deployment of ARM template **03-spokes.json** creates the spoke2 and spoke3 vnets and the vnet peering with vnet1.
At this stage 
- the **vm1** can reach out the **vmspoke2** and **vmspoke3** 
- the **vm2** and **vm3** can't reach out **vmspoke2** and **vmspoke3** because the local networks in VPN Gateways do not have the networks 10.2.0.0/24 and 10.3.0.0/24 in the list.

## <a name="update of local networks in vpnGtw2 and vpnGtw3"></a>4. Adding the address space of spoke2 and spok3 to the local networks in vpngGtw2 and vpngGtw3
Deployment of ARM template **03-spokes.json** creates the spoke2 and spoke3 vnets and the vnet peering with vnet1.
At this stage 
- the **vm1** can reach out the **vmspoke2** and **vmspoke3** 
- the **vm2** and **vm3** can't reach out **vmspoke2** and **vmspoke3** becasue the local networks in VPN Gateways do not have the networks 10.2.0.0/24 and 10.3.0.0/24 in the list.

## <a name="update Local Networks and Connections"></a>5. Update Local Networks and Connections
The ARM template **04-vpn-update-connections.json** updates the Local Networks associated with **vpnGtw2** and **vpnGtw3*, update Traffic Selectors in connections in **vpnGtw1**.

The Local Networks associated with **vpnGtw2** contains the address space of the **spoke2**.
In **vpnGtw1**, the Connection towards **vnet2** contain includes in the traffic selector the address space of the **spoke2**.

[![9]][9]


The Local Networks associated with  **vpnGtw3** contains the address space of the **spoke3**.
In **vpnGtw1**, the Connection towards **vnet3** contain includes in the traffic selector the address space of the **spoke3**.

[![10]][10]

## <a name="Deployment of Azure firewall in vnet1"></a>6. Deployment of Azure firewall in vnet1
The ARM template **05-azfw.json** creates an Azure firewall in **vnet1** with security policy.<br>
The presence of Azure firewall does not influence the communications, because there is no UDR applied to the spoke vnets and Gateway Subnet of vnet1 to force the traffic to transit through the firewall.

[![11]][11]

## <a name="Annex"></a>7. Annex: Reference an existing IP in ARM template
The **02-vpn-connections.json** reference the existing public IPs of VPN gateways. As reported in the official Microsoft documentation, **reference an existing resource (or one not defined in the same template), a full resourceId must be supplied to the reference() function**

In the AM template **02-vpn-connections.json** to get the existing public IP of the VPN Gateway: 
```console
reference(variables('gateway1PublicIP1Id'),'2022-05-01').ipAddress
```
In the ARM template **06-udr.json** to get the private IP of the Azure firewall:
```console
"[reference(resourceId(resourceGroup().name, 'Microsoft.Network/azureFirewalls', variables('firewallName')), '2022-05-01').ipConfigurations[0].properties.privateIPAddress]"
```

`Tags: S2S VPN, site-to-site VPN, Azure VPN, traffic selector` <br>
`date: 08-07-23`

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram - overview" 
[2]: ./media/s2s.png "site-to-site VPN tunnels"
[3]: ./media/s2s-details.png "site-to-site VPN tunnels with details"
[4]: ./media/datapath.png "communication between vnets"
[5]: ./media/traffic-selector1.png "traffic selector applied to the connections in vpnGtw1 towards vnet2"
[6]: ./media/traffic-selector2.png "traffic selector applied to the connections in vpnGtw1 towards vnet3"
[7]: ./media/connection-gtw1-ip1-gtw2-ip1.png "configuration of connection in vpnGtw1 towards vpnGw2-IP1"
[8]: ./media/connection-gtw1-ip2-gtw2-ip2.png "configuration of connection in vpnGtw1 towards vpnGtw2-IP2"
[9]: ./media/update-connections-towards-vnet2.png "update the Connections towards vpnGtw2"
[10]: ./media/update-connections-towards-vnet3.png "update the Connections towards vpnGtw3"
[11]: ./media/az-firewall.png "azure firewall security policy"

<!--Link References-->

