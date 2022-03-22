<properties
pageTitle= 'Connect networks to Azure Monitor through Azure Private Link'
description= "Azure Connection Monitor"
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

# Azure Connection Monitor across private link 
This article discusses a configuration of Azure Connection Monitor with data ingestion through private link.
<br>
The network diagram of our environment is shown below:

[![1]][1]


The full configuration is created through ARM templates.
The article walks you through the integration of Azure Monitor with private link and then discusses about the specific configuration with Azure Connection Monitor.  


## <a name="Use Azure Private Link to connect networks to Azure Monitor"></a>1. Use Azure Private Link to connect networks to Azure Monitor
Azure Monitor is a group of different interconnected services that work together to monitor your workloads. An Azure Monitor Private Link connects a private endpoint to a set of Azure Monitor resources (Log Analytics workspaces and Application Insights resources), defining the boundaries of your monitoring network. That set is called an **Azure Monitor Private Link Scope (AMPLS)**.
<br>


[![2]][2]


* When creating a new **AMPLS (Azure Monitor Private Link Scope)** resource, you're now required to select the desired access modes, for ingestion and queries separately.
   * Private Only mode - allows traffic only to Private Link resources
   * Open mode - uses Private Link to communicate with resources in the AMPLS, but also allows to non-Private-Link traffic (resources out of the AMPLS) to continue to access to resources 
* Control networks access to your Azure Monitor resources - configure each of your workspaces or components to accept or block traffic from public networks. You can apply different settings for ingestion and query requests. In Log Analytics workspace there are two properties:
   * accept or block ingestion from public networks
   * accept or block queries from public networks
   In ARM template those properties are specified with log analytics workspace by the following:
```
"publicNetworkAccessForIngestion": "Disabled",
"publicNetworkAccessForQuery": "Enabled"
```

**NOTE:** Each VNet can only connect to one **AMPLS** object, and a workspace can be linked to maximum 5 **AMLS**.

When you set up a Private Link connection, your DNS zones map Azure Monitor endpoints to private IPs in order to send traffic through the Private Link.

## <a name="Azure Private Endpoint DNS configuration"></a>1. Azure Private Endpoint DNS configuration
Microsoft Azure services already have a DNS configuration for a public endpoint. This configuration must be overridden to connect using your private endpoint.
* You have to correctly configure your DNS settings to resolve the private endpoint IP address to the fully qualified domain name (FQDN).
* You can use private DNS zones to override the DNS resolution for a private endpoint. A private DNS zone can be linked to your VNet to resolve specific domains.
* Azure creates a canonical name DNS record (CNAME) on the public DNS. The CNAME record redirects the resolution to the private domain name. You can override the resolution with the private IP address of your private endpoints.
* Your applications don't need to change the connection URL. When resolving to a public DNS service, the DNS server will resolve to your private endpoints.

The table reports the private link resources the Azure monitor:

| Private link resource type / Subresource | Private DNS zone name       | Public DNS zone forwarders |       
| ---------------------------------------- |:--------------------------- | -------------------------- |
| Azure Monitor (Microsoft.Insights/privateLinkScopes) / azuremonitor    |  privatelink.monitor.azure.com <br> privatelink.oms.opinsights.azure.com <br> privatelink.ods.opinsights.azure.com <br> privatelink.agentsvc.azure-automation.net <br> privatelink.blob.core.windows.net | monitor.azure.com <br> oms.opinsights.azure.com <br> ods.opinsights.azure.com <br> agentsvc.azure-automation.net <br> blob.core.windows.net|


## <a name="Private DNS zone group"></a>2. Private DNS zone group
If you choose to integrate your private endpoint with a private DNS zone, a private DNS zone group is also created. The DNS zone group is a strong association between the private DNS zone and the private endpoint that helps auto-updating the private DNS zone when there is an update on the private endpoint. For example, when you add or remove regions, the private DNS zone is automatically updated.

When you delete the private endpoint, all the DNS records within the DNS zone group will be deleted as well.

A common scenario for DNS zone group is in a hub-and-spoke topology, where it allows the private DNS zones to be created only once in the hub and allows the spokes to register to it, rather than creating different zones in each spoke.


## <a name="List of files"></a>1. List of files 

