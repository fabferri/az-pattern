#
#  variables in init.json file:
#   $subscriptionName: Azure subscription name
#   $rgWanName: resource group name for the virtual WAN resources
#   $rgSpoke21: resource group name for spoke21
#   $spoke21location: Azure region for spoke21 resources
#   $spoke21vnetName: name of the spoke21 virtual network
#   $spoke21AddressPrefix: address prefix for the spoke21 virtual network
#   $spoke21subnetFEName: front-end subnet name
#   $spoke21subnetFEPrefix: front-end subnet address prefix
#   $spoke21subnetBEName: back-end subnet name
#   $spoke21subnetBEPrefix: back-end subnet address prefix
#   $spoke21subnetWLName: workload subnet name
#   $spoke21subnetWLPrefix: workload subnet address prefix
#   $spoke22AddressPrefix: address prefix for remote spoke22
#   $spoke21BAddressPrefix: address prefix for child spoke21B
#   $spoke22BAddressPrefix: address prefix for child spoke22B
#   $spoke21rtSubnetWLName: route table name for spoke21 workload subnet
#   $spoke21rtEntryNameLocalChildSpoke: route entry name toward spoke21B
#   $spoke21rtEntryNameRemoteSpoke: route entry name toward spoke22
#   $spoke21rtEntryNameRemoteChildSpoke: route entry name toward spoke22B
#   $spoke21lbName: load balancer name
#   $spoke21lbFrontEndIP: load balancer frontend IP
#   $spoke21lbFrontEndConfigName: load balancer frontend configuration name
#   $spoke21lbBackEndPoolName: load balancer backend pool name
#   $spoke21lbProbeName: load balancer probe name
#   $R21-1: first router VM name
#   $R21-2: second router VM name
#   $WL21-1: workload VM name
#   $R21_1_privIP: private IP for R21-1
#   $R21_2_privIP: private IP for R21-2
#   $WL21_1_privIP: private IP for WL21-1
#   $adminUsername: administrator username
#   $adminPassword: administrator password
#
################# Input parameters #################
param(
     [string]$initFile = 'init.json'
)

