#
#  the script reads the ipunt variables in init.json file.
#
################# Input parameters #################
$deploymentName = 'vpn_connections'
$armTemplateFile = '02-vpn-conns.json'
$inputParams = 'init.json'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"

# reading the input parameter file $inputParams and convert the values in hashtable 
If (Test-Path -Path $pathFiles\$inputParams) {
     # convert the json into PSCustomObject
     $jsonObj = Get-Content -Raw $pathFiles\$inputParams | ConvertFrom-Json
     if ($null -eq $jsonObj) {
          Write-Host "file $inputParams is empty"
          Exit
     }
     # convert the PSCustomObject in hashtable
     if ($jsonObj -is [psobject]) {
          $hash = @{}
          foreach ($property in $jsonObj.PSObject.Properties) {
               $hash[$property.Name] = $property.Value
          }
     }
     foreach ($key in $hash.keys) {
          $message = '{0} = {1} ' -f $key, $hash[$key]
          Write-Output $message
          Try { New-Variable -Name $key -Value $hash[$key] -ErrorAction Stop }
          Catch { Set-Variable -Name $key -Value $hash[$key] }
     }
} 
else { Write-Warning "$inputParams file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

# checking the values of variables
Write-Host ""
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit } else { Write-Host '   administrator username.: '$adminUsername -ForegroundColor Green }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit } else { Write-Host '   administrator password.: '$adminPassword -ForegroundColor Green }
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit } else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit } else { Write-Host '   resource group name...: '$ResourceGroupName -ForegroundColor Yellow }
if (!$RGTagExpireDate) { Write-Host 'variable $RGTagExpireDate is null' ; Exit } else { Write-Host '   RGTagExpireDate.......: '$RGTagExpireDate -ForegroundColor Yellow }
if (!$RGTagContact) { Write-Host 'variable $RGTagContact is null' ; Exit } else { Write-Host '   RGTagContact..........: '$RGTagContact -ForegroundColor Yellow }
if (!$RGTagNinja) { Write-Host 'variable $RGTagNinja is null' ; Exit } else { Write-Host '   RGTagNinja............: '$RGTagNinja -ForegroundColor Yellow }
if (!$RGTagUsage) { Write-Host 'variable $RGTagUsage is null' ; Exit } else { Write-Host '   RGTagUsage............: '$RGTagUsage -ForegroundColor Yellow }

