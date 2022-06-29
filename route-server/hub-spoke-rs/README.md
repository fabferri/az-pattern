<properties
pageTitle= 'Hub-spoke vnets with Route Server and FRR'
description= "Hub-spoke vnets with Route Server and FRR"
documentationcenter: na
services=""
documentationCenter="github"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="howto-Azure-examples"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="Azure vnet peering, Azure Bastion"
   ms.date="28/06/2022"
   ms.review=""
   ms.author="fabferri" />

# Hub-spoke vnets with Route Server and FRR
The article describes a scenario with hub-spoke vnets in peering. The network diagram is shown below:

[![1]][1]

The configuration aims to create a communication between spoke vnets connected to different hubs.<br> 
Let's discuss briefly the configuration:
- the configuration does not use UDRs in spoke vnets, but only in the subnets of NVAs
- an iBGP session is established between **nva1** and **nva2**
- an eBGP session is created between the route server **rs1** and the **nva1**
- an eBGP session is created between the route server **rs2** and the **nva2** 
- configuration in **nva1** and **nva2** is executed at VM bootstrap time through the cloud-init files (**cloud-init-nva1.txt**, **cloud-init-nva2.txt**))
- cloud-init enable _IP forwarding_ (in the Azure object NIC and inside the OS) in nva1 and nva2   
- the vnet peering between hub and spoke vnets are created with the following setting:
   - in the hub vnets hub1 and hub2:     <br>
      "allowVirtualNetworkAccess": true, <br>
      "allowForwardedTraffic": true,     <br>
      **"allowGatewayTransit": true,**   <br>
      **"useRemoteGateways": false,**    <br>
   - in the spoke vnets spoke1, spoke2, spoke3, spoke4:
      "allowVirtualNetworkAccess": true, <br>
      "allowForwardedTraffic": true,     <br>
      **"allowGatewayTransit": false,**  <br>
      **"useRemoteGateways": true,**     <br>
- the Azure Bastion has to be deployed with **Standard** SKU; the properties of Azure Bastion are configured as:<br>
   "disableCopyPaste": false,            <br>
   "enableFileCopy": true,               <br>
   **"enableIpConnect": true,**          <br>
   "enableShareableLink": false,         <br>
   "enableTunneling": true,              <br>
The property **enableIpConnect** is required to connect via Bastion to the VMs via private IP address.
- Azure Bastion can reach out the remote spoke3 and spoke4 vnets through the vnet peering between hub1 and hub2. 
- Azure Bastion connection to the spoke3 and spoke4 transits only through the nva2 (nva1 is not in the path)
- The setup allow/not allow the following communications:
   - **spoke1 <-> spoke2: data path NOT allow**
   - **spoke3 <-> spoke4: data path NOT allow**
   - **spoke1 <-> spoke3: data path allow**
   - **spoke1 <-> spoke4: data path allow**
   - **spoke2 <-> spoke3: data path allow**
   - **spoke2 <-> spoke4: data path allow**
- The ARM template uses the custom script extension to install ngix and setup a simple homepage in vmhub1, vmhub2, vmspoke1,vmspoke2,vmespoke3 and vmspoke4.

The diagram below shows few allow communications between spoke vnets connected to different hubs:

[![2]][2]

The communications between spoke connected to different hubs pass across nva1 and nva2; the paths are symmetrical.

## <a name="list of files"></a>2. Project files

| File name                 | Description                                                                       |
| ------------------------- | --------------------------------------------------------------------------------- |
| **init.json**             | define the value of input variables required for the full deployment              |
| **01-vnets.json**         | ARM template to deploy spoke vnets, hub vnets, Azure bastions, route server, VMs  |
| **01-vnets.ps1**          | powershell script to run **01-vnets.json**                                        |
| **cloud-init-nva1.txt**   | cloud-init file to install and configure FRR in nva1                              |
| **cloud-init-nva2.txt**   | cloud-init file to install and configure FRR in nva2                              |
| **nva1-config.txt**       | FRR configuration applied to **nva1**                                             |
| **nva2-config.txt**       | FRR configuration applied to **nva2**                                             |
| **routing.txt**           | Routing information in **nva1**, **nva2**, **rs1**, **rs2**                       |
| **nva1-config.txt**       | **nva1** configuration                                                            |
| **nva2-config.txt**       | **nva2** configuration                                                            |
| **bgp-nva1.cap**          | IP packets capture between **nva1** and **rs1**                                   |

