$agreementTerms=Get-AzMarketplaceTerms  -Publisher "cisco" -Product "cisco-csr-1000v"  -Name "17_3_4a-byol"

 Set-AzMarketplaceTerms -Publisher "cisco" -Product "cisco-csr-1000v" -Name "17_3_4a-byol" -Terms $agreementTerms -Accept