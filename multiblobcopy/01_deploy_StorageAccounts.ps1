#
# powershell script to create via ARM template the list of target storage accounts.
#
################# INPUT VARIABLES #################
$subscriptionName      = "AZURE_SUBSCRITIONNAME_TARGET_STORAGE_ACCOUNT"
$destResourceGrp       = "RESOURCE_GROUP_TARGET_STORAGE_ACCOUNT"
$resourceGrpDeployment = "NAME_RESOURCEGROUPDEPLOYMENT"
$location              = "northeurope"
####################################################
$pathFiles=Split-Path -Parent $PSCommandPath
$templateFile ="$pathFiles\CreateStorageAccountStandard.json"
$parametersFile = "$pathFiles\CreateStorageAccountStandard-parameters.json"


Get-AzureRmSubscription -SubscriptionName $subscriptionName | Select-AzureRmSubscription 
New-AzureRmResourceGroup -Name $destResourceGrp -Location $location
#Get-AzureRmResourceGroup

write-host $templateFile
write-host $parametersFile
New-AzureRmResourceGroupDeployment -Name $resourceGrpDeployment -ResourceGroupName $destResourceGrp -TemplateFile $templateFile -TemplateParameterFile  $parametersFile -Verbose 


