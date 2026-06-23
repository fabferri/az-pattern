#
# Script to deploy the ARM template 02_deploy-vnets.json
# Creates spoke VNets (spoke-1 through spoke-6)
#
################# Input parameters #################
$deploymentName = 'deploy-spoke-vnets'
$armTemplateFile = '02_deploy-vnets.json'
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
     $spoke1 = $arrayParams.spoke1
     $spoke2 = $arrayParams.spoke2
     $spoke3 = $arrayParams.spoke3
     $spoke4 = $arrayParams.spoke4
     $spoke5 = $arrayParams.spoke5
     $spoke6 = $arrayParams.spoke6
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                       else { Write-Host '   resource group name...: '$rgName -ForegroundColor Yellow }
if (!$location) { Write-Host 'variable $location is null' ; Exit }                   else { Write-Host '   location..............: '$location -ForegroundColor Yellow }
if (!$spoke1) { Write-Host 'variable $spoke1 is null' ; Exit }                       else { Write-Host '   spoke1................: '$spoke1 -ForegroundColor Yellow }
if (!$spoke2) { Write-Host 'variable $spoke2 is null' ; Exit }                       else { Write-Host '   spoke2................: '$spoke2 -ForegroundColor Yellow }
if (!$spoke3) { Write-Host 'variable $spoke3 is null' ; Exit }                       else { Write-Host '   spoke3................: '$spoke3 -ForegroundColor Yellow }
if (!$spoke4) { Write-Host 'variable $spoke4 is null' ; Exit }                       else { Write-Host '   spoke4................: '$spoke4 -ForegroundColor Yellow }
if (!$spoke5) { Write-Host 'variable $spoke5 is null' ; Exit }                       else { Write-Host '   spoke5................: '$spoke5 -ForegroundColor Yellow }
if (!$spoke6) { Write-Host 'variable $spoke6 is null' ; Exit }                       else { Write-Host '   spoke6................: '$spoke6 -ForegroundColor Yellow }

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
       --parameters location=$location spoke1=$spoke1 spoke2=$spoke2 spoke3=$spoke3 spoke4=$spoke4 spoke5=$spoke5 spoke6=$spoke6 `
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
