<properties
pageTitle= 'vnet peering with transit across load balancer in HA'
description= "vnet peering with transit across load balancer in HA"
documentationcenter: na
services="Azure vnet, Azure load balancer"
documentationCenter="na"
authors="fabferri"
manager=""
editor="fabferri"/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="na"
   ms.date="01/06/2022"
   ms.author="fabferri" />

# VNet peering with transit across load balancer in HA
The network configuration is shown in the diagram:

[![1]][1]

* The ARM template uses custom script extension to install in Azure Ubuntu VMs: 
   * nginx with small homepage running on TCP port 80
   * iperf3 to transfer data at high speed
* The standard load balancer is configured in HA ports with health probe define don TCP port 80.
* the internal load balancer is created with:
   * 13 frontend IPs in subnet1 of the vnet2 
   * 13 backend IPs in subnet2 of the vnet2
   * 13 different load balancer rules, to map each single frontend IP with one single backed IP 
* a UDR is applied to the subnet1 of the vnet1 to force the traffic to transit always across the load balancer. The UDR is not mandatory if the VMs in vnet1 reference as destination the frontend IPs of the load balancer. 

The template can be used to run a throughput benchmark. The total throughput can be achieved depends on the VMs SKU.
To achieve a good throughput is recommended to use the largest VM SKU in the VM family. 

| Size                | vCPU | Max network bandwidth (Mbps) |
| ------------------- | ---- | ---------------------------- |
| Standard\_D2ds\_v5  | 2    | 12500                        |
| Standard\_D4ds\_v5  | 4    | 12500                        |
| Standard\_D8ds\_v5  | 8    | 12500                        |
| Standard\_D16ds\_v5 | 16   | 12500                        |
| Standard\_D32ds\_v5 | 32   | 16000                        |
| Standard\_D48ds\_v5 | 48   | 24000                        |
| Standard\_D64ds\_v5 | 64   | 30000                        |
| Standard\_D96ds\_v5 | 96   | 35000                        |

The VM SKU is defined in the ARM template by the parameter **"vmSize"**

To run with larger SKU check the quota assigned to the Azure subscription. If the default total number of cores (assigned to the VM family in specific Azure region you want to run) should not be enough, you can increase it through the Azure management portal. If the procedure of quota augment should fail, you need to open an Azure ticket and ask for the target capacity.

The ARM template specifies the flag to enable/disable the accelerated networking in the Azure VMs:
```json
"acceleratedNetworking": {
   "type": "bool",
   "defaultValue": true,
   "allowedValues": [
      true,
      false
   ],
   "metadata": {
      "description": "accelerated networking"
   }
},
```

Not all the Azure VMs support accelerated networking; to enable the accelerated networking you need to check if it is supported for the specific VM SKU:

```console
az vm list-skus -l westus2 --all true -r virtualMachines --query '[].{size:size, name:name, acceleratedNetworkingEnabled: capabilities[?name==`AcceleratedNetworkingEnabled`].value | [0]}' -o table

az vm list-skus --resource-type virtualMachines --query '[].{name:name, an_enabled:capabilities[?name==`AcceleratedNetworkingEnabled`].value | [0]} | [?an_enabled==`True`][].name | sort(@)'  | unique
```  


A powershell script to get the list of VM SKU with/without support for accelerated networking:

```powershell
$location ='eastus'
$v = Get-AzComputeResourceSku | Where-Object { $_.Locations.Contains($location) -and $_.ResourceType.Contains('virtualMachines') } 
$hash = @{}

foreach ($i in $v) {
    $vmSKU = $i.Name
    $accel = ($i.Capabilities | Where-Object { $_.Name.Contains('AcceleratedNetworkingEnabled') }).Value
    $hash.add($vmSKU,$accel)
}
$obj = New-Object -TypeName PSObject -Property $hash 
write-host "list of VMs with/without support for accelerated networking:" -ForegroundColor Cyan
$obj
```

Today, the Azure networking stack supports 1M total flows (500k inbound and 500k outbound) for a VM. Total active connections that can be handled by a VM in different scenarios are as follows.
   * VMs that belongs to VNET can handle 500k active connections for all VM sizes with 500k active flows in each direction.
   * VMs with network virtual appliances (NVAs) such as gateway, proxy, firewall can handle 250k active connections with 500k active flows in each direction due to the forwarding
see more detail in the [azure documentation](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-machine-network-throughput)

## <a name="List of files"></a>1. List of files

| file                 | description                                                        |       
| -------------------- |:------------------------------------------------------------------ |
| **init.json**        | Define a list of input variables required as input to **az.json**  |
| **az.json**          | ARM template to create vnets, VMs, vpn Gateways in each vnet       |
| **az.ps1**           | powershell script to deploy the ARM template **az.json**           |
| **getIP.ps1**        | powershell script to fatch the public IPs of the Azure VMs         |


**NOTE in init.json**
The input variables are stored in **init.json** file. Before starting the deployment check the consistency of input variables.
The file **init.json** sets SSH key as authentication method; if you want to use the password as authentication method, rename the file **init_.json** in **init.json** 
In the **init.json** file the variable **"authenticationType"** can takes to fix strings: "sshPublicKey" OR "password"


## <a name="List of files"></a>2. Internal load balancer configuration
The standard load balancer is configured in HA. Configuration of frontend IPs, backend IPs and load balancer rules are shown below:

[![2]][2]




<!--Image References-->

[1]: ./media/network-diagram.png "network diagram - overview" 
[2]: ./media/network-diagram2.png "load balancer frontend, balancing rules, backend pools" 

<!--Link References-->

