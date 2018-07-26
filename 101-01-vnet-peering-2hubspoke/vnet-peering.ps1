################# Input parameters #################
$subscriptionName      = "NAME_OF_YOUR_AZURE_SUBSCRIPTION"
$location              = "eastus"
$destResourceGrp       = "rg-vnetpeering01"
$resourceGrpDeployment = "deploy-vnetpeering"
$armTemplateFile       = "vnet-peering.json"
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"


$subscr=Get-AzureRmSubscription -SubscriptionName $subscriptionName
Select-AzureRmSubscription -SubscriptionId $subscr.Id

$runTime=Measure-Command {
New-AzureRmResourceGroup -Name $destResourceGrp -Location $location
write-host $templateFile
New-AzureRmResourceGroupDeployment  -Name $resourceGrpDeployment -ResourceGroupName $destResourceGrp -TemplateFile $templateFile -Verbose
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()