To run the project, follow the steps in sequence:
1. change/modify the value of input variables in the file **init.json**
2. run the powershell script **01-vnets.ps1**; at the end of execution the two hub-spoke will be created, with the VMs
3. connect to the VMs through Bastion 

<br>

- In **nva1** and **nva2**, to access to the command line interface of the FRR as root privilege run the shell command  **vtysh**
- **bgp-nva1.cap** is the IP data capture between nva1 and rs1; the capture is executed by the tcpdump command:<br>
**nva1# tcpdump -i eth0  'host 10.1.0.132' -w bgp.cap**

The meaning of input variables in **init.json** are shown below:
```json
{
    "subscriptionName": "NAME_OF_AZURE_SUBSCRIPTION",
    "ResourceGroupName": "NAME_OF_RESOURCE_GROUP",
    "locationhub1": "AZURE_LOCATION_hub1_VNET",
    "locationspoke1": "AZURE_LOCATION_spoke1_VNET",
    "locationspoke2": "AZURE_LOCATION_spoke2_VNET",
    "locationhub2": "AZURE_LOCATION_hub2_VNET",
    "locationspoke3": "AZURE_LOCATION_spoke3_VNET",
    "locationspoke4": "AZURE_LOCATION_spoke4_VNET",
    "locationvnet1": "AZURE_LOCATION_vnet1",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "authenticationType": "password",
    "adminPasswordOrKey": "ADMINISTRATOR_PASSWORD",
    "mngIP": "PUBLIC_IP_ADDRESS_TO_FILTER_SSH_ACCESS_TO_VMS - it can be empty string, if you do not want to filter access!"
}
```

## <a name="nva1 and nva2 configurations"></a>3. Notes on nva1 and nva2 configurations

* The route-map associated with each peer: <br>
   **route-map BGP_IN in**   <br>
   **route-map BGP_OUT out** <br>
   are required becasue in FRR by default the BGP policy is to discard ingress and egress BGP advertisements. <br>
   In absence of route-map, the command **"show ip bgp neighbor"** shows the output:<br> 
   _Inbound updates discarded due to missing policy_
   _Outbound updates discarded due to missing policy_

* Loop prevention in eBGP is done by verifying the AS number in the AS Path. If the receiving router sees its own AS number in the AS Path of the received BGP packet, the packet is dropped. The receiving router assumes that the packet was originated from its own AS and has reached the same place from where it originated initially. The default behaviour can be override by the statement **"neighbor <IP_Addr_Peer> as-override"**. In our case we have the following routing:

[![3]][3]

## <a name="Effective routing tables"></a>3. Effective routing tables

The nva1 advertise to the rs1 the following networks:
```console
nva1# show ip bgp neighbors 10.1.0.132 advertised-routes 
BGP table version is 13, local router ID is 10.1.0.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.1.0/24      0.0.0.0                  0         32768 i
*> 10.0.2.0/24      0.0.0.0                  0         32768 i
*> 10.0.3.0/24      0.0.0.0                       100      0 i
*> 10.0.4.0/24      0.0.0.0                       100      0 i
*> 10.1.0.0/24      0.0.0.0                                0 65001 i
*> 10.2.0.0/24      0.0.0.0                       100      0 65001 i
*> 10.255.0.0/24    0.0.0.0                                0 65001 i

Total number of prefixes 7
```

The route server learns the following network from the nva1:
```console
Get-AzRouteServerPeerlearnedRoute -RouteServerName rs1 -ResourceGroupName $rgName -peername $peerName |ft

LocalAddress Network       NextHop   SourcePeer Origin AsPath      Weight
------------ -------       -------   ---------- ------ ------      ------
10.1.0.133   10.0.1.0/24   10.1.0.10 10.1.0.10  EBgp   65001        32768
10.1.0.133   10.0.2.0/24   10.1.0.10 10.1.0.10  EBgp   65001        32768
10.1.0.133   10.1.0.0/24   10.1.0.10 10.1.0.10  EBgp   65001-65001  32768
10.1.0.133   10.255.0.0/24 10.1.0.10 10.1.0.10  EBgp   65001-65001  32768
10.1.0.133   10.0.3.0/24   10.1.0.10 10.1.0.10  EBgp   65001        32768
10.1.0.133   10.0.4.0/24   10.1.0.10 10.1.0.10  EBgp   65001        32768
10.1.0.133   10.2.0.0/24   10.1.0.10 10.1.0.10  EBgp   65001-65001  32768
10.1.0.132   10.0.1.0/24   10.1.0.10 10.1.0.10  EBgp   65001        32768
10.1.0.132   10.0.2.0/24   10.1.0.10 10.1.0.10  EBgp   65001        32768
10.1.0.132   10.1.0.0/24   10.1.0.10 10.1.0.10  EBgp   65001-65001  32768
10.1.0.132   10.255.0.0/24 10.1.0.10 10.1.0.10  EBgp   65001-65001  32768
10.1.0.132   10.0.3.0/24   10.1.0.10 10.1.0.10  EBgp   65001        32768
10.1.0.132   10.0.4.0/24   10.1.0.10 10.1.0.10  EBgp   65001        32768
10.1.0.132   10.2.0.0/24   10.1.0.10 10.1.0.10  EBgp   65001-65001  32768
```
The network 10.0.1.0/24 and 10.0.2.0/24 are advertised from nva1 to rs1 with next-hop 10.1.0.10  
Anyway, those routes are <ins>not</ins> propagated in the system routing table of hub1 with next-hope 10.1.0.10 because the vnet peering has higher priority over BGP advertisement.

