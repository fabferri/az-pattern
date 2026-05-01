#
#  variables in init.json file:
#   $subscriptionName: Azure subscription name
#   $rgSpoke22: resource group name for spoke22
#   $rgSpoke22B: resource group name for spoke22B
#   $spoke22location: Azure region for spoke22 resources
#   $spoke22Blocation: Azure region for spoke22B resources
#   $spoke22vnetName: name of the parent spoke22 virtual network
#   $spoke22AddressPrefix: address prefix for the parent spoke22 virtual network
#   $spoke22BvnetName: name of the spoke22B virtual network
#   $spoke22BAddressPrefix: address prefix for the spoke22B virtual network
#   $spoke22BsubnetWLName: workload subnet name in spoke22B
#   $spoke22BsubnetWLPrefix: workload subnet address prefix in spoke22B
#   $WL22B-1: workload VM name in spoke22B
#   $WL22B_1_privIP: private IP for WL22B-1
#   $spoke22BrtSubnetWLName: route table name for spoke22B workload subnet
#   $spoke22BrtEntryNameMajorNet: route entry name toward the major network
#   $spoke22BrtEntryNameParentSpoke: route entry name toward parent spoke22
#   $spoke22lbFrontEndIP: frontend IP of the spoke22 load balancer used as next hop
#   $vnetpeeringName22Bto22: peering name from spoke22B to spoke22
#   $vnetpeeringName22to22B: peering name from spoke22 to spoke22B
#   $adminUsername: administrator username
#   $adminPassword: administrator password
#
################# Input parameters #################
param(
     [string]$initFile = 'init.json'
)
$deploymentName = (Get-Item $PSCommandPath).BaseName
$armTemplateFile = '02-spoke22B.json'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"
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
     $arrayParams = (Get-Content -Raw $inputParamsFile | ConvertFrom-Json)
     $subscriptionName = $arrayParams.subscriptionName
     $rgSpoke22 = $arrayParams.rgSpoke22
     $rgSpoke22B = $arrayParams.rgSpoke22B
     $spoke22location = $arrayParams.spoke22location
     $spoke22Blocation = $arrayParams.spoke22Blocation
     $spoke22vnetName = $arrayParams.spoke22vnetName
     $spoke22AddressPrefix = $arrayParams.spoke22AddressPrefix
     $spoke22BAddressPrefix = $arrayParams.spoke22BAddressPrefix
     $spoke22lbFrontEndIP = $arrayParams.spoke22lbFrontEndIP
     $vnetpeeringName22Bto22 = $arrayParams.vnetpeeringName22Bto22
     $vnetpeeringName22to22B = $arrayParams.vnetpeeringName22to22B
     $spoke22BvnetName = $arrayParams.spoke22BvnetName
     $spoke22BsubnetWLName = $arrayParams.spoke22BsubnetWLName
     $spoke22BsubnetWLPrefix = $arrayParams.spoke22BsubnetWLPrefix
     $WL22B_1_Name = $arrayParams.'WL22B-1'
     $WL22B_1_privIP = $arrayParams.WL22B_1_privIP
     $spoke22BrtSubnetWLName = $arrayParams.spoke22BrtSubnetWLName
     $spoke22BrtEntryNameMajorNet = $arrayParams.spoke22BrtEntryNameMajorNet
     $spoke22BrtEntryNameParentSpoke = $arrayParams.spoke22BrtEntryNameParentSpoke
     $adminUsername = $arrayParams.adminUsername
     $adminPassword = $arrayParams.adminPassword 
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }             else { Write-Host '   subscription name......: '$subscriptionName -ForegroundColor Yellow }
if (!$rgSpoke22B) { Write-Host 'variable $rgSpoke22B is null' ; Exit }                         else { Write-Host '   spoke22B resource group: '$rgSpoke22B -ForegroundColor Yellow }
if (!$spoke22Blocation) { Write-Host 'variable $spoke22Blocation is null' ; Exit }             else { Write-Host '   spoke22B location......: '$spoke22Blocation -ForegroundColor Yellow }
if (!$spoke22vnetName) { Write-Host 'variable $spoke22vnetName is null' ; Exit }               else { Write-Host '   spoke22 VNet name......: '$spoke22vnetName -ForegroundColor Yellow }
if (!$spoke22AddressPrefix) { Write-Host 'variable $spoke22AddressPrefix is null' ; Exit }     else { Write-Host '   spoke22 prefix.........: '$spoke22AddressPrefix -ForegroundColor Yellow }
if (!$spoke22BvnetName) { Write-Host 'variable $spoke22BvnetName is null' ; Exit }             else { Write-Host '   spoke22B VNet name.....: '$spoke22BvnetName -ForegroundColor Yellow }
if (!$spoke22BAddressPrefix) { Write-Host 'variable $spoke22BAddressPrefix is null' ; Exit }   else { Write-Host '   spoke22B prefix........: '$spoke22BAddressPrefix -ForegroundColor Yellow }
if (!$spoke22BsubnetWLName) { Write-Host 'variable $spoke22BsubnetWLName is null' ; Exit }     else { Write-Host '   spoke22B subnet name...: '$spoke22BsubnetWLName -ForegroundColor Yellow }
if (!$spoke22BsubnetWLPrefix) { Write-Host 'variable $spoke22BsubnetWLPrefix is null' ; Exit } else { Write-Host '   spoke22B subnet prefix.: '$spoke22BsubnetWLPrefix -ForegroundColor Yellow }
if (!$WL22B_1_Name) { Write-Host "variable 'WL22B-1' is null" ; Exit }                         else { Write-Host '   VM name WL22B-1........: '$WL22B_1_Name -ForegroundColor Yellow }
if (!$WL22B_1_privIP) { Write-Host 'variable $WL22B_1_privIP is null' ; Exit }                 else { Write-Host '   WL22B-1 private IP.....: '$WL22B_1_privIP -ForegroundColor Yellow }
if (!$spoke22BrtSubnetWLName) { Write-Host 'variable $spoke22BrtSubnetWLName is null' ; Exit } else { Write-Host '   route table name.......: '$spoke22BrtSubnetWLName -ForegroundColor Yellow }
if (!$spoke22BrtEntryNameMajorNet) { Write-Host 'variable $spoke22BrtEntryNameMajorNet is null' ; Exit }       else { Write-Host '   major net route........: '$spoke22BrtEntryNameMajorNet -ForegroundColor Yellow }
if (!$spoke22BrtEntryNameParentSpoke) { Write-Host 'variable $spoke22BrtEntryNameParentSpoke is null' ; Exit } else { Write-Host '   parent spoke route.....: '$spoke22BrtEntryNameParentSpoke -ForegroundColor Yellow }
if (!$spoke22lbFrontEndIP) { Write-Host 'variable $spoke22lbFrontEndIP is null' ; Exit }       else { Write-Host '   spoke22 LB frontend IP.: '$spoke22lbFrontEndIP -ForegroundColor Yellow }
if (!$vnetpeeringName22Bto22) { Write-Host 'variable $vnetpeeringName22Bto22 is null' ; Exit } else { Write-Host '   peering 22B to 22......: '$vnetpeeringName22Bto22 -ForegroundColor Yellow }
if (!$vnetpeeringName22to22B) { Write-Host 'variable $vnetpeeringName22to22B is null' ; Exit } else { Write-Host '   peering 22 to 22B......: '$vnetpeeringName22to22B -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }                   else { Write-Host '   administrator username.: '$adminUsername -ForegroundColor Green }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }                   else { Write-Host '   administrator password.: '$adminPassword -ForegroundColor Green }


