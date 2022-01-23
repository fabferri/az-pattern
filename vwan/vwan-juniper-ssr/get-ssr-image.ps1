##### List of Azure powershell commands to find out the publisher, offer, SKU and images in Azure marketplace
##### 
##### Getting all the publishers in a specific region
$locName="westus2"
#Get-AzVMImagePublisher -Location $locName | Select PublisherName


##### Getting Juniper network
$pubName="juniper-networks"
#Get-AzVMImageOffer -Location $locName -PublisherName $pubName | Select Offer


##### Getting SKUs, Offer, PublisherName
$offerName="session-smart-networking-payg"
#Get-AzVMImageSku -Location $locName -PublisherName $pubName -Offer $offerName 



##### Getting the last sku
$locName="westus2"
$pubName="juniper-networks"
$offerName="session-smart-networking-payg"
$skuName ="session-smart-networking-private-513"
Get-AzVMImage -Location $locName -PublisherName $pubName -Offer $offerName -Skus $skuName | ft
Exit

##### Getting the version
Get-AzVMImage -Location $locName -PublisherName $pubName -Offer $offerName -Sku $skuName | Select Version