if (!$rgName_erCircuit1) { Write-Host 'variable $rgName_erCircuit1 is null' ; Exit } else { Write-Host '   $rgName_erCircuit1....: '$rgName_erCircuit1 -ForegroundColor Yellow }
if (!$erCircuit1Name) { Write-Host 'variable $erCircuit1Name is null' ; Exit } else { Write-Host '   $erCircuit1Name.......: '$erCircuit1Name -ForegroundColor Yellow }
if (!$erConnection1Name) { Write-Host 'variable $erConnection1Name is null' ; Exit } else { Write-Host '   $erConnection1Name....: '$erConnection1Name -ForegroundColor Yellow }
if (!$location1) { Write-Host 'variable $location1 is null' ; Exit } else { Write-Host '   location1.............: '$location1 -ForegroundColor Yellow }
if (!$location2) { Write-Host 'variable $location2 is null' ; Exit } else { Write-Host '   location2.............: '$location2 -ForegroundColor Yellow }
if (!$vNet1Name) { Write-Host 'variable $vNet1Name is null' ; Exit } else { Write-Host '   vNet1Name.............: '$vNet1Name -ForegroundColor Yellow }
if (!$vNet2Name) { Write-Host 'variable $vNet2Name is null' ; Exit } else { Write-Host '   vNet2Name.............: '$vNet2Name -ForegroundColor Yellow }
if (!$vNet1AddressPrefix) { Write-Host 'variable $vNet1AddressPrefix is null' ; Exit } else { Write-Host '   vNet1AddressPrefix....: '$vNet1AddressPrefix -ForegroundColor Yellow }
if (!$vNet2AddressPrefix) { Write-Host 'variable $vNet2AddressPrefix is null' ; Exit } else { Write-Host '   vNet2AddressPrefix....: '$vNet2AddressPrefix -ForegroundColor Yellow }
if (!$vnet1subnet1Name) { Write-Host 'variable $vnet1subnet1Name is null' ; Exit } else { Write-Host '   vnet1subnet1Name......: '$vnet1subnet1Name -ForegroundColor Yellow }
if (!$vnet2subnet1Name) { Write-Host 'variable $vnet2subnet1Name is null' ; Exit } else { Write-Host '   vnet2subnet1Name......: '$vnet2subnet1Name -ForegroundColor Yellow }
if (!$vnet1subnet1Prefix) { Write-Host 'variable $vnet1subnet1Prefix is null' ; Exit } else { Write-Host '   vnet1subnet1Prefix....: '$vnet1subnet1Prefix -ForegroundColor Yellow }
if (!$gateway1subnetPrefix) { Write-Host 'variable $gateway1subnetPrefix is null' ; Exit } else { Write-Host '   gateway1subnetPrefix..: '$gateway1subnetPrefix -ForegroundColor Yellow }
if (!$vnet2subnet1Prefix) { Write-Host 'variable $vnet2subnet1Prefix is null' ; Exit } else { Write-Host '   vnet2subnet1Prefix....: '$vnet2subnet1Prefix -ForegroundColor Yellow }
if (!$gateway2subnetPrefix) { Write-Host 'variable $gateway2subnetPrefix is null' ; Exit } else { Write-Host '   gateway2subnetPrefix..: '$gateway2subnetPrefix -ForegroundColor Yellow }
if (!$erGateway1Name) { Write-Host 'variable $erGateway1Name is null' ; Exit } else { Write-Host '   erGateway1Name........: '$erGateway1Name -ForegroundColor Yellow }
if (!$erGateway1PublicIP1Name) { Write-Host 'variable $erGateway1PublicIP1Name is null' ; Exit } else { Write-Host '   erGateway1PublicIP1Name: '$erGateway1PublicIP1Name -ForegroundColor Yellow }
if (!$vpnGateway1Name) { Write-Host 'variable $vpnGateway1Name is null' ; Exit } else { Write-Host '   vpnGateway1Name.........: '$vpnGateway1Name -ForegroundColor Cyan }
if (!$vpnGateway2Name) { Write-Host 'variable $vpnGateway2Name is null' ; Exit } else { Write-Host '   vpnGateway2Name.........: '$vpnGateway2Name -ForegroundColor Cyan }
if (!$vpnGateway1PublicIP1Name) { Write-Host 'variable $vpnGateway1PublicIP1Name is null' ; Exit } else { Write-Host '   vpnGateway1PublicIP1Name: '$vpnGateway1PublicIP1Name -ForegroundColor Cyan }
if (!$vpnGateway1PublicIP2Name) { Write-Host 'variable $vpnGateway1PublicIP2Name is null' ; Exit } else { Write-Host '   vpnGateway1PublicIP2Name: '$vpnGateway1PublicIP2Name -ForegroundColor Cyan }
if (!$vpnGateway2PublicIP1Name) { Write-Host 'variable $vpnGateway2PublicIP1Name is null' ; Exit } else { Write-Host '   vpnGateway2PublicIP1Name: '$vpnGateway2PublicIP1Name -ForegroundColor Cyan }
if (!$vpnGateway2PublicIP2Name) { Write-Host 'variable $vpnGateway2PublicIP2Name is null' ; Exit } else { Write-Host '   vpnGateway2PublicIP2Name: '$vpnGateway2PublicIP2Name -ForegroundColor Cyan }
if (!$erGatewaySku) { Write-Host 'variable $erGatewaySku is null' ; Exit } else { Write-Host '   erGatewaySku............: '$erGatewaySku -ForegroundColor Cyan }
if (!$vpnGatewaySku) { Write-Host 'variable $vpnGatewaySku is null' ; Exit } else { Write-Host '   vpnGatewaySku...........: '$vpnGatewaySku -ForegroundColor Cyan }
if (!$localGatewayName11) { Write-Host 'variable $localGatewayName11 is null' ; Exit } else { Write-Host '   localGatewayName11......: '$localGatewayName11 -ForegroundColor Cyan }
if (!$localGatewayName12) { Write-Host 'variable $localGatewayName12 is null' ; Exit } else { Write-Host '   localGatewayName12......: '$localGatewayName12 -ForegroundColor Cyan }
if (!$localGatewayName21) { Write-Host 'variable $localGatewayName21 is null' ; Exit } else { Write-Host '   localGatewayName21......: '$localGatewayName21 -ForegroundColor Cyan }
if (!$localGatewayName22) { Write-Host 'variable $localGatewayName22 is null' ; Exit } else { Write-Host '   localGatewayName22......: '$localGatewayName22 -ForegroundColor Cyan }
if (!$connectionName11_21) { Write-Host 'variable $connectionName11_21 is null' ; Exit } else { Write-Host '   connectionName11_21.....: '$connectionName11_21 -ForegroundColor Cyan }
if (!$connectionName12_22) { Write-Host 'variable $connectionName12_22 is null' ; Exit } else { Write-Host '   connectionName12_22.....: '$connectionName12_22 -ForegroundColor Cyan }
if (!$connectionName21_11) { Write-Host 'variable $connectionName21_11 is null' ; Exit } else { Write-Host '   connectionName21_11.....: '$connectionName21_11 -ForegroundColor Cyan }
if (!$connectionName22_12) { Write-Host 'variable $connectionName22_12 is null' ; Exit } else { Write-Host '   connectionName22_12.....: '$connectionName22_12 -ForegroundColor Cyan }
if (!$sharedKey) { Write-Host 'variable $sharedKey is null' ; Exit } else { Write-Host '   sharedKey...............: '$sharedKey -ForegroundColor Cyan }
if (!$vm1Name) { Write-Host 'variable $vm1Name is null' ; Exit } else { Write-Host '   vm1Name.................: '$vm1Name -ForegroundColor White }
if (!$vm2Name) { Write-Host 'variable $vm2Name is null' ; Exit } else { Write-Host '   vm2Name.................: '$vm2Name -ForegroundColor White }





