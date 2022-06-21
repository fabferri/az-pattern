<properties
pageTitle= 'Azure Bastion to access to Azure VMs'
description= "Azure Bastion to access to Azure VMs"
documentationcenter: na
services=""
documentationCenter="na"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="Azure networking"
   ms.tgt_pltfrm="na"
   ms.workload="Azure Bastion"
   ms.date="05/03/2022"
   ms.author="fabferri" />

## Azure Bastion to access to Azure VMs

The article describes a configuration with Azure Bastion to connect to the Azure VMs

[![1]][1]

Deployment of VMs in the vnet is executed by an array named **vmArray**.

<br>

The Azure VMs in **vmArray**., can be deployed with/without public IP and NSG.
The objects "pipObject" and "nsgObject" control the creation of public IP and NSG:

```json
"pipObject": "[variables('vm1pipObject')]",
"nsgObject": "[variables('vm1nsgObject') ]"
```
In the specific case, the ARM template assigns the following values: 

```json
"vm1pipObject": "",
"vm2pipObject": {
                    "id": "[resourceId( 'Microsoft.Network/publicIPAddresses',concat( variables('vm2Name'),'-pubIP' )  )]"
                },
"vm1nsgObject": "",
"vm2nsgObject": {
                    "id": "[resourceId( 'Microsoft.Network/networkSecurityGroups',concat( variables('vm2Name'),'-nsg' )  )]"
                },
```

* **"vm1pipObject"** is an empty string that will determine a no deployment of public IP of the Azure vm1
* **"vm1nsgObject"** is an empty string that will determine a no deployment of NSG associated with the NIV of the Azure vm1


The same criteria is valid of for the NSG:
* **"vm2pipObject"** is not empty and contains the Id of the public IP of the vm2; in this case the public IP will be deployed because the object is not empty.
* **"vm2nsgObject"** is not empty and contains the Id of the NSG applied to the NIC of the vm2; in this case the NSG will be deployed because the object is not empty.

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"

<!--Link References-->

