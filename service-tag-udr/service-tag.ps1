# The script deploye a VNet, Azure VMs and UDRs
#
# Variables:
#   $subscriptionName: name of the Azure subscription
#   $location: name of the Azure region
#   $adminUsername: Administrator username of the Azure VMs
#   $adminPassword: administrator password of the Azure VMs
#   $mngIP: it is the management IP set in NSG to access to the VMs in SSH and RDP
#
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='VMs administrator username')]
    [string]$adminUsername = 'ADMINISTRATOR_USERNAME',
 
    [Parameter(Mandatory = $false, HelpMessage='SSH public key')]
    [string]$adminPassword = 'ADMINISTRATOR_PASSWORD'
    )
################# Input parameters #################
$mngIP = 'MANAGEMENT_IP/32'
$subscriptionName = 'Pathfinders'
$location = 'eastus2'   
$rgName = 'fab-servicetag2'
$deploymentName = 'tag'
$armTemplateFile = 'service-tag.json'
#
#
$RGTagExpireDate = '7/29/2021'
$RGTagContact = 'user1@contoso.com'
$RGTagNinja = 'user1'
$RGTagUsage = 'testing UDR tag'
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"



$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$parameters=@{
              "mngIP" = $mngIP
              "adminUsername"= $adminUsername;
              "adminPassword"= $adminPassword;
              "location"= $location
              }


# Create Resource Group 
Write-Host "$(Get-Date) - check Resource Group $rgName " -ForegroundColor Cyan
Try {
     $rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host '  resource exists, skipping'
     }
Catch {
       Write-Host "$(Get-Date) - create Resource Group $rgName " -ForegroundColor Cyan
       $rg = New-AzResourceGroup -Name $rgName  -Location $location  
       }

# set a tag on the resource group if it doesn't exist.
if ((Get-AzResourceGroup -Name $rgName).Tags -eq $null)
{
  # Add Tag Values to the Resource Group
  Set-AzResourceGroup -Name $rgName -Tag @{Expires=$RGTagExpireDate; Contacts=$RGTagContact; Pathfinder=$RGTagNinja; Usage=$RGTagUsage} | Out-Null
}

$startTime = "$(Get-Date)"
$runTime=Measure-Command {
   write-host "running ARM template:"$templateFile
   New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}
 
write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime -ForegroundColor Yellow
write-host "endt time.: "$(Get-Date) -ForegroundColor Yellow