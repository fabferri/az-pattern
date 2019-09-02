# Powershell script to deploy a configuration with hub-spoke VNet
# the full configuration is described in the ARM template "ipv6-standaloneVM.json"
#
################# Input parameters #################
$subscriptionName      = "AzureDemo3"     
$location              = "uksouth"
$rgName                = "ipv6-standalone"
$rgDeployment          = "ipv6-depl"
$armTemplateFile       = "ipv6-standaloneVM.json"
$armParamsFile         = "ipv6-standaloneVM.parameters.json"
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"
$paramsFile     = "$pathFiles\$armParamsFile"

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$runTime=Measure-Command {
New-AzResourceGroup -Name $rgName -Location $location
write-host  "templatefile  : "$templateFile -ForegroundColor Cyan
write-host  "parametersfile: "$paramsFile -ForegroundColor Cyan
New-AzResourceGroupDeployment  -Name $rgDeployment -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterFile $paramsFile  -Verbose
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()