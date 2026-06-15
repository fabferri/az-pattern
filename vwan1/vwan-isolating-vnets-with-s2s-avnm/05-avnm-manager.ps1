#
#  variables in init.json file:
#   $subscriptionName: Azure subscription name
#   $ResourceGroupName: resource group name
#   $hub1location: Azure region of hub1
#   $hub2location: Azure region of hub2
#   $hub1Name: name of the virtual hub1
#   $hub2Name: name of the virtual hub2
#
# Deploys the subscription-scoped ARM template net-mgr1-arm.json which creates:
#   1. Network Manager (net-mgr1) + 4 network groups
#   2. 4 HubAndSpoke connectivity configurations targeting vWAN connection policies
#   3. Azure Policy definitions + assignments (dynamic group membership via tags)
#   4. Deployment script that commits/activates the connectivity configurations
#
# NOTE: uses New-AzDeployment (subscription scope), NOT New-AzResourceGroupDeployment
#
# Run order in the project:
#   1. 01-vwan.ps1                -> vWAN, hubs, route tables, VNets (tagged)
#   2. 02-vpn.ps1                 -> VPN gateways on hub1 and hub2
#   3. 03-vwan-site.ps1           -> S2S VPN sites and connections
#   4. 04-avnm-conn-policies.ps1  -> AVNM connection policies on hub1 and hub2
#   5. 05-avnm-manager.ps1        <-- THIS script
#
################# Input parameters #################
$deploymentName  = 'avnm-manager'
$armTemplateFile = '05-avnm-manager.json'
$initFile        = 'init.json'
####################################################

$pathFiles     = Split-Path -Parent $PSCommandPath
$templateFile  = "$pathFiles\$armTemplateFile"

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
     $arrayParams      = (Get-Content -Raw $inputParamsFile | ConvertFrom-Json)
     $subscriptionName = $arrayParams.subscriptionName
     $ResourceGroupName = $arrayParams.ResourceGroupName
     $hub1location     = $arrayParams.hub1location
     $hub2location     = $arrayParams.hub2location
     $hub1Name         = $arrayParams.hub1Name
     $hub2Name         = $arrayParams.hub2Name
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

$rgName   = $ResourceGroupName
$location = $hub1location

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Login Check
Try {
     Write-Host 'Using Subscription: ' -NoNewline
     Write-Host $((Get-AzContext).Name) -ForegroundColor Green
}
Catch {
     Write-Warning 'You are not logged in dummy. Login and try again!'
     Return
}

# Resource Group — must exist before the nested RG-scoped deployments inside the template run
Write-Host "$(Get-Date) - creating Resource Group: "$rgName -ForegroundColor Cyan
Try {
     $rg = Get-AzResourceGroup -Name $rgName -ErrorAction Stop
     Write-Host "$(Get-Date) - Resource Group exists, skipping" -ForegroundColor Yellow
}
Catch {
     $rg = New-AzResourceGroup -Name $rgName -Location $location
     Write-Host "$(Get-Date) - Resource group created: "$rg.ResourceGroupName -ForegroundColor Green
     Set-AzResourceGroup -Name $rgName -Tag @{"owner" = "fabferri"; "Project" = "validation avnm+vWAN" }
}

# Check if Network Manager already exists
$networkManagerName = 'net-mgr1'
Write-Host "$(Get-Date) - checking Network Manager: $networkManagerName" -ForegroundColor Cyan
Try {
     $nm = Get-AzNetworkManager -ResourceGroupName $rgName -Name $networkManagerName -ErrorAction Stop
     Write-Host "$(Get-Date) - Network Manager '$networkManagerName' exists, deployment will update it (Incremental mode)" -ForegroundColor Yellow
}
Catch {
     Write-Host "$(Get-Date) - Network Manager '$networkManagerName' not found, it will be created" -ForegroundColor Green
}

# Template parameters — location and resourceGroupName are the only outer parameters;
# the 4 connection policy resource IDs use defaults derived from hub1Name/hub2Name
# in the template. Override them here only if your names differ.
$parameters = @{
     "location"          = $location
     "resourceGroupName" = $rgName
}

$startTime = Get-Date
Write-Host "$(Get-Date) - running ARM template: $templateFile" -ForegroundColor Cyan

# New-AzDeployment targets subscription scope (equivalent to 'az deployment sub create')
New-AzDeployment `
     -Name $deploymentName `
     -Location $location `
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
