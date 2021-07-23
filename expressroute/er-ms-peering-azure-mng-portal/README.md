<properties
pageTitle= 'traffic of Azure Management portal across ExpressRoute Microsoft peering'
description= "traffic of Azure Management portal across ExpressRoute Microsoft peering"
documentationcenter: na
services="networking"
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
   ms.date="21/07/2021"
   ms.author="fabferri" />

# Traffic of Azure management portal across ExpressRoute Microsoft peering
This article provides some information on how to configure the ExpressRoute Microsoft peering to allow to the Azure Management portal traffic to pass across ExpressRoute Microsoft peering. 

## Summary
A good part of the Azure management portal traffic can pass through ExpressRoute Microsoft peering, but access to internet in on-premises network is anyway mandatory, to resolve URLs by public DNS and establish HTTPS connections with public endpoints only available in internet.
To have the traffic of Azure management portal routed through ExpressRoute Microsoft peering, customers have to include in the route filter the *"nearest"* Azure regional BGP community. If the *"nearest"* Azure regional BGP community is not selected, the traffic of Azure management portal will pass across internet.
The communication with Azure Active Directory endpoints can pass across ExpressRoute Microsoft peering if the **Azure Active Directory (12076:5060)** BGP community is enclosed in the route filter.

[![1]][1]

## <a name="security policy in on-premises firewall"></a>1. Azure Management portal is based on combination of multiple different traffics
The Azure management portal traffic is always initialized from an on-premises client by a web browser. In a configuration without ExpressRoute Microsoft peering, the traffic of Azure management portal passes all across internet.
<br>
Below a high level network diagram with ExpressRoute Microsoft peering:

[![2]][2]

To access to the Azure management portal, customers use the URL https://portal.azure.com resolved by public DNS in public IP.
The on-premises DNS has the DNS forwarder pointing to a public DNS, i.e. the DNS of service provider available in internet, able to translate the URL https://portal.azure.com in public IP.
<br>

Azure management portal engages a combination of traffics:
*	*Azure identity* traffic. The web browser needs to connect the Azure Active Directory to get the [access token](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-oauth-ropc). Including the BGP community **Azure Active Directory (12076:5060)** in the route filter, the Azure Identity traffic can mostly transit across ExpressRoute Microsoft peering. The entity of this traffic is low, but crucial to have a successful authentication.
* *static web form content* available only in public CDN. This traffic can't pass across ExpressRoute Microsoft peering. As example, the login forms to authenticate the user with AAD are not available in ExpressRoute Microsoft peering.
*	*Azure Resource Manager* traffic. This traffic can transit through ExpressRoute Microsoft peering. Large part of traffic associated with Azure Management portal is in this category. The Azure Resource Manager is managed by public IP anycast: the traffic is served by public endpoints belonging to the nearest Azure region. For example, if the on-premises client is in Ashburn, the Azure Resource Manager is served by a public IPs associated in East US Azure region.
* *management portal API* traffic.

<br>


**NOTE**
To have the traffic of Azure Resource Manager routed through ExpressRoute Microsoft peering, customers have to include in the route filter the right regional BGP community. If customers do not include in the route filter the *"nearest"* Azure regional BGP community, the Azure Resource Management traffic will pass across internet.
A way for verifying the correct transit across Microsoft peering is to run a traffic capture in the customer's edge routers.  The full list public IPs associated with Azure portal, Azure Resource Manager and Azure Active Directory are available in [Azure IP Ranges and Service Tags – Public Cloud](https://www.microsoft.com/en-us/download/details.aspx?id=56519). Browsing in the network capture taken on the customer's edge router, it can be verified the presence of traffic flows in ExpressRoute Microsoft peering from/to public IPs associated with Azure portal, Azure Resource Manager, Azure Identity.

<br> 

## <a name="security policy in on-premises firewall"></a>2. Security policy in on-premises firewall require access to internet
The Azure Management portal traffic can't transit all through ExpressRoute Microsoft peering, but it requires as mandatory in on-premises network a connection to internet. 
The security policy in on-premises firewall requires traffic permission from on-premises to internet on following ports: 
*	TCP and UDP port 53 to resolve URLs with public DNS resolver,
*	communication in HTTPS with public endpoints only available in internet (i.e. static web forms)
If the access to internet in HTTPS is denied, the connection to the Azure Management portal will fail. 

[![3]][3]

## <a name="traffic capture in on-premises client"></a>3. Traffic capture in on-premises client
In on-premises client the HTTP/HTTPS traffic capture can be done by fiddler (or similar), to find out the main list of URLs required in Azure Management portal:
* portal.azure.com
* login.microsoftonline.com
* aadcdn.msauth.net
* login.live.com
* logincdn.msauth.net
* afd.hosting.portal.azure.net
* *.reactblade.portal.azure.net
* management.azure.com 
* reactblade.portal.azure.net
* bmxservice.trafficmanager.net
* afd.hosting.portal.azure.net
* amcdn.msftauth.net
* web.vortex.data.microsoft.com

