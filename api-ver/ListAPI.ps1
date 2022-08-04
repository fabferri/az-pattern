$location='eastus'

Write-Host "List API in $location" 

Write-host "===================== Virtual Network API:" -ForegroundColor Cyan
$apilist1=((Get-AzResourceProvider -ProviderNamespace Microsoft.Network -Location $location).ResourceTypes | Where-Object ResourceTypeName -eq VirtualNetworks).ApiVersions
Write-host $apilist1 -Separator "`n" -ForegroundColor cyan
Write-host "-----------------------------------------" 



Write-Host "===================== VM API:" -ForegroundColor White
$apilist2=((Get-AzResourceProvider -ProviderNamespace Microsoft.Compute -Location $location).ResourceTypes | Where-Object ResourceTypeName -eq VirtualMachines).ApiVersions
Write-host $apilist2 -Separator "`n" -ForegroundColor White

Write-host "===================== Azure VM extension:" -ForegroundColor Red
$apilist3=((Get-AzResourceProvider -ProviderNamespace Microsoft.Compute -Location $location).ResourceTypes | Where-Object ResourceTypeName -eq "virtualMachines/extensions").ApiVersions
Write-host $apilist3


Write-host "===================== VPN Gateway API:" -ForegroundColor Green
$apilist4=((Get-AzResourceProvider -ProviderNamespace Microsoft.Network -Location $location).ResourceTypes | Where-Object ResourceTypeName -eq vpnGateways).ApiVersions
Write-host $apilist4 -Separator "`n" -ForegroundColor Green
Write-host "-----------------------------------------" 


Write-host "===================== Azure firewall API:" -ForegroundColor Red
$apilist5=((Get-AzResourceProvider -ProviderNamespace Microsoft.Network -Location $location).ResourceTypes | Where-Object ResourceTypeName -eq azureFirewalls).ApiVersions
Write-host $apilist5 -Separator "`n" -ForegroundColor Red
Write-host "-----------------------------------------" 



