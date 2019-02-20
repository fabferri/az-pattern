#
# Note:
#
#
# Run the script by command:
# .\scriptName -adminUsername YOUR_ADMIN_USERNAME -adminPassword YOUR_ADMIN_PASSWORD
#
#
################# Input parameters #################
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True, ValueFromPipeline=$false, HelpMessage='username administrator VMs', Position=0)]
    [string]$adminUsername,
 
    [Parameter(Mandatory = $true, HelpMessage='password administrator VMs', Position=1)]
    [string]$adminPassword
)

$subscriptionName      = "AzureDemo1"   
$location              = "eastus"
$rgName                = "ilb-01"
$rgDeployment          = "deploy-hub"
$armTemplateFile       = "ilb-ha.json"
####################################################
$parameters=@{
      "adminUsername"= $adminUsername;
      "adminPassword"= $adminPassword
}
$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"


$subscr=Get-AzureRmSubscription -SubscriptionName $subscriptionName
Select-AzureRmSubscription -SubscriptionId $subscr.Id

$runTime=Measure-Command {
New-AzureRmResourceGroup -Name $rgName -Location $location
write-host $templateFile
New-AzureRmResourceGroupDeployment  -Name $rgDeployment -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()