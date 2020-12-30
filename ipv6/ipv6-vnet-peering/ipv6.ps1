# Powershell script to deploy a configuration with hub-spoke VNet
# the full configuration is described in the ARM template "ipv6.json"
#
#
# Note: 
#  Before running the script, set properly the value of following variables:
#  1. $adminUsername
#  2. $adminPassword
#  3. $subscriptionName: Azure subscription name
#  4. $location: name of Azure region where is stored the deployed configuration
# 
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='username administrator VMs')]
    [string]$adminUsername = "ADMIN_USERUSERNAME",
 
    [Parameter(Mandatory = $false, HelpMessage='password administrator VMs')]
    [string]$adminPassword = "ADMIN_PASSWORD"
    )

################# Input parameters #################
$subscriptionName      = "AzureDemo3"     
$location              = "northeurope"
$rgName                = "ipv6-1"
$rgDeployment          = "ipv6-depl"
$armTemplateFile       = "ipv6.json"
####################################################

$pathFiles          = Split-Path -Parent $PSCommandPath
$templateFile       = "$pathFiles\$armTemplateFile"
$templateParamsFile = "$pathFiles\$armParameterFile"
$parameters=@{
              "adminUsername"= $adminUsername;
              "adminPassword"= $adminPassword
              }

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$runTime=Measure-Command {
New-AzResourceGroup -Name $rgName -Location $location
write-host $templateFile
New-AzResourceGroupDeployment  -Name $rgDeployment -ResourceGroupName $rgName -TemplateFile $templateFile  -TemplateParameterObject $parameters  -Verbose
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()