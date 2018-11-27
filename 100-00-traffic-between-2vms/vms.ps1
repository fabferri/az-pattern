## Powershell script to deploy the Azure VNet and VMs.
##
## NOTE:
##   Before running the script set 
##   1. your Azure subscription name in the variable $subscriptionName
##   2. the anme of your Azure resource group in the variable $rgName
##
##   Run the script by command:
##
##  .\vms -adminUsername YOUR_USERNAME -adminPassword YOUR_PASSWORD
##
################# Input parameters #################
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True, ValueFromPipeline=$false, HelpMessage='username administrator VMs', Position=0)]
    [string]$adminUsername,
 
    [Parameter(Mandatory = $true, HelpMessage='password administrator VMs')]
    [string]$adminPassword
    )


####################### SET VARIABLES #################
$subscriptionName      = "Windows Azure MSDN - Visual Studio Ultimate"
$location              = "eastus"
$rgName                = "RG-VMs-01"
$resourceGrpDeployment = "basic-vms"
$armTemplateFile       = "vms.json"
#
$parameters=@{
              "adminUsername"= $adminUsername;
              "adminPassword"= $adminPassword
              }
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"


$subscr=Get-AzureRmSubscription -SubscriptionName $subscriptionName
Select-AzureRmSubscription -SubscriptionId $subscr.Id

$runTime=Measure-Command {
New-AzureRmResourceGroup -Name $rgName -Location $location
write-host $templateFile
New-AzureRmResourceGroupDeployment -Mode Incremental -Name $resourceGrpDeployment -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()