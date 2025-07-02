## script to create vnets, VMs and VPN Gateways
################# Input parameters #################
$deploymentName = 'cata-deploy1'
$armTemplateFile = '01-catalyst.json'
$inputParams = 'init.json'
####################################################
$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"
$inputParamsFile = "$pathFiles\$inputParams"

try {
     $arrayParams = (Get-Content -Raw $inputParamsFile | ConvertFrom-Json)
     $subscriptionName = $arrayParams.subscriptionName
     $rgName = $arrayParams.rgName
     $location = $arrayParams.location
     $adminUsername = $arrayParams.adminUsername
     $adminPassword = $arrayParams.adminPassword
     $catalystName = $arrayParams.catalystName
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

# checking the values of variables from init-var.json
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }  else { Write-Host '  subscription name...: '$subscriptionName -ForegroundColor Yellow }
if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                      else { Write-Host '  resource group......: '$rgName -ForegroundColor Yellow }
if (!$location) { Write-Host 'variable $location is null' ; Exit }                  else { Write-Host '  location............: '$location -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }        else { Write-Host '  adminUsername.......: '$adminUsername -ForegroundColor Red }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }        else { Write-Host '  adminPassword.......: '$adminPassword -ForegroundColor Red } 
if (!$catalystName) { Write-Host 'variable $catalystName is null' ; Exit }          else { Write-Host '  catalystName........: '$catalystName -ForegroundColor Cyan } 


$parameters = @{
     "location"      = $location;
     "adminUsername" = $adminUsername;
     "adminPassword" = $adminPassword;
     "catalystName"  = $catalystName
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
Write-Host "$StartTime - ARM template:"$templateFile -ForegroundColor Yellow
New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime: $RunTime" -ForegroundColor Yellow

write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime -ForegroundColor Yellow
write-host "end time..: "$(Get-Date) -ForegroundColor Yellow