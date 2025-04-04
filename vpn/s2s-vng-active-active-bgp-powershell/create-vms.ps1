###
### powershell script to create Azure VNet and Azure VM
### The script uses two powershell functions to create VNet and Azure VM
### when the function to create the VM is invokes, it checkes the existance of the Azure VNet. if the Azure VNet doesn't exist, the script create it.
###
### Customize your script- 
### in the section
### 
###  adminUsername = 'ADMINISTRATOR_USERNAME'
###  adminPassword = 'ADMINISTRATOR_PASSWORD'
###
### replace ADMINISTRATOR_USERNAME with the administrator username of the Azure VM
### replace ADMINISTRATOR_PASSWORD with the administrator username of the Azure VM
###
###
###
## function to create the Azure VM ##
Function CreateVM() {
  param(
    [hashtable] $source
  )

  $rgName = $source['rgName']
  $location = $source['location']
  $vnetName = $source['vnetName']
  $subnet1Name = $source['subnet1Name']
  $subnet2Name = $source['subnet2Name']
  $addrPrefix = $source['addrPrefix']
  $subnet1Prefix = $source['subnet1Prefix']
  $subnet2Prefix = $source['subnet2Prefix']
  $publisher = $source['publisher']
  $offer = $source['offer']
  $sku = $source['sku']
  $version = $source['version']
  $vmSize = $source['vmSize']
  $vmName = $source['vmName']
  $adminUsername = $source['adminUsername']
  $adminPassword = $source['adminPassword']

  $vmPubIP = $vmName + '-pubIP'
  $nicName = $vmName + '-nic'
  $nsgName = $vmName + '-nsg'

  ##Create resource Group ##
  Try {
    $rg = Get-AzResourceGroup -Name $rgName -ErrorAction Stop
    Write-Host "Resource group: $rgName exists, skipping"
  }
  Catch {
    $rg = New-AzResourceGroup -Name $rgName -Location $location
  }

  ## Create network security group ##
  $rule1 = New-AzNetworkSecurityRuleConfig -Name 'rule-SSH-in' -Description 'allow-SSH-in' `
    -Protocol '*' -SourcePortRange '*' -DestinationPortRange '22' -SourceAddressPrefix '*' -DestinationAddressPrefix '*' `
    -Access 'Allow' -Priority 100 -Direction 'Inbound'


  Write-Host "$(Get-Date) - Creating NSG: $nsgName "-ForegroundColor Cyan
  Try {
    $nsg = Get-AzNetworkSecurityGroup -Name 'nsgName' -ResourceGroupName $rgName -ErrorAction Stop 
    Write-Host "$(Get-Date) - NSG: $nsgName exists, skipping"
  }
  Catch {
    $nsg = New-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $rgName -Location $location -SecurityRules $rule1 -Force
  }

  Write-Host "$(Get-Date) - Creating public IP: $vmPubIP "-ForegroundColor Cyan
  Try {
    $vmPublicIP = Get-AzPublicIpAddress -ResourceGroupName $rgName -Name $vmPubIP -ErrorAction Stop
    Write-Host "$(Get-Date) - Public IP: $vmPubIP exists, skipping"
  }
  Catch {
    $vmPublicIP = 
    New-AzPublicIpAddress -Name $vmPubIP -ResourceGroupName  $rgName -Location $location -AllocationMethod Static -Sku Standard -Tier Regional -Zone 1,2,3
  }

  Try {
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName -ErrorAction Stop
    $subnet1 = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnet1Name -ErrorAction Stop
    $subnet2 = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnet2Name -ErrorAction Stop
    Write-Host "$(Get-Date) - vnet: $vnetName exists, skipping"
  }
  Catch {
    $subnetConfig1 = New-AzVirtualNetworkSubnetConfig -Name $subnet1Name -AddressPrefix $subnet1Prefix
    $subnetConfig2 = New-AzVirtualNetworkSubnetConfig -Name $subnet2Name -AddressPrefix $subnet2Prefix
    $vnet = New-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName -Location $location -AddressPrefix $addrPrefix -Subnet $subnetConfig1, $subnetConfig2
    Write-Host "$(Get-Date) - vnet: $vnetName created" -ForegroundColor Cyan
  }

  $vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName
  $subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnet1Name
  $nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $rgName

  Try {
    Write-Host "$(Get-Date) - creating NIC: $nicName" -ForegroundColor Cyan
    $vmNIC = Get-AzNetworkInterface -ResourceGroupName $rgName -Name $nicName -ErrorAction Stop 
    Write-Host "$(Get-Date) - NIC: $nicName exists, skipping"
  }
  Catch {
    $vmNIC = New-AzNetworkInterface -Name $nicName -ResourceGroupName $rgName -Location $location -Subnet $subnet -PublicIpAddress $vmPublicIP -NetworkSecurityGroup $nsg
  }

  Write-Host "$(Get-Date) - setting VM parameters" -ForegroundColor Cyan
  $adminSecurePassword = ConvertTo-SecureString -String $adminPassword -AsPlainText -Force
  $vmAdminCreds = New-Object System.Management.Automation.PSCredential( $adminUsername, $adminSecurePassword);

  $osDiskName = $vmName + "-OSdisk"
  $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize
  $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -ComputerName  $vmName -Credential $vmAdminCreds -Linux 
  $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName $publisher -Offer $offer -Skus $sku -Version $version
  $vmConfig = Set-AzVMOSDisk -VM $vmConfig -Name $osDiskName -CreateOption 'FromImage'
  $vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable
  $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $vmNIC.Id -Primary

  Try {
    Write-Host "$(Get-Date) - getting VM: $vmName" -ForegroundColor Cyan
    $vm = Get-AzVM -Name $vmName -ResourceGroupName $rgName -ErrorAction Stop 
    Write-Host "$(Get-Date) - VM: $vmName  exists, skipping"
  }
  Catch {
    Write-Host "$(Get-Date) - creating VM: $vmName" -ForegroundColor Cyan
    New-AzVM  -VM $vmConfig -ResourceGroupName $rgName -Location $location
    $vm = Get-AzVM -Name $vmName -ResourceGroupName $rgName
    Write-Host "$(Get-Date) - VM: " $vm.Name " has been deployed." -foreground Yellow
  }
}

