<properties
pageTitle= 'Hub-spoke vnets with Azure Bastion in one hub vnet'
description= "Hub-spoke vnets with Azure Bastion in one hub vnet"
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
   ms.date="18/07/2022"
   ms.review=""
   ms.author="fabferri" />

# Hub-spoke vnets with Azure Bastion in one hub vnet
The article describes a scenario with hub-spoke vnets in peering, with Azure Bastion deployed only in one hub vnet. The network diagram is reported below:

[![1]][1]

The configuration aims to use a single Azure Bastion in hub1 to manage all the VMs in the local hub-spoke vnets, as well as in the remote hub-spoke vnets.
- UDRs are required in the spoke3 and spoke4 having as destination the Bastion address space, with nexthop the IP of the nva2;
- in nva2 is enabled the IP forwarding, installed and configured FRR (Free Range Routing) to create a BGP peering with route server in hub1;  
- the Azure Bastion has to be deployed with **Standard** SKU;
- the properties of Azure Bastion are configured as:<br>
   "disableCopyPaste": false,<br>
   "enableFileCopy": true,<br>
   **"enableIpConnect": true,**<br>
   "enableShareableLink": false,<br>
   "enableTunneling": true, <br>
The property **enableIpConnect** is required to connect via Bastion to the VMs via private IP address.  
- Azure Bastion can reach out the remote spoke3 and spoke4 vnets through the vnet peering between hub1 and hub2. 

**NOTE: the UDRs in spoke3 and spok4 are required, otherwise the routing hub1-spoke3, hub1-spoke4 will be broken.**

Connect to vmspoke4 by Bastion:

[![2]][2]

## <a name="list of files"></a>2. Project files

| File name                 | Description                                                                       |
| ------------------------- | --------------------------------------------------------------------------------- |
| **init.json**             | define the value of input variables required for the full deployment              |
| **01-vnets.json**         | ARM template to deploy spoke vnets, hub vnets, Azure bastions, route server, VMs  |
| **01-vnets.ps1**          | powershell script to run **01-vnets.json**                                        |
| **cloud-init-nva2.txt**   | cloud-init file to install and configure FRR in nva2                              |


To run the project, follow the steps in sequence:
1. change/modify the value of input variables in the file **init.json**
2. run the powershell script **01-vnets.ps1**; at the end of execution the two hub-spoke will be created, with the VMs
3. connect to nva2 through Bastion and use the vtysh shell to verify the BGP peering between nva2 and the route server in hub1


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

The ARM template uses the customer script extension to install ngix and setup a simple homepage.

## <a name="nva"></a>2. nva2
The ARM template uses cloud-init to setup ip forwarding, install and configure FRR (Free Range Routing) to create a BGP peering with the route server in the hub1. The diagram below shows the BGP peering between the route server in hub1 and the nva2 in hub2:

[![3]][3]

The route server in hub1 learns the address space of the spoke3 (10.0.3.0/24) and spoke4 (10.0.4.0/24) vnets:

```powershell
Get-AzRouteServerPeerlearnedRoute -RouteServerName rs1 -ResourceGroupName 'hub-spoke-200' -peername 'bgp-conn1' |ft

LocalAddress Network     NextHop   SourcePeer Origin AsPath Weight
------------ -------     -------   ---------- ------ ------ ------
10.1.0.5     10.0.3.0/24 10.2.0.10 10.2.0.10  EBgp   65001   32768
10.1.0.5     10.0.4.0/24 10.2.0.10 10.2.0.10  EBgp   65001   32768
10.1.0.4     10.0.3.0/24 10.2.0.10 10.2.0.10  EBgp   65001   32768
10.1.0.4     10.0.4.0/24 10.2.0.10 10.2.0.10  EBgp   65001   32768
```

The route server in hub1 advertises to the nva2 the address space of the hub1 (10.1.0.0/24):

```powershell
Get-AzRouteServerPeerAdvertisedRoute -RouteServerName rs1 -ResourceGroupName 'hub-spoke-200' -peername 'bgp-conn1' |ft

LocalAddress Network     NextHop  SourcePeer Origin AsPath Weight
------------ -------     -------  ---------- ------ ------ ------
10.1.0.5     10.1.0.0/24 10.1.0.5            Igp    65515       0
10.1.0.4     10.1.0.0/24 10.1.0.4            Igp    65515       0
````

The local address [10.1.0.4, 10.1.0.5] are the internal IPs of the router server. The address space of hub1 10.1.0.0/24 is advertised to the nva2 and set as next-hop the route server IPs.

```console
nva2# show ip bgp
BGP table version is 2, local router ID is 10.2.0.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.3.0/24      0.0.0.0                  0         32768 i
*> 10.0.4.0/24      0.0.0.0                  0         32768 i
   10.1.0.0/24      10.1.0.5                               0 65515 i
                    10.1.0.4                               0 65515 i

Displayed  3 routes and 4 total paths
```

```
nva2# show ip bgp neighbors 10.1.0.4 advertised-routes 
BGP table version is 2, local router ID is 10.2.0.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.0.3.0/24      10.2.0.10                0         32768 i
*> 10.0.4.0/24      10.2.0.10                0         32768 i

Total number of prefixes 2
```

Networks advertised from the router server to the nva2:
```console
nva2# show ip bgp neighbors 10.1.0.4 received-routes 
BGP table version is 2, local router ID is 10.2.0.10, vrf id 0
Default local pref 100, local AS 65001
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.1.0.0/24      10.1.0.4                               0 65515 i

Total number of prefixes 1
```

The snippet of FRR configuration in nva2 is shown below:
```console
ip route 10.0.3.0/24 10.2.0.1
ip route 10.0.4.0/24 10.2.0.1
!
router bgp 65001
 bgp router-id 10.2.0.10
 neighbor 10.1.0.4 remote-as 65515
 neighbor 10.1.0.4 timers 60 180
 neighbor 10.1.0.5 remote-as 65515
 neighbor 10.1.0.5 timers 60 180
 !
 address-family ipv4 unicast
  network 10.0.3.0/24
  network 10.0.4.0/24
  neighbor 10.1.0.4 soft-reconfiguration inbound
  neighbor 10.1.0.4 route-map BGP_IN in
  neighbor 10.1.0.4 route-map BGP_OUT out
  neighbor 10.1.0.5 soft-reconfiguration inbound
  neighbor 10.1.0.5 route-map BGP_IN in
  neighbor 10.1.0.5 route-map BGP_OUT out
 exit-address-family
exit
!
ip prefix-list BGP_OUT2 seq 10 permit 10.0.3.0/24
ip prefix-list BGP_OUT2 seq 20 permit 10.0.4.0/24
ip prefix-list BGP_IN seq 10 permit 0.0.0.0/0 le 32
!
route-map BGP_OUT permit 10
 match ip address prefix-list BGP_OUT2
 set ip next-hop 10.2.0.10
exit
!
route-map BGP_IN permit 10
 match ip address prefix-list BGP_IN
exit
```


`Tags: hub-spoke vnets, Azure Bastion`
`date: 22-06-22`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/bastion.png "from Bastion connect to the VM via IP"
[3]: ./media/bgp-peering.png "bgp peering between the router server in hub1 and the nva2 in hub2"


<!--Link References-->

