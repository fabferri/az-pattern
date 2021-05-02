# List the publishers:
# $locName="eastus"
# Get-AzVMImagePublisher -Location $locName | Select-Object PublisherName


#Fill in your chosen publisher name and list the offers:
$locName='eastus'
$pubName='cisco'
Get-AzVMImageOffer -Location $locName  -PublisherName $pubName 


#Fill in your chosen SKU name and get the image version:
$offerName="cisco-csr-1000v"
Get-AzVMImageSku -Location $locName -PublisherName $pubName -Offer $offerName | Select Skus