## script to create vnets, VMs and VPN Gateways
################# Input parameters #################
$deploymentName = 'vpngw1'
$armTemplateFile = '02-azvng.json'
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
     $adminUsername = $arrayParams.adminUsername
     $adminPassword = $arrayParams.adminPassword
     $catalystName = $arrayParams.catalystName
     $sharedKey = $arrayParams.sharedKey
     $vpnGatewayName = $arrayParams.vpnGatewayName
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

 
# checking the values of variables from init.json
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '  subscription name...: '$subscriptionName -ForegroundColor Yellow }
if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                       else { Write-Host '  resource group......: '$rgName -ForegroundColor Yellow }
if (!$location) { Write-Host 'variable $location is null' ; Exit }                   else { Write-Host '  location............: '$location -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }         else { Write-Host '  adminUsername.......: '$adminUsername -ForegroundColor Red }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }         else { Write-Host '  adminPassword.......: '$adminPassword -ForegroundColor Red }
if (!$catalystName) { Write-Host 'variable $catalystName is null' ; Exit }           else { Write-Host '  catalystName........: '$catalystName -ForegroundColor Cyan }
if (!$sharedKey) { Write-Host 'variable $sharedKey is null' ; Exit }                 else { Write-Host '  sharedKey...........: '$sharedKey -ForegroundColor Cyan }
if (!$vpnGatewayName) { Write-Host 'variable $vpnGatewayName is null' ; Exit }       else { Write-Host '  vpnGatewayName......: '$vpnGatewayName -ForegroundColor Cyan }


# Collect information 
#   $localGatewayIpAddress1
#   $localGatewayIpAddress2
#   $bgpPeeringAddress1
#   $bgpPeeringAddress2
$catalystIPAddress1Name = $catalystName + '-pubIP3' 
$catalystIPAddress2Name = $catalystName + '-pubIP4' 
$bgpPeeringAddress1 = '172.168.0.1'
$bgpPeeringAddress2 = '172.168.0.2'

try {
     $catalystIPAddress1 = Get-AzPublicIpAddress -Name $catalystIPAddress1Name -ResourceGroupName $rgName -ErrorAction Stop
     $localGatewayIpAddress1 = $catalystIPAddress1.IpAddress
     if ($localGatewayIpAddress1) {
          write-host "Catalyst public IP1: "$catalystIPAddress1.IpAddress -ForegroundColor Cyan 
     }
} 
catch {
     write-host "Catalyst public IP1 not found:" -ForegroundColor Yellow 
     write-host "  -check the resource group........: "$rgName  -ForegroundColor Yellow
     write-host "  -check the Catalyst public IP1...: "$catalystIPAddress1Name -ForegroundColor Yellow
     Exit
}
try {
     $catalystIPAddress2 = Get-AzPublicIpAddress -Name $catalystIPAddress2Name -ResourceGroupName $rgName -ErrorAction Stop
     $localGatewayIpAddress2 = $catalystIPAddress2.IpAddress
     if ($localGatewayIpAddress2) {
          write-host "Catalyst public IP2: "$catalystIPAddress2.IpAddress -ForegroundColor Cyan 
     }
} 
catch {
     write-host "Catalyst public IP1 not found:" -ForegroundColor Yellow 
     write-host "  -check the resource group........: "$rgName  -ForegroundColor Yellow
     write-host "  -check the Catalyst public IP1...: "$catalystIPAddress2Name -ForegroundColor Yellow
     Exit
}


$parameters = @{
     "location"               = $location;
     "localGatewayIpAddress1" = $localGatewayIpAddress1;
     "localGatewayIpAddress2" = $localGatewayIpAddress2;
     "adminUsername"          = $adminUsername;
     "adminPassword"          = $adminPassword;
     "gatewayName"            = $vpnGatewayName;
     "sharedKey"              = $sharedKey
}

Write-Host 'variable $paramenters:' 
write-host $parameters


$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# Create Resource Group
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating Resource Group' -ForegroundColor Cyan
Try {
     Get-AzResourceGroup -Name $rgName -ErrorAction Stop
     Write-Host 'Resource exists, skipping'
}
Catch { New-AzResourceGroup -Name $rgName -Location $location }


$StartTime = Get-Date
Write-Host "$StartTime - ARM template:"$templateFile -ForegroundColor Yellow
New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$RunTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
Write-Host "runtime: $RunTime" -ForegroundColor Yellow

write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime -ForegroundColor Yellow
write-host "end time..: "$(Get-Date) -ForegroundColor Yellow