#
#  variables in init.json file:
#   $subscriptionName: Azure subscription name
#   $rgSpoke22: resource group name for spoke22
#   $spoke22location: Azure region for spoke22 resources
#   $spoke22vnetName: name of the spoke22 virtual network
#   $spoke22AddressPrefix: address prefix for the spoke22 virtual network
#   $spoke22subnetFEName: front-end subnet name
#   $spoke22subnetFEPrefix: front-end subnet address prefix
#   $spoke22subnetBEName: back-end subnet name
#   $spoke22subnetBEPrefix: back-end subnet address prefix
#   $spoke22subnetWLName: workload subnet name
#   $spoke22subnetWLPrefix: workload subnet address prefix
#   $spoke22BAddressPrefix: address prefix for child spoke22B
#   $spoke21AddressPrefix: address prefix for remote spoke21
#   $spoke21BAddressPrefix: address prefix for child spoke21B
#   $spoke22rtSubnetWLName: route table name for spoke22 workload subnet
#   $spoke22rtEntryNameLocalChildSpoke: route entry name toward spoke22B
#   $spoke22rtEntryNameRemoteSpoke: route entry name toward spoke21
#   $spoke22rtEntryNameRemoteChildSpoke: route entry name toward spoke21B
#   $spoke22lbName: load balancer name
#   $spoke22lbFrontEndIP: load balancer frontend IP
#   $spoke22lbFrontEndConfigName: load balancer frontend configuration name
#   $spoke22lbBackEndPoolName: load balancer backend pool name
#   $spoke22lbProbeName: load balancer probe name
#   $R22-1: first router VM name
#   $R22-2: second router VM name
#   $WL22-1: workload VM name
#   $R22_1_privIP: private IP for R22-1
#   $R22_2_privIP: private IP for R22-2
#   $WL22_1_privIP: private IP for WL22-1
#   $adminUsername: administrator username
#   $adminPassword: administrator password
#
################# Input parameters #################
param(
     [string]$initFile = 'init.json'
)
$deploymentName = (Get-Item $PSCommandPath).BaseName
$armTemplateFile = '01-spoke22.json'
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
     $spoke21AddressPrefix = $arrayParams.spoke21AddressPrefix
     $spoke21BAddressPrefix = $arrayParams.spoke21BAddressPrefix
     $rgSpoke22 = $arrayParams.rgSpoke22
     $spoke22location = $arrayParams.spoke22location
     $spoke22vnetName = $arrayParams.spoke22vnetName
     $spoke22AddressPrefix = $arrayParams.spoke22AddressPrefix
     $spoke22subnetFEName = $arrayParams.spoke22subnetFEName
     $spoke22subnetFEPrefix = $arrayParams.spoke22subnetFEPrefix
     $spoke22subnetBEName = $arrayParams.spoke22subnetBEName
     $spoke22subnetBEPrefix = $arrayParams.spoke22subnetBEPrefix
     $spoke22subnetWLName = $arrayParams.spoke22subnetWLName
     $spoke22subnetWLPrefix = $arrayParams.spoke22subnetWLPrefix
     $spoke22BAddressPrefix = $arrayParams.spoke22BAddressPrefix
     $spoke22rtSubnetWLName = $arrayParams.spoke22rtSubnetWLName
     $spoke22rtEntryNameLocalChildSpoke = $arrayParams.spoke22rtEntryNameLocalChildSpoke
     $spoke22rtEntryNameMajorPrivNet = $arrayParams.spoke22rtEntryNameMajorPrivNet
     $majorPrivNetwork = $arrayParams.majorPrivNetwork
     $spoke22lbName = $arrayParams.spoke22lbName
     $spoke22lbFrontEndIP = $arrayParams.spoke22lbFrontEndIP
     $spoke22lbFrontEndConfigName = $arrayParams.spoke22lbFrontEndConfigName
     $spoke22lbBackEndPoolName = $arrayParams.spoke22lbBackEndPoolName
     $spoke22lbProbeName = $arrayParams.spoke22lbProbeName
     $R22_1_Name = $arrayParams.'R22-1'
     $R22_2_Name = $arrayParams.'R22-2'
     $WL22_1_Name = $arrayParams.'WL22-1'
     $R22_1_privIP = $arrayParams.R22_1_privIP
     $R22_2_privIP = $arrayParams.R22_2_privIP
     $WL22_1_privIP = $arrayParams.WL22_1_privIP
     $adminUsername = $arrayParams.adminUsername
     $adminPassword = $arrayParams.adminPassword 
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }                       else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$spoke21AddressPrefix) { Write-Host 'variable $spoke21AddressPrefix is null' ; Exit }               else { Write-Host '   spoke21 prefix........: '$spoke21AddressPrefix -ForegroundColor Yellow }
if (!$spoke21BAddressPrefix) { Write-Host 'variable $spoke21BAddressPrefix is null' ; Exit }             else { Write-Host '   spoke21B prefix.......: '$spoke21BAddressPrefix -ForegroundColor Yellow }
if (!$rgSpoke22) { Write-Host 'variable $rgSpoke22 is null' ; Exit }                                     else { Write-Host '   spoke22 resource group: '$rgSpoke22 -ForegroundColor Yellow }
if (!$spoke22location) { Write-Host 'variable $spoke22location is null' ; Exit }                         else { Write-Host '   spoke22 location......: '$spoke22location -ForegroundColor Yellow }
if (!$spoke22vnetName) { Write-Host 'variable $spoke22vnetName is null' ; Exit }                         else { Write-Host '   spoke22 VNet name.....: '$spoke22vnetName -ForegroundColor Yellow }
if (!$spoke22AddressPrefix) { Write-Host 'variable $spoke22AddressPrefix is null' ; Exit }               else { Write-Host '   spoke22 address prefix: '$spoke22AddressPrefix -ForegroundColor Yellow }
if (!$spoke22subnetFEName) { Write-Host 'variable $spoke22subnetFEName is null' ; Exit }                 else { Write-Host '   subnet FE name........: '$spoke22subnetFEName -ForegroundColor Yellow }
if (!$spoke22subnetFEPrefix) { Write-Host 'variable $spoke22subnetFEPrefix is null' ; Exit }             else { Write-Host '   subnet FE prefix......: '$spoke22subnetFEPrefix -ForegroundColor Yellow }
if (!$spoke22subnetBEName) { Write-Host 'variable $spoke22subnetBEName is null' ; Exit }                 else { Write-Host '   subnet BE name........: '$spoke22subnetBEName -ForegroundColor Yellow }
if (!$spoke22subnetBEPrefix) { Write-Host 'variable $spoke22subnetBEPrefix is null' ; Exit }             else { Write-Host '   subnet BE prefix......: '$spoke22subnetBEPrefix -ForegroundColor Yellow }
if (!$spoke22subnetWLName) { Write-Host 'variable $spoke22subnetWLName is null' ; Exit }                 else { Write-Host '   subnet WL name........: '$spoke22subnetWLName -ForegroundColor Yellow }
if (!$spoke22subnetWLPrefix) { Write-Host 'variable $spoke22subnetWLPrefix is null' ; Exit }             else { Write-Host '   subnet WL prefix......: '$spoke22subnetWLPrefix -ForegroundColor Yellow }
if (!$spoke22BAddressPrefix) { Write-Host 'variable $spoke22BAddressPrefix is null' ; Exit }             else { Write-Host '   spoke22B prefix.......: '$spoke22BAddressPrefix -ForegroundColor Yellow }
if (!$spoke22rtSubnetWLName) { Write-Host 'variable $spoke22rtSubnetWLName is null' ; Exit }             else { Write-Host '   route table name......: '$spoke22rtSubnetWLName -ForegroundColor Yellow }
if (!$spoke22rtEntryNameLocalChildSpoke) { Write-Host 'variable $spoke22rtEntryNameLocalChildSpoke is null' ; Exit }   else { Write-Host '   local child route.....: '$spoke22rtEntryNameLocalChildSpoke -ForegroundColor Yellow }
if (!$spoke22rtEntryNameMajorPrivNet) { Write-Host 'variable $spoke22rtEntryNameMajorPrivNet is null' ; Exit }         else { Write-Host '   major private network route: '$spoke22rtEntryNameMajorPrivNet -ForegroundColor Yellow }
if (!$majorPrivNetwork) { Write-Host 'variable $majorPrivNetwork is null' ; Exit }                       else { Write-Host '   major private network....: '$majorPrivNetwork -ForegroundColor Yellow }
if (!$spoke22lbName) { Write-Host 'variable $spoke22lbName is null' ; Exit }                             else { Write-Host '   load balancer name....: '$spoke22lbName -ForegroundColor Yellow }
if (!$spoke22lbFrontEndIP) { Write-Host 'variable $spoke22lbFrontEndIP is null' ; Exit }                 else { Write-Host '   LB frontend IP........: '$spoke22lbFrontEndIP -ForegroundColor Yellow }
if (!$spoke22lbFrontEndConfigName) { Write-Host 'variable $spoke22lbFrontEndConfigName is null' ; Exit } else { Write-Host '   LB frontend config....: '$spoke22lbFrontEndConfigName -ForegroundColor Yellow }
if (!$spoke22lbBackEndPoolName) { Write-Host 'variable $spoke22lbBackEndPoolName is null' ; Exit }       else { Write-Host '   LB backend pool.......: '$spoke22lbBackEndPoolName -ForegroundColor Yellow }
if (!$spoke22lbProbeName) { Write-Host 'variable $spoke22lbProbeName is null' ; Exit }                   else { Write-Host '   LB probe name.........: '$spoke22lbProbeName -ForegroundColor Yellow }
if (!$R22_1_Name) { Write-Host "variable 'R22-1' is null" ; Exit }                                       else { Write-Host '   VM R22-1 name.........: '$R22_1_Name -ForegroundColor Yellow }
if (!$R22_2_Name) { Write-Host "variable 'R22-2' is null" ; Exit }                                       else { Write-Host '   VM R22-2 name.........: '$R22_2_Name -ForegroundColor Yellow }
if (!$WL22_1_Name) { Write-Host "variable 'WL22-1' is null" ; Exit }                                     else { Write-Host '   VM WL22-1 name........: '$WL22_1_Name -ForegroundColor Yellow }
if (!$R22_1_privIP) { Write-Host 'variable $R22_1_privIP is null' ; Exit }                               else { Write-Host '   R22-1 private IP......: '$R22_1_privIP -ForegroundColor Yellow }
if (!$R22_2_privIP) { Write-Host 'variable $R22_2_privIP is null' ; Exit }                               else { Write-Host '   R22-2 private IP......: '$R22_2_privIP -ForegroundColor Yellow }
if (!$WL22_1_privIP) { Write-Host 'variable $WL22_1_privIP is null' ; Exit }                             else { Write-Host '   WL22-1 private IP.....: '$WL22_1_privIP -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }         else { Write-Host '   administrator username: '$adminUsername -ForegroundColor Green }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }         else { Write-Host '   administrator password: '$adminPassword -ForegroundColor Green }


