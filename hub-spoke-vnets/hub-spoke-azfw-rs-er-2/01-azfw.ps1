################# Input parameters #################
$deploymentName = 'test-hubspoke'
$armTemplateFile = '01-azfw.json'
$inputParams = 'init.json'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"
$parametersFile = "$pathFiles\$inputParams"

try {
  $arrayParams = (Get-Content -Raw $parametersFile | ConvertFrom-Json)
  $subscriptionName = $arrayParams.subscriptionName
  $resourceGroupName = $arrayParams.resourceGroupName
  $location = $arrayParams.location
  $locationhub1 = $arrayParams.locationhub1
  $locationhub2 = $arrayParams.locationhub2
  $locationspoke1 = $arrayParams.locationspoke1
  $locationspoke2 = $arrayParams.locationspoke2
  $locationspoke3 = $arrayParams.locationspoke3
  $locationspoke4 = $arrayParams.locationspoke4
  $adminUsername = $arrayParams.adminUsername
  $authenticationType = $arrayParams.authenticationType
  $adminPasswordOrKey = $arrayParams.adminPasswordOrKey
  $er_subscriptionId1 = $arrayParams.er_subscriptionId1
  $er_resourceGroup1 = $arrayParams.er_resourceGroup1
  $er_circuitName1 = $arrayParams.er_circuitName1
  $er_authorizationKey1 = $arrayParams.er_authorizationKey1
  

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }     else { Write-Host '  subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit }   else { Write-Host '  resource group name...: '$ResourceGroupName -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }           else { Write-Host '  admin username........: '$adminUsername -ForegroundColor Green }
if (!$authenticationType) { Write-Host 'variable $authenticationType is null' ; Exit } else { Write-Host '  authentication type...: '$authenticationType -ForegroundColor Green }
if (!$adminPasswordOrKey) { Write-Host 'variable $adminPasswordOrKey is null' ; Exit } else { Write-Host '  admin password/key....: '$adminPasswordOrKey -ForegroundColor Green }
if (!$locationhub1) { Write-Host 'variable $locationhub1 is null' ; Exit }             else { Write-Host '  locationhub1..........: '$locationhub1 -ForegroundColor Yellow }
if (!$locationspoke1) { Write-Host 'variable $locationspoke1 is null' ; Exit }         else { Write-Host '  locationspoke1........: '$locationspoke1 -ForegroundColor Yellow }
if (!$locationspoke2) { Write-Host 'variable $locationspoke2 is null' ; Exit }         else { Write-Host '  locationspoke2........: '$locationspoke2 -ForegroundColor Yellow }
if (!$locationhub2) { Write-Host 'variable $locationhub2 is null' ; Exit }             else { Write-Host '  locationhub2..........: '$locationhub2 -ForegroundColor Yellow }
if (!$locationspoke3) { Write-Host 'variable $locationspoke3 is null' ; Exit }         else { Write-Host '  locationspoke3........: '$locationspoke3 -ForegroundColor Yellow }
if (!$locationspoke4) { Write-Host 'variable $locationspoke4 is null' ; Exit }         else { Write-Host '  locationspoke4........: '$locationspoke4 -ForegroundColor Yellow }
if (!$er_subscriptionId1) { Write-Host 'variable$er_subscriptionId1 is null' ; Exit }        else { Write-Host '  er_subscriptionId1....: '$er_subscriptionId1 -ForegroundColor Green }
if (!$er_resourceGroup1) { Write-Host 'variable $er_resourceGroup1 is null' ; Exit }         else { Write-Host '  er_resourceGroup1.....: '$er_resourceGroup1 -ForegroundColor Green }
if (!$er_circuitName1 ) { Write-Host 'variable $er_circuitName1  is null' ; Exit }           else { Write-Host '  er_circuitName1 ......: '$er_circuitName1 -ForegroundColor Green }
if (!$er_authorizationKey1) { Write-Host 'variable $er_authorizationKey1  is null' ; Exit }  else { Write-Host '  er_authorizationKey1..: '$er_authorizationKey1 -ForegroundColor Green }
}
catch {
  Write-Host 'error in reading the template file: '$parametersFile -ForegroundColor Yellow
  Exit
}


$rgName = $ResourceGroupName
$location = $locationhub1

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$parameters = @{
  "adminUsername"      = $adminUsername;
  "authenticationType" = $authenticationType;
  "adminPasswordOrKey" = $adminPasswordOrKey;
  "locationhub1"       = $locationhub1;
  "locationspoke1"     = $locationspoke1;
  "locationspoke2"     = $locationspoke2;
  "locationhub2"       = $locationhub2;
  "locationspoke3"     = $locationspoke3;
  "locationspoke4"     = $locationspoke4
}


# Create Resource Group 
Write-Host "$(Get-Date) - Creating Resource Group $rgName " -ForegroundColor Cyan
Try {
  $rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
  Write-Host '  resource exists, skipping'
}
Catch { $rg = New-AzResourceGroup -Name $rgName  -Location $location }


$StartTime = Get-Date
write-host "$StartTime - running ARM template: $templateFile"
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime: $RunTime" -ForegroundColor Yellow