$rgName = $ResourceGroupName

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


$parameters = @{
     "location1"                = $location1;
     "location2"                = $location2;
     "vNet1Name"                = $vNet1Name;
     "vNet2Name"                = $vNet2Name;
     "vNet1AddressPrefix"       = $vNet1AddressPrefix;
     "vNet2AddressPrefix"       = $vNet2AddressPrefix;
     "vnet1subnet1Name"         = $vnet1subnet1Name;
     "vnet2subnet1Name"         = $vnet2subnet1Name;
     "vnet1subnet1Prefix"       = $vnet1subnet1Prefix;
     "gateway1subnetPrefix"     = $gateway1subnetPrefix;
     "vnet2subnet1Prefix"       = $vnet2subnet1Prefix;
     "gateway2subnetPrefix"     = $gateway2subnetPrefix;
     "vpnGateway1Name"          = $vpnGateway1Name;
     "vpnGateway2Name"          = $vpnGateway2Name;
     "vpnGateway1PublicIP1Name" = $vpnGateway1PublicIP1Name;
     "vpnGateway1PublicIP2Name" = $vpnGateway1PublicIP2Name;
     "vpnGateway2PublicIP1Name" = $vpnGateway2PublicIP1Name;
     "vpnGateway2PublicIP2Name" = $vpnGateway2PublicIP2Name;
     "vpnGatewaySku"            = $vpnGatewaySku;
     "localGatewayName11"       = $localGatewayName11;
     "localGatewayName12"       = $localGatewayName12;
     "localGatewayName21"       = $localGatewayName21;
     "localGatewayName22"       = $localGatewayName22;
     "connectionName11-21"      = $connectionName11_21;
     "connectionName12-22"      = $connectionName12_22;
     "connectionName21-11"      = $connectionName21_11;
     "connectionName22-12"      = $connectionName22_12;
     "sharedKey"                = $sharedKey
}


$location = $location1
# Create Resource Group
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating Resource Group' -ForegroundColor Cyan
Try {
     $rg = Get-AzResourceGroup -Name $rgName -ErrorAction Stop
     Write-Host 'Resource exists, skipping'
}
Catch { $rg = New-AzResourceGroup -Name $rgName -Location $location }


# set a tag on the resource group if it doesn't exist.
if ((Get-AzResourceGroup -Name $rgName).Tags -eq $null) {
     # Add Tag Values to the Resource Group
     Set-AzResourceGroup -Name $rgName -Tag @{Expires = $RGTagExpireDate; Contacts = $RGTagContact; Pathfinder = $RGTagNinja; Usage = $RGTagUsage } | Out-Null
}

$startTime = "$(Get-Date)"
$runTime = Measure-Command {
     write-host "running ARM template:"$templateFile
     New-AzResourceGroupDeployment  -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 
}
 
write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime -ForegroundColor Yellow
write-host "endt time.: "$(Get-Date) -ForegroundColor Yellow







