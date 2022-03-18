<properties
pageTitle= 'Azure Traffic Analytics'
description= "Azure Traffic Analytics"
documentationcenter: na
services="Azure Monitor"
documentationCenter="na"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="na"
   ms.date="30/04/2022"
   ms.author="fabferri" />

# Azure Traffic Analytics
Azure Traffic Analytics analyzes Network Watcher network security group (NSG) flow logs to provide insights into traffic flow in Azure VNets.
* the NSG flow captures information about [ingress IP, egress IP, protocol, source port, desk port] through a NSG associated to individual network interfaces, VMs, or subnets. 
* Traffic analytics examines the raw NSG flow logs and captures reduced logs by aggregating common flows. 
* Traffic Analytics supports collecting NSG Flow Logs data at a higher frequency of 10 mins
* The log analytics workspace hosting the traffic analytics solution and the NSGs do not have to be in the same region. [For example, you may have traffic analytics in a workspace in the West Europe region, while you may have NSGs in East US and West US]
* Multiple NSGs can be configured in the same Log Analytics workspace.


**NOTE:**
**The traffic Analytics dashboard in Azure Management portal may take up to 30 minutes to appear the first time because Traffic Analytics must first aggregate enough data for it to derive meaningful insights, before it can generate any reports.**

The network diagram of our setup is shown:

[![1]][1]

<br>

After the deployment of the ARM templates, you can check out through the Azure management portal the presence of **Network Watcher Flow logs**. Three flows are created, one for each NSG associated with the NIC of the Azure VM. To visualize the setup, under **Network Watcher** -> _Metrics_, select **NSG flow logs**:

[![2]][2]

A screenshot of the Traffic Analytics is shown below with the traffic distribution:

[![3]][3]

## <a name="List of files"></a>1. List of files 

| file                   | description                                                               |       
| ---------------------- |:------------------------------------------------------------------------- |
| **01-vnets-vms.json**  | ARM template to create two vnets, vnet peering, VMs, NSG, storage account, Log Analytics workspace |
| **01-vnets-vms.ps1**   | powershell script to deploy the ARM template **01-vnets-vms.json**        |
| **02-flowlogs.json**   | ARM template to create the **Network Watcher flow log**                   |
| **02-flowlogs.ps1**    | powershell script to deploy the ARM template **02-flowlogs.json**         |


<br>
 
Before spinning up the powershell scripts, edit the file **init.json** to customize the values of the input variables.
The structure of **init.json** file:
```json
{
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "subscriptionName": "NAME_AZURE_SUBSCRIPTION",
    "ResourceGroupName": "NAME_RESOURCE_GROUP",
    "location" : "westus2",
    "vm1Name" : "NAME_AZURE_VM1",
    "vm2Name" : "NAME_AZURE_VM2",
    "vm3Name" : "NAME_AZURE_VM3",
    "mngIP": "MANAGEMENT_PUBLIC_IP_ADDRESS_TO_CONNECT_IN_SSH_TO_THE_VM"
}
```

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "network diagram"
[3]: ./media/traffic-analytics.png "Traffic Analytics"
<!--Link References-->

