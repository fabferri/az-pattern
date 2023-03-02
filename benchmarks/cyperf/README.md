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

By Cyperf Controller, each Cyper agent is configured with client role or server role; the topology is shown below:

[![2]][2]


Cyperf allows to run performance tests of different NVAs; the diagram below shows the network diagram:


The UDRs applied to the subnet Cyperf agent force the cyperf traffic to transit through the NVA:

[![3]][3]


## <a name="list of files"></a>1. File list
| File name                         | Description                                                                             |
| --------------------------------- | --------------------------------------------------------------------------------------- |
| **cyperf-controller-agents.json** | ARM template to create the Azure VNet, the Cyperf Controller and the Cyperf Agents. <br> The ARM template does not include the creation of subnets for the NVA and the NVA itself                                                                            |
| **cyperf-controller-agents-parameters.json** | parameter file for **cyperf-controller-agents.json**                         |
| **cyperf-controller-agents.ps1**  |  powershell script to deploy **cyperf-controller-agents.json**                          |
| **nva-D8ds_v4.json**              | ARM template to deploy an Ubuntu **Standard_D8ds_v4** VM SKU                            |
| **nva-D16ds_v4.json**             | ARM template to deploy an Ubuntu **Standard_D16ds_v4** VM SKU                           |
| **nva-D32ds_v4.json**             | ARM template to deploy an Ubuntu **Standard_D32ds_v4** VM SKU                           |
| **srx-D8ds_v4.json**              | ARM template to deploy a Juniper SRX in **Standard_D8ds_v4** VM SKU                     |
| **srx-D16ds_v4.json**             | ARM template to deploy a Juniper SRX in **Standard_D16ds_v4** VM SKU                    |
| **srx-D32ds_v4.json**             | ARM template to deploy a Juniper SRX in **Standard_D32ds_v4** VM SKU                    |


## <a name="list of files"></a>2. Juniper SRX in Standard_D16ds_v4 VM SKU
ARM template: <ins>**srx-D16ds_v4.json**</ins>

[![4]][4]

SRX configuration:

```console
# define a static IP for the interfaces
set interfaces ge-0/0/0 unit 0 family inet dhcp
set interfaces ge-0/0/1 unit 0 family inet dhcp
set interfaces ge-0/0/2 unit 0 family inet dhcp

# static routes to reach out the subnets
set routing-options static route 172.16.3.0/24 next-hop 172.16.10.1
set routing-options static route 172.16.4.0/24 next-hop 172.16.11.1

# define the security zone a association of interfaces to security zones
set security zones security-zone untrust interfaces ge-0/0/0.0 host-inbound-traffic system-services all
set security zones security-zone untrust interfaces ge-0/0/0.0 host-inbound-traffic protocols all
set security zones security-zone trust-1 interfaces ge-0/0/1.0 host-inbound-traffic system-services all
set security zones security-zone trust-1 interfaces ge-0/0/1.0 host-inbound-traffic protocols all
set security zones security-zone trust-2 interfaces ge-0/0/2.0 host-inbound-traffic system-services all
set security zones security-zone trust-2 interfaces ge-0/0/2.0 host-inbound-traffic protocols all

# define the policy options
set security policies from-zone trust to-zone untrust policy default-permit match source-address any
set security policies from-zone trust to-zone untrust policy default-permit match destination-address any
set security policies from-zone trust to-zone untrust policy default-permit match application any
set security policies from-zone trust to-zone untrust policy default-permit then permit
set security policies from-zone trust to-zone trust policy default-permit match source-address any
set security policies from-zone trust to-zone trust policy default-permit match destination-address any
set security policies from-zone trust to-zone trust policy default-permit match application any
set security policies from-zone trust to-zone trust policy default-permit then permit
set security policies from-zone trust-1 to-zone trust-2 policy trust-1-2 match source-address any
set security policies from-zone trust-1 to-zone trust-2 policy trust-1-2 match destination-address any
set security policies from-zone trust-1 to-zone trust-2 policy trust-1-2 match application any
set security policies from-zone trust-1 to-zone trust-2 policy trust-1-2 then permit
set security policies from-zone trust-2 to-zone trust-1 policy trust-2-1 match source-address any
set security policies from-zone trust-2 to-zone trust-1 policy trust-2-1 match destination-address any
set security policies from-zone trust-2 to-zone trust-1 policy trust-2-1 match application any
set security policies from-zone trust-2 to-zone trust-1 policy trust-2-1 then permit
```

## <a name="list of files"></a>3. Ubuntu in Standard_D16ds_v4 VM SKU
ARM template: <ins>**nva-D16ds_v4.json**</ins>

[![5]][5]

## <a name="list of files"></a>4. Juniper SRX in Standard_D32ds_v4 VM SKU
ARM template: <ins>**srx-D32ds_v4.json**</ins>

[![6]][6]

## <a name="list of files"></a>5. Ubuntu in Standard_D32ds_v4 VM SKU
ARM template: <ins>**nva-D16ds_v4.json**</ins>

[![7]][7]

## <a name="list of files"></a>6. Juniper SRX in Standard_D8ds_v4 VM SKU
ARM template: <ins>**srx-D8ds_v4.json**</ins>

[![8]][8]

## <a name="list of files"></a>7. Ubuntu in Standard_D8ds_v4 VM SKU
ARM template: <ins>**nva-D8ds_v4.json**</ins>

[![9]][9]

## <a name="Cyperf benchmarks"></a>8. Cyperf benchmarks setup

### <a name="Cyperf benchmarks:CPS"></a>8.1 Max connection per second
[![10]][10]

### <a name="Cyperf benchmarks: unidirectional throughout"></a>8.2 Max unidirectional throughput

[![11]][11]

### <a name="Cyperf benchmarks: bidirectional throughout"></a>8.3 Max bidirectional throughput

[![12]][12]


`Tags: Cyperf benchmarks` <br>
`date: 23-01-23`


<!--Image References-->
[1]: ./media/network-diagram1.png "Cyperf deployment"
[2]: ./media/network-diagram2.png "Cyperf topology configuration"
[3]: ./media/network-diagram3.png "network diagram"
[4]: ./media/network-diagram4.png "Juniper SRX in Standard_D16ds_v4"
[5]: ./media/network-diagram5.png "Ubuntu in Standard_D16ds_v4"
[6]: ./media/network-diagram6.png "Juniper SRX in Standard_D32ds_v4"
[7]: ./media/network-diagram7.png "Ubuntu in Standard_D32ds_v4"
[8]: ./media/network-diagram8.png "Juniper SRX in Standard_D8ds_v4"
[9]: ./media/network-diagram9.png "Ubuntu in Standard_D8ds_v4"
[10]: ./media/network-diagram10.png "Cyperf: Max connection per second"
[11]: ./media/network-diagram11.png "Cyperf: Max unidirectional throughput"
[12]: ./media/network-diagram12.png "Cyperf: Max bidirectional throughput"
<!--Link References-->

