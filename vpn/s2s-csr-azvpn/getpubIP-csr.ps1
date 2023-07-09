# getting the public IP of the Cisco CSR
#
#
#
$subscriptionName  = "AzDev"
$rg_csr            = "rg-csr"
$publiIPName_csr   = "csr-pubIP"


try {
  $IPcsr=Get-AzPublicIpAddress -Name $publiIPName_csr -ResourceGroupName $rg_csr -ErrorAction Stop
  if ($IPcsr) {
    write-host "CSR public IP: "$IPcsr.IpAddress -ForegroundColor Cyan 
  }
} 
catch {
  write-host "CSR public IP not found:" -ForegroundColor Yellow 
  write-host " -Check the resource group..:"$rg_csr  -ForegroundColor Yellow
  write-host " -check the CSR public IP...:"$publiIPName_csr -ForegroundColor Yellow
}