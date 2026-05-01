#
#  variables in init.json file:
#   $subscriptionName: Azure subscription name
#   $rgSpoke21: resource group name for spoke21
#   $rgSpoke21B: resource group name for spoke21B
#   $spoke21location: Azure region for spoke21 resources
#   $spoke21Blocation: Azure region for spoke21B resources
#   $spoke21vnetName: name of the parent spoke21 virtual network
#   $spoke21AddressPrefix: address prefix for the parent spoke21 virtual network
#   $spoke21BvnetName: name of the spoke21B virtual network
#   $spoke21BAddressPrefix: address prefix for the spoke21B virtual network
#   $spoke21BsubnetWLName: workload subnet name in spoke21B
#   $spoke21BsubnetWLPrefix: workload subnet address prefix in spoke21B
#   $WL21B-1: workload VM name in spoke21B
#   $WL21B_1_privIP: private IP for WL21B-1
#   $spoke21BrtSubnetWLName: route table name for spoke21B workload subnet
#   $spoke21BrtEntryNameMajorNet: route entry name toward the major network
#   $spoke21BrtEntryNameParentSpoke: route entry name toward parent spoke21
#   $spoke21lbFrontEndIP: frontend IP of the spoke21 load balancer used as next hop
#   $vnetpeeringName21Bto21: peering name from spoke21B to spoke21
#   $vnetpeeringName21to21B: peering name from spoke21 to spoke21B
#   $adminUsername: administrator username
#   $adminPassword: administrator password
#
################# Input parameters #################
param(
     [string]$initFile = 'init.json'
)
$deploymentName = (Get-Item $PSCommandPath).BaseName
$armTemplateFile = '02-spoke21B.json'
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
     $rgSpoke21 = $arrayParams.rgSpoke21
     $rgSpoke21B = $arrayParams.rgSpoke21B
     $spoke21location = $arrayParams.spoke21location
     $spoke21Blocation = $arrayParams.spoke21Blocation
     $spoke21vnetName = $arrayParams.spoke21vnetName
     $spoke21AddressPrefix = $arrayParams.spoke21AddressPrefix
     $spoke21BAddressPrefix = $arrayParams.spoke21BAddressPrefix
     $spoke21BvnetName = $arrayParams.spoke21BvnetName
     $spoke21BsubnetWLName = $arrayParams.spoke21BsubnetWLName
     $spoke21BsubnetWLPrefix = $arrayParams.spoke21BsubnetWLPrefix
     $WL21B_1_Name = $arrayParams.'WL21B-1'
     $WL21B_1_privIP = $arrayParams.WL21B_1_privIP
     $spoke21BrtSubnetWLName = $arrayParams.spoke21BrtSubnetWLName
     $spoke21BrtEntryNameMajorNet = $arrayParams.spoke21BrtEntryNameMajorNet
     $spoke21BrtEntryNameParentSpoke = $arrayParams.spoke21BrtEntryNameParentSpoke
     $spoke21lbFrontEndIP = $arrayParams.spoke21lbFrontEndIP
     $vnetpeeringName21Bto21 = $arrayParams.vnetpeeringName21Bto21
     $vnetpeeringName21to21B = $arrayParams.vnetpeeringName21to21B
     $adminUsername = $arrayParams.adminUsername
     $adminPassword = $arrayParams.adminPassword
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }           else { Write-Host '   subscription name......: '$subscriptionName -ForegroundColor Yellow }
if (!$rgSpoke21) { Write-Host 'variable $rgSpoke21 is null' ; Exit }                         else { Write-Host '   spoke21 resource group.: '$rgSpoke21 -ForegroundColor Yellow }
if (!$spoke21location) { Write-Host 'variable $spoke21location is null' ; Exit }             else { Write-Host '   spoke21 location.......: '$spoke21location -ForegroundColor Yellow }
if (!$rgSpoke21B) { Write-Host 'variable $rgSpoke21B is null' ; Exit }                       else { Write-Host '   spoke21B resource group: '$rgSpoke21B -ForegroundColor Yellow }
if (!$spoke21Blocation) { Write-Host 'variable $spoke21Blocation is null' ; Exit }           else { Write-Host '   spoke21B location......: '$spoke21Blocation -ForegroundColor Yellow }
if (!$spoke21vnetName) { Write-Host 'variable $spoke21vnetName is null' ; Exit }             else { Write-Host '   spoke21 VNet name......: '$spoke21vnetName -ForegroundColor Yellow }
if (!$spoke21AddressPrefix) { Write-Host 'variable $spoke21AddressPrefix is null' ; Exit }   else { Write-Host '   spoke21 prefix.........: '$spoke21AddressPrefix -ForegroundColor Yellow }
if (!$spoke21BvnetName) { Write-Host 'variable $spoke21BvnetName is null' ; Exit }           else { Write-Host '   spoke21B VNet name.....: '$spoke21BvnetName -ForegroundColor Yellow }
if (!$spoke21BAddressPrefix) { Write-Host 'variable $spoke21BAddressPrefix is null' ; Exit } else { Write-Host '   spoke21B prefix........: '$spoke21BAddressPrefix -ForegroundColor Yellow }
if (!$spoke21BsubnetWLName) { Write-Host 'variable $spoke21BsubnetWLName is null' ; Exit }   else { Write-Host '   spoke21B subnet name...: '$spoke21BsubnetWLName -ForegroundColor Yellow }
if (!$spoke21BsubnetWLPrefix) { Write-Host 'variable $spoke21BsubnetWLPrefix is null' ; Exit } else { Write-Host '   spoke21B subnet prefix.: '$spoke21BsubnetWLPrefix -ForegroundColor Yellow }
if (!$WL21B_1_Name) { Write-Host "variable 'WL21B-1' is null" ; Exit }                     else { Write-Host '   VM name WL21B-1........: '$WL21B_1_Name -ForegroundColor Yellow }
if (!$WL21B_1_privIP) { Write-Host 'variable $WL21B_1_privIP is null' ; Exit }             else { Write-Host '   WL21B-1 private IP.....: '$WL21B_1_privIP -ForegroundColor Yellow }
if (!$spoke21BrtSubnetWLName) { Write-Host 'variable $spoke21BrtSubnetWLName is null' ; Exit }                 else { Write-Host '   route table name.......: '$spoke21BrtSubnetWLName -ForegroundColor Yellow }
if (!$spoke21BrtEntryNameMajorNet) { Write-Host 'variable $spoke21BrtEntryNameMajorNet is null' ; Exit }       else { Write-Host '   major net route........: '$spoke21BrtEntryNameMajorNet -ForegroundColor Yellow }
if (!$spoke21BrtEntryNameParentSpoke) { Write-Host 'variable $spoke21BrtEntryNameParentSpoke is null' ; Exit } else { Write-Host '   parent spoke route.....: '$spoke21BrtEntryNameParentSpoke -ForegroundColor Yellow }
if (!$spoke21lbFrontEndIP) { Write-Host 'variable $spoke21lbFrontEndIP is null' ; Exit } else { Write-Host '   spoke21 LB IP..........: '$spoke21lbFrontEndIP -ForegroundColor Yellow }
if (!$vnetpeeringName21Bto21) { Write-Host 'variable $vnetpeeringName21Bto21 is null' ; Exit } else { Write-Host '   peering 21B to 21......: '$vnetpeeringName21Bto21 -ForegroundColor Yellow }
if (!$vnetpeeringName21to21B) { Write-Host 'variable $vnetpeeringName21to21B is null' ; Exit } else { Write-Host '   peering 21 to 21B......: '$vnetpeeringName21to21B -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }         else { Write-Host '   administrator username.: '$adminUsername -ForegroundColor Green }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }         else { Write-Host '   administrator password.: '$adminPassword -ForegroundColor Green }


