<properties
pageTitle= 'Virtual WAN: BGP peering with virtual hubs'
description= "Virtual WAN: BGP peering with virtual hubs"
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
   ms.date="03/10/2021"
   ms.author="fabferri" />

# Virtual WAN: BGP peering with virtual hubs
This article describes a configuration with two virtual hubs with NVAs in spoke VNets and branches connected to the virtual hubs. Each NVA is in BGP peering with the Azure Virtual WAN hub router. The network diagram is shown below:

[![1]][1]

The nva1, further to communicate with the hub1 router in BGP, has also a communication in BGP to the remote nva101 through site-to-site VPN tunnel.
<br>
The same configuration is present in nva2 with communication in BGP with hub2 router and a BGP session to the remote nva102 through a site-to-site VPN tunnel.  

<br>

Let's discuss in summary the configuration:
- the nva1 in vnet1 is in BGP peering with the Virtual hub Router in hub1.
- the nva101 in vnet101 has a site-to-site VPN with the nva1 in vnet1 and exchange network prefixes through BGP running on top of IPsec tunnel
- the nva2 in vnet2 is in BGP peering with the Virtual hub Router in hub2.
- the nva102 in vnet102 establishes a site-to-site VPN with the nva2 in vnet2 and exchange network prefixes through BGP running on top of IPsec tunnel
- the routing in Virtual networks vnet1 and vnet2 are defined as:
   - Associated route table: **defaultRouteTable**
   - Propagating to route tables: **defaultRouteTable**
- the branches (site-to-site VPN and ExpressRoute) have:
    - Associated route table: **defaultRouteTable**
    - Propagating to route tables: **defaultRouteTable**
- vnet3 is in peering with vnet1. The vnet peering in vnet3 has remote gateway transit disabled.
- vnet4 is in peering with vnet2. The vnet peering in vnet4 has remote gateway transit disabled.
The configuration creates an any-to-any communications between all VMs, in vnets and in the branches (VPN sites and ExpressRoute on-premises site).

The network diagram reports the BGP sessions between NVAs and between NVAs and Virtual hub Routers:
[![2]][2]

<br>

A network diagram inclusive of IP addresses is shown below: 

[![3]][3]

- nva1 
   - nic0-IP: 10.0.0.10
   - nic1-IP: 10.0.0.100
   - IP tunnel interface: 172.16.0.1
   - lookback interface: 192.168.0.1
   - ASN 65001
- nva101
   - nic0-IP: 10.0.101.10
   - nic1-IP: 10.0.101.100
   - IP tunnel interface: 172.16.0.2
   - lookback interface: 192.168.0.2
   - ASN 65101
- nva2 
   - nic0-IP: 10.0.2.10
   - nic1-IP: 10.0.2.100
   - IP tunnel interface: 172.16.0.1
   - lookback interface: 192.168.0.1
   - ASN 65002
- the nva102 has:
   - nic0-IP: 10.0.102.10
   - nic1-IP: 10.0.102.100
   - IP tunnel interface: 172.16.0.2
   - lookback interface: 192.168.0.2
   - ASN 65102
- branch1:
   - vnet address space: 192.168.1.0/24
   - VPN Gateway-BGP IP1: 192.168.1.228
   - VPN Gateway-BGP IP2: 192.168.1.229 
- branch2:
   - vnet address space: 192.168.2.0/24
   - VPN Gateway-BGP IP1: 192.168.2.228
   - VPN Gateway-BGP IP2: 192.168.2.229 

To keep the routing simple the UDRs have the same routing entries inclusive of major networks **10.0.0.0/8**, **192.168.0.0/16** with next-hop the address of internal interface of the nearest NVA. 



## <a name="List of files"></a>1. List of ARM templates and scripts

