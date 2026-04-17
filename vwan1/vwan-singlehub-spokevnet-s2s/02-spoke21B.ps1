#
#  variables in init.json file:
#   $subscriptionName: Azure subscription name
#   $ResourceGroupName: resource group name
#   $hub1location: Azure region to deploy the virtual hub1
#   $branch1location: Azure region to deploy the branch1
#   $hub1Name: name of the virtual hub1
#   $sharedKey: share secret of the site-to-site VPN between the branch and the hub1
#   $mngIP: management public IP to connect in SSH to the Azure VMs
#   $adminUsername: administrator username
#   $adminPassword: administrator password
#   $mngIP: public IP to filter inbound SSH connection to the VM. it can be empty if you do not want to set a restriction.
#
################# Input parameters #################
$deploymentName = 'spoke21B'
$armTemplateFile = '02-spoke21B.json'
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
     $rgSpoke21 = $arrayParams.rgSpoke21
     $spoke21location = $arrayParams.spoke21location
     $adminUsername = $arrayParams.adminUsername
     $adminPassword = $arrayParams.adminPassword 
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }         else { Write-Host '   administrator username: '$adminUsername -ForegroundColor Green }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }         else { Write-Host '   administrator password: '$adminPassword -ForegroundColor Green }
if (!$location) { Write-Host 'variable $location is null' ; Exit }                   else { Write-Host '   location..............: '$location -ForegroundColor Yellow }
if (!$spoke21location) { Write-Host 'variable $spoke21location is null' ; Exit }     else { Write-Host '   spoke21 location......: '$spoke21location -ForegroundColor Yellow }
if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                       else { Write-Host '   resource group name...: '$rgName -ForegroundColor Yellow }
if (!$rgSpoke21) { Write-Host 'variable $rgSpoke21 is null' ; Exit }                 else { Write-Host '   spoke21 resource group: '$rgSpoke21 -ForegroundColor Yellow }



$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id



$parameters = @{
     "location"      = $spoke21location;
     "adminUsername" = $adminUsername;
     "adminPassword" = $adminPassword;
     
}


# Create Resource Group
Write-Host "$(Get-Date) - creating Resource Group: "$rgSpoke21 -ForegroundColor Cyan
Try {
     $rg = Get-AzResourceGroup -Name $rgSpoke21 -ErrorAction Stop
     Write-Host 'Resource exists, skipping'
}
Catch { 
     $rg = New-AzResourceGroup -Name $rgSpoke21 -Location $spoke21location 
     Write-Host 'Resource group created' -ForegroundColor Green
     # Set tag on the resource group
     Set-AzResourceGroup -Name $rgSpoke21 -Tag @{"PM owner"="fabferri"; "Project" = "vWAN validation"}
}

$startTime = Get-Date
write-host "$(Get-Date) - running ARM template:"$templateFile
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgSpoke21 -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

Write-Host "$(Get-Date) - setup completed" -ForegroundColor Green
$endTime = Get-Date
$timeDiff = New-TimeSpan $startTime $endTime
$mins = $timeDiff.Minutes
$secs = $timeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $mins, $secs
Write-Host "$(Get-Date) - Script completed" -ForegroundColor Green
Write-Host "Time to complete: "$runTime