$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id


$parameters = @{
     "location"                       = $spoke21Blocation;
     "spoke21BvnetName"               = $spoke21BvnetName;
     "spoke21BAddressPrefix"          = $spoke21BAddressPrefix;
     "spoke21BsubnetWLName"           = $spoke21BsubnetWLName;
     "spoke21BsubnetWLPrefix"         = $spoke21BsubnetWLPrefix;
     "WL21B-1"                        = $WL21B_1_Name;
     "WL21B_1_privIP"                 = $WL21B_1_privIP;
     "spoke21BrtSubnetWLName"         = $spoke21BrtSubnetWLName;
     "spoke21BrtEntryNameMajorNet"    = $spoke21BrtEntryNameMajorNet;
     "spoke21BrtEntryNameParentSpoke" = $spoke21BrtEntryNameParentSpoke;
     "spoke21lbFrontEndIP"            = $spoke21lbFrontEndIP;
     "spoke21vnetName"                = $spoke21vnetName;
     "spoke21AddressPrefix"           = $spoke21AddressPrefix;
     "rgSpoke21"                      = $rgSpoke21;
     "vnetpeeringName21Bto21"         = $vnetpeeringName21Bto21;
     "vnetpeeringName21to21B"         = $vnetpeeringName21to21B;
     "adminUsername"                  = $adminUsername;
     "adminPassword"                  = $adminPassword
}


# Create Resource Group
Write-Host "$(Get-Date) - creating Resource Group: "$rgSpoke21B -ForegroundColor Cyan
Try {
     Get-AzResourceGroup -Name $rgSpoke21B -ErrorAction Stop
     Write-Host 'Resource exists, skipping'
}
Catch { 
     New-AzResourceGroup -Name $rgSpoke21B -Location $spoke21Blocation 
     Write-Host 'Resource group created' -ForegroundColor Green
     # Set tag on the resource group
     Set-AzResourceGroup -Name $rgSpoke21B -Tag @{"PM owner" = "fabferri"; "Project" = "vWAN validation" }
}

$startTime = Get-Date
write-host "$(Get-Date) - running ARM template:"$templateFile
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgSpoke21B -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

Write-Host "$(Get-Date) - setup completed" -ForegroundColor Green
$endTime = Get-Date
$timeDiff = New-TimeSpan $startTime $endTime
$mins = $timeDiff.Minutes
$secs = $timeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $mins, $secs
Write-Host "$(Get-Date) - Script completed" -ForegroundColor Green
Write-Host "Time to complete: "$runTime







