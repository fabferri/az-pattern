#
#  variables in init.json file:
#   $subscriptionName: Azure subscription name
#   $ResourceGroupName: resource group name
#   $hub1location: Azure region of hub1
#   $hub2location: Azure region of hub2
#   $hub1Name: name of the virtual hub1
#   $hub2Name: name of the virtual hub2
#
# Run order in the project:
#   1. 01-vwan.ps1          -> vWAN, hubs, route tables, VNets (hub connections disabled)
#   2. 02-vpn.ps1           -> VPN gateways on hub1 and hub2
#   3. 03-vwan-site.ps1     -> S2S VPN sites and connections
#   4. 04-avnm-conn-policies.ps1  <-- THIS script
#   5. 05-avnm-manager.ps1        -> AVNM + network groups + connectivity configs + commit
#
################# Input parameters #################
$deploymentName  = 'avnm-conn-policies'
$armTemplateFile = '04-avnm-conn-policies.json'
$initFile        = 'init.json'
####################################################

$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplateFile"

$inputParamsFile = if ([System.IO.Path]::IsPathRooted($initFile)) {
     $initFile
}
else {
     Join-Path $pathFiles $initFile
}

if (-not (Test-Path -Path $inputParamsFile -PathType Leaf)) {
     Write-Host 'parameters file not found: '$inputParamsFile -ForegroundColor Yellow
     Exit 1
}

$inputParams = Split-Path -Leaf $inputParamsFile

try {
     $arrayParams    = (Get-Content -Raw $inputParamsFile | ConvertFrom-Json)
     $subscriptionName = $arrayParams.subscriptionName
     $ResourceGroupName = $arrayParams.ResourceGroupName
     $hub1location   = $arrayParams.hub1location
     $hub2location   = $arrayParams.hub2location
     $hub1Name       = $arrayParams.hub1Name
     $hub2Name       = $arrayParams.hub2Name
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName)  { Write-Host 'variable $subscriptionName is null'  ; Exit } else { Write-Host '   subscription name......: '$subscriptionName  -ForegroundColor Yellow }
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit } else { Write-Host '   resource group name....: '$ResourceGroupName -ForegroundColor Yellow }
if (!$hub1location)      { Write-Host 'variable $hub1location is null'      ; Exit } else { Write-Host '   hub1 location..........: '$hub1location      -ForegroundColor Yellow }
if (!$hub2location)      { Write-Host 'variable $hub2location is null'      ; Exit } else { Write-Host '   hub2 location..........: '$hub2location      -ForegroundColor Yellow }
if (!$hub1Name)          { Write-Host 'variable $hub1Name is null'          ; Exit } else { Write-Host '   hub1 name..............: '$hub1Name          -ForegroundColor Yellow }
if (!$hub2Name)          { Write-Host 'variable $hub2Name is null'          ; Exit } else { Write-Host '   hub2 name..............: '$hub2Name          -ForegroundColor Yellow }

$rgName = $ResourceGroupName

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Login Check
Try {
     Write-Host 'Using Subscription: ' -NoNewline
     Write-Host $((Get-AzContext).Name) -ForegroundColor Green
}
Catch {
     Write-Warning 'You are not logged in. Login and try again!'
     Return
}

$parameters = @{
     "hub1location" = $hub1location
     "hub2location" = $hub2location
     "hub1Name"     = $hub1Name
     "hub2Name"     = $hub2Name
}

$startTime = Get-Date
Write-Host "$(Get-Date) - running ARM template: $templateFile" -ForegroundColor Cyan
New-AzResourceGroupDeployment `
     -Name $deploymentName `
     -ResourceGroupName $rgName `
     -TemplateFile $templateFile `
     -TemplateParameterObject $parameters `
     -Verbose

Write-Host "$(Get-Date) - setup completed" -ForegroundColor Green
$endTime  = Get-Date
$timeDiff = New-TimeSpan $startTime $endTime
$mins = $timeDiff.Minutes
$secs = $timeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $mins, $secs
Write-Host "$(Get-Date) - Script completed" -ForegroundColor Green
Write-Host "Time to complete: "$runTime -ForegroundColor Green
