## script to create vnets, VMs and VPN Gateways
################# Input parameters #################
$deploymentName = 'deploy-gws'
$armTemplateFile = '01-gws.json'
$inputParams = 'init.json'
####################################################
$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"
$inputParamsFile = "$pathFiles\$inputParams"

try {
     $arrayParams = (Get-Content -Raw $inputParamsFile | ConvertFrom-Json)
     $subscriptionName = $arrayParams.subscriptionName
     $rgName = $arrayParams.rgName
     $location1 = $arrayParams.location1
     $location2 = $arrayParams.location2
     $gateway1Name = $arrayParams.gateway1Name
     $gateway2Name = $arrayParams.gateway2Name
     $adminUsername = $arrayParams.adminUsername
     $adminPassword = $arrayParams.adminPassword
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

# checking the values of variables from init.json
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }  else { Write-Host '  subscription name...: '$subscriptionName -ForegroundColor Yellow }
if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                      else { Write-Host '  resource group......: '$rgName -ForegroundColor Yellow }
if (!$location1) { Write-Host 'variable $location1 is null' ; Exit }                else { Write-Host '  location1...........: '$location1 -ForegroundColor Yellow }
if (!$location2) { Write-Host 'variable $location2 is null' ; Exit }                else { Write-Host '  location2...........: '$location2 -ForegroundColor Yellow }
if (!$gateway1Name) { Write-Host 'variable $gateway1Name is null' ; Exit }          else { Write-Host '  gateway1Name........: '$gateway1Name -ForegroundColor Cyan } 
if (!$gateway2Name) { Write-Host 'variable $gateway2Name is null' ; Exit }          else { Write-Host '  gateway2Name........: '$gateway2Name -ForegroundColor Cyan } 
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }        else { Write-Host '  adminUsername.......: '$adminUsername -ForegroundColor Red }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }        else { Write-Host '  adminPassword.......: '$adminPassword -ForegroundColor Red } 

$location= $location1
$parameters = @{
     "location1"     = $location1;
     "location2"     = $location2;
     "gateway1Name"  = $gateway1Name;
     "gateway2Name"  = $gateway2Name
     "adminUsername" = $adminUsername;
     "adminPassword" = $adminPassword
}

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating Resource Group' -ForegroundColor Cyan
Try {
     Get-AzResourceGroup -Name $rgName -ErrorAction Stop
     Write-Host 'Resource exists, skipping'
}
Catch { New-AzResourceGroup -Name $rgName -Location $location }


$StartTime = Get-Date
Write-Host "$StartTime - ARM template: "$templateFile -ForegroundColor Yellow
New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime -ForegroundColor Yellow
write-host "end time..: "$EndTime -ForegroundColor Yellow