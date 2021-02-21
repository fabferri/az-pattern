<properties
pageTitle= 'ARM template to create a VNet with ExpressRoute gateway'
description= "ARM template to create a VNet with ExpressRoute gateway"
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
   ms.date="21/02/2021"
   ms.author="fabferri" />

## ARM template to create a VNet with ExpressRoute gateway
The ARM template **er-gtw.json** creates an Azure VNet with an ExpressRoute Gateway.
The ExpressRoute Gateway can be deployed with/without zoning. 


The network diagram is shown below:

[![1]][1]

The parameter **ipZoning** in ARM template is boolean: 

* it returns a value true is the ExpressRoute Gateway is set with SKU in zoning: **"ErGw1AZ", "ErGw2AZ", "ErGw3AZ"**.
* it returns a value false if the ExpressRoute Gateway SKU is set to one of values: **"Standard", "HighPerformance", "UltraPerformance"**.

ExpressRoute Gateway in availability zone requires a **single IP** with **Standard SKU** and **Static allocation method**.

The variables in ARM template **er-gtw.json**:
```json
"pubIPSKU": "[if(parameters('ipZoning'),'Standard','Basic')]",
"pubIPAllocationMethod": "[if(parameters('ipZoning'),'Static','Dynamic')]",
```
assign the values in the public IP of the ExpressRoute Gateway:

```json
        {
            "comments": "public IP of the ExpressRoute Gateway",
            "type": "Microsoft.Network/publicIPAddresses",
            "apiVersion": "2020-06-01",
            "name": "[variables('gatewayPublicIPName')]",
            "location": "[variables('location')]",
            "sku": {
                "name": "[variables('pubIPSKU')]"
            },
            "properties": {
                "publicIPAllocationMethod": "[variables('pubIPAllocationMethod')]"
            }
        }

```

> **[!NOTE1]**
> Before spinning up the ARM template you should change the following in the file **er-gtw.json**:
> * variable **$subscriptionName**:  name of your Azure subscription
> 
> 

> **[!NOTE2]**
> Deployment of ExpressRoute Gateway in availability zone is supported only in Azure region with zoning.
> [Azure regions with availability zone](https://docs.microsoft.com/en-us/azure/availability-zones/az-region)
> 
> 


<!--Image References-->
[1]: ./media/network-diagram.png "network diagram"
<!--Link References-->

