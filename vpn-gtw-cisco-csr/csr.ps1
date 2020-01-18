# powershell script to deploy the ARM template specified in the variable $armTemplateFile
#
# the ARM template makes the following actions:
#  - deploy a vnet
#  - deploy NSG
#  - deploy UDRs
#  - deploy Cisco CSR
#  - deploy a CentOs VM
#
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='username administrator VMs')]
    [string]$adminUsername = "ADMINISTRATOR_USERNAME",
 
    [Parameter(Mandatory = $false, HelpMessage='password administrator VMs')]
    [string]$adminPassword = "ADMINISTRATOR_PASSWORD"
    )

################# Input parameters #################
$subscriptionName      = "AzDev"     
$location              = "eastus"
$rgName                = "rg-csr"
$rgDeployment          = "deploy-vpn"
$armTemplateFile       = "csr.json"
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
write-host $templateFile
New-AzResourceGroupDeployment  -Name $rgDeployment -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()