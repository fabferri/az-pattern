<properties
pageTitle= 'Hub-spoke vnets deployed by REST API'
description= "hub-spoke vnets deployed by REST AP"
documentationcenter= "github.com/fabferri/az-pattern/"
services="vnet peering"
documentationCenter="na"
authors="fabferri"
/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="powershell"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="vnet peering"
   ms.date="23/06/2024"
   ms.author="fabferri" />

# Hub-spoke vnets deployed by REST AP
A list of powershell scripts provide a deployment with single hub connects to two spoke VNets through VNet peering. This deployment was done using REST API. The network diagram is shown below:

[![1]][1]


## List of files
- `init.json`: file with the list of input variable
- `read-jsonfile.ps1`: script to read the init.json file; it creates global variables can be shared with all the other powershell scripts
- `01-create-hub1.ps1`: it creates the **hub1** vnet
- `02-create-spoke1.ps1`: it creates the **spoke1** vnet
- `03-create-spoke2.ps1`: it creates the **spoke2** vnet
- `04-create-peeringhub1-spoke1.ps1`: it creates the vnet peering hub1--to--spoke1
- `05-create-peeringspoke1-hub1.ps1`: it creates the vnet peering spoke1--to--hub1
- `06-create-peeringhub1-spoke2.ps1`: it creates the vnet peering hub1--to--spoke2
- `07-create-peeringspoke2-hub1.ps1`: it creates the vnet peering spoke2--to--hub1
- `08-create-vms.ps1`: the script deploys the three VMs in the vnets

NOTE 1 <br>
In **read-jsonfile.ps1** are assigned the global variables using the commands: 
```powershell
New-Variable -Name $key -Value $hash[$key] -Scope Global 
Set-Variable -Name $key -Value $hash[$key] -Scope Global
```

NOTE 2 <br>
The scripts to generate vnets, vnet peering and VM acquires the value of input variables calling **read-jsonfile.ps1** by the command:
```powershell
& $PSScriptRoot/read-jsonfile.ps1
```

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"

<!--Link References-->

