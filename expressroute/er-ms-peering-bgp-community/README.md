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

# ExpressRoute Microsoft peering: how to retrieve the list of prefixes associated with BGP community
Simple powershell script to get the list of prefixes in ExpressRoute Microsoft peering with specific BGP community.

Office 365 IP prefixes that are advertised over ExpressRoute Microsoft peering are tagged with service specific BGP community values:


| Service                  | BGP Community Value |
|--------------------------|---------------------|
| Exchange                 | 12076:5010          |
| sharepoint               | 12076:5020          |
| skype for business       | 12076:5030          |
| other Office 365 services| 12076:5100          |


To run the script you need to login in your Azure subscription by **Login-AzAccount**
To select all the prefixes associated with a specific BGP community, i.e. Skype for business:

```powershell
Get-AzBgpServiceCommunity | ? {$_.name -eq 'SkypeForBusiness' }

Get-AzBgpServiceCommunity | ?{$_.Name -eq 'Exchange' -or $_.Name -eq 'Sharepoint' -or $_.Name -eq 'SkypeForBusiness' -or $_.Name -eq 'OtherOffice365Services'}

```

Powershell script to extract BGP communities names and BGP community value:

```powershell
$fullList=Get-AzBgpServiceCommunity 
$BGPCommunityName=@()
$BGPCommunity=@{}

# use the hash table to store (BGP community name, BGP community value)
foreach ($i in $fullList)
{
  $BGPCommunity.Add($i.Name,$i.BgpCommunities.CommunityValue)
} 
$BGPCommunity

foreach ($i in $fullList)
{
  $BGPCommunityName +=$i.Name
} 
Write-Host ''
Write-Host 'full list of BGP community name:'
Write-Host -Separator "`n" $BGPCommunityName -ForegroundColor Cyan

# $str: substring to search
# search all the BGP communities name for SQL
$str= "SQL"
foreach ($i in $BGPCommunityName )
{
  $s=$str.toLower()
 if ($i.toLower().Contains($s)) { 
   Write-Host $i -ForegroundColor Yellow
 }
}
```