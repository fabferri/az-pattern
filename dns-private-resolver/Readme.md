<properties
pageTitle= 'Azure DNS private resolver and private endpoint'
description= "Azure DNS private resolver and private endpoint"
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
   ms.workload="Azure DNS private resolver"
   ms.date="16/06/2023"
   ms.review=""
   ms.author="fabferri" />

# Configuration with Azure DNS private resolver
The article walks you through a configuration with an Azure private endpoint to access to the blob storage and Azure DNS private resolver to resolve the naming of storage account from a remote vnet.<br>
The network diagram is shown below:

[![1]][1]

* the virtual network vnet1 and vnet2 can be in same of different Azure region
* the vnet2 works as "simulation" of an on-premises network
* in each vnet is deployed an Azure VPN Gateway to connect vnet1 and vnet2 through site-to-site IPsec tunnels
* in the vnet1 is present a private endpoint to access to the blob storage through private IP
* a private DNS zone **privatelink.blob.core.windows.net** is defined and associated with vnet1, to resolve the name of blob storage with the IP of private endpoint 
* in dns2 VM is configured a Windows DNS server. dns2 works as custom DNS for the vnet2. 

Azure DNS private resolver provides the ability to query Azure private DNS zone from an on-premises environment and provides the ability to query on-premises DNS from Azure. <br> 
Azure private resolvers are regional and require dedicated subnets /28 or larger.<br>
A DNS private resolver works in two directions using endpoints. Inbound endpoint is used to resolve client requests from on-premises network to Azure resources. Outbound endpoint is used to forward Azure client DNS request to DNS on-premises.

**Note**<br>
The Azure DNS private resolve requires as mandatory a delegation to the service **Microsoft.Network/dnsResolvers** in the subnets for inbound endpoint and outblund endpoints. If the delegation is not set, the deployment of Azure DNS private resolver will fail.

  ```json
 "delegations": [
    {
        "name": "Microsoft.Network.dnsResolvers",
        "properties": {
            "serviceName": "Microsoft.Network/dnsResolvers"
        }
    }
]
```

The IP address assignment is shown in the diagram:

[![2]][2]

**vnet1:**
- snet-workload: subnet to host the vm1
- snet-privep: subnet used for the private endpoint 
- snet-inbound: subnet to the inbound endpoints for Azure private DNS resolver
- snet-outbound:subnet to the outbound endpoints for Azure private DNS resolver
- GatewaySubnet: subnet reserved to the VPN Gateway


**vnet2:**
- subnet21: subnet to host the vm2 and dns2
- subnet22: subnet for future deployments
- GatewaySubnet: subnet reseved to the VPN Gateway


## <a name="list of files"></a>1. File list

| File name                    | Description                                                                             |
| ---------------------------- | --------------------------------------------------------------------------------------- |
| **az-params.json**           | define the value of input variables required for the full deployment                    |
| **01-vpn.json**              | ARM template to deploy vnets, VPN Gateway, establish site-to-site IPsec tunnels and VMs |
| **01-vpn.ps1**               | powershell script to deploy **vpn.json**                                                |
| **02-private-endpoint.json** | ARM template to create storage account, create private endpoint for the storage blob, create the private DNS zone for the storage blob |
| **02-private-endpoint.ps1**  | powershell script to deploy **private-endpoint.json**                                   |
| **03-dns-resolver.json**     | ARM template to deploy the Azure private DNS resolver in the vnet1                      |
| **03-dns-resolver.ps1**      | powershell script to deploy **dns-resolver.json**                                       |
| **dns-server-config.ps1**    | powershell script to configure the Windows DNS server. you need to run manually inside the dns2 VM |


To run the project, follow the steps <ins>in sequence</ins>:
1. change/modify the value of input variables in the file **az-params.json**. The meaning of input variables is described in the file.
2. run the powershell script **vpn.ps1**
3. run the powershell script **private-endpoint.ps1**
4. run the powershell script **dns-resolver.ps1**



## <a name="DNS server in vnet2"></a>2. DNS server configuration in the vnet2
Conditional DNS forwarding is a method to direct DNS queries related to a specific domain to another DNS server. This is done by creating conditional DNS forwarders or rules on the DNS server. This is a method to resolve DNS queries belonging to an external domain.
To resolve the `<storageaccountName>`.blob.core.windows.net the Windows DNS server dns2 (in the vnet2) needs of a condition DNS forwarding pointing to the IP address of inbound endpoint in Azure DNS private resolver.

[![3]][3]

The Windows DNS server in the vnet2 can be configured running the powershell command **dns-server-config.ps1** using the **Run Command** feature. The **Run Command** feature uses the virtual machine (VM) agent to run PowerShell scripts within an Azure Windows VM.<br>
By **RunPowerShellScript** command to run the custom script **dns-server-config.ps1**:

```powershell
Invoke-AzVMRunCommand -ResourceGroupName '<myResourceGroup>' -Name '<myVMName>' -CommandId 'RunPowerShellScript' -ScriptPath '<pathToScript>' -Parameter @{"arg1" = "var1";"arg2" = "var2"}

Invoke-AzVMRunCommand -ResourceGroupName '<myResourceGroup>' -Name 'dns2' -CommandId 'RunPowerShellScript' -ScriptPath "$pwd\dns-server-config.ps1"

```

- The **Run Command** feature runs the script as System on Windows.
- To function correctly, Run Command requires connectivity (port 443) to Azure public IP addresses
- to make troubleshooting action in Windows environments, refer to the RunCommandExtension log file located in the following directory: C:\WindowsAzure\Logs\Plugins\Microsoft.CPlat.Core.RunCommandWindows\<version>\RunCommandExtension.log

<br>

The dns2 is configured to forward requests for the naming **privatelink.blob.core.windows.net** to the inbound endpoint of DNS private resolver.


## <a name="Verification"></a>3. Verification
To get the storage account name:
```
(Get-AzStorageAccount  -ResourceGroupName '<myResourceGroup>').StorageAccountName
```

Connect to the **dns2** and check the translation of URL of storage account:

```Console
nslookup <storageAccountName>.blob.core.windows.net
```

Connect to the **vm2** and check the translation of URL of storage account:

```Console
nslookup <storageaccountName>.blob.core.windows.net
```

Connect to the **vm1** and check the translation of URL of storage account:
```Console
nslookup <storageaccountName>.blob.core.windows.net
```

Disable to public access to the storage account.<br>
Download the Azure storage explorer in **vm2**. <br>
In **vm2** connect to the storage account using Azure storage explorer.

[![4]][4]

`Tags: Azure DNS private resolver, private endpoint` <br>
`date: 16-06-2023`

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/ip-networks.png "IP networks"
[3]: ./media/dns-conditional-forwarders.png "Windows server conditional forwarders"
[4]: ./media/transit-through-private-endpoint.png "access to the storage blob with transit through private endpoint"

<!--Link References-->