$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$parameters = @{
     "spoke22location"                   = $spoke22location;
     "spoke22vnetName"                   = $spoke22vnetName;
     "spoke22AddressPrefix"              = $spoke22AddressPrefix;
     "spoke22subnetFEName"               = $spoke22subnetFEName;
     "spoke22subnetFEPrefix"             = $spoke22subnetFEPrefix;
     "spoke22subnetBEName"               = $spoke22subnetBEName;
     "spoke22subnetBEPrefix"             = $spoke22subnetBEPrefix;
     "spoke22subnetWLName"               = $spoke22subnetWLName;
     "spoke22subnetWLPrefix"             = $spoke22subnetWLPrefix;
     "spoke22BAddressPrefix"             = $spoke22BAddressPrefix;
     "spoke22rtSubnetWLName"             = $spoke22rtSubnetWLName;
     "spoke22rtEntryNameLocalChildSpoke" = $spoke22rtEntryNameLocalChildSpoke;
     "spoke22rtEntryNameMajorPrivNet"    = $spoke22rtEntryNameMajorPrivNet;
     "majorPrivNetwork"                  = $majorPrivNetwork;
     "spoke22lbName"                     = $spoke22lbName;
     "spoke22lbFrontEndIP"               = $spoke22lbFrontEndIP;
     "spoke22lbFrontEndConfigName"       = $spoke22lbFrontEndConfigName;
     "spoke22lbBackEndPoolName"          = $spoke22lbBackEndPoolName;
     "spoke22lbProbeName"                = $spoke22lbProbeName;
     "R22_1_privIP"                      = $R22_1_privIP;
     "R22_2_privIP"                      = $R22_2_privIP;
     "WL22_1_privIP"                     = $WL22_1_privIP;
     "R22-1"                             = $R22_1_Name;
     "R22-2"                             = $R22_2_Name;
     "WL22-1"                            = $WL22_1_Name;
     "adminUsername"                     = $adminUsername;
     "adminPassword"                     = $adminPassword
}


# Create Resource Group
Write-Host "$(Get-Date) - creating Resource Group: "$rgSpoke22 -ForegroundColor Cyan
Try {
     Get-AzResourceGroup -Name $rgSpoke22 -ErrorAction Stop
     Write-Host 'Resource exists, skipping'
}
Catch { 
     New-AzResourceGroup -Name $rgSpoke22 -Location $spoke22location 
     Write-Host 'Resource group created' -ForegroundColor Green
     # Set tag on the resource group
     Set-AzResourceGroup -Name $rgSpoke22 -Tag @{"PM owner" = "fabferri"; "Project" = "vWAN validation" }
}



$startTime = Get-Date
write-host "$(Get-Date) - running ARM template:"$templateFile
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgSpoke22 -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

Write-Host "$(Get-Date) - setup completed" -ForegroundColor Green
$endTime = Get-Date
$timeDiff = New-TimeSpan $startTime $endTime
$mins = $timeDiff.Minutes
$secs = $timeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $mins, $secs
Write-Host "$(Get-Date) - Script completed" -ForegroundColor Green
Write-Host "Time to complete: "$runTime