| file                        | description                                                                |       
| --------------------------- |:-------------------------------------------------------------------------- |
| **01-vms.json**             | ARM template to create vnet1, vnet2, vnet3, vnet4, vnet101, vnet102, all the NVAs and  routing tables  |
| **01-vms.ps1**              | powershell script to deploy the ARM template **01-vms.json**               |
| **02-generate-crs1-config.ps1** | powershell script to generate the site-to-site VPN configuration on csr1 in the vnet1 |
| **02-generate-crs2-config.ps1** | powershell script to generate the site-to-site VPN configuration on csr2 in the vnet2 |
| **02-generate-crs101-config.ps1** | powershell script to generate the site-to-site VPN configuration on csr101 in the vnet101 |
| **02-generate-crs102-config.ps1** | powershell script to generate the site-to-site VPN configuration on csr102 in the vnet101 |
| **03-vwan.json**            | ARM template to create: <br> hub1, hub2, site-to-site VPN Gateway in hub1, site-to-site VPN Gateway in hub2, connection of vnet1 with hub1 and connection of vnet2 with hub2 |
| **03-vwan.ps1**             | powershell script to deploy the ARM template **03-vwan.json**              |
| **04-add-BGP-peer-to-csr1.ps1** | powershell script to generate the IOS XE commands to create BGP peering between csr1 and the hub1 virtual router |
| **04-add-BGP-peer-to-csr2.ps1** | powershell script to generate the IOS XE commands to create BGP peering between csr2 and the hub2 virtual router |
| **04-bgp-conn.json**        | ARMT template to create the BGP connection between hub1 and csr1 and <br> the BGP connection between hub2 and csr2 |
| **04-bgp-conn.ps1**         | powershell script to deploy the ARM template **04-bgp-conn.json**          |
| **05-vpn.json**             | ARM template to create the branch1 and branch2<br> The ARM template create vnet, VPN gateway, local network, connection and one VM in each branch. |
| **02-vpn.ps1**              | powershell script to deploy the ARM template **05-vpn.json**               |
| **06-vwan-site.json**       | create in the hub1 a site-to-site connections with the branch1 and <br> in the hub2 a site-to-site connection with the branch2 |
| **06-vwan-site.ps1**        | powershell script to deploy the ARM template **06-vwan-site.json**         |
| **07-er.json**              | create in the hub1 a ExpressRoute connection with an Expressroute circuit  |
| **07-er.ps1**               | powershell script to deploy the ARM template **07-er.json**                |

The powershell scripts in the live above should run in sequence.
All the scripts and ARM templates consume the values defined in the file **init.json**
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "subscriptionName": "AZURE_SUBSCRIPTION_NAME",
    "ResourceGroupName": "NAME_AZURE_RESOURCE_GROUP",
    "hub1location": "westus2",
    "hub2location": "westus2",
    "branch1location": "westus2",
    "branch2location": "westus2",
    "hub1Name": "hub1",
    "hub2Name": "hub2",
    "sharedKey": "SITE_TO_SITE_VPN_SHARED_SECRET",
    "mngIP": "MANAGEMENT_PUBLIC_IP_ADDRESS",
    "ercircuitId": "/subscriptions/AZURE_SUBSCRIPTION_ID/resourceGroups/ASH-Cust13/providers/Microsoft.Network/expressRouteCircuits/ASH-Cust13-ER",
    "authorizationKey": "29085238-c821-4d2c-8884-bd05823f865c",
    "er1AddressPrefix": "10.2.12.0/25",
    "RGTagExpireDate": "10/30/2021",
    "RGTagContact": "user1@contoso.com",
    "RGTagNinja": "user1",
    "RGTagUsage": "test BGP peering with virtual hubs"
}
```
The variable "mngIP" is the managment public IP used to access in SSH to the Azure VMs. The variable is used to allow traffic inbound in the NSGs applied to the NIC of the VMs.  

<br>

Before running any powershell script, please customize the values in the file **init.json**. The file **init.json** guarantees a consistency of input parameters across all the ARM templates. This is crucial to get a successful deployment.

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
- **ercircuitId**: ExpressRoute circuit Id
- **authorizationKey**: Authorization key associated to the ExpressRoute circuit
- **er1AddressPrefix**: on-premises network advertised to the ExpressRoute circuit
- **RGTagExpireDate**: tag assigned to the resource group. It is used to track the expiration date of the deployment in testing
- **RGTagContact**: tag assigned to the resource group. It is used to email to the owner of the deployment
- **RGTagNinja**: alias of the user
- **RGTagUsage**: short description of the deployment purpose

<br> <br>

The architecture operates with an existing ExpressRoute circuit. In the ARM template **07-er.json**, the existing ExpressRoute circuit is referenced through the ExpressRoute circuit ID and the authorization key. Those values have to be specified in the **init.json** file. The variable **ercircuitId** has the following format:
```console
/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP_NAME>/providers/Microsoft.Network/expressRouteCircuits/<EXPRESSROUTE_CIRCUIT_NAME>
```

## <a name="deployment steps"></a>2. Deployment steps
This paragraph shown the sequence steps for running the deployment.

[![4]][4]

### <a name="deployment steps"></a>STEP1
[![5]][5]

### <a name="deployment steps"></a>STEP2
[![6]][6]

[![7]][7]
### <a name="deployment steps"></a>STEP3
[![8]][8]

### <a name="deployment steps"></a>STEP4
The BGP IP addresses assigned to the hub1 router and hub2 router can be fetched by:
```powershell
(Get-AzVirtualHub -ResourceGroupName $rgName -Name hub1).VirtualRouterIps
10.10.0.69
10.10.0.68

