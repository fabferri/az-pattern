# 
# script to approval the legal terms to use the image in Azure marketplace
# $subscriptionName: Azure subscription name
# $locationName: name of the Azure region
# $publisherName: name of image publisher
#
$subscriptionName = 'AZURE_SUBSCRIPTION_NAME'    
$locationName='westus2'
$publisherName='cisco'


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

write-host 'List of image offer' -ForegroundColor Yellow
Get-AzVMImageOffer -Location $locationName  -PublisherName $publisherName


#Fill in your chosen SKU name and get the image version:
$productName="cisco-csr-1000v"

Get-AzVMImageSku -Location $locationName -PublisherName $publisherName -Offer $productName | Select Skus 



$agreementTerms=Get-AzMarketplaceTerms -Publisher $publisherName -Product $productName -Name '17_3_4a-byol' 
$agreementTerms
Set-AzMarketplaceTerms -Publisher $publisherName -Product $productName -Name '17_3_4a-byol' -Terms $agreementTerms -Accept -Verbose
Write-Host $agreementTerms.Accepted