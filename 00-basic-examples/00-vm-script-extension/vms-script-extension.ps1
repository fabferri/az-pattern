## Powershell script to deploy the Azure VNet and VMs.
##
## NOTE:
##   Before running the script set 
##   1. your Azure subscription name in the variable $subscriptionName
##   2. the anme of your Azure resource group in the variable $rgName
##
##   Run the script by command:
##
##  .\vms-script-extension.ps1 -adminUsername ADMINISTRATOR_USERNAME -adminPassword ADMINISTRATOR_PASSWORD
##
## where:
##  ADMINISTRATOR_USERNAME: username of the administrator of Azure VMs
##  ADMINISTRATOR_PASSWORD: password of the administrator of Azure VMs
################# Input parameters #################
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false, ValueFromPipeline=$false, HelpMessage='username administrator VMs', Position=0)]
    [string]$adminUsername= "ADMINISTRATOR_USERNAME",
 
    [Parameter(Mandatory = $false, HelpMessage='password administrator VMs')]
    [string]$adminPassword ="ADMINISTRATOR_PASSWORD"
    )


####################### SET VARIABLES #################
$subscriptionName= "AzDev"
$location        = "eastus"
$rgName          = "rg-customscript"
$rgGrpDeployment = "script-extension"
$armTemplateFile = "vms-script-extension.json"
#
$parameters=@{
              "adminUsername"= $adminUsername;
              "adminPassword"= $adminPassword
              }
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -Tenant $subscr.TenantId

# Create Resource Group 
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Resource Group $rgName " -ForegroundColor Cyan
Try {$rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location  }

$runTime=Measure-Command {
  Write-Host (Get-Date)' - ' -NoNewline
  Write-host "ARM template:"$templateFile -ForegroundColor Yellow
  $output=New-AzResourceGroupDeployment -Name $rgGrpDeployment -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose
}
Write-Host (Get-Date)' - ' -NoNewline
write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()