All the communications between the on-premises and the URLs reported above use the TCP port 443. 
The file **capture1-client.xlsx** report the summary of fiddler capture in 

## <a name="traffic capture in customer's edge routers"></a>4. Traffic capture in customer's edge router
The capture in customer's edge router is reported in the file.
<br>
Matching the IPs in the capture with the networks and tags reported in [Azure IP Ranges and Service Tags – Public Cloud](https://www.microsoft.com/en-us/download/details.aspx?id=56519) is possibile to build up a summary table:
* in the first column the IPs carved out from the traffic capture in ExpressRoute Microsoft peering
* in the second column the tag name related to the IP 
* in the third column is full network associated to the service, i.e.
```json
    {
      "name": "AzureResourceManager.EastUS",
      "id": "AzureResourceManager.EastUS",
      "properties": {
        "changeNumber": 1,
        "region": "eastus",
        "regionId": 32,
        "platform": "Azure",
        "systemService": "AzureResourceManager",
        "addressPrefixes": [
          "20.62.130.0/23",
          "40.71.13.224/28",
          "40.79.158.0/23",
          "2603:1030:210::180/122",
          "2603:1030:210:402::280/122"
        ],
        "networkFeatures": null
      }
```

| IP collected in capture in edge router| tag name associated with the IP | network prefixes associated with the tag |
| ----------------- | ------------------------------------- | --------------- |
|20.42.6.197        | AzurePortal.EastUS                    | 20.42.6.192/27  | 
|20.190.151.9       | AzureActiveDirectory.ServiceEndpoint  | 20.190.151.0/28 |    
|40.126.28.21       | AzureActiveDirectory.ServiceEndpoint  | 40.126.28.16/29 |
|40.71.13.226       | AzureResourceManager.EastUS           | 40.71.13.224/28 |
|52.226.139.185     | Windows Notification Service          |      -          |

As double check, in the Azure VM in eastus region is possible by **nslookup** queries to find the match between the URL and IP:
```console
C:\Users\>nslookup portal.azure.com
Non-authoritative answer:
Name:    portal-prod-eastus-02.eastus.cloudapp.azure.com
Address:  20.42.6.197
Aliases:  portal.azure.com
          portal.azure.com.trafficmanager.net

C:\Users\>nslookup reactblade.portal.azure.net
Name:    portal-prod-eastus-02.eastus.cloudapp.azure.com
Address:  20.42.6.197
Aliases:  reactblade.portal.azure.net
          portal.azure.com
          portal.azure.com.trafficmanager.net

C:\Users\>nslookup login.microsoftonline.com
Non-authoritative answer:
Name:    www.tm.ak.prd.aadg.akadns.net
Addresses:  20.190.151.69
          20.190.151.9
          20.190.151.134
          20.190.151.133
          20.190.151.7
          20.190.151.67
          20.190.151.6
          20.190.151.131
Aliases:  login.microsoftonline.com
          ak.privatelink.msidentity.com     

C:\Users\>nslookup management.azure.com
Non-authoritative answer:
Name:    rpfd-prod-bl-01.cloudapp.net
Address:  40.71.13.226
Aliases:  management.azure.com
          management.privatelink.azure.com
          arm-frontdoor-prod.trafficmanager.net
          eastus.management.azure.com

C:\Users\>nslookup adnotifications.windowsazure.com
Non-authoritative answer:
Name:    chi.b.ak.prd.aadg.trafficmanager.net
Addresses:  40.126.28.21
          40.126.28.23
          40.126.28.14
          40.126.28.18
          40.126.7.32
          40.126.28.19
          40.126.28.22
          40.126.28.20
Aliases:  adnotifications.windowsazure.com
          ak.prd.aadg.msidentity.com
          www.tm.ak.prd.aadg.trafficmanager.net


C:\Users\>nslookup wns.windows.com
Non-authoritative answer:
Name:    wns.notify.trafficmanager.net
Address:  52.226.139.185
Aliases:  wns.windows.com
```

## <a name="traffic capture in customer's edge routers"></a>5. ANNEX: how to capture the traffic in customer's edge (CE) router
A network diagram with ExpressRoute Microsoft peering, with more details is reported below:

[![4]][4]

In ExpressRoute Microsoft peering, the customer's edge routers CE1 and CE2 routers are generally configured to advertise via eBGP the same public network prefixes (NAT pool) to the primary and secondary link of the same ExpressRoute circuit, without AS path prepending. The traffic between on-premises and Azure pass through both of ExpressRoute physical links, in load balancing. 
<br>

To capture all the traffic in transit across the ExpressRoute Microsoft peering, it is favourable setting up a BGP policy to force the traffic to transit only through one CE router. To force the traffic to pass through CE1, we can increase the AS PATH length on the CE2.

[![5]][5]

<br>

A iBGP session is established between the firewall on-premises and the customer's edge routers CE1 and CE2. The firewall on-premises advertises in BGP the public network XX.YYY.12.66/23 to CE1 and CE2.
<br>
In our case the CE1 and CE2 operates with Cisco IOS-XE.
A snippet of BGP configuration on CE1 (IOS-XE router):
```console
vrf definition 10
 rd 65021:10
 address-family ipv4
 address-family ipv6
 !
interface TenGigabitEthernet0/1/0.101
 description Microsoft Peering to Azure
 encapsulation dot1Q 12 second-dot1q 101
 vrf forwarding 10
 ip address X.1.1.1 255.255.255.252
 bfd interval 300 min_rx 300 multiplier 3
 no bfd echo
 no shutdown
 !
router bgp 65021
 address-family ipv4 vrf 10
  ! MS peering
  neighbor X.1.1.2 remote-as 12076
  neighbor X.1.1.2 activate
  neighbor X.1.1.2 next-hop-self
  neighbor X.1.1.2 soft-reconfiguration inbound
 exit-address-family
```

Below a snippet of configuration on CE2 (IOS-XE):
```console
vrf definition 10
 rd 65021:10
 address-family ipv4
 address-family ipv6
 !
 interface TenGigabitEthernet0/1/0.101
  description Microsoft Peering to Azure
  encapsulation dot1Q 10 second-dot1q 101
  vrf forwarding 10
  ip address X.1.1.5 255.255.255.252
  bfd interval 300 min_rx 300 multiplier 3
  no bfd echo
  no shutdown
 !
router bgp 65021
 address-family ipv4 vrf 10
  ! MS peering
  neighbor X.1.1.6 remote-as 12076
  neighbor X.1.1.6 activate
  neighbor X.1.1.6 route-map PREPEND-1 out
  neighbor X.1.1.6 next-hop-self
  neighbor X.1.1.6 soft-reconfiguration inbound
 exit-address-family

route-map PREPEND-1 permit 10
  set as-path prepend 65021 65021
```

Cisco IOS-XE supports traffic capture by **monitor capture** command.
<br>

The list of Cisco IOS-XE command to activate the capture on CE1 router is shown below:
```console
ip access-list extended Cust10-capture
  permit ip host XX.YYY.12.66 any
  permit ip any host XX.YYY.12.66
 
monitor capture CAP interface TenGigabitEthernet0/1/0.101 both   
monitor capture CAP buffer size 8 
monitor capture CAP access-list Cust10-capture
show monitor capture CAP parameter
 
monitor capture CAP start
monitor capture CAP stop
show monitor capture CAP buffer brief
monitor capture CAP export tftp://10.0.0.1/CAP.pcap
```

Description of IOS-XE commands:
1. Define the interface where the capture occurs:   
   **monitor capture CAP  interface GigabitEthernet0/0/1 both**

2. Define the buffer for the capture (buffer size is in MB)
   **monitor capture CAP buffer circular size 3** 

2. Associate a filter. The filter may be specified inline, or by an ACL or class-map: 
   **monitor capture CAP access-list Cust10-capture**
   
   To display the list of commands used to configure the capture named CAP:<br> 
   **show monitor capture CAP parameter**

3. Start the capture: 
   **monitor capture CAP start**

4. The capture is now active. Allow it to collect the necessary data; to show captures in progress:<br>
   **show monitor capture**

5. Stop the capture:<br>
   **monitor capture CAP stop**

6. Examine the capture in a summary view: <br>
   **show monitor capture CAP buffer brief**

7. Examine the capture in a detailed view: <br>
   **show monitor capture CAP buffer detailed**

8. Examine the capture with dump packets in ASCII format: <br>
   **show monitor capture CAP buffer dump**

9. In addition, export the capture in PCAP format for further analysis (optional): <br> 
   **monitor capture CAP export tftp://10.0.0.1/CAP.pcap**   
  <br>
   where 10.0.0.1 is the IP address of the tftp server.
   
   [Note: Wireshark can open exported pcap files.]

10. To clear the content of the packet buffer:  
   **monitor capture CAP clear**

11. Once the necessary data has been collected, remove the capture: 
   **no monitor capture CAP**

The capture in CE1 is reported in the file **capture-CE1.txt**


<!--Image References-->
[1]: ./media/high-level.png "high level network diagram"
[2]: ./media/network-diagram.png "network diagram"
[3]: ./media/access-internet.png "security policy in on-premises firewall to access to internet in HTTPS and DNS"
[4]: ./media/network-details.png "network diagram inclusive of IPs"
[5]: ./media/bgp-peering.png "BGP peering"
<!--Link References-->

