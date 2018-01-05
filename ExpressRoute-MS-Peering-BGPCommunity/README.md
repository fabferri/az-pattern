<properties
   pageTitle="ExpressRoute Microsoft peering: powershell script to get the list of prefixes associated with BGP Community"
   description="ExpressRoute Microsoft peering: powershell script to get the list of prefixes associated with BGP Community"
   services=""
   documentationCenter="na"
   authors="fabferri"
   manager=""
   editor=""/>

<tags
   ms.service="Azure-ExpressRoute-Microsoft peering"
   ms.devlang="powershell"
   ms.topic="script"
   ms.tgt_pltfrm="na"
   ms.workload="na"
   ms.date="05/01/2018"
   ms.author="fabferri" />

# ExpressRoute Microsoft peering: powershell script
This is a simple powershell script to get the list of prefixes in ExpressRoute Microsoft peering with specific BGP community.

Office 365 IP prefixes that are advertised over ExpressRoute Microsoft peering are tagged with service specific BGP community values:



| Service            | BGP Community Value |
|--------------------|---------------------|
| Exchange           | 12076:5010          |
| sharepoint         | qux                 |
| skype for business | quuz                |
|other Office 365 services|12076:510       |
| CRM Online         |12076:5040           |

Before running the script be sure you are login in your Azure subscription by **Login-AzureRmAccount**
