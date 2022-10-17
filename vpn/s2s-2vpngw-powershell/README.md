<properties
pageTitle= 'Site to site VPN between two Azure VPN Gateways'
description= "Site to site VPN between two Azure VPN Gateways"
documentationcenter: Azure
services="VPN Gateway"
documentationCenter="github"
authors="fabferri"
editor=""/>

<tags
   ms.service="howto-Azure-examples"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="Azure VPN Gateway, site-to-site VPN"
   ms.date="16/10/2022"
   ms.review=""
   ms.author="fabferri" />

# Site to site VPN between two Azure VPN Gateways
The article describes a scenario with two vnets, vnet1 and vnet2, connected through site-to-site VPN. The network diagram is reported below:

[![1]][1]

Each Azure VPN Gateway is configured as Route-Based deployed with two public IPs, in active-active configuration with BGP. <br>
Two IPSec tunnels are established between the two VPN Gateways: **vpnGw1**, **vpnGtw2**. <br>
the two VPN Gateways can be deployed in the same or different Azure regions. <br>
The network diagram below shows the site-to-site VPN configuration details: VPN local networks, BGP peering IPs and the public IPs associated with each VPN Gateway.

[![2]][2]


## <a name="list of files"></a>2. Script files

| File name                | Description                                                                    |
| ------------------------ | ------------------------------------------------------------------------------ |
| **init.json**            | define the value of input variables required for the full deployment           |
| **create-vpn-gtw1.ps1**  | powershell script to create vnet1 and VPN Gateway 1                            |
| **create-vpn-gtw2.ps1**  | powershell script to create vnet2 and VPN Gateway 2                            |
| **connection.ps1**       | powershell script to create VPN Gateways local network and Connections         |
| **create-vms.ps1**       | powershell script to create vm1 in vnet1 and vm2 in vnet2. the script use RunAs to install iperf3 in the VMs |
| **apply-policy.ps1**     | powershell script to configure IKE/IPsec policy for S2S VPN                    |

The meaning of input variables in **init.json** are shown below:
```json
{
    "subscriptionName": "NAME_OF_THE_SUBSCRIPTION",
    "ResourceGroupName": "NAME_OF_THE_RESOURCE_GROUP",
    "location1": "AZURE_REGION_vnet1",
    "vnet1Name": "vnet1",
    "app1SubnetName": "subnet1",
    "vnet1Prefix": "10.1.0.0/24",
    "app1SubnetPrefix": "10.1.0.0/27",
    "gw1SubnetPrefix": "10.1.0.224/27",
    "gw1Name": "NAME_AZURE_VPN_GATEWAY1",
    "location2": "AZURE_REGION_vnet2",
    "vnet2Name": "vnet2",
    "app2SubnetName": "subnet1",
    "vnet2Prefix": "10.2.0.0/24",
    "app2SubnetPrefix": "10.2.0.0/27",
    "gw2SubnetPrefix": "10.2.0.224/27",
    "gw2Name": "NAME_AZURE_VPN_GATEWAY2",
    "vpnSku": "VpnGw2",
    "asn1": "BGP_AUTONOMOUS_SYSTEM_NUMBER_VPN_GATEWAY1",
    "asn2": "BGP_AUTONOMOUS_SYSTEM_NUMBER_VPN_GATEWAY2",
    "sharedKey": "AZURE_VPN_SHARED_SECRET",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "vmPublisher" : "canonical",
    "vmOffer": "0001-com-ubuntu-server-focal",
    "vmSKU": "20_04-lts",
    "vmVersion": "latest",
    "vmSize": "VM_SIZE_SKU"
}
```

To run the project, follow the steps in sequence:
1. as first action, change/modify the value of input variables in the file **init.json**
2. run the powershell script **create-vpn-gtw1.ps1** and **create-vpn-gtw2.ps1** in parallel to speed up the creation of Azure VPN Gateways in vnet1 and vnet2
3. run the powershell script **connection.ps1**; at the end the IPsec tunnels between VPN gtw1 adn VPN gtw2 will be created.
4. run the powershell script **create-vms.ps1** to create a vm1 in vnet1 and vm2 in vnet2. **create-vms.ps1** can run in parallel with **connection.ps1**
5. run the powershell script **apply-policy.ps1** only if you want to configure IKE/IPsec policy for S2S VPN. if you do not run **apply-policy.ps1** the default  encryption policy for IKE and IPsec will be used.

