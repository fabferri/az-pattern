$location=Get-AzLocation | select displayname | `
Out-GridView -PassThru -Title "Choose a location"

$pubName=Get-AzVMImagePublisher `
-Location $location.DisplayName | `
Out-GridView -PassThru -Title "Choose a publisher"

$offerName = Get-AzVMImageOffer `
-Location $location.DisplayName `
-PublisherName $pubname.PublisherName | `
Out-GridView -PassThru -Title "Choose an offer"

$title="SKUs for location: " + `
$location.DisplayName + `
", Publisher: "+ $pubName.PublisherName + `
", Offer: " + $offerName.Offer
 
Get-AzVMImageSku `
-Location $location.DisplayName `
-PublisherName $pubName.PublisherName `
-Offer $offerName.Offer | `
select SKUS | `
Out-GridView -Title $title