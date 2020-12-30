<properties
pageTitle= 'Create NICs with multiple IP Addresses through Azure ARM template'
description= "Create NICs with multiple IP Addresses through Azure ARM template"
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
   ms.date="04/04/2020"
   ms.author="fabferri" />

## Create NICs with multiple IP Addresses through Azure ARM template

Create NIC for Azure VM through ARM template is a basic task, but the association of multiple IPs with a network adapter is tricker. ARM template support resource iteration by the **copy** element to the resources section.
The copy element has the following general format:

```json
"copy": {
  "name": "<name-of-loop>",
  "count": <number-of-iterations>,
  "mode": "serial" <or> "parallel",
  "batchSize": <number-to-deploy-serially>
}
```

* The "name" property is any value that identifies the loop. 
* The "count" property specifies the number of iterations you want for the resource type.

The interation on resources in ARM template is quite common, but it is less common to see applied **copy** to the variables.
The ARM template shows an example with three network adapaters and assigment of large number of private IPs to each adapater in subnet ranges.

[![1]][1]



> [!NOTE]
> Before spinning up the ARM template you should edit the file **nic.ps1** and set:
> * your Azure subscription name in the variable **$subscriptionName**
> 

### nic1
[![2]][2]

### nic2
[![3]][3]

### nic3
[![4]][4]

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/nic1.png "nic1"
[3]: ./media/nic2.png "nic2"
[4]: ./media/nic3.png "nic3"

<!--Link References-->

