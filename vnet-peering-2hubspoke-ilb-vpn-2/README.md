<properties
pageTitle= 'ARM template to create two hub-spoke VNets connected by VNet peering'
description= "Two hub-spoke VNets connected by VNet pering with Azure load balancer in HA ports in the hub VNets"
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
   ms.date="27/07/2019"
   ms.author="fabferri" />

# Two hub-spoke VNets connected by VNet peering with load balancer in HA ports in the hub VNets
The article depicts two hub-spoke vnets in different regions interconnected by VNets in peering.
* In each hub vnet are present two linux VMs (nva11, nva12 in hub1 VNet and nva21,nva21 in hub2 VNet) configured with ip forwarding.
* In each hub VNet is deployed an internal standard load balancer (ILB) configured with HA ports. The presence of ILB provides a configuration in HA on the flow in transit through the NVA VMs. The IBL has got a an heath probe on HTTP port 80. To receive a traffic from the ILB, the nva11,nva12,nva21,nva22 VMs require a httpd daemon.


The network diagram is reported below:

[![1]][1]

### Files
* **2hubspoke-ilb.json**: ARM template to create the deployment
* **2hubspoke-ilb.ps1**: powershell script to run the **2hubspoke-ilb.json**
* **DumpEffectiveRoutesNICs.ps1**: powershell script to dump the effective route associated with NIC if the VMs
* **DumpEffetiveRoutesNICs.txt**: outcome of powershell script **DumpEffectiveRoutesNICs.ps1**
* **DumpRoutes-VPNGateways.ps1**: powershell to get the list of routes in VPN gateways
* **DumpRouting-VPNGateways.txt**: outcome of powershell script **DumpRoutes-VPNGateways.ps1**
* **DumpRouting-VPNGateways-withoutIPSec-tunnel-dc0-hub1.txt**: list of routes in VPN gateway without tunnel between dc0 VNet and hub1 VNet
* **ipforwarder.sh**: bash script to st ip forwarder and httpd daemon in nva11, nva12, nva21, nva22




> [!NOTE]
>
> Before spinning up the ARM template you should in **2hubspoke-ilb.ps1**:
> * set the Azure subscription name
> * set the administrator username and password of Azure VMs
>


#### <a name="EnableIPForwarding"></a>1. Setup ip forwarding and httpd in nva11, nva12, nva21, nva22
After running the **2hubspoke-ilb.ps1**, connect in SSH to the nva11, nva12, nva21, nva22 and run in each VM the bash script **ipforwarder.sh** to enable the IP forwarding and httpd deamon:

```bash
#!/bin/bash
# Enable IP Forwarding in the Linux
sed -i -e '$a\net.ipv4.ip_forward = 1' /etc/sysctl.conf
systemctl restart network.service

# Install Apache for HealthProbe
yum -y install httpd
systemctl enable httpd.service
systemctl restart httpd.service
```


#### <a name="UDR"></a>2.UDRs applied to the subnets

[![3]][3]

#### <a name="UDR"></a>3.Effective routes in the NIC of the VMs
[![4]][4]

[![5]][5]

#### <a name="installnginx"></a>4. comunication flows between VNets
Run tcpdump on the nva11,nva12, nva21, nva22 to verify the traffic transit symmetrically through the VMs.

[![6]][6]



[![7]][7]

In case of failure of IPSec tunnel between the hub1 vnet and the dc0 vnet, the traffic is routed through the VPN gateway in hub2 VNet.

[![8]][8]

<!--Image References-->

[1]: ./media/network-diagram-overview.png "network diagram: overview"
[2]: ./media/network-diagram.png "network diagram"
[3]: ./media/udr.png "User Defined Routes"
[4]: ./media/effective-routes-nics01.png
[5]: ./media/effective-routes-nics02.png
[6]: ./media/flows1.png "flows"
[7]: ./media/flows2.png "flows"
[8]: ./media/flows3.png "flows"


<!--Link References-->

