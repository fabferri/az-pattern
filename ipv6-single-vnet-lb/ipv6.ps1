# Before running the script:
# replace USERNAME_ADMINISTRATOR_VMs with the Administrator username
# replace PASSWORD_ADMINISTRATOR_VMs with the Administrator password
# OR
# run the script with:
# .\ipv6.ps1 -adminUsername USERNAME_ADMINISTRATOR_VMs -adminPassword PASSWORD_ADMINISTRATOR_VMs
#
#
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='username administrator VMs')]
    [string]$adminUsername = "USERNAME_ADMINISTRATOR_VMs",
 
    [Parameter(Mandatory = $false, HelpMessage='password administrator VMs')]
    [string]$adminPassword = "PASSWORD_ADMINISTRATOR_VMs"
    )

################# Input parameters #################
$subscriptionName      = "AzureDemo3"     
$location              = "uksouth" # "eastus"
$rgName                = "ipv6-03"
$rgDeployment          = "deppppipv6"
$armTemplateFile       = "ipv6.json"
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