$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$parameters = @{
     "location"                    = $spoke22Blocation;
     "spoke22BvnetName"            = $spoke22BvnetName;
     "spoke22BAddressPrefix"       = $spoke22BAddressPrefix;
     "spoke22BsubnetWLName"        = $spoke22BsubnetWLName;
     "spoke22BsubnetWLPrefix"      = $spoke22BsubnetWLPrefix;
     "WL22B-1"                     = $WL22B_1_Name;
     "WL22B_1_privIP"              = $WL22B_1_privIP;
     "spoke22BrtSubnetWLName"      = $spoke22BrtSubnetWLName;
     "spoke22BrtEntryNameMajorNet" = $spoke22BrtEntryNameMajorNet;
     "spoke22BrtEntryNameParentSpoke" = $spoke22BrtEntryNameParentSpoke;
     "spoke22lbFrontEndIP"         = $spoke22lbFrontEndIP;
     "spoke22vnetName"             = $spoke22vnetName;
     "spoke22AddressPrefix"        = $spoke22AddressPrefix;
     "rgSpoke22"                   = $rgSpoke22;
     "vnetpeeringName22Bto22"      = $vnetpeeringName22Bto22;
     "vnetpeeringName22to22B"      = $vnetpeeringName22to22B;
     "adminUsername"               = $adminUsername;
     "adminPassword"               = $adminPassword
}


# Create Resource Group
Write-Host "$(Get-Date) - creating Resource Group: "$rgSpoke22B -ForegroundColor Cyan
Try {
     Get-AzResourceGroup -Name $rgSpoke22B -ErrorAction Stop
     Write-Host 'Resource exists, skipping' -ForegroundColor Yellow
}
Catch { 
     New-AzResourceGroup -Name $rgSpoke22B -Location $spoke22Blocation 
     Write-Host 'Resource group created' -ForegroundColor Green
     # Set tag on the resource group
     Set-AzResourceGroup -Name $rgSpoke22B -Tag @{"PM owner"="fabferri"; "Project" = "vWAN validation"}
}

# The child spoke deployment creates peering to the parent spoke VNet.
# Validate that the parent VNet exists before running the ARM deployment.
$parentVnet = Get-AzVirtualNetwork -ResourceGroupName $rgSpoke22 -Name $spoke22vnetName -ErrorAction SilentlyContinue
if (-not $parentVnet) {
     Write-Host "$(Get-Date) - parent VNet '$spoke22vnetName' was not found in resource group '$rgSpoke22'." -ForegroundColor Red
     Write-Host "Deploy the parent spoke first (for example: .\01-spoke22.ps1 -initFile $inputParams) and then rerun this script." -ForegroundColor Yellow
     Exit 1
}

$startTime = Get-Date
write-host "$(Get-Date) - running ARM template:"$templateFile -ForegroundColor Cyan
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgSpoke22B -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

Write-Host "$(Get-Date) - setup completed" -ForegroundColor Green
$endTime = Get-Date
$timeDiff = New-TimeSpan $startTime $endTime
$mins = $timeDiff.Minutes
$secs = $timeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $mins, $secs
Write-Host "$(Get-Date) - Script completed" -ForegroundColor Green
Write-Host "Time to complete: "$runTime







