################# Input parameters #################
$adminUsername = 'ADMINISTRATOR_USERNAME'
$adminPassword = 'ADMINISTRATOR_PASSWORD'
$subscriptionName = 'Pathfinders'
$deploymentName = 'srxD8_v4'
$armTemplateFile = 'srx-D8ds_v4.json'

$location = 'westus2'   
$rgName = 'cyperf01'
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