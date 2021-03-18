<properties
pageTitle= 'Windows Server 2019 as NVA for site-to-site VPN'
description= "Windows Server 2019 as NVA for site-to-site VPN"
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

## Using Windows Server 2019 as NVA for site-to-site VPN
The network diagram is shown below:

[![0]][0]

A site-to-site VPN is established between the Windows server 20219 and the Azure VPN.

A static routing is set through the site-to-site VPN.

The site-to-site VPN in Windows 2019 VM is implemented through the Routing and Remote Access (RRAS)

<br>

**List of files:**
+ **s2s.json**: create all the object with exception of local network gateway and Connection.
+ **s2s.ps1**: powershell script to run the ARM template **s2s.json**
+ **connection.json**: create the locla network gateway for the VPN Gateway in vnet1 and a Connection between Azure VPN Gateway remote vnet2 
+ **connection.ps1**: powershell script to run the ARM template **connection.json**

<br>

> **_NOTE1_**
>
> Deployment needs to be done in sequence: the first run is **s2s.ps1**. When deployment is completed run **connection.ps1**
>
> Before spinning up the ARM template you should edit the file **s2s.ps1** and set:
> * your Azure subscription name in the variable **$subscriptionName**
> * the administrator username and password of the Azure VMs in the variables **$adminUsername**, **$adminPassword**
>

<br>

> **_NOTE2_**
>
> The ARM template **connection.json** requires the public IP of the NVA to create the Connection **"Microsoft.Network/connections"**:
```json
"nvaPublicIP1Id": "[resourceId(variables('resourceGroupNVA'),'Microsoft.Network/publicIPAddresses',variables('nvaPublicIPName'))]"

"gatewayIpAddress": "[reference(variables('nvaPublicIP1Id'),'2020-06-01').ipAddress]"

```


## <a name="BGP-peer1"></a> Install RRAS inWindows server VM
Install Routing and Remote Access (RRAS) on Windows server 2019:

```powershell
# Add RRAS Role
Install-WindowsFeature -Name RemoteAccess, DirectAccess-VPN, Routing -IncludeManagementTools -Verbose
```
When the installation is completed, open the RRSA UI by the command **rrasmgmt.msc** 
Right-click on the server name and select **Configure and Enable Routing and Remote Access**

[![2]][2]

In the wizard 
- select **Secure connection between two private networks**
- leave the "Demand-Dial" Connections as default to **Yes**
- in "IP Address Assigment" keep the default to **Automatically**

[![3]][3]
[![4]][4]
[![5]][5]

At the end of wizard, the RRAS starts and a new wizard named **Demand-dial Interface Wizard** is automatically shown.
- enter the interface name
- select **Connect using virtual private networking (VPN)**
- in "VPN type" select **IKEv2**
- in the "Destination Address" specify the public IP of the Azure VPN Gateway
- in "Protocols and Security" leave **Route IP packet on this interface**
- in "Static Routes for Remote Networks" specify the address space of remove Azure VNet
- in the "Dial-Out Credentials" leave the fields at default blank

[![6]][6]
[![7]][7]
[![8]][8]
[![9]][9]
[![10]][10]
[![11]][11]
[![12]][12]
[![13]][13]
[![14]][14]

At the end of "Demand-dial Interface Wizard" the network interface to the Azure VPN Gateway is status **Disconnected**

Double-click on the interface, 
- in the **Option** tab, set the **Redial attempts** to 3
- in the **Security** tab, select **Use preshared key for authentication** and set the PSK

[![15]][15]
[![16]][16]
[![17]][17]
[![18]][18]


In the Routing and Remote Access, select IPv4 and then add "Static Routes":
- click-on **New Static Route**
- specify as **Destination** the address space of the remote Azure VNet
- set the Metric to 10
- flag the **Use this route to initialize demand-dial connections**

[![19]][19]
[![20]][20]
[![21]][21]

 
The interfaces of the nva Windows VM:

