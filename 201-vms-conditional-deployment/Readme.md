<properties
   pageTitle="Conditional deployment of Azure VMs"
   description="Azure template to make a conditional deployment of Azure VMs"
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
   ms.date="25/11/2016"
   ms.author="fabferri" />

# Conditional deployment of Azure VMs

The purpose of the Azure template is to deploy an arbitrary Azure VMs, in specific subnets as specified in template parameter file.
Before running the deployment, define the custom values in the template file.

Snippets:

- **azure-deploy.ps1**: powerhell script to create the deployment
- **azuredeploy.json**: master template; the template recall child template to create Azure an VNet, NSGs, VMs.
- **azuredeploy.parameters.json**: parameter template; it contains two arrays named "vmArraySubnet1" and "vmArraySubnet2" each with a list of values for the Azure VMs.
- **nsg-subnets.json**: template to create a Network Security Group (NSG) to apply to the subnet. 
- **nsg-subnets-empty.json**: the template contains an reference to the NSG, but the resources in the template are empty.
- **vms-workgroup.json**: template to create the Windows VMs (all in a workgroup)
- **vms-workgroup-empty.json** : the template contains a reference to the VMs, but the resources in the template are empty.
- **vnet.json**: template to create the VNet with two subnets.

The Azure templates create:

- a VNet with two subnets (subnet1, subnet2)
- a Network Security Group applied to the subnets
- few Azure VMs attached to the subnet1; the number of VMs is specified in parameter file in the array **"vmArraySubnet1"**
- few Azure VMs attached to the subnet2; the number of VMs is specified in parameter file in the array **"vmArraySubne2"**

The array **"vmArraySubnet1"** and **"vmArraySubnet1"** define the spec of the VMs.
All the VMs have a private static IP address.

The conditional deployment is controlled by the flags:

- **"flagDeployVmSubnet1"**: this variable can be only set to the value **"true"** or **"false"**. The deployment of the VMs in subnet1 is executed only in case the flag is set to "true"
- **"flagDeployVmSubnet2"**: this variable can be only set to the value **"true"** or **"false"**. The deployment of the VMs in subnet2 is executed only in case the flag is set to "true".
- **"flagDeployNSG"** : this variable can be only set to the value **"true"** or **"false"**. The deployment of the NSG in subnet1 and subnet2 is done only in case the flag is set to "true" 


### Note
The arrays **"vmArraySubnet1"** and **"vmArraySubnet2"** need to be consistent in the IP address schema otherwise the template will fail.