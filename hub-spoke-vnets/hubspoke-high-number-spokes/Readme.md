<properties
   pageTitle="Configuration hub-spoke with large number of spoke vnets"
   description="Configuration hub-spoke with large number of spoke vnets"
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
   ms.date="28/07/2021"
   ms.author="fabferri" />

# Configuration hub-spoke with large number of spoke vnets

ARM templates to deploy a single hub vnet with large number of spoke vnets in peering.  

List of files:

| Name                    | Description                                                                   |
|:----------------------- |:------------------------------------------------------------------------------|
| **vnets.json**          | ARM template to create hub vnet, spoke vnets and connect hub-spoke in peering |
| **vnets.ps1**           | powershell script to deploy **vnets.json**                                    |
| **vnets-peering.json**  | ARM template to create vnet peering between hub and spoke vnets               |
| **vnets-peering.ps1**   | powershell script to deploy **vnets-peering.json**                            |

Run the scripts in sequence:
- first step: run the **vnets.ps1** to deploy hub and spoke vnets
- second step: run the **vnets-peering.ps1** to create the peering between hub and spoke vnets
<br>

**vnets-peering.ps1** will fail if the hub and spoke vnets are not already deployed. 

> **NOTE**
> the powershell scripts read get the values of some variables from the file init.txt
>
>  $rgName: name of resource group
>
>  $RGTagExpireDate: set an expiration date in the tag value
>
>  $RGTagContact: set a contact in the tag value
>
>  $RGTagNinja: set the alias in the tag value
>
>  $RGTagUsage: purpose of deployment in the tag value
>

## Mechanism of assignment of the address space to the spoke vnets
The ARM template supports automatic creation of spoke vnets with address space by a loop. 
<br>
Each spoke vnet has an address space /24 as below:
```console
First-Octet.SecondOctet.ThirdOctet.0/24
```

- **First-Octet**: it is fixed digit
- **SecondOctet**: it starts from a starting integer value specified in the ARM template. The value of SecondOctet increases from the starting value only when the ThirdOctet overcome 255
- **ThirdOctet**: the counter on this octet start from 0 to 255. For number of spoke above 255, the value of second octet restart from zero
<br>

The logic of assigment of **SecondOctet** and **ThirdOctet** in address space of spoke vnets is implemented through the functions:

```json
string( add(variables('secondOctet'),div(copyIndex(),255)) )
string( add(variables('thirdOctet'),mod(copyIndex(),255)) )
```

- **add**: returns the sum of the two provided integers.
- **div**: returns the integer division of the two provided integers.
- **mod**: returns the remainder of the integer division using the two provided integers.

> **NOTE**
>
> The cycles in ARM template to create the vnet peering are established sequentially by **"batchSize": 1** to avoid deployment collisions and failure. Due to sequential operations the execution of the **vnets-peering.json** takes longer runtime. The runtime to create 400 vnet peering takes more or less 3 hours.
>

[![1]][1]

## Caveats
The ARM template is able to deploy max 400 spoke vnets. If you set a with high number of spoke vnets, you might get the error message:
```console
Error: Code=InvalidTemplate; Message=Deployment template validation failed: 'The number of template resources limit exceeded. Limit: '800'
```

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"

<!--Link References-->