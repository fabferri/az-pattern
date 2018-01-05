$nl = [Environment]::NewLine
$a=Get-AzureRmBgpServiceCommunity 
For ($i=0; $i -le $a.Length; $i++) 
{
    switch($a[$i].Name)
    {
      "Exchange" {
         $Name=$a[$i].Name
         $arrayPrefixesExchange=$a[$i].BgpCommunities.ToArray()
         $prefix=$arrayPrefixesExchange.CommunityPrefixes
         $NumberPrefixesExchange=$arrayPrefixesExchange.CommunityPrefixes.Count
         # write-host -ForegroundColor Green $prefix $nl
         }
      "OtherOffice365Services" {
         $Name=$a[$i].Name
         $arrayPrefixesOtherOffice365Services=$a[$i].BgpCommunities.ToArray()
         $prefix=$arrayPrefixesOtherOffice365Services.CommunityPrefixes
         $NumberPrefixesOtherOffice365Services=$arrayPrefixesOtherOffice365Services.CommunityPrefixes.Count
         # write-host -ForegroundColor Yellow $prefix $nl
         }
      "SkypeForBusiness" {
         $Name=$a[$i].Name
         $arrayPrefixesSkypeForBusiness=$a[$i].BgpCommunities.ToArray()
         $prefix=$arrayPrefixesSkypeForBusiness.CommunityPrefixes
         $NumberPrefixesSkype=$arrayPrefixesSkypeForBusiness.CommunityPrefixes.Count
         # write-host -ForegroundColor Cyan $prefix $nl
         }
      "SkypeForBusiness" {
         $Name=$a[$i].Name
         $arrayPrefixesSkypeForBusiness=$a[$i].BgpCommunities.ToArray()
         $prefix=$arrayPrefixesSkypeForBusiness.CommunityPrefixes
         $NumberPrefixesSkype=$arrayPrefixesSkypeForBusiness.CommunityPrefixes.Count
         #write-host -ForegroundColor Cyan $prefix $nl
         }        
      "SharePoint" {
         $Name=$a[$i].Name
         $arrayPrefixesSharePoint=$a[$i].BgpCommunities.ToArray()
         $prefix=$arrayPrefixesSharePoint.CommunityPrefixes
         $NumberPrefixesSharePoint=$arrayPrefixesSharePoint.CommunityPrefixes.Count
         #write-host -ForegroundColor White $prefix $nl
         }
       "CRMOnline" {
         $Name=$a[$i].Name
         $arrayPrefixesCRMOnline=$a[$i].BgpCommunities.ToArray()
         $prefix=$arrayPrefixesCRMOnline.CommunityPrefixes
         $NumberPrefixesCRMOnline=$arrayPrefixesCRMOnline.CommunityPrefixes.Count
         #write-host -ForegroundColor Gray $prefix $nl
         }
     }
} 
      write-host -ForegroundColor Yellow "total number of prefixes in OtherOffice365Services: " $NumberPrefixesOtherOffice365Services 
      write-host -ForegroundColor Green  "total number of prefixes in Exchange..............: " $NumberPrefixesExchange
      write-host -ForegroundColor Cyan   "total number of prefixes in SkypeForBusiness......: " $NumberPrefixesSkype
      write-host -ForegroundColor Red    "total number of prefixes in SharePoint............: " $NumberPrefixesSharePoint
      write-host -ForegroundColor Gray   "total number of prefixes in CRMOnline.............: " $NumberPrefixesCRMOnline

      Write-Host -ForegroundColor White  "--------------------------------------------------------------------------"
      Write-Host -ForegroundColor Yellow "---------------------------OtherOffice365Services-------------------------"
      foreach ($k in $arrayPrefixesOtherOffice365Services.CommunityPrefixes.GetEnumerator()) {
         Write-Host -ForegroundColor Yellow $k
      }

      Write-Host -ForegroundColor White "--------------------------------------------------------------------------"
      Write-Host -ForegroundColor Green "---------------------------Exchange---------------------------------------"
      foreach ($k in $arrayPrefixesExchange.CommunityPrefixes.GetEnumerator()) {
         Write-Host -ForegroundColor Green $k
      }
      Write-Host -ForegroundColor White "--------------------------------------------------------------------------"
      Write-Host -ForegroundColor Cyan  "---------------------------SkypeForBusiness-------------------------------"
      foreach ($k in $arrayPrefixesSkypeForBusiness.CommunityPrefixes.GetEnumerator()) {
         Write-Host -ForegroundColor Cyan $k
      }
      Write-Host -ForegroundColor White "--------------------------------------------------------------------------"
      Write-Host -ForegroundColor Red   "---------------------------SharePoint-------------------------------------"
      foreach ($k in $arrayPrefixesSharePoint.CommunityPrefixes.GetEnumerator()) {
         Write-Host -ForegroundColor Red $k
      }
      Write-Host -ForegroundColor White "--------------------------------------------------------------------------"
      Write-Host -ForegroundColor Gray  "---------------------------CRMOnline-------------------------------------"
      foreach ($k in $arrayPrefixesCRMOnline.CommunityPrefixes.GetEnumerator()) {
         Write-Host -ForegroundColor Gray $k
      }
