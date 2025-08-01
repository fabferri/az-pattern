<properties
pageTitle= 'Subnet peering in hub-spoke configuration deployed by REST API'
description= "Subnet peering in hub-spoke configuration deployed by REST API"
documentationcenter= "github.com/fabferri/az-pattern/"
services="subnet peering"
authors="fabferri"
/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="powershell"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="vnet peering"
   ms.date="01/08/2025"
   ms.author="fabferri" />

# Subnet peering in hub-spoke configuration deployed by REST API

In this article a list of powershell scripts provide a deployment with single hub connects to two spoke VNets through subnet peering. This deployment is executed using REST API. The network diagram is shown below:

[![1]][1]

- the subnet1 in hub1 is in peering with subnet1 in spoke1
- the subnet1 in hub1 is in peering with subnet1 in spoke2

## List of files

- `init.json`: file with the list of input variable
- `00-read-jsonfile.ps1`: script to read the init.json file; it creates global variables can be shared with all the other powershell scripts
- `01-create-hub1.ps1`: it creates the **hub1** vnet
- `02-create-spoke1.ps1`: it creates the **spoke1** vnet
- `03-create-spoke2.ps1`: it creates the **spoke2** vnet
- `04-create-peeringhub1-spoke1.ps1`: it creates the subnet peering between hub1-subnet1-to--spoke1-subnet1
- `05-create-peeringspoke1-hub1.ps1`: it creates the subnet peering spoke1-subnet1-to--hub1-subnet1
- `06-create-peeringhub1-spoke2.ps1`: it creates the subnet peering hub1-subnet1-to--spoke2-subnet1
- `07-create-peeringspoke2-hub1.ps1`: it creates the subnet peering spoke2-subnet1-to--hub1-subnet1
- `08-create-vms.ps1`: the script deploys the three VMs in the vnets

For a correct deployment, the scripts need to run in sequence: **00-read-jsonfile.ps1**, **01-create-hub1.ps1**, **02-create-spoke1.ps1**

`NOTE 1` <br>
In **00-read-jsonfile.ps1** are assigned the global variables using the statements:

```powershell
New-Variable -Name $key -Value $hash[$key] -Scope Global 
Set-Variable -Name $key -Value $hash[$key] -Scope Global
```

`NOTE 2` <br>
The scripts to generate vnets, vnet peering and VM acquires the value of input variables calling **read-jsonfile.ps1** by the command:

```powershell
& $PSScriptRoot/read-jsonfile.ps1
```

## Effective route tables

Effective route table in **hub1vm1**:
[![2]][2]

Effective route table in **spoke1vm1**:
[![3]][3]

Effective route table in **spoke2vm1**:
[![4]][4]

<br>

`Tags: Azure subnet peering, REST API` <br>
`date: 01-08-2025` <br>

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/effetive-route-hub1vm1.png "effective route table in hub1vm1"
[3]: ./media/effetive-route-spoke1vm1.png "effective route table in spoke1vm1"
[4]: ./media/effetive-route-spoke2vm1.png "effective route table in spoke1vm1"

<!--Link References-->