```
C:\>ipconfig

Windows IP Configuration

Ethernet adapter Ethernet 2:

   Connection-specific DNS Suffix  . : qhrkkoe035vexozltqgyrngkxc.zx.internal.cloudapp.net
   Link-local IPv6 Address . . . . . : fe80::8f4:df00:b893:1f47%7
   IPv4 Address. . . . . . . . . . . : 10.0.10.10
   Subnet Mask . . . . . . . . . . . : 255.255.255.0
   Default Gateway . . . . . . . . . : 10.0.10.1

Ethernet adapter Ethernet 3:

   Connection-specific DNS Suffix  . : qhrkkoe035vexozltqgyrngkxc.zx.internal.cloudapp.net
   Link-local IPv6 Address . . . . . : fe80::24b3:5af2:c478:c78a%8
   IPv4 Address. . . . . . . . . . . : 10.0.11.10
   Subnet Mask . . . . . . . . . . . : 255.255.255.0
   Default Gateway . . . . . . . . . :

PPP adapter AzureGW:

   Connection-specific DNS Suffix  . :
   Autoconfiguration IPv4 Address. . : 169.254.0.31
   Subnet Mask . . . . . . . . . . . : 255.255.0.0
   Default Gateway . . . . . . . . . :
```
The ethernet 2 interface is the external interface with gateway. The packets matching the default route 0.0.0.0/0 are forwarded from the interface with the gateway.

The ethernet 3 interface is internal interface and does not have gateway and it is used only to communicate with the VMs in the VNet.

A static route is required to forward the packet coming from vnet1 to the VMs in vnet2 through the internal interface ethernet 3:

[![22]][22]
[![23]][23]


The nva has to be able to route packets with destination different from own IPs. To check the IP forwarding enabled in the network interfaces:
```
PS C:\> Get-NetIPInterface | select ifIndex,InterfaceAlias,AddressFamily,ConnectionState,Forwarding | Sort-Object -Property IfIndex | Format-Table

ifIndex InterfaceAlias              AddressFamily ConnectionState Forwarding
------- --------------              ------------- --------------- ----------
      1 Loopback Pseudo-Interface 1          IPv6       Connected    Enabled
      1 Loopback Pseudo-Interface 1          IPv4       Connected    Enabled
      7 Ethernet 2                           IPv6       Connected    Enabled
      7 Ethernet 2                           IPv4       Connected    Enabled
      8 Ethernet 3                           IPv6       Connected    Enabled
      8 Ethernet 3                           IPv4       Connected    Enabled
     31 Azure GW                             IPv4       Connected    Enabled
```
### <a name="UDR"></a> User Defined Route (UDR)
In our configuration the remote network associated with the local network Gateway [10.0.10.0/24,10.0.11.0/24,10.0.12.0/24] are set automatically pushed from the Azure VPN Gateway to the VMs in the vnet1.
The vnet1 does not required than any UDR.
In the vnet2 one UDR is required, applied to subnet2 and subnet2, to send the remote traffic though the internal interface ethernet 3 of the nva.

| destination Addr  | nexthop type     | nexthop IP |
| ----------------- |------------------| -----------|
| 10.0.3.0/24       | virtualAppliance | 10.0.11.10 |


[![24]][24]


The MTU between the vnet1 and vnet2:
```console
@vm1:~# ping -M do -s 1410 10.0.12.10
PING 10.0.12.10 (10.0.12.10) 1410(1438) bytes of data.
1418 bytes from 10.0.12.10: icmp_seq=1 ttl=63 time=5.84 ms
1418 bytes from 10.0.12.10: icmp_seq=2 ttl=63 time=6.51 ms
1418 bytes from 10.0.12.10: icmp_seq=3 ttl=63 time=8.32 ms
1418 bytes from 10.0.12.10: icmp_seq=4 ttl=63 time=7.24 ms
```
A capture of ping with wireshark shows a max total Ethernet frame length of 1452 byte corresponding to IP packet of 1438 byte.

[![25]][25]