The **vmhub1** has the following effective routes:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.1.0.0/24      | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.255.0.0/24    | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.0.2.0/24      | VNet peering            | \-                  | \-                      |
| Default                 | Active | 10.0.1.0/24      | VNet peering            | \-                  | \-                      |
| Default                 | Active | 10.2.0.0/24      | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 10.1.0.10           | \-                      |
| Virtual network gateway | Active | 10.0.4.0/24      | Virtual network gateway | 10.1.0.10           | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |

The networks 10.0.1.0/24, 10.0.2.0/24 are inserted in the effective routing table with next-hop **VNet peering** 

The **vmspoke1** has the following effective routes:

| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.1.0/24      | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.1.0.0/24      | VNet peering            | \-                  | \-                      |
| Default                 | Active | 10.255.0.0/24    | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 10.1.0.10           | \-                      |
| Virtual network gateway | Active | 10.2.0.0/24      | Virtual network gateway | 10.1.0.10           | \-                      |
| Virtual network gateway | Active | 10.0.4.0/24      | Virtual network gateway | 10.1.0.10           | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |

The address space of the network spoke2 (10.0.2.0/24) is not present in the effective routing table, then **vmspoke1** won't be able to communicate with **vmspoke2**.
<br>

Same behaviour for **vmspoke2** effective routing table:
| Source                  | State  | Address Prefixes | Next Hop Type           | Next Hop IP Address | User Defined Route Name |
| ----------------------- | ------ | ---------------- | ----------------------- | ------------------- | ----------------------- |
| Default                 | Active | 10.0.2.0/24      | Virtual network         | \-                  | \-                      |
| Default                 | Active | 10.1.0.0/24      | VNet peering            | \-                  | \-                      |
| Default                 | Active | 10.255.0.0/24    | VNet peering            | \-                  | \-                      |
| Virtual network gateway | Active | 10.2.0.0/24      | Virtual network gateway | 10.1.0.10           | \-                      |
| Virtual network gateway | Active | 10.0.3.0/24      | Virtual network gateway | 10.1.0.10           | \-                      |
| Virtual network gateway | Active | 10.0.4.0/24      | Virtual network gateway | 10.1.0.10           | \-                      |
| Default                 | Active | 0.0.0.0/0        | Internet                | \-                  | \-                      |

The address space of the network spoke1 (10.0.1.0/24) is not present in the effective routing table, then the **vmspoke2** won't be able to communicate with **vmspoke1**.

[![4]][4]

## <a name="Effective routing tables"></a>4. Communication between spoke vnets in peering with hub
Communication between spoke vnets connected with the same hub can be achieved with UDRs applied to the spoke vnets, as in the diagram:

[![5]][5]

In this case, the presence of UDRs in spoke vnets create a static route in system routing table forcing the traffic towards the local nva. <br>
**_NOTE: the ARM template does not create the UDRs applied to the spoke vnets._**

`Tags: hub-spoke vnets, route server`
`date: 28-06-22`

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "few communications between spoke vnets"
[3]: ./media/bgp-peering.png "BGP peering between rs1-nva1-nva2-rs2"
[4]: ./media/network-diagram3.png "not allow datapath between spoke vnet connected to the same hub"
[5]: ./media/network-diagram4.png "adding UDR to the spoke vnets allow the communication spoke-to-spoke connected to the same hub"

<!--Link References-->

