<properties
pageTitle= 'Juniper vSRX: basic configuration to allow traffic in transit between two VMs'
description= "Juniper vSRX: basic configuration to allow traffic in transit between two VMs"
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
   ms.tgt_pltfrm="Azure"
   ms.workload="na"
   ms.date="30/01/2023"
   ms.author="fabferri" />

# Juniper vSRX: basic configuration to allow traffic in transit between two VMs
The article reports the ARM templates to create a Juniper vSRX and two VMs connected to two different subnets of the same vnet. <br> 
The configuration aims to establish a communication between two VMs, with transit through the vSRX. The network diagram is shown below:

[![1]][1]

Two UDRs are applied to the subnets of VMs, to route the traffic through the vSRX. <br>
The communication path between the two VMs is shown in the diagram:

[![2]][2]


## <a name="AzureDeployment"></a>1. List of files
|file               |description                               | 
|-------------------|------------------------------------------|
|**srx.json**       | ARM template to deploy vnet, vSRX and VMs|
|**srx.ps1**        | powershell script to run **srx.json**    |
|**srx-config.txt** | vSRX configuration                       |

Username and password of VMs and vSRX are specified in the variables **$adminUsername**, **$adminPassword** of the powershell script **srx.ps1**.


### <a name="AzureDeployment"></a>2. Azure Marketplace terms and condition to run the vSRX image
Deployment of NVAs in Azure marketplace requires three mandatory parameters: "publisher", "offer", "sku", "version"

The ARM template uses the following image:
  - "publisher" "juniper-networks"
  - "offer": "vsrx-next-generation-firewall"
  - "sku":  "vsrx-byol-azure-image"
  - "version": "latest"

Utilization of third-party software in azure marketplace requires approval of terms and condition. If you reference a product in ARM template without acceptance of terms and condition your deployment will fail with message:

```console
New-AzResourceGroupDeployment : 10:04:44 - Error: Code=MarketplacePurchaseEligibilityFailed; Message=Marketplace purchase eligibilty check returned errors.
```

To accept market terms and condition run the following command:
```powershell
# get the azure subscription Id
$subId=(Get-AzSubscription -SubscriptionName $subscriptionName).id
$agreementTerms=Get-AzMarketplaceTerms  -Publisher "juniper-networks" -Product "vsrx-next-generation-firewall-payg"  -Name "vsrx-azure-image-byol" -SubscriptionId $subId -OfferType 'virtualmachine'

# check that the variable $agreementTerms is not emptry:
write-host $agreementTerms 

# if the $agreementTerms is not null, accept the terms and condition:
Set-AzMarketplaceTerms -Publisher "juniper-networks" -Product "vsrx-next-generation-firewall" -Name "vsrx-byol-azure-image" -Subs
criptionId $subId -Accept
```


### <a name="AzureDeployment"></a>3. How to set the vSRX configuration
By default, the management Ethernet interface (usually fxp0) provides the out-of-band management network for the vSRX. <br>
- Connect to the console of the vSRX and enter in configuration mode (**configure** command OR **edit** command).
- Paste the content of file **srx-config.txt** in the vSRX console. <br>
- Run the Junos command **commit check** to check the consistency of configuration. If there is no error, proceed with the command **commit** to apply the configuration to the vSRX.

To display the vSRX configuration:
```console
show configuration | display set
```
To see the IP address assigned to the vSRX interfaces:
```
 show interfaces terse
```
Generate traffic between vm1 and vm2, e.g. iperf traffic or HTTP traffic; while the traffic is in transit through the vSRX, you can verify the live flows by the command:
```console
show security flow session
```
To check the CPU utlization of vSRX:
```console
show chassis routing-engine
```

## <a name="Juniper"></a>4. Annex1: basic Juniper info

### <a name="Juniper"></a>4.1 Zone
A security zone is a collection of one or more network segments requiring the regulation of inbound and outbound traffic through policies. By default, interfaces are in the null zone. The interfaces will not pass traffic until they have been assigned to a zone.

### <a name="Juniper"></a>4.2 Security policy
A security policy is a set of statements that controls traffic from a specified source to a specified destination using a specified service. 
A policy permits, denies, or tunnels specified types of traffic <ins>**unidirectionally**</ins> between two points.
Each security policy consists of:
* a unique name for the policy,
* a _from-zone_ and a _to-zone_,
* a set of match criteria defining the conditions that must be satisfied (based on a source IP address, destination IP address, and application)
* a set of actions to be performed in case of a match—permit or deny
* a set of source VRF names (not used in our case)
* a set of destination VRF names (not used in our case)


`Tags: Juniper vSRX` <br>
`date: 31-01-23`


<!--Image References-->
[1]: ./media/network-diagram1.png  "network diagram"
[2]: ./media/network-diagram2.png "communication path between two VMs in two different subnets"
<!--Link References-->