(Get-AzVirtualHub -ResourceGroupName $rgName -Name hub2).VirtualRouterIps
10.11.0.69
10.11.0.68
```

- Running the script **04-add-BGP-peer-to-csr1.ps1** creates the configuration snippet **csr1-add-bgp-config.txt** to be applied to csr1. The powershell script uses the command above to fetch the hub1 router BGP addresses. To add to csr1 the BGP configuration with hub1 router, paste the content of file **csr1-add-bgp-config.txt** in the console of csr1
- Running the script **04-add-BGP-peer-to-csr2.ps1** generates the configuration snippet **csr2-add-bgp-config.txt** to be applied to csr2. The powershell script uses the command above to fetch the hub2 router BGP addresses. To add to csr1 the BGP configuration with hub1 router, paste the content of file **csr1-add-bgp-config.txt** in the console of csr2
- The template **04-bgp-conn.json** creates the BGP peering in hub1 router and hub2 router

[![9]][9]

### <a name="deployment steps"></a>STEP5
[![10]][10]

### <a name="deployment steps"></a>STEP6
[![11]][11]

### <a name="deployment steps"></a>STEP7
[![12]][12]


## <a name="BGP tables"></a>3. BGP tables in the NVAs
```console
csr1#show ip bgp
BGP table version is 21, local router ID is 192.168.0.1
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.0.0.0/26      0.0.0.0                  0         32768 i
 *    10.0.0.0/24      10.10.0.69                             0 65515 i
 *>                    10.10.0.68                             0 65515 i
 *>   10.0.0.64/26     0.0.0.0                  0         32768 i
 *>   10.0.0.128/26    10.0.0.65                0         32768 i
 *    10.0.2.0/26      10.10.0.68                             0 65515 65520 65520 65002 e
 *>                    10.10.0.69                             0 65515 65520 65520 65002 e
 *    10.0.2.0/24      10.10.0.69                             0 65515 65520 65520 e
 *>                    10.10.0.68                             0 65515 65520 65520 e
 *    10.0.2.64/26     10.10.0.68                             0 65515 65520 65520 65002 e
 *>                    10.10.0.69                             0 65515 65520 65520 65002 e
 *    10.0.2.128/26    10.10.0.68                             0 65515 65520 65520 65002 e
 *>                    10.10.0.69                             0 65515 65520 65520 65002 e
 *>   10.0.3.0/24      10.0.0.65                0         32768 i
 *    10.0.4.0/24      10.10.0.69                             0 65515 65520 65520 65002 e
 *>                    10.10.0.68                             0 65515 65520 65520 65002 e
 *>   10.0.101.0/26    192.168.0.2              0             0 65101 i
 *>   10.0.101.64/26   192.168.0.2              0             0 65101 i
 *>   10.0.101.128/26  192.168.0.2              0             0 65101 i
 *    10.0.102.0/26    10.10.0.68                             0 65515 65520 65520 65002 65102 e
 *>                    10.10.0.69                             0 65515 65520 65520 65002 65102 e
 *    10.0.102.64/26   10.10.0.68                             0 65515 65520 65520 65002 65102 e
 *>                    10.10.0.69                             0 65515 65520 65520 65002 65102 e
 *    10.0.102.128/26  10.10.0.68                             0 65515 65520 65520 65002 65102 e
 *>                    10.10.0.69                             0 65515 65520 65520 65002 65102 e
 *    10.2.13.0/25     10.10.0.68                             0 65515 12076 65021 i
 *>                    10.10.0.69                             0 65515 12076 65021 i
 *    10.10.0.0/23     10.10.0.69                             0 65515 i
 *>                    10.10.0.68                             0 65515 i
 *    192.168.1.0      10.10.0.69                             0 65515 65010 i
 *>                    10.10.0.68                             0 65515 65010 i
 *    192.168.2.0      10.10.0.69                             0 65515 65520 65520 65011 e
 *>                    10.10.0.68                             0 65515 65520 65520 65011 e
