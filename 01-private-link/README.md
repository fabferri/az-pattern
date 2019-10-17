<properties
pageTitle= 'private service link'
description= "private service link"
documentationcenter: na
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
   ms.date="16/10/2019"
   ms.author="fabferri" />

## Example of private service link with ExpressRoute
This post talks through as example of Azure private service link by ARM template.
Below the network diagram:

[![1]][1]


The configuration is based on two deployments to execute in sequence:
* 1-st step: create the VNet with private service link. The deployment is created through the **provider.json**
* 2-nd step: create the consumer VNet with ExpressRoute gateway and Connection. The deployment is created by **consumer-vnet-1er.json**. To use the ARM template is required the availability of an ExpressRoute circuit deployed in different Azure subscription.
To link an ExpressRoute Gateway to the circuit in different Azure subscription, a redeem authorization is required. The redeem authorization has to be set inside the **consumer-vnet-1er.json**
The 2-nd step requires as mandatory the availability of primate link service deployed in the 1-st step.


List of scripts:
* **provider.ps1**: powershell command to run the ARM template **provider.json**; you can run the script by command:
  provider.ps1 -adminUsername <USERNAME_ADMINISTRATOR_VMs> -adminPassword <PASSWORD_ADMINISTRATOR_VMs> 
* **provider.json**: ARM template to create a VNet with private link service.
* **consumer-vnet-1er.ps1**: powershell to deploy **consumer-vnet-1er.json**
* **consumer-vnet-1er.json**: ARM template to create a VNet with the private endpoint. The ARM template contain two variables:    
   - **"erCircuitId"**: it is the resource Id of the existing Expressroute circuit. The structure of variable is reported below:
"erCircuitId": "/subscriptions/<AZURE_SUBSCRIPITON_ID>/resourceGroups/<RESOURCE-GROUP>/providers/Microsoft.Network/expressRouteCircuits/<EXPRESSROUTE_CIRCUIT_NAME>"
   - **"authorizationKey"** : it contains the redeem authorization, needed to link the gateway to the ExpressRoute circuit.

Short description of  **provider.json**:
* Create a VNet with two subnets: private link subnet and backend subnet.  
   - private link subnet: it is the subnet with attached the private link service
   - backend subnet: it is the subnet with attached the VMs served by private link
* Create a standard internal load balancer and associate the NIC of the VMs with the backend pool
* create the *private link service* in prive link subnet

Short description of  **consumer-vnet-1er.json**:
* Create a VNet with subnet1 and GatewaySubnet
* Create the VM in the subnet1
* Create the private endpoint in subnet1, linked to private service link
* Create the ExpressRoute Gateway
* Create the Connection (requires the redeem authorization associated with the ExpressRoute circuit)


> Note
> before running the powershell scripts customize the values of variables:
>
>   $subscriptionName: name of the Azure subscription
>
>   $location: name of the Azure region
>
>   $rgName: name of the Resource Group

Below the effective routes in the NIC of vm1:
[![2]][2]

<!--Image References-->

[1]: ./media/network-diagram.png "network overview"
[2]: ./media/effective-routes.png "effective routes vm1"
<!--Link References-->

