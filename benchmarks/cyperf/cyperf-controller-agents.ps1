# To connect to the controller/agents:
# ssh -i <file_SSH_privateKey> <ADMINISTRATOR_USERNAME>@<PUB_IP_CONTROLLER>
#
# 
################# Input parameters #################
$subscriptionName = 'Pathfinders'
$deploymentName = 'cyperf101'
$armTemplateFile = 'cyperf-controller-agents.json'
$armParametersFile = 'cyperf-controller-agents-parameters.json'
$location = 'westus2'
$rgName = 'cyperf01'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"
$parametersFile = "$pathFiles\$armParametersFile"

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group 
Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
Try {
  $rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
  Write-Host '  resource exists, skipping'
}
Catch { $rg = New-AzResourceGroup -Name $rgName  -Location $location }


$StartTime = Get-Date
write-host "$StartTime - running ARM template: $templateFile"
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterFile $parametersFile -Verbose 

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime: $RunTime" -ForegroundColor Yellow