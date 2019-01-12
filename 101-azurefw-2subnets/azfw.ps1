################# Input parameters #################
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True, ValueFromPipeline=$false, HelpMessage='username administrator VMs', Position=0)]
    [string]$adminUsername,
 
    [Parameter(Mandatory = $true, HelpMessage='password administrator VMs', Position=1)]
    [string]$adminPassword
)
################################################
$subscriptionName      = "Windows Azure MSDN - Visual Studio Ultimate"
$location              = "eastus"
$destResourceGrp       = "Test-Firewall21"
$resourceGrpDeployment = "deploy-az-firewall"
$armTemplateFile       = "azfw.json"
####################################################
$parameters=@{
      "adminUsername" = $adminUsername;
      "adminPassword" = $adminPassword;
}
$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"


$subscr=Get-AzureRmSubscription -SubscriptionName $subscriptionName
Select-AzureRmSubscription -SubscriptionId $subscr.Id

$runTime=Measure-Command {
New-AzureRmResourceGroup -Name $destResourceGrp -Location $location
write-host $templateFile
New-AzureRmResourceGroupDeployment  -Name $resourceGrpDeployment -ResourceGroupName $destResourceGrp -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose
}

write-host -ForegroundColor Yellow -background Black "runtime: "$runTime.ToString()
