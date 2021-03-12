<properties
pageTitle= 'BGP between two Windows Server 2019 VMs in Azure VNet'
description= "BGP between two Windows Server 2019 VMs in Azure VNet"
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
   ms.date="12/03/2021"
   ms.author="fabferri" />

## BGP between two Windows Server 2019 VMs in Azure VNet
The network diagram is shown below:

[![1]][1]

To enable BGP in the Windows server 2019:
install "Remote Access Role" then "Routing Role Services"

```powershell
Install-WindowsFeature RemoteAccess
Install-WindowsFeature Routing
````
 Enable LAN routing on the system:
```powershell
Install-WindowsFeature RSAT-RemoteAccess-PowerShell
Install-RemoteAccess -VpnType RoutingOnly
```

In the diagram below is shown the BGP peering between vm1 and vm2, the ASN and the IPv4 network prefixes each peer advertises via BGP.

[![2]][2]



> [!NOTE]
> Before spinning up the ARM template you should edit the file **vms.ps1** and set:
> * your Azure subscription name in the variable **$subscriptionName**
> * the administrator username and password of the Azure VMs in the variables **$adminUsername**, **$adminPassword**
>



### <a name="BGP-peer1"></a>1. BGP configuration in vm1

The BGP identifier is the router-id - you can use the IP address assigned to the Azure VM. 
```powershell
Add-BgpRouter -BgpIdentifier 10.0.1.10 -LocalASN 65001
Add-BgpPeer -LocalIPAddress 10.0.1.10 -PeerIPAddress 10.0.2.10 -PeerASN 65002 -Name vm2
```
**Add-BgpPeer** command adds a BGP peer to the BGP router and automatically starts establishing BGP peering session with that neighbor.
The qualifier **-PeeringMode**  has the default value set to **Automatic**.

Add routes:
```powershell
Add-BgpCustomRoute -network 172.16.0.0/24
Add-BgpCustomRoute -network 172.16.1.0/24
Add-BgpCustomRoute -network 172.16.2.0/24
Add-BgpCustomRoute -network 172.16.3.0/24
```

### <a name="BGP-peer2"></a>2. BGP configuration in vm2

The BGP identifier is the router-id - you can use the IP address assigned to the Azure VM. 
```powershell
Add-BgpRouter -BgpIdentifier 10.0.2.10 -LocalASN 65002
Add-BgpPeer -LocalIPAddress 10.0.2.10 -PeerIPAddress 10.0.1.10 -PeerASN 65001 -Name vm1
```
Add routes:
```powershell
Add-BgpCustomRoute -network 192.168.0.0/24
Add-BgpCustomRoute -network 192.168.1.0/24
Add-BgpCustomRoute -network 192.168.2.0/24
Add-BgpCustomRoute -network 192.168.3.0/24
```
### <a name="BGP-check"></a>2. check BGP between vm1 and vm2
Check out the BGP peer:
```powershell
Get-BgpPeer
Get-BgpRouteInformation -Type All
```

In vm1:
```powershell
vm1-PS C:\> Get-BgpPeer

PeerName LocalIPAddress PeerIPAddress PeerASN OperationMode ConnectivityStatus
-------- -------------- ------------- ------- ------------- ------------------
vm2      10.0.1.10      10.0.2.10     65002   Mixed         Connected   

vm1-PS C:\> Get-BgpRouteInformation -Type All

DestinationNetwork NextHop   LearnedFromPeer State        LocalPref MED
------------------ -------   --------------- -----        --------- ---
192.168.0.0/24     10.0.2.10 vm2             Unresolvable              
192.168.1.0/24     10.0.2.10 vm2             Unresolvable              
192.168.2.0/24     10.0.2.10 vm2             Unresolvable              
192.168.3.0/24     10.0.2.10 vm2             Unresolvable  
```
the state of prefixes received is **Unresolvable**.
**ConnectivityStatus** can take the values: Connecting, Connected, Stopped

In vm2:
```powershell
vm2-PS C:\> Get-BgpPeer

PeerName LocalIPAddress PeerIPAddress PeerASN OperationMode ConnectivityStatus
-------- -------------- ------------- ------- ------------- ------------------
vm1      10.0.2.10      10.0.1.10     65001   Mixed         Connected         

vm2-PS C:\> Get-BgpRouteInformation -Type All