csr1#

```
<br>

```console
csr2#show ip bgp
BGP table version is 22, local router ID is 192.168.0.1
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *    10.0.0.0/26      10.11.0.68                             0 65515 65520 65520 65001 e
 *>                    10.11.0.69                             0 65515 65520 65520 65001 e
 *    10.0.0.0/24      10.11.0.68                             0 65515 65520 65520 e
 *>                    10.11.0.69                             0 65515 65520 65520 e
 *    10.0.0.64/26     10.11.0.68                             0 65515 65520 65520 65001 e
 *>                    10.11.0.69                             0 65515 65520 65520 65001 e
 *    10.0.0.128/26    10.11.0.68                             0 65515 65520 65520 65001 e
 *>                    10.11.0.69                             0 65515 65520 65520 65001 e
 *>   10.0.2.0/26      0.0.0.0                  0         32768 i
 *    10.0.2.0/24      10.11.0.68                             0 65515 i
 *>                    10.11.0.69                             0 65515 i
 *>   10.0.2.64/26     0.0.0.0                  0         32768 i
 *>   10.0.2.128/26    10.0.2.65                0         32768 i
 *    10.0.3.0/24      10.11.0.68                             0 65515 65520 65520 65001 e
 *>                    10.11.0.69                             0 65515 65520 65520 65001 e
 *>   10.0.4.0/24      10.0.2.65                0         32768 i
 *    10.0.101.0/26    10.11.0.68                             0 65515 65520 65520 65001 65101 e
 *>                    10.11.0.69                             0 65515 65520 65520 65001 65101 e
 *    10.0.101.64/26   10.11.0.68                             0 65515 65520 65520 65001 65101 e
 *>                    10.11.0.69                             0 65515 65520 65520 65001 65101 e
 *    10.0.101.128/26  10.11.0.68                             0 65515 65520 65520 65001 65101 e
 *>                    10.11.0.69                             0 65515 65520 65520 65001 65101 e
 *>   10.0.102.0/26    192.168.0.2              0             0 65102 i
 *>   10.0.102.64/26   192.168.0.2              0             0 65102 i
 *>   10.0.102.128/26  192.168.0.2              0             0 65102 i
 *    10.2.13.0/25     10.11.0.68                             0 65515 65520 65520 12076 65021 e
 *>                    10.11.0.69                             0 65515 65520 65520 12076 65021 e
 *    10.11.0.0/23     10.11.0.68                             0 65515 i
 *>                    10.11.0.69                             0 65515 i
 *    192.168.1.0      10.11.0.68                             0 65515 65520 65520 65010 e
 *>                    10.11.0.69                             0 65515 65520 65520 65010 e
 *    192.168.2.0      10.11.0.68                             0 65515 65011 i
 *>                    10.11.0.69                             0 65515 65011 i
csr2#