# $inputParams: json file with list of input variables
$inputParams = 'init.json'

$pathFiles = Split-Path -Parent $PSCommandPath
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
    # Write-Output $message
    Try { New-Variable -Name $key -Value $hash[$key] -ErrorAction Stop }
    Catch { Set-Variable -Name $key -Value $hash[$key] }
  }
} 
else { Write-Warning "$inputParams file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }     else { Write-Host '  subscription name...: '$subscriptionName -ForegroundColor Yellow }
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit }   else { Write-Host '  resource group name.: '$ResourceGroupName -ForegroundColor Yellow }
if (!$location1) { Write-Host 'variable $location1 is null' ; Exit }                   else { Write-Host '  location1...........: '$location1 -ForegroundColor Yellow }
if (!$vnet1Name) { Write-Host 'variable $vnet1Name is null' ; Exit }                   else { Write-Host '  vnet1 Name..........: '$vnet1Name -ForegroundColor Yellow }
if (!$app1SubnetName) { Write-Host 'variable $app1SubnetName is null' ; Exit }         else { Write-Host '  app1SubnetName......: '$app1SubnetName -ForegroundColor Yellow }
if (!$vnet1Prefix) { Write-Host 'variable $vnet1Prefix is null' ; Exit }               else { Write-Host '  vnet1Prefix.........: '$vnet1Prefix -ForegroundColor Green }
if (!$app1SubnetPrefix) { Write-Host 'variable $app1SubnetPrefix is null' ; Exit }     else { Write-Host '  app1SubnetPrefix....: '$app1SubnetPrefix -ForegroundColor Green }
if (!$gw1SubnetPrefix) { Write-Host 'variable $gw1SubnetPrefix is null' ; Exit }       else { Write-Host '  gw1SubnetPrefix.....: '$gw1SubnetPrefix -ForegroundColor Green }
if (!$gw1Name) { Write-Host 'variable $gw1Name is null' ; Exit }                       else { Write-Host '  gw1Name.............: '$gw1Name -ForegroundColor Yellow }
if (!$location2) { Write-Host 'variable $location2 is null' ; Exit }                   else { Write-Host '  location2...........: '$location2 -ForegroundColor Yellow }
if (!$vnet2Name) { Write-Host 'variable $vnet2Name is null' ; Exit }                   else { Write-Host '  vnet2 Name..........: '$vnet2Name -ForegroundColor Yellow }
if (!$app2SubnetName) { Write-Host 'variable $app2SubnetName is null' ; Exit }         else { Write-Host '  app2SubnetName......: '$app2SubnetName -ForegroundColor Yellow }
if (!$vnet2Prefix) { Write-Host 'variable $vnet2Prefix is null' ; Exit }               else { Write-Host '  vnet2Prefix.........: '$vnet2Prefix -ForegroundColor Green }
if (!$app2SubnetPrefix) { Write-Host 'variable $app2SubnetPrefix is null' ; Exit }     else { Write-Host '  app2SubnetPrefix....: '$app2SubnetPrefix -ForegroundColor Green }
if (!$gw2SubnetPrefix) { Write-Host 'variable $gw2SubnetPrefix is null' ; Exit }       else { Write-Host '  gw2SubnetPrefix.....: '$gw2SubnetPrefix -ForegroundColor Green }
if (!$gw2Name) { Write-Host 'variable $gw2Name is null' ; Exit }                       else { Write-Host '  gw2Name.............: '$gw2Name -ForegroundColor Yellow }
if (!$vpnSku) { Write-Host 'variable $vpnSku is null' ; Exit }                         else { Write-Host '  vpnSku..............: '$vpnSku -ForegroundColor Yellow }
if (!$asn1) { Write-Host 'variable $asn1 is null' ; Exit }                             else { Write-Host '  asn1................: '$asn1 -ForegroundColor Yellow }
if (!$asn2) { Write-Host 'variable $asn2 is null' ; Exit }                             else { Write-Host '  asn2................: '$asn2 -ForegroundColor Yellow }
if (!$sharedKey) { Write-Host 'variable $sharedKey is null' ; Exit }                   else { Write-Host '  sharedKey...........: '$sharedKey -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }           else { Write-Host '  adminUsername.......: '$adminUsername -ForegroundColor Yellow }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }           else { Write-Host '  adminPassword.......: '$adminPassword -ForegroundColor Yellow }
if (!$vmPublisher) { Write-Host 'variable $vmPublisher is null' ; Exit }               else { Write-Host '  vmPublisher.........: '$vmPublisher -ForegroundColor Yellow }
if (!$vmOffer) { Write-Host 'variable $vmOffer is null' ; Exit }                       else { Write-Host '  vmOffer.............: '$vmOffer -ForegroundColor Yellow }
if (!$vmSKU) { Write-Host 'variable $vmSKU is null' ; Exit }                           else { Write-Host '  vmSKU...............: '$vmSKU -ForegroundColor Yellow }
if (!$vmVersion) { Write-Host 'variable $vmVersion is null' ; Exit }                   else { Write-Host '  vmVersion...........: '$vmVersion -ForegroundColor Yellow }
if (!$vmSize) { Write-Host 'variable $vmSize is null' ; Exit }                         else { Write-Host '  vmSize..............: '$vmSize -ForegroundColor Yellow }

