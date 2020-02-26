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
Simple powershell script to get the list of prefixes in ExpressRoute Microsoft peering with specific BGP community.

Office 365 IP prefixes that are advertised over ExpressRoute Microsoft peering are tagged with service specific BGP community values:



| Service                  | BGP Community Value |
|--------------------------|---------------------|
| other Office 365 services| 12076:5100          |
| Exchange                 | 12076:5010          |
| sharepoint               | 12076:5020          |
| skype for business       | 12076:5030          |
| CRM Online               | 12076:5040          |

To run the script you need to login in your Azure subscription by **Login-AzAccount**
To select all the prefixes associated with a specific BGP community, i.e. Skype for business:

```console
Get-AzBgpServiceCommunity | ? {$_.name -eq 'SkypeForBusiness' }
```