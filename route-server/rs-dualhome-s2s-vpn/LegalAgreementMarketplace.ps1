# Sign up the legal agreement and terms to use the image from Azure marketplace
#
#  $subscriptionName" Azure subscription name
#  $locationName: Azure region
#  $publisherName: name publisher of the marketplace image
#
$subscriptionName  = "AzDev"    
$locationName='uksouth'
$publisherName='cisco'


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

write-host 'List of image offer' -ForegroundColor Yellow
Get-AzVMImageOffer -Location $locationName  -PublisherName $publisherName


#Fill in your chosen SKU name and get the image version:
$productName="cisco-csr-1000v"

Get-AzVMImageSku -Location $locationName -PublisherName $publisherName -Offer $productName | Select Skus 



$agreementTerms=Get-AzMarketplaceTerms -Publisher $publisherName -Product $productName -Name '17_3_3-byol' 
$agreementTerms
Set-AzMarketplaceTerms -Publisher $publisherName -Product $productName -Name '17_3_3-byol' -Terms $agreementTerms -Accept -Verbose
Write-Host $agreementTerms.Accepted


$agreementTerms=Get-AzMarketplaceTerms -Publisher $publisherName -Product $productName -Name '17_3_2-byol' 
$agreementTerms
Set-AzMarketplaceTerms -Publisher $publisherName -Product $productName -Name '17_3_2-byol' -Terms $agreementTerms -Accept -Verbose