$rgName = $ResourceGroupName  


## qualification values of the Azure VM ##
$vm1 = @{
  rgName        = $rgName  
  location      = $location1
  vnetName      = $vnet1Name
  subnet1Name   = $app1SubnetName
  subnet2Name   = 'GatewaySubnet'
  addrPrefix    = $vnet1Prefix
  subnet1Prefix = $app1SubnetPrefix
  subnet2Prefix = $gw1SubnetPrefix
  publisher     = $vmPublisher
  offer         = $vmOffer
  sku           = $vmSKU
  version       = $vmVersion
  vmSize        = $vmSize
  vmName        = 'vm1'
  adminUsername = $adminUsername
  adminPassword = $adminPassword
}
CreateVM($vm1)

Write-Host "$(Get-Date) - invoke RunAs command in the VM: "$vm1.vmName -ForegroundColor Cyan
Start-Sleep -Seconds 10
Invoke-AzVMRunCommand -ResourceGroupName $rgName -Name $vm1.vmName  -CommandId 'RunShellScript' -ScriptPath "$pathFiles\iperf3.sh"

$vm2 = @{
  rgName        = $rgName  
  location      = $location2
  vnetName      = $vnet2Name
  subnet1Name   = $app2SubnetName
  subnet2Name   = 'GatewaySubnet'
  addrPrefix    = $vnet2Prefix
  subnet1Prefix = $app2SubnetPrefix
  subnet2Prefix = $gw2SubnetPrefix
  publisher     = $vmPublisher
  offer         = $vmOffer
  sku           = $vmSKU
  version       = $vmVersion
  vmSize        = $vmSize
  vmName        = 'vm2'
  adminUsername = $adminUsername
  adminPassword = $adminPassword
}
CreateVM($vm2)

Write-Host "$(Get-Date) - invoke RunAs command in the VM: "$vm2.vmName -ForegroundColor Cyan
Start-Sleep -Seconds 10
Invoke-AzVMRunCommand -ResourceGroupName $rgName -Name $vm2.vmName  -CommandId 'RunShellScript' -ScriptPath "$pathFiles\iperf3.sh"

