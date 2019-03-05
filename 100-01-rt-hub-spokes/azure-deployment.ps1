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

$subscriptionName      = "Windows Azure MSDN - Visual Studio Ultimate"   
$location              = "eastus"
$rgName                = "vnet-test01"
$rgDeployment          = "deploy-hub-spokes"
$armTemplateFile       = "azure-deployment.json"
####################################################
$parameters=@{
      "adminUsername"= $adminUsername;
      "adminPassword"= $adminPassword
}
$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"


$ctx=Get-AzContext -Name $subscriptionName 
 
$runTime=Measure-Command {
New-AzResourceGroup -Name $rgName -Location $location
write-host $templateFile
New-AzResourceGroupDeployment -ResourceGroupName $rgName -Name $rgDeployment -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()