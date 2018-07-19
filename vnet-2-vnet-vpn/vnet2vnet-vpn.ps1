################# Input parameters #################
$subscriptionName      = "AzureDemo2"  ## "Windows Azure MSDN - Visual Studio Ultimate" 
$location              = "northeurope"
$destResourceGrp       = "RG-VPN103"
$resourceGrpDeployment = "deployVNets"
$armTemplateFile       = "vnet2vnet-vpn.json"
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