# INPUT VARIABLES:
#   $adminUsername: adminsitrator username of the vSRX and VMs
#   $adminPassword: administrator password of the vSRX and VMs
#   $subscriptionName: subscription name
#   $deploymentName: deployment name
#   $armTemplateFile: ARM template file name
#   $location: Azure region
#   $rgName: resource group name
#
### Before running, replace the value of ADMINISTRATOR_USERNAME and ADMINISTRATOR_PASSWORD with 
### your administrator username and administrator password
###
################# Input parameters #################
$adminUsername = 'ADMINISTRATOR_USERNAME'
$adminPassword = 'ADMINISTRATOR_PASSWORD'
$subscriptionName = 'AzDev'
$deploymentName = 'srx101'
$armTemplateFile = 'srx.json'

$location = "westus2"   
$rgName = 'test-srx'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"


$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group 
Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
Try {
  $rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
  Write-Host '  resource exists, skipping'
}
Catch { $rg = New-AzResourceGroup -Name $rgName  -Location $location }

$parameters = @{
  "adminUsername"      = $adminUsername;
  "adminPassword"      = $adminPassword;
  "location"           = $location
}

$StartTime = Get-Date
write-host "$StartTime - running ARM template: $templateFile"
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 


$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime: $RunTime" -ForegroundColor Yellow