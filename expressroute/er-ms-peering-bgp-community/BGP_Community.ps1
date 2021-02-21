$fullList=Get-AzBgpServiceCommunity 
foreach ($i in $fullList)
{
    switch($i.Name)
    {
      "Exchange" {
         $Name=$i.Name
         $arrayPrefixesExchange=$i.BgpCommunities.ToArray()
         $prefix=$arrayPrefixesExchange.CommunityPrefixes
         $NumberPrefixesExchange=$arrayPrefixesExchange.CommunityPrefixes.Count
         # write-host -ForegroundColor Green $prefix
         }
      "OtherOffice365Services" {
         $Name=$i.Name
         $arrayPrefixesOtherOffice365Services=$i.BgpCommunities.ToArray()
         $prefix=$arrayPrefixesOtherOffice365Services.CommunityPrefixes
         $NumberPrefixesOtherOffice365Services=$arrayPrefixesOtherOffice365Services.CommunityPrefixes.Count
         # write-host -ForegroundColor Yellow $prefix
         }
      "SharePoint" {
         $Name=$i.Name
         $arrayPrefixesSharePoint=$i.BgpCommunities.ToArray()
         $prefix=$arrayPrefixesSharePoint.CommunityPrefixes
         $NumberPrefixesSharePoint=$arrayPrefixesSharePoint.CommunityPrefixes.Count
         #write-host -ForegroundColor White $prefix $nl
         }
      "SkypeForBusiness" {
         $Name=$i.Name
         $arrayPrefixesSkypeForBusiness=$i.BgpCommunities.ToArray()
         $prefix=$arrayPrefixesSkypeForBusiness.CommunityPrefixes
         $NumberPrefixesSkype=$arrayPrefixesSkypeForBusiness.CommunityPrefixes.Count
         # write-host -ForegroundColor Cyan $prefix $nl
         }
     }
} 

$list =@()
$list +=$arrayPrefixesExchange.CommunityPrefixes
$list +=$arrayPrefixesOtherOffice365Services.CommunityPrefixes
$list +=$arrayPrefixesSharePoint.CommunityPrefixes
$list +=$arrayPrefixesSkypeForBusiness.CommunityPrefixes


[Array]::Sort([array]$list)

$totalNumberPrefixes=$list.Count

write-host "total number of prefixes in OtherOffice365Services: " $NumberPrefixesOtherOffice365Services -ForegroundColor White
write-host "total number of prefixes in Exchange..............: " $NumberPrefixesExchange -ForegroundColor Green 
write-host "total number of prefixes in SkypeForBusiness......: " $NumberPrefixesSkype -ForegroundColor Cyan
write-host "total number of prefixes in SharePoint............: " $NumberPrefixesSharePoint -ForegroundColor Red
write-host "total number of prefixes: " $totalNumberPrefixes -ForegroundColor Yellow
write-host ""
write-host "List of prefixes: "
$list


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