# description: powershell script to deploy the ARM template
#
# Note: Before runnin the script, you should set the value of variables:
#  $adminUsername: administrator username
#  $adminPassword: administrator password
#  $subscriptionName: Azure subscription name
#  $rgName: resource group name
#  $mngIP: public management IP to connect to the VMs and CSRs in SSH
#
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='VMs administrator username')]
    [string]$adminUsername = "ADMINISTRATOR_USERNAME",
 
    [Parameter(Mandatory = $false, HelpMessage='VMs administrator password')]
    [string]$adminPassword = "ADMINISTRATOR_PASSWORD"
    )
################# Input parameters #################
$subscriptionName  = 'AzDev1'     
$location = 'uksouth'
$rgName = 'rs03'
$deploymentName = "vnets"
$armTemplateFile = "az-deployment.json"

$RGTagExpireDate = '4/30/2021'
$RGTagContact = 'user1@contoso.com'
$RGTagNinja = 'user1'
$RGTagUsage = 'spoke vnet with Route Server and hub vnets with nva'
$mngIP = "100.0.0.1"
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"
$parameters=@{
              "adminUsername"= $adminUsername;
              "adminPassword"= $adminPassword;
              "mngIP"= $mngIP
              }


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group 
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Resource Group $rgName " -ForegroundColor Cyan
Try {$rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location  }

# Add Tag Values to the Resource Group
Set-AzResourceGroup -Name $RGName -Tag @{Expires=$RGTagExpireDate; Contacts=$RGTagContact; Pathfinder=$RGTagNinja; Usage=$RGTagUsage} | Out-Null


$runTime=Measure-Command {

write-host "running ARM template:"$templateFile
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}

write-host -ForegroundColor Yellow "runtime: "$runTime.ToString()