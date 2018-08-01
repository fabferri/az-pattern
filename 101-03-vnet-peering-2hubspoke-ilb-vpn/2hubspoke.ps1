################# Input parameters #################
$subscriptionName      = "NAME_YOUR_AZURE_SUBSCRIPTION" 
$location              = "eastus"
$destResourceGrp       = "RG-vnetpeering01"
$resourceGrpDeployment = "deploy-vnetpeering"
$armTemplateFile       = "2hubspoke.json"
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