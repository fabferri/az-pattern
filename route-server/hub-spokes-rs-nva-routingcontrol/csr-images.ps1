# powershell to approve term an condition to deploye Cisco CSR from Azure marketplace
$subscriptionName  = "ExpressRoute-Lab"    
$locationName='westus2'
$publisherName='cisco'


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

write-host 'List of image offer' -ForegroundColor Yellow
Get-AzVMImageOffer -Location $locationName  -PublisherName $publisherName


#Fill in your chosen SKU name and get the image version:
$productName = 'cisco-csr-1000v'

Get-AzVMImageSku -Location $locationName -PublisherName $publisherName -Offer $productName | Select-Object Skus 



$agreementTerms = Get-AzMarketplaceTerms -Publisher $publisherName -Product $productName -Name '17_3_4a-byol' -SubscriptionId  $subscr.Id -OfferType 'virtualmachine'

$agreementTerms

Set-AzMarketplaceTerms  -Terms $agreementTerms -Accept  -Verbose 
Write-Host $agreementTerms.Accepted
 

