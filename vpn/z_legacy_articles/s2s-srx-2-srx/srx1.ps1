# Script to deploy the site1:  
#
# Run the script by command:
# .\scriptName -adminUsername YOUR_ADMIN_USERNAME -adminPassword YOUR_ADMIN_PASSWORD
#
#
################# Input parameters #################

[CmdletBinding()]
param (
    [Parameter(Mandatory=$True, ValueFromPipeline=$false, HelpMessage='administrator username ', Position=0)]
    [string]$adminUsername,
 
    [Parameter(Mandatory = $true, HelpMessage='administrator password', Position=1)]
    [string]$adminPassword
)


$subscriptionName    = "AzDev"   
$location            = "eastus"
$rgName              = "srx-01"
$rgDeployment        = "deploy-srx1"
$armTemplateFile     = "srx1.json"
####################################################

$parameters=@{
      "adminUsername"= $adminUsername;
      "adminPassword"= $adminPassword
}


$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"

$s=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -Subscription $s
 
$runTime=Measure-Command {
New-AzResourceGroup -Name $rgName -Location $location
write-host $templateFile
New-AzResourceGroupDeployment -ResourceGroupName $rgName -Name $rgDeployment -TemplateFile $templateFile -TemplateParameterObject $parameters  -Verbose
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()