```
<br>

```console
csr101#show ip bgp
BGP table version is 21, local router ID is 192.168.0.2
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.0.0.0/26      192.168.0.1              0             0 65001 i
 *>   10.0.0.0/24      192.168.0.1                            0 65001 65515 i
 *>   10.0.0.64/26     192.168.0.1              0             0 65001 i
 *>   10.0.0.128/26    192.168.0.1              0             0 65001 i
 *>   10.0.2.0/26      192.168.0.1                            0 65001 65515 65520 65520 65002 e
 *>   10.0.2.0/24      192.168.0.1                            0 65001 65515 65520 65520 e
 *>   10.0.2.64/26     192.168.0.1                            0 65001 65515 65520 65520 65002 e
 *>   10.0.2.128/26    192.168.0.1                            0 65001 65515 65520 65520 65002 e
 *>   10.0.3.0/24      192.168.0.1              0             0 65001 i
 *>   10.0.4.0/24      192.168.0.1                            0 65001 65515 65520 65520 65002 e
 *>   10.0.101.0/26    0.0.0.0                  0         32768 i
 *>   10.0.101.64/26   0.0.0.0                  0         32768 i
 *>   10.0.101.128/26  10.0.101.65              0         32768 i
 *>   10.0.102.0/26    192.168.0.1                            0 65001 65515 65520 65520 65002 65102 e
 *>   10.0.102.64/26   192.168.0.1                            0 65001 65515 65520 65520 65002 65102 e
 *>   10.0.102.128/26  192.168.0.1                            0 65001 65515 65520 65520 65002 65102 e
 *>   10.2.13.0/25     192.168.0.1                            0 65001 65515 12076 65021 i
 *>   10.10.0.0/23     192.168.0.1                            0 65001 65515 i
 *>   192.168.1.0      192.168.0.1                            0 65001 65515 65010 i
 *>   192.168.2.0      192.168.0.1                            0 65001 65515 65520 65520 65011 e
csr101#

```

<br>

```console
csr102#show ip bgp
BGP table version is 21, local router ID is 192.168.0.2
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal,
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter,
              x best-external, a additional-path, c RIB-compressed,
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.0.0.0/26      192.168.0.1                            0 65002 65515 65520 65520 65001 e
 *>   10.0.0.0/24      192.168.0.1                            0 65002 65515 65520 65520 e
 *>   10.0.0.64/26     192.168.0.1                            0 65002 65515 65520 65520 65001 e
 *>   10.0.0.128/26    192.168.0.1                            0 65002 65515 65520 65520 65001 e
 *>   10.0.2.0/26      192.168.0.1              0             0 65002 i
 *>   10.0.2.0/24      192.168.0.1                            0 65002 65515 i
 *>   10.0.2.64/26     192.168.0.1              0             0 65002 i
 *>   10.0.2.128/26    192.168.0.1              0             0 65002 i
 *>   10.0.3.0/24      192.168.0.1                            0 65002 65515 65520 65520 65001 e
 *>   10.0.4.0/24      192.168.0.1              0             0 65002 i
 *>   10.0.101.0/26    192.168.0.1                            0 65002 65515 65520 65520 65001 65101 e
 *>   10.0.101.64/26   192.168.0.1                            0 65002 65515 65520 65520 65001 65101 e
 *>   10.0.101.128/26  192.168.0.1                            0 65002 65515 65520 65520 65001 65101 e
 *>   10.0.102.0/26    0.0.0.0                  0         32768 i
 *>   10.0.102.64/26   0.0.0.0                  0         32768 i
 *>   10.0.102.128/26  10.0.102.65              0         32768 i
 *>   10.2.13.0/25     192.168.0.1                            0 65002 65515 65520 65520 12076 65021 e
 *>   10.11.0.0/23     192.168.0.1                            0 65002 65515 i
 *>   192.168.1.0      192.168.0.1                            0 65002 65515 65520 65520 65010 e
 *>   192.168.2.0      192.168.0.1                            0 65002 65515 65011 i
csr102#