Dependencies:
* **create-vpn-gtw1.ps1** and **create-vpn-gtw2.ps1** are independent and they can run in parallel
* **create-vms.ps1** requires the presence of vnet1 and vnet2. **create-vms.ps1** has dependency from **create-vpn-gtw1.ps1** and **create-vpn-gtw2.ps1**
* **connection.ps1** can run only after completion of **create-vpn-gtw1.ps1** and **create-vpn-gtw2.ps1**. The script **connection.ps1** will fail if the VPN Gateways are not deployed
* **apply-policy.ps1** is not mandatory and it can be deployed only after running **connection.ps1**. The script **apply-policy.ps1** will fail if the Azure VPN Connections are not created

## <a name="list of files"></a>3. Benchmarks Azure site-to-site VPN
From Azure documentation: <br>
* VPN SKU: **VpnGw3** - Aggregate Throughput Benchmark: 2.5 Gbps
* VM SKU: **Standard_DS3_v2** - Expected network bandwidth: 3Gbps

The value of RTT between vm1 and vm2 by ping: <br>
RTT vm1 [_western europe_] - vm2 [_uk south_]: ~10 ms    

Values achieved using iperf3:
| VPN SKU     | VM SKU              | Azure region1  |  Azure region21  | IKE/IPsec policy     |  iperf3 -P| throughput  |
| ----------- | ------------------- | -------------- | ---------------- | -------------------- |  -------- | ----------- |
| **VpnGw3**  | **Standard_DS3_v2** | western europe | uk south         | default              |     1     | ~  740 Mbps |
| **VpnGw3**  | **Standard_DS3_v2** | western europe | uk south         | default              |     3     | ~ 1.96 Gbps |
| **VpnGw3**  | **Standard_DS3_v2** | western europe | uk south         | default              |     5     | ~ 2.60 Gbps |
| **VpnGw3**  | **Standard_DS3_v2** | western europe | uk south         | _policy1_ (see below)|     1     | ~  750 Mbps |
| **VpnGw3**  | **Standard_DS3_v2** | western europe | uk south         | _policy1_ (see below)|     3     | ~ 1.2  Gbps |
| **VpnGw3**  | **Standard_DS3_v2** | western europe | uk south         | _policy1_ (see below)|     5     | ~ 1.8  Gbps |
| **VpnGw3**  | **Standard_DS3_v2** | western europe | uk south         | _policy1_ (see below)|    10     | ~ 1.8  Gbps |
| **VpnGw3**  | **Standard_DS3_v2** | western europe | uk south         | _policy1_ (see below)|    20     | ~ 2.3  Gbps |
| **VpnGw3**  | **Standard_DS3_v2** | western europe | uk south         | _policy2_ (see below)|     1     | ~  900 Mbps |
| **VpnGw3**  | **Standard_DS3_v2** | western europe | uk south         | _policy2_ (see below)|     3     | ~ 1.8  Gbps |
| **VpnGw3**  | **Standard_DS3_v2** | western europe | uk south         | _policy2_ (see below)|     5     | ~ 2.5  Gbps |

The throughput values in the table are the average value over a period time of 60s. <br>
iperf3 command used to send data: 
```
iperf3 -c 10.2.0.4 -P <numTCPFlow> -t 60
```

The column iperf3 -P specifies the number of parallel TCP flows.

IKE/IPsec _policy1_ in the above table: 
* IKE Encryption: AES256
* IKE Integrity: SHA384
* DH Group: DHGroup24
* Pfs Group: PFS24
* Ipsec Encryption: AES256 
* Ipsec Integrity: SHA256 

IKE/IPsec _policy2_ in the above table: 
* IKE Encryption: AES256
* IKE Integrity: SHA256
* DH Group: DHGroup14
* Pfs Group: PFS2048
* Ipsec Encryption: GCMAES256 
* Ipsec Integrity: GCMAES256 




`Tags: Azure VPN, site-to-site VPN`
`date: 16-10-22`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/network-diagram2.png "site-to-site VPN details"

<!--Link References-->

