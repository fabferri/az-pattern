# Powershell script to deploy a configuration with hub-spoke VNet
# the full configuration is described in the ARM template "ipv6-standaloneVM.json"
#
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'username administrator VMs')]
    [string]$adminUsername = "ADMINISTRATOR_USERNAME",
 
    [Parameter(Mandatory = $false, HelpMessage = 'password administrator VMs')]
    [string]$adminPassword = "ADMINISTRATOR_PASSWORD"
)
#
################# Input parameters #################
$subscriptionName      = "AzureDev"     
$location              = "uksouth"
$rgName                = "ipv6-02"
$rgDeployment          = "ipv6-depl"
$armTemplateFile       = "single-vm.json"
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"

$parameters=@{
              "adminUsername"= $adminUsername;
              "adminPassword"= $adminPassword
              }

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$runTime=Measure-Command {
New-AzResourceGroup -Name $rgName -Location $location
write-host  "templatefile  : "$templateFile -ForegroundColor Cyan
New-AzResourceGroupDeployment  -Name $rgDeployment -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters  -Verbose
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()