```
The BGP routes in the customer edge router connected to the MSEE router:
```
customer-edge-01#    show ip bgp vpnv4 vrf 13                                                                
BGP table version is 15117323, local router ID is 192.168.0.0
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 65021:13 (default for vrf 13)
 * i  0.0.0.0          192.168.0.0              0    100      0 6453 i
 *>   10.0.0.0/24      192.168.13.18                          0 12076 i
 *>   10.0.2.0/26      192.168.13.18                          0 12076 e
 *>   10.0.2.0/24      192.168.13.18                          0 12076 e
 *>   10.0.2.64/26     192.168.13.18                          0 12076 e
 *>   10.0.2.128/26    192.168.13.18                          0 12076 e
 *>   10.0.3.0/24      192.168.13.18                          0 12076 i
 *>   10.0.4.0/24      192.168.13.18                          0 12076 e
 *>   10.0.101.0/26    192.168.13.18                          0 12076 i
 *>   10.0.101.64/26   192.168.13.18                          0 12076 i
 *>   10.0.101.128/26  192.168.13.18                          0 12076 i
 *>   10.0.102.0/26    192.168.13.18                          0 12076 e
 *>   10.0.102.64/26   192.168.13.18                          0 12076 e
 *>   10.0.102.128/26  192.168.13.18                          0 12076 e
 *>i  10.2.13.0/25     192.168.13.1                  100      0 i
 *>   10.10.0.0/23     192.168.13.18                          0 12076 i
 *>   192.168.1.0      192.168.13.18                          0 12076 i
 *>   192.168.2.0      192.168.13.18                          0 12076 e

customer-edge-01#show ip bgp vpnv4 vrf 13 neighbors 192.168.13.18 routes 
BGP table version is 15117323, local router ID is 192.168.0.0
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 65021:13 (default for vrf 13)
 *>   10.0.0.0/24      192.168.13.18                          0 12076 i
 *>   10.0.2.0/26      192.168.13.18                          0 12076 e
 *>   10.0.2.0/24      192.168.13.18                          0 12076 e
 *>   10.0.2.64/26     192.168.13.18                          0 12076 e
 *>   10.0.2.128/26    192.168.13.18                          0 12076 e
 *>   10.0.3.0/24      192.168.13.18                          0 12076 i
 *>   10.0.4.0/24      192.168.13.18                          0 12076 e
 *>   10.0.101.0/26    192.168.13.18                          0 12076 i
 *>   10.0.101.64/26   192.168.13.18                          0 12076 i
 *>   10.0.101.128/26  192.168.13.18                          0 12076 i
 *>   10.0.102.0/26    192.168.13.18                          0 12076 e
 *>   10.0.102.64/26   192.168.13.18                          0 12076 e
 *>   10.0.102.128/26  192.168.13.18                          0 12076 e
 *>   10.10.0.0/23     192.168.13.18                          0 12076 i
 *>   192.168.1.0      192.168.13.18                          0 12076 i
 *>   192.168.2.0      192.168.13.18                          0 12076 e

Total number of prefixes 16 

```
where 192.168.13.18 is the IP address of MSEE router.

<!--Image References-->

[1]: ./media/network-diagram1.png "high level network diagram"
[2]: ./media/network-diagram2.png "network diagram with details"
[3]: ./media/network-diagram3.png "network diagram with IP addresses"
[4]: ./media/network-diagram4.png "network diagram: sequence of steps"
[5]: ./media/network-diagram5.png "network diagram: STEP1- creation of the vnet1,vnet2,vnet101,vnet102 and vnet peering"
[6]: ./media/network-diagram6.png "network diagram: STEP2"
[7]: ./media/network-diagram7.png "network diagram: STEP2- paste the configurations of CSRs in the terminal of NVAs"
[8]: ./media/network-diagram8.png "network diagram: STEP3"
[9]: ./media/network-diagram9.png "network diagram: STEP4"
[10]: ./media/network-diagram10.png "network diagram: STEP5"
[11]: ./media/network-diagram11.png "network diagram: STEP6"
[12]: ./media/network-diagram12.png "network diagram: STEP7"
<!--Link References-->

