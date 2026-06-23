#
# Script to deploy the ARM template hub-nosummarization.json
#
################# Input parameters #################
$deploymentName = 'hub-no_summarization'
$armTemplateFile = 'hub-no_summarization.json'
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
if (!$location1) { Write-Host 'variable $location1 is null' ; Exit }                 else { Write-Host '   location1.............: '$location1 -ForegroundColor Yellow }
if (!$location2) { Write-Host 'variable $location2 is null' ; Exit }                 else { Write-Host '   location2.............: '$location2 -ForegroundColor Yellow }


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

# Check Resource Group exists
Write-Host (Get-Date)' - getting Resource Group' -ForegroundColor Cyan
$rgExists = az group exists --name $rgName
if ($rgExists -eq 'false') {
     Write-Host (Get-Date)' - Resource Group: '$rgName' does not exist' -ForegroundColor Yellow
     Exit
}
Write-Host (Get-Date)' - Resource Group exists, continuing' -ForegroundColor Cyan

$StartTime = Get-Date
Write-Host (Get-Date)' - ARM template:' $templateFile -ForegroundColor Yellow
Write-Host (Get-Date)' - Remove the summarization' -ForegroundColor Cyan

try {
     az deployment group create `
       --name $deploymentName `
       --resource-group $rgName `
       --template-file $templateFile `
       --parameters location1=$location1  `
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