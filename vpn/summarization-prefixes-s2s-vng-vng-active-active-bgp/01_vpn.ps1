#
# Script to deploy the ARM template vpn.json using Azure CLI
#
# The value of variables:
#    subscriptionName: Azure subscription name
#    ResourceGroupName: Name of the Resource group 
#    location1: Azure region of the vnet1
#    location2: Azure region of the vnet2
# are collected from the file "init.json"
#
#
################# Input parameters #################
$deploymentName = 'gw-s2s-deployment'
$armTemplateFile = '01_vpn.json'
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
     $location1 = $arrayParams.location1
     $location2 = $arrayParams.location2
     $gateway1Name = $arrayParams.gateway1Name
     $gateway2Name = $arrayParams.gateway2Name
     $asnGtw1 = $arrayParams.asnGtw1
     $asnGtw2 = $arrayParams.asnGtw2
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
if (!$location1) { Write-Host 'variable $location1 is null' ; Exit }                 else { Write-Host '   location1.............: '$location1 -ForegroundColor Yellow }
if (!$location2) { Write-Host 'variable $location2 is null' ; Exit }                 else { Write-Host '   location2.............: '$location2 -ForegroundColor Yellow }
if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                       else { Write-Host '   resource group name...: '$rgName -ForegroundColor Yellow }
if (!$gateway1Name) { Write-Host 'variable $gateway1Name is null' ; Exit }           else { Write-Host '   gateway1 name.........: '$gateway1Name -ForegroundColor Yellow }
if (!$gateway2Name) { Write-Host 'variable $gateway2Name is null' ; Exit }           else { Write-Host '   gateway2 name.........: '$gateway2Name -ForegroundColor Yellow }
if (!$asnGtw1) { Write-Host 'variable $asnGtw1 is null' ; Exit }                     else { Write-Host '   ASN gateway1..........: '$asnGtw1 -ForegroundColor Yellow }
if (!$asnGtw2) { Write-Host 'variable $asnGtw2 is null' ; Exit }                     else { Write-Host '   ASN gateway2..........: '$asnGtw2 -ForegroundColor Yellow }

# Set subscription
try {
     az account set --subscription $subscriptionName
     if ($LASTEXITCODE -ne 0) { throw "az account set failed with exit code $LASTEXITCODE" }
}
catch {
     Write-Host 'error in setting subscription: '$subscriptionName -ForegroundColor Red
     Write-Host $_.Exception.Message -ForegroundColor Red
     Exit
}

# Create Resource Group
Write-Host (Get-Date)' - Creating Resource Group' -ForegroundColor Cyan
try {
     az group create --name $rgName --location $location
     if ($LASTEXITCODE -ne 0) { throw "az group create failed with exit code $LASTEXITCODE" }
}
catch {
     Write-Host 'error in creating resource group: '$rgName -ForegroundColor Red
     Write-Host $_.Exception.Message -ForegroundColor Red
     Exit
}

$StartTime = Get-Date
Write-Host (Get-Date)' - ARM template:' $templateFile -ForegroundColor Yellow
try {
     az deployment group create `
       --name $deploymentName `
       --resource-group $rgName `
       --template-file $templateFile `
       --parameters location1=$location1 location2=$location2 adminUsername=$adminUsername adminPassword=$adminPassword gateway1Name=$gateway1Name gateway2Name=$gateway2Name asnGtw1=$asnGtw1 asnGtw2=$asnGtw2 `
       --verbose
     if ($LASTEXITCODE -ne 0) { throw "az deployment failed with exit code $LASTEXITCODE" }
}
catch {
     Write-Host 'error in deploying ARM template: '$templateFile -ForegroundColor Red
     Write-Host $_.Exception.Message -ForegroundColor Red
     Exit
}

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime: $RunTime" -ForegroundColor Yellow

write-host "runtime...: "$RunTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime -ForegroundColor Yellow
write-host "end time..: "$(Get-Date) -ForegroundColor Yellow
