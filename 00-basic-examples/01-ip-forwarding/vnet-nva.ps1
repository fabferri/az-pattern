## NOTE:
##   Before running the script set 
##   1. your Azure subscription name in the variable $subscriptionName
##   2. the anme of your Azure resource group in the variable $rgName
##
##   Run the script by command:
##
##   .\vnet-nva.ps1 -adminUsername YOUR_USERNAME -adminPassword YOUR_PASSWORD
##
## where:
##   YOUR_USERNAME: username of the adminsitrator of Azure VMs
##   YOUR_PASSWORD: password of the administrator of Azure VMs
################# Input parameters #################
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True, ValueFromPipeline=$false, HelpMessage='username administrator VMs', Position=0)]
    [string]$adminUsername,
 
    [Parameter(Mandatory = $true, HelpMessage='password administrator VMs')]
    [string]$adminPassword
    )
################# Input parameters #################
$subscriptionName      = "Windows Azure MSDN - Visual Studio Ultimate"
$location              = "eastus"
$destResourceGrp       = "rg-nva01"
$resourceGrpDeployment = "deploy-nva"
$armTemplateFile       = "vnet-nva.json"
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"
$parameters=@{
              "adminUsername"= $adminUsername;
              "adminPassword"= $adminPassword
              }

$subscr=Get-AzureRmSubscription -SubscriptionName $subscriptionName
Select-AzureRmSubscription -SubscriptionId $subscr.Id

$runTime=Measure-Command {
New-AzureRmResourceGroup -Name $destResourceGrp -Location $location
write-host $templateFile
New-AzureRmResourceGroupDeployment  -Name $resourceGrpDeployment -ResourceGroupName $destResourceGrp -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()