$deploymentName = (Get-Item $PSCommandPath).BaseName
$armTemplateFile = '01-spoke21.json'
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
     $rgWanName = $arrayParams.rgWanName
     $rgSpoke21 = $arrayParams.rgSpoke21
     $spoke21location = $arrayParams.spoke21location
     $spoke21vnetName = $arrayParams.spoke21vnetName
     $spoke21AddressPrefix = $arrayParams.spoke21AddressPrefix
     $spoke21subnetFEName = $arrayParams.spoke21subnetFEName
     $spoke21subnetFEPrefix = $arrayParams.spoke21subnetFEPrefix
     $spoke21subnetBEName = $arrayParams.spoke21subnetBEName
     $spoke21subnetBEPrefix = $arrayParams.spoke21subnetBEPrefix
     $spoke21subnetWLName = $arrayParams.spoke21subnetWLName
     $spoke21subnetWLPrefix = $arrayParams.spoke21subnetWLPrefix
     $spoke21BAddressPrefix = $arrayParams.spoke21BAddressPrefix
     $spoke21rtSubnetWLName = $arrayParams.spoke21rtSubnetWLName
     $spoke21rtEntryNameLocalChildSpoke = $arrayParams.spoke21rtEntryNameLocalChildSpoke
     $spoke21rtEntryNameMajorPrivNet = $arrayParams.spoke21rtEntryNameMajorPrivNet
     $majorPrivNetwork = $arrayParams.majorPrivNetwork
     $spoke21lbName = $arrayParams.spoke21lbName
     $spoke21lbFrontEndIP = $arrayParams.spoke21lbFrontEndIP
     $spoke21lbFrontEndConfigName = $arrayParams.spoke21lbFrontEndConfigName
     $spoke21lbBackEndPoolName = $arrayParams.spoke21lbBackEndPoolName
     $spoke21lbProbeName = $arrayParams.spoke21lbProbeName
     $majorPrivNetwork = $arrayParams.majorPrivNetwork
     $R21_1_name = $arrayParams.'R21-1'
     $R21_2_name = $arrayParams.'R21-2'
     $WL21_1_name = $arrayParams.'WL21-1'
     $R21_1_privIP = $arrayParams.R21_1_privIP
     $R21_2_privIP = $arrayParams.R21_2_privIP
     $WL21_1_privIP = $arrayParams.WL21_1_privIP
     $spoke22AddressPrefix = $arrayParams.spoke22AddressPrefix
     $spoke22BAddressPrefix = $arrayParams.spoke22BAddressPrefix 
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
if (!$rgWanName) { Write-Host 'variable $rgWanName is null' ; Exit }                           else { Write-Host '   resource group name....: '$rgWanName -ForegroundColor Yellow }
if (!$rgSpoke21) { Write-Host 'variable $rgSpoke21 is null' ; Exit }                           else { Write-Host '   spoke21 resource group.: '$rgSpoke21 -ForegroundColor Yellow }
if (!$spoke21location) { Write-Host 'variable $spoke21location is null' ; Exit }               else { Write-Host '   spoke21 location.......: '$spoke21location -ForegroundColor Yellow }
if (!$spoke21vnetName) { Write-Host 'variable $spoke21vnetName is null' ; Exit }               else { Write-Host '   spoke21 vnet name......: '$spoke21vnetName -ForegroundColor Yellow }
if (!$spoke21AddressPrefix) { Write-Host 'variable $spoke21AddressPrefix is null' ; Exit }     else { Write-Host '   spoke21 address prefix.: '$spoke21AddressPrefix -ForegroundColor Yellow }
if (!$spoke21subnetFEName) { Write-Host 'variable $spoke21subnetFEName is null' ; Exit }       else { Write-Host '   spoke21 subnetFE name..: '$spoke21subnetFEName -ForegroundColor Yellow }
if (!$spoke21subnetFEPrefix) { Write-Host 'variable $spoke21subnetFEPrefix is null' ; Exit }   else { Write-Host '   spoke21 subnetFE prefix: '$spoke21subnetFEPrefix -ForegroundColor Yellow }
if (!$spoke21subnetBEName) { Write-Host 'variable $spoke21subnetBEName is null' ; Exit }       else { Write-Host '   spoke21 subnetBE name..: '$spoke21subnetBEName -ForegroundColor Yellow }
if (!$spoke21subnetBEPrefix) { Write-Host 'variable $spoke21subnetBEPrefix is null' ; Exit }   else { Write-Host '   spoke21 subnetBE prefix: '$spoke21subnetBEPrefix -ForegroundColor Yellow }
if (!$spoke21subnetWLName) { Write-Host 'variable $spoke21subnetWLName is null' ; Exit }       else { Write-Host '   spoke21 subnetWL name..: '$spoke21subnetWLName -ForegroundColor Yellow }
if (!$spoke21subnetWLPrefix) { Write-Host 'variable $spoke21subnetWLPrefix is null' ; Exit }   else { Write-Host '   spoke21 subnetWL prefix: '$spoke21subnetWLPrefix -ForegroundColor Yellow }
if (!$spoke21BAddressPrefix) { Write-Host 'variable $spoke21BAddressPrefix is null' ; Exit }   else { Write-Host '   spoke21B address prefix: '$spoke21BAddressPrefix -ForegroundColor Yellow }
if (!$spoke21rtSubnetWLName) { Write-Host 'variable $spoke21rtSubnetWLName is null' ; Exit }   else { Write-Host '   spoke21 RT WL name.....: '$spoke21rtSubnetWLName -ForegroundColor Yellow }
if (!$spoke21rtEntryNameLocalChildSpoke) { Write-Host 'variable $spoke21rtEntryNameLocalChildSpoke is null' ; Exit }   else { Write-Host '   RT entry local child...: '$spoke21rtEntryNameLocalChildSpoke -ForegroundColor Yellow }
if (!$spoke21rtEntryNameMajorPrivNet) { Write-Host 'variable $spoke21rtEntryNameMajorPrivNet is null' ; Exit }   else { Write-Host '   RT entry major private..: '$spoke21rtEntryNameMajorPrivNet -ForegroundColor Yellow }
if (!$majorPrivNetwork) { Write-Host 'variable $majorPrivNetwork is null' ; Exit }             else { Write-Host '   major private network..: '$majorPrivNetwork -ForegroundColor Yellow }
if (!$spoke21lbName) { Write-Host 'variable $spoke21lbName is null' ; Exit }                   else { Write-Host '   spoke21 LB name........: '$spoke21lbName -ForegroundColor Yellow }
if (!$spoke21lbFrontEndIP) { Write-Host 'variable $spoke21lbFrontEndIP is null' ; Exit }       else { Write-Host '   spoke21 LB frontend IP.: '$spoke21lbFrontEndIP -ForegroundColor Yellow }
if (!$spoke21lbFrontEndConfigName) { Write-Host 'variable $spoke21lbFrontEndConfigName is null' ; Exit } else { Write-Host '   spoke21 LB FE config...: '$spoke21lbFrontEndConfigName -ForegroundColor Yellow }
if (!$spoke21lbBackEndPoolName) { Write-Host 'variable $spoke21lbBackEndPoolName is null' ; Exit }       else { Write-Host '   spoke21 LB BE pool.....: '$spoke21lbBackEndPoolName -ForegroundColor Yellow }
if (!$spoke21lbProbeName) { Write-Host 'variable $spoke21lbProbeName is null' ; Exit }         else { Write-Host '   spoke21 LB probe name..: '$spoke21lbProbeName -ForegroundColor Yellow }
if (!$majorPrivNetwork) { Write-Host 'variable $majorPrivNetwork is null' ; Exit }             else { Write-Host '   major private network..: '$majorPrivNetwork -ForegroundColor Yellow }
if (!$R21_1_name) { Write-Host "variable 'R21-1' is null" ; Exit }                             else { Write-Host '   R21-1 name.............: '$R21_1_name -ForegroundColor Yellow }
if (!$R21_2_name) { Write-Host "variable 'R21-2' is null" ; Exit }                             else { Write-Host '   R21-2 name.............: '$R21_2_name -ForegroundColor Yellow }
if (!$WL21_1_name) { Write-Host "variable 'WL21-1' is null" ; Exit }                           else { Write-Host '   WL21-1 name............: '$WL21_1_name -ForegroundColor Yellow }
if (!$R21_1_privIP) { Write-Host 'variable $R21_1_privIP is null' ; Exit }                     else { Write-Host '   R21-1 private IP.......: '$R21_1_privIP -ForegroundColor Yellow }
if (!$R21_2_privIP) { Write-Host 'variable $R21_2_privIP is null' ; Exit }                     else { Write-Host '   R21-2 private IP.......: '$R21_2_privIP -ForegroundColor Yellow }
if (!$WL21_1_privIP) { Write-Host 'variable $WL21_1_privIP is null' ; Exit }                   else { Write-Host '   WL21-1 private IP......: '$WL21_1_privIP -ForegroundColor Yellow }
if (!$spoke22AddressPrefix) { Write-Host 'variable $spoke22AddressPrefix is null' ; Exit }     else { Write-Host '   spoke22 address prefix.: '$spoke22AddressPrefix -ForegroundColor Yellow }
if (!$spoke22BAddressPrefix) { Write-Host 'variable $spoke22BAddressPrefix is null' ; Exit }   else { Write-Host '   spoke22B address prefix: '$spoke22BAddressPrefix -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }                   else { Write-Host '   administrator username.: '$adminUsername -ForegroundColor Green }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }                   else { Write-Host '   administrator password.: '$adminPassword -ForegroundColor Green }

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$parameters = @{
     "spoke21location"                    = $spoke21location;
     "spoke21vnetName"                    = $spoke21vnetName;
     "spoke21AddressPrefix"               = $spoke21AddressPrefix;
     "spoke21subnetFEName"                = $spoke21subnetFEName;
     "spoke21subnetFEPrefix"              = $spoke21subnetFEPrefix;
     "spoke21subnetBEName"                = $spoke21subnetBEName;
     "spoke21subnetBEPrefix"              = $spoke21subnetBEPrefix;
     "spoke21subnetWLName"                = $spoke21subnetWLName;
     "spoke21subnetWLPrefix"              = $spoke21subnetWLPrefix;
     "spoke22AddressPrefix"               = $spoke22AddressPrefix;
     "spoke21BAddressPrefix"              = $spoke21BAddressPrefix;
     "spoke22BAddressPrefix"              = $spoke22BAddressPrefix;
     "spoke21rtSubnetWLName"              = $spoke21rtSubnetWLName;
     "spoke21rtEntryNameLocalChildSpoke"  = $spoke21rtEntryNameLocalChildSpoke;
     "spoke21rtEntryNameMajorPrivNet"     = $spoke21rtEntryNameMajorPrivNet;
     "majorPrivNetwork"                   = $majorPrivNetwork;
     "spoke21lbName"                      = $spoke21lbName;
     "spoke21lbFrontEndIP"                = $spoke21lbFrontEndIP;
     "spoke21lbFrontEndConfigName"        = $spoke21lbFrontEndConfigName;
     "spoke21lbBackEndPoolName"           = $spoke21lbBackEndPoolName;
     "spoke21lbProbeName"                 = $spoke21lbProbeName;
     "R21_1_privIP"                       = $R21_1_privIP;
     "R21_2_privIP"                       = $R21_2_privIP;
     "WL21_1_privIP"                      = $WL21_1_privIP;
     "R21-1"                              = $R21_1_name;
     "R21-2"                              = $R21_2_name;
     "WL21-1"                             = $WL21_1_name;
     "adminUsername"                      = $adminUsername;
     "adminPassword"                      = $adminPassword
}


# Create Resource Group
Write-Host "$(Get-Date) - creating Resource Group: "$rgSpoke21 -ForegroundColor Cyan
Try {
     $rg = Get-AzResourceGroup -Name $rgSpoke21 -ErrorAction Stop
     Write-Host "$(Get-Date) - Resource Group exists, skipping" -ForegroundColor Yellow
}
Catch { 
     $rg = New-AzResourceGroup -Name $rgSpoke21 -Location $spoke21location 
     Write-Host "$(Get-Date) - Resource group created: "$rg.ResourceGroupName -ForegroundColor Green
     # Set tag on the resource group
     Set-AzResourceGroup -Name $rgSpoke21 -Tag @{"PM owner" = "fabferri"; "Project" = "vWAN validation" }
}

$startTime = Get-Date
write-host "$(Get-Date) - running ARM template:"$templateFile -ForegroundColor Cyan
New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgSpoke21 -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

Write-Host "$(Get-Date) - setup completed" -ForegroundColor Green
$endTime = Get-Date
$timeDiff = New-TimeSpan $startTime $endTime
$mins = $timeDiff.Minutes
$secs = $timeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $mins, $secs
Write-Host "$(Get-Date) - Script completed" -ForegroundColor Green
Write-Host "Time to complete: "$runTime







