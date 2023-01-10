<properties
pageTitle= 'ARM template to deploy CyPerf controller and agents in Azure VMs'
description= "ARM template to deploy CyPerf controller and agents in Azure VMs"
documentationcenter: github
services=""
documentationCenter="github"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="na"
   ms.date="10/01/2023"
   ms.author="fabferri" />

## ARM template to deploy CyPerf controller and agents in Azure VMs
The ARM template **cyperf-controller-agents.json** creates an VNet with VMs to run a benchmark through Keysight Cyperf. <br>
Cyperf is a Keysight product available in Azure marketplace able to generate different type of traffics to get the throughput, max concurrency (connection per second-CPS), application latency, TSL performance and threat detection. <br>
The ARM template deploys an infrastructure with the following diagram: 


[![1]][1]


Cyperf has two roles, **controller** and **agent**. The controller has the UI to define the type of test and selection of the agents to send/receive the traffic patterns. The agents run in the VMs and are the generators and/or receivers of the traffic test. 
The Cyperf is not a competitor of open source software like iperf3 because has a broad options able to generate a simulation of real application traffic. 


The parameter file **parameters.json** specifies the administrator username (variable **adminUsername**) and the SSH public key (in the variable **SSHPublicKey**)


Deployment of the ARM template requires the acceptance of the legal terms and license condition in Azure marketplace. Acceptance can be done through the Azure management portal or through powershell:
```powershell
# get the image offering
Get-AzVMImageOffer -Location westus2 -PublisherName keysighttechnologies_cyperf
# get the SKUs
Get-AzVMImageSku -Location westus2 -PublisherName keysighttechnologies_cyperf -Offer keysight-cyperf

### license for controller
Get-AzMarketplaceTerms -Publisher keysighttechnologies_cyperf -Name keysight-cyperf-controller -Product keysight-cyperf
Set-AzMarketplaceTerms -Accept -Publisher  keysighttechnologies_cyperf -Name keysight-cyperf-controller -Product keysight-cyperf

### license for agent
Get-AzMarketplaceTerms -Publisher keysighttechnologies_cyperf -Name keysight-cyperf-agent -Product keysight-cyperf
Set-AzMarketplaceTerms -Accept -Publisher keysighttechnologies_cyperf -Name keysight-cyperf-agent -Product keysight-cyperf
```

when the deployment of ARM template is completed, you can connect to the Cyperf controller in HTTPS. 

If you want to use Cyperf, you need to reach out a Keysight representative and ask for a license. Without license you won't be able to run Cyperf tests. The license needs to be load in the Cyperf controller. <br>
Registration of the can can be executed on the controller UI by following selections: <br>
**Settings -> License Manager -> Activate License -> Load Data**

## NOTE
**The ARM template does not include the creation of subnets for the NVA and the NVA itself.** <br>
**The ARM template will be improved**- *working in progress*

<!--Image References-->
[1]: ./media/network-diagram.png "network diagram"
<!--Link References-->