| file                     | description                                                               |       
| ------------------------ |:------------------------------------------------------------------------- |
| **01-vnets-vms.json**    | ARM template to create two vnets, vnet peering, VMs, NSG, storage account, Log Analytics workspace |
| **01-vnets-vms.ps1**     | powershell script to deploy the ARM template **01-vnets-vms.json**        |
| **02-conn-monitor.json** | ARM template to create the Azure Connection Monitor                       |
| **02-conn-monitor.ps1**  | powershell script to deploy the ARM template **02-conn-monitor.json**     |

* **01-vnets-vms.json**: 
   * create three vnets, vnet1, vnet2, vnet3 in Azure regions specified from the variables location1, location2, location3.
   * create a configuration hub-spoke by vnet peering: vnet1-vnet2 and vnet1-vnet3. vnet1 is the hub vnet and vnet2, vnet3 are the spoke vnets.
   * create a Windows VM in the subnet1 of each vnet. By custom script extension an IIS is installed with basic homepage, and the ICMP echo is enabled through the windows firewall. The network watcher agent is installed in each windows VM for data ingestion in Azure Connection Monitor. 
   * a log analytics workspace is created in the same azure region of the vnet1  (hub vnet).
   * a storage account is deployed for future Data Collection Endpoint (DCE) resource (not in used in the current ARM template). A private endpoint is created in the subnet1 of vnet1 for private connectivity with the storage account.

* **02-conn-monitor.json**: 
   * create a connection Monitor configuration. The vm1, vm2,vm3 are used as endpoints. Three different test configurations are defined: a test based on TCP port 80, a test based on HTTP, a tes based on ICMP. In total 6 test groups are used to monitor the end-to-end delay:
      - vm1 to vm2 based on test TCP port 80
      - vm1 to vm2 based on test HTTP port 80
      - vm1 to vm2 based on test ICMP
      - vm1 to vm3 based on test TCP port 80
      - vm1 to vm3 based on test HTTP port 80
      - vm1 to vm3 based on test ICMP

<br>
 
Before spinning up the powershell scripts, edit the file **init.json** to customize the values of the input variables.
The structure of **init.json** file:
```json
{
    "subscriptionName": "AZURE_SUBSCRIPTION_NAME",
    "ResourceGroupName": "RESOURCE_GROUP_NAME",
    "location1" : "AZURE_REGION_VNET1",
    "location2" : "AZURE_REGION_VNET2",
    "location3" : "AZURE_REGION_VNET3",
    "vm1Name" : "NAME_AZURE_VM_IN_VNET1",
    "vm2Name" : "NAME_AZURE_VM_IN_VNET2",
    "vm3Name" : "NAME_AZURE_VM_IN_VNET3",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "mngIP": "MANAGEMENT_PUBLIC_IP_ADDRESS_TO_CONNECT_IN_SSH_TO_THE_VM"
}
```

After the deployment of two ARM templates, you can browse in Azure Network Watcher to display the configuration of Connection Monitor:

[![3]][3]

Click-on one a test configuration to see the latency:
[![4]][4]

The Virtual networks access configuration of Analytics log workspace is shown below:

[![5]][5]

The private DNS zone for the private endpoint associated with Azure Monitor:

[![6]][6]

Azure Monitor Private Link Scope of our deployment:
[![7]][7]

[![8]][8]

**NOTE about Log analytics workspace** <br>
Log analytics workspace name uniqueness is per resource group. <br>
It allows you to use the same workspace name in deployments across multiple environments for consistency. Workspace uniqueness is maintained as follow:
* Workspace ID – global uniqueness remained unchanged.
* Workspace resource ID – global uniqueness.
* Workspace name – per resource group




## <a name="Reference docs"></a>3. Reference

[Use Azure Private Link to connect networks to Azure Monitor](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/private-link-security)

[Azure Private Endpoint DNS configuration](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-dns)

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "Azure Monitor through Azure Private Link"
[3]: ./media/network-diagram3.png "Connection Monitor"
[4]: ./media/network-diagram4.png "latency in connection monitor"
[5]: ./media/network-diagram5.png "filtering access to the log analytics workspace"
[6]: ./media/network-diagram6.png "DNS private zone configuration for the private endpoint associated with Azure monitor"
[7]: ./media/network-diagram7.png "Azure Monitor Private Link Scope configuration"
[8]: ./media/network-diagram8.png "Azure Monitor Private Link Scope configuration"

<!--Link References-->

