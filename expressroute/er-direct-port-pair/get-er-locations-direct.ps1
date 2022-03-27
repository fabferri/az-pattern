Get-AzExpressRoutePortsLocation | Where-Object {$_.Name -match "^Equinix*"}
Write-Host "-------------------------------------------------------------" -ForegroundColor Green
Write-Host "-------------------------------------------------------------" -ForegroundColor Green
Get-AzExpressRoutePortsLocation | Where-Object {$_.Name -match "^interxion*"}
Write-Host "-------------------------------------------------------------" -ForegroundColor Green
Write-Host "-------------------------------------------------------------" -ForegroundColor Green
foreach ($i in Get-AzExpressRoutePortsLocation)
{
  write-host $i.Name -NoNewline
  write-host " --- "$i.Address -ForegroundColor Cyan
} 