DestinationNetwork NextHop   LearnedFromPeer State        LocalPref MED
------------------ -------   --------------- -----        --------- ---
172.16.0.0/24      10.0.1.10 vm1             Unresolvable              
172.16.1.0/24      10.0.1.10 vm1             Unresolvable              
172.16.2.0/24      10.0.1.10 vm1             Unresolvable              
172.16.3.0/24      10.0.1.10 vm1             Unresolvable 
```
the state of prefixes received is **Unresolvable**.


In BGP router, the parameter **DefaultGatewayRouting** indicates that routing of the unresolvable routes to the default (Internet) gateway is enabled or disabled.
To change the status from routes **Unresolvable** to **Best** the parameter **DefaultGatewayRouting**  has to be changed to $true:

```powershell
vm1-PS C:\> Set-BgpRouter -DefaultGatewayRouting $true
vm1-PS C:\> Get-BgpRouter

RoutingDomain            : 
BgpIdentifier            : 10.0.1.10
LocalASN                 : 65001
CompareMEDAcrossASN      : False
DefaultGatewayRouting    : True
IPv6Routing              : Disabled
LocalIPv6Address         : 
PeerName                 : {vm2}
PolicyName               : 
TransitRouting           : Disabled
RouteReflector           : Disabled
ClusterId                : 
ClientToClientReflection : 

vm1-PS C:\> Get-BgpRouteInformation

DestinationNetwork NextHop   LearnedFromPeer State LocalPref MED
------------------ -------   --------------- ----- --------- ---
192.168.0.0/24     10.0.2.10 vm2             Best               
192.168.1.0/24     10.0.2.10 vm2             Best               
192.168.2.0/24     10.0.2.10 vm2             Best               
192.168.3.0/24     10.0.2.10 vm2             Best 
```
The same operation has to be applied to the vm2.

Learned routes in BGP are present in routing table:
```powershell
vm1-PS C:\> get-netroute 

ifIndex DestinationPrefix                              NextHop                                  RouteMetric ifMetric PolicyStore
------- -----------------                              -------                                  ----------- -------- -----------
5       255.255.255.255/32                             0.0.0.0                                          256 10       ActiveStore
1       255.255.255.255/32                             0.0.0.0                                          256 75       ActiveStore
5       224.0.0.0/4                                    0.0.0.0                                          256 10       ActiveStore
1       224.0.0.0/4                                    0.0.0.0                                          256 75       ActiveStore
5       192.168.3.0/24                                 10.0.1.1                                           0 10       ActiveStore
5       192.168.2.0/24                                 10.0.1.1                                           0 10       ActiveStore
5       192.168.1.0/24                                 10.0.1.1                                           0 10       ActiveStore
5       192.168.0.0/24                                 10.0.1.1                                           0 10       ActiveStore
5       169.254.169.254/32                             10.0.1.1                                           1 10       ActiveStore
5       168.63.129.16/32                               10.0.1.1                                           1 10       ActiveStore
1       127.255.255.255/32                             0.0.0.0                                          256 75       ActiveStore
1       127.0.0.1/32                                   0.0.0.0                                          256 75       ActiveStore
1       127.0.0.0/8                                    0.0.0.0                                          256 75       ActiveStore
5       10.0.1.255/32                                  0.0.0.0                                          256 10       ActiveStore
5       10.0.1.10/32                                   0.0.0.0                                          256 10       ActiveStore
5       10.0.1.0/24                                    0.0.0.0                                          256 10       ActiveStore
5       0.0.0.0/0                                      10.0.1.1                                           0 10       ActiveStore
5       ff00::/8                                       ::                                               256 10       ActiveStore
1       ff00::/8                                       ::                                               256 75       ActiveStore
5       fe80::cc68:45:a865:babd/128                    ::                                               256 10       ActiveStore
5       fe80::/64                                      ::                                               256 10       ActiveStore
1       ::1/128                                        ::                                               256 75       ActiveStore
```
**PolicyStore** specifies the PolicyStore value. The acceptable values for this parameter are:
* ActiveStore. Current routing information, used by the OS. When a computer reboots, information in this store is lost.
* PersistentStore. Cannot be used. Routing information in this store preserved across reboots. When a computer starts, it copies the saved settings from this store to the ActiveStore.

By default, a route is saved in both stores. 


To fetch BGP peering-related message and route advertisement statistics:
```
vm1-PS C:\> Get-BgpStatistics

PeerName                 : vm2
TcpConnectionEstablished : 3/12/2021 3:46:29 PM
TcpConnectionClosed      : 3/12/2021 3:46:36 PM
OpenMessage              : LastSent      : 3/12/2021 3:46:29 PM
                           LastReceived  : 3/12/2021 3:46:29 PM
                           SentCount     : 1
                           ReceivedCount : 1
NotificationMessage      : LastSent      : 
                           LastReceived  : 
                           SentCount     : 0
                           ReceivedCount : 0
KeepAliveMessage         : LastSent      : 3/12/2021 5:28:14 PM
                           LastReceived  : 3/12/2021 5:28:17 PM
                           SentCount     : 116
                           ReceivedCount : 116
RouteRefreshMessage      : LastSent      : 
                           LastReceived  : 
                           SentCount     : 0
                           ReceivedCount : 0
UpdateMessage            : LastSent      : 3/12/2021 3:46:30 PM
                           LastReceived  : 3/12/2021 3:46:30 PM
                           SentCount     : 1
                           ReceivedCount : 1
IPv4Route                : UpdateSentCount        : 4
                           UpdateReceivedCount    : 4
                           WithdrawlSentCount     : 0
                           WithdrawlReceivedCount : 0
IPv6Route                : UpdateSentCount        : 0
                           UpdateReceivedCount    : 0
                           WithdrawlSentCount     : 0
                           WithdrawlReceivedCount : 0
```

### <a name="BGP-remove-network"></a>3. Remove BGP network
In vm1, let remove a network from BGP advertisement:
```powershell
vm1-PS C:\> Get-BgpCustomRoute

Interface : 
Network   : {172.16.0.0/24, 172.16.1.0/24, 172.16.2.0/24, 172.16.3.0/24}

vm1-PS C:\> Remove-BgpCustomRoute -network 172.16.3.0/24
```
> [NOTE!]
> The command **Remove-BgpCustomRoute** removes the entry in BGP table only if the entry is present otherwise it doesn't have any effect.
>


### <a name="BGP-remove-network"></a>4. Add  BGP polices
In vm1
```powershell
vm1-PS C:\> Add-BgpRoutingPolicy -Name RoutePolicy1 -MatchPrefix 172.16.1.0/24 -PolicyType ModifyAttribute -AddCommunity 100:101
 
vm1-PS C:\> Add-BgpRoutingPolicyForPeer -PeerName vm2 -PolicyName RoutePolicy1 -Direction Egress
```
In vm2:
```powershell
vm2-PS C:\> Get-BgpRouteInformation -Network 172.16.1.0/24 | fl

DestinationNetwork : 172.16.1.0/24
NextHop            : 10.0.1.10
State              : Best
Origin             : IGP
Path               : 65001
LocalPref          : 
Community          : {100:101}
MED                : 
LearnedFromPeer    : vm1
OriginatorId       : 
ClusterList        : 
Aggregate          : False
Aggregator         : 

```

### <a name="add static routes"></a>ANNEX
To add static routes to the routeting table of the vm:
```powershell
New-NetRoute -DestinationPrefix <DestinationNetwork> -InterfaceIndex <ifIndex> -NextHop <IP-next-hop>
```
To set the static routes is required the interface index. To get the **ifIndex** of the network interface:
```powershell
Get-NetIPInterface
```

In vm1:
```powershell
vm1-PS C:\> Get-NetIPInterface

ifIndex InterfaceAlias                  AddressFamily NlMtu(Bytes) InterfaceMetric Dhcp     ConnectionState PolicyStore
------- --------------                  ------------- ------------ --------------- ----     --------------- -----------
5       Ethernet 2                      IPv6                  1500              10 Enabled  Connected       ActiveStore
1       Loopback Pseudo-Interface 1     IPv6            4294967295              75 Disabled Connected       ActiveStore
5       Ethernet 2                      IPv4                  1500              10 Enabled  Connected       ActiveStore
1       Loopback Pseudo-Interface 1     IPv4            4294967295              75 Disabled Connected       ActiveStore
```
For vm1 the **ifIndex** is **5**

In vm2:
```powershell
vm2-PS C:\Users\edgeuser> Get-NetIPInterface

ifIndex InterfaceAlias                  AddressFamily NlMtu(Bytes) InterfaceMetric Dhcp     ConnectionState PolicyStore
------- --------------                  ------------- ------------ --------------- ----     --------------- -----------
7       Ethernet 2                      IPv6                  1500              10 Enabled  Connected       ActiveStore
1       Loopback Pseudo-Interface 1     IPv6            4294967295              75 Disabled Connected       ActiveStore
7       Ethernet 2                      IPv4                  1500              10 Enabled  Connected       ActiveStore
1       Loopback Pseudo-Interface 1     IPv4            4294967295              75 Disabled Connected       ActiveStore
```
For vm1 the **ifIndex** is **7**

add static routes in vm1:
```powershell
New-NetRoute -DestinationPrefix 172.16.0.0/24 -InterfaceIndex 5 -NextHop 10.0.1.1
New-NetRoute -DestinationPrefix 172.16.1.0/24 -InterfaceIndex 5 -NextHop 10.0.1.1
```


<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/bgp-peer.png "network diagram"

<!--Link References-->

