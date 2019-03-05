<properties
pageTitle= 'Simple hub-spoke VNets configuration with VNet peering and UDR'
description= "ARM template to create Azure hub-spoke VNets with VNet peering"
documentationcenter: na
services=""
documentationCenter="na"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="howto-example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="na"
   ms.date="05/03/2019"
   ms.author="fabferri" />

# How to create hub-spoke VNets interconnected by VNet peering and UDR


The article describes a basic configuration with one Azure hub VNet in VNet peering with two spoke VNets.
in the hub VNet a VM works as ip forwarder.

[![1]][1]

By UDRs (User Defined Routes) the traffic between the spoke1-VNet and spoke2-VNet2 is forced to transit through the ip forwarder (nva) in the hub-VNet. The traffic between subnets (subnet1 and subnet2) in the same VNet does not transit through the nva.


After running the template, enable ip forwarding on nva in hub-vnet:


```
sed -i -e '$a\net.ipv4.ip_forward = 1' /etc/sysctl.conf
systemctl restart network.service
sysctl net.ipv4.ip_forward
```

## <a name="routing-spoke1"></a>2. routing table applied to subnet1, subnet of the spoke1-vnet
Azure selects a route based on the destination IP address, using the longest prefix match algorithm.

Here the routing table applied to the subnet1 and subnet2 of spoke1-vnet:

|Source |State |Address Prefixes|Next Hop Type        | IPAddress    |UDR Name    |
|-------|------|----------------|:------------------- |:------------:|:----------:|
|Default|Active|**10.0.1.0/24** |**Virtual network**  |    -         |    -       |
|Default|Active|10.0.0.0/24     |VNet peering	      |    -         |    -       |
|Default|Active| 0.0.0.0/0      |Internet             |    -         |    -       |
|Default|Active|100.64.0.0/10   |None                 |    -         |    -       |
|Default|Active|192.168.0.0/16  |None                 |    -         |    -       |
|User   |Active|**10.0.0.0/8**  |**Virtual appliance**|**10.0.0.10** |route-to-hub|


In the route table there are two routes:

* One route specifies the 10.0.1.0/24 address prefix
* One route specifies the 10.0.0.0/8 address prefix

then

* the traffic generated in **subnet1-spoke1** and **subnet2-spoke1**, with destination addresses in 10.0.2.0/24 matches with the route 10.0.0.0/8.
* The traffic generated in the **subnet1-spoke1** with destination in **subnet2-spoke2**  matches the route 10.0.1.0/24

## <a name="routing-spoke2"></a>3. routing table applied to subnet1, subnet of the spoke2-vnet
The routing table applied to the subnet1 and subnet2 of the spoke2-vnet:

|Source |State |Address Prefixes|Next Hop Type        | IPAddress    |UDR Name    |
|-------|------|----------------|:------------------- |:------------:|:----------:|
|Default|Active|**10.0.2.0/24** |**Virtual network**  |    -         |    -       |
|Default|Active|10.0.0.0/24     |VNet peering	      |    -         |    -       |
|Default|Active| 0.0.0.0/0      |Internet             |    -         |    -       |
|Default|Active|100.64.0.0/10   |None                 |    -         |    -       |
|Default|Active|192.168.0.0/16  |None                 |    -         |    -       |
|User   |Active|**10.0.0.0/8**  |**Virtual appliance**|**10.0.0.10** |route-to-hub|

The diagram below reports the flow between VMs

[![2]][2]


[![3]][3]

Transit of traffic on nva can be checked by tcpdump:

```console
[root@nva ~]#  tcpdump -i eth0 -nqt "(net 10.0.1.0/24 or net 10.0.2.0/24)"
```


<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/flow1.png "tcp flow transit between VMs"
[3]: ./media/flow2.png "tcp flow transit between VMs"

<!--Link References-->