Using nmap is possible to find out the PMTU (Path MTU Discovery): 
```
@vm1:~# nmap --script path-mtu 10.0.12.10
Starting Nmap 7.80 ( https://nmap.org ) at 2021-03-18 18:43 UTC
Nmap scan report for 10.0.12.10
Host is up (0.0090s latency).
Not shown: 998 closed ports
PORT   STATE SERVICE
22/tcp open  ssh
80/tcp open  http

Host script results:
|_path-mtu: 1006 <= PMTU < 1492

Nmap done: 1 IP address (1 host up) scanned in 3.14 seconds

```



### <a name="Legacy"></a> ANNEX - Legacy RRAS setup by powershell
If you use the powershell to setup the site-to-site VPN and you open the RRAS admin UI, you get the message  "Legacy mode is disabled" appears. This is because the legacy setup cannot be represented in the new UI. 
As a workaround, do not use powershell but instead, configure VPN manually in the RRAS admin UI. 

[![26]][26]

```powershell
# $remoteGatewayIP: it is the IP address of the remote Azure VPN 
# $VpnS2SInterfaceName: it is the name of the local dial interface 
# $SharedSecret: it is the PSK of the site-to-site VPN
# $IPv4Subnet: list of remote networks
$remoteGatewayIP = '51.105.5.57'
$VpnS2SInterfaceName = 'AzureGW'
$IPv4Subnet = @("10.0.1.0/24:10","10.0.2.0/24:10","10.0.3.0/24:10")
$SharedSecret = 'mYpassworD101'
 

### Install RRAS role
Install-WindowsFeature -Name RemoteAccess, DirectAccess-VPN, Routing -IncludeManagementTools -Verbose
 
### Install S2S VPN
if ((Get-RemoteAccess).VpnS2SStatus -ne "Installed")
{
Install-RemoteAccess -VpnType VpnS2S
}
 
### Add and configure S2S VPN interface
Add-VpnS2SInterface -Protocol IKEv2 -AuthenticationMethod PSKOnly -NumberOfTries 3 -ResponderAuthenticationMethod PSKOnly -Name $VpnS2SInterfaceName -Destination $remoteGatewayIP -IPv4Subnet $IPv4Subnet -SharedSecret $SharedSecret -Persistent
Set-VpnServerIPsecConfiguration -EncryptionType MaximumEncryption
Set-VpnS2Sinterface -Name $VpnS2SInterfaceName -InitiateConfigPayload $false 
set-VpnS2SInterface -Name $VpnS2SInterfaceName -IdleDisconnectSeconds 0
 
### Restart the RRAS service
Restart-Service RemoteAccess
 
### Dial-in to Azure gateway
Connect-VpnS2SInterface -Name $VpnS2SInterfaceName
```

<!--Image References-->

[0]: ./media/network-diagram.png "network diagram"
[1]: ./media/01.png "setup Windows RRAS"
[2]: ./media/02.png "setup Windows RRAS"
[3]: ./media/03.png "setup Windows RRAS"
[4]: ./media/04.png "setup Windows RRAS"
[5]: ./media/05.png "setup Windows RRAS"
[6]: ./media/06.png "setup Windows RRAS"
[7]: ./media/07.png "setup Windows RRAS"
[8]: ./media/08.png "setup Windows RRAS"
[9]: ./media/09.png "setup Windows RRAS"
[10]: ./media/10.png "setup Windows RRAS"
[11]: ./media/11.png "setup Windows RRAS"
[12]: ./media/12.png "setup Windows RRAS"
[13]: ./media/13.png "setup Windows RRAS"
[14]: ./media/14.png "setup Windows RRAS"
[15]: ./media/15.png "setup Windows RRAS"
[16]: ./media/16.png "setup Windows RRAS"
[17]: ./media/17.png "setup Windows RRAS"
[18]: ./media/18.png "setup Windows RRAS"
[19]: ./media/19.png "setup Windows RRAS"
[20]: ./media/20.png "setup Windows RRAS"
[21]: ./media/21.png "setup Windows RRAS"
[22]: ./media/22.png "setup Windows RRAS"
[23]: ./media/23.png "setup Windows RRAS"
[24]: ./media/UDR.png "UDR"
[25]: ./media/ping-capture.png "setup Windows RRAS"
[26]: ./media/legacy.png "setup Windows RRAS"

<!--Link References-->

