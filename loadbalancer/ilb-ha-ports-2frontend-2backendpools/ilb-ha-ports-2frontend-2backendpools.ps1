################# Input parameters #################
$subscriptionName      = "NAME_OF_YOUR_AZURE_SUBSCRIPTION"
$location              = "eastus"
$destResourceGrp       = "rg-ha-ports01"
$resourceGrpDeployment = "deploy-ilb"
$armTemplateFile       = "ilb-ha-ports-2frontend-2backendpools.json"
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