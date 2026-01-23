# Script to create Azure VNet and Azure VM
# Azure CLI version
#
# The script uses a PowerShell function to create VNet and Azure VM
# When the function is invoked, it checks the existence of the Azure VNet. If it doesn't exist, the script creates it.
#
# The variables used in the script are read from the file init.json
# The file init.json must contain the following variables:
#    "subscriptionName": "SUBSCRIPTION_NAME_GOES_HERE",
#    "rgName": "RESOURCE_GROUP_NAME_GOES_HERE",
#    "location": "LOCATION_GOES_HERE",
#    "adminUsername": "ADMINISTRATOR_USERNAME_GOES_HERE",
#    "adminPassword": "ADMINISTRATOR_PASSWORD_GOES_HERE"
#

## Function to create the Azure VM ##
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

    ## Create resource Group ##
    $rgExists = az group exists --name $rgName
    if ($rgExists -eq "true") {
        Write-Host "Resource group: $rgName exists, skipping"
    }
    else {
        az group create --name $rgName --location $location
    }

    ## Create network security group ##
    Write-Host "$(Get-Date) - Creating NSG: $nsgName" -ForegroundColor Cyan
    $nsgExists = az network nsg show --name $nsgName --resource-group $rgName --query "name" -o tsv 2>$null
    if ($nsgExists) {
        Write-Host "$(Get-Date) - NSG: $nsgName exists, skipping"
    }
    else {
        az network nsg create `
            --name $nsgName `
            --resource-group $rgName `
            --location $location

        az network nsg rule create `
            --name 'rule-SSH-in' `
            --nsg-name $nsgName `
            --resource-group $rgName `
            --priority 100 `
            --direction Inbound `
            --access Allow `
            --protocol '*' `
            --source-port-ranges '*' `
            --destination-port-ranges 22 `
            --source-address-prefixes '*' `
            --destination-address-prefixes '*' `
            --description 'allow-SSH-in'
    }

    ## Create public IP ##
    Write-Host "$(Get-Date) - Creating public IP: $vmPubIP" -ForegroundColor Cyan
    $pipExists = az network public-ip show --name $vmPubIP --resource-group $rgName --query "name" -o tsv 2>$null
    if ($pipExists) {
        Write-Host "$(Get-Date) - Public IP: $vmPubIP exists, skipping"
    }
    else {
        az network public-ip create `
            --name $vmPubIP `
            --resource-group $rgName `
            --location $location `
            --allocation-method Static `
            --sku Standard `
            --tier Regional `
            --zone 1 2 3
    }

    ## Create VNet if it doesn't exist ##
    $vnetExists = az network vnet show --name $vnetName --resource-group $rgName --query "name" -o tsv 2>$null
    if ($vnetExists) {
        Write-Host "$(Get-Date) - vnet: $vnetName exists, skipping"
    }
    else {
        Write-Host "$(Get-Date) - Creating vnet: $vnetName" -ForegroundColor Cyan
        az network vnet create `
            --name $vnetName `
            --resource-group $rgName `
            --location $location `
            --address-prefixes $addrPrefix

        az network vnet subnet create `
            --name $subnet1Name `
            --vnet-name $vnetName `
            --resource-group $rgName `
            --address-prefixes $subnet1Prefix

        az network vnet subnet create `
            --name $subnet2Name `
            --vnet-name $vnetName `
            --resource-group $rgName `
            --address-prefixes $subnet2Prefix

        Write-Host "$(Get-Date) - vnet: $vnetName created" -ForegroundColor Cyan
    }

    ## Create NIC with dual-stack (IPv4 and IPv6) ##
    Write-Host "$(Get-Date) - Creating NIC: $nicName" -ForegroundColor Cyan
    $nicExists = az network nic show --name $nicName --resource-group $rgName --query "name" -o tsv 2>$null
    if ($nicExists) {
        Write-Host "$(Get-Date) - NIC: $nicName exists, skipping"
    }
    else {
        # Create NIC with primary IPv4 configuration
        az network nic create `
            --name $nicName `
            --resource-group $rgName `
            --location $location `
            --vnet-name $vnetName `
            --subnet $subnet1Name `
            --network-security-group $nsgName `
            --public-ip-address $vmPubIP

        # Add IPv6 IP configuration to the NIC
        az network nic ip-config create `
            --name "ipconfig-ipv6" `
            --nic-name $nicName `
            --resource-group $rgName `
            --private-ip-address-version IPv6 `
            --vnet-name $vnetName `
            --subnet $subnet1Name
    }

    ## Create VM ##
    Write-Host "$(Get-Date) - Checking VM: $vmName" -ForegroundColor Cyan
    $vmExists = az vm show --name $vmName --resource-group $rgName --query "name" -o tsv 2>$null
    if ($vmExists) {
        Write-Host "$(Get-Date) - VM: $vmName exists, skipping"
    }
    else {
        Write-Host "$(Get-Date) - Creating VM: $vmName" -ForegroundColor Cyan
        $imageUrn = "${publisher}:${offer}:${sku}:${version}"
        
        az vm create `
            --name $vmName `
            --resource-group $rgName `
            --location $location `
            --nics $nicName `
            --image $imageUrn `
            --size $vmSize `
            --admin-username $adminUsername `
            --admin-password $adminPassword `
            --authentication-type password `
            --os-disk-delete-option Delete `
            --nic-delete-option Delete

        Write-Host "$(Get-Date) - VM: $vmName has been deployed." -ForegroundColor Yellow
    }
} ## end of function CreateVM ##

################### start of the main script ###################
$pathFiles = Split-Path -Parent $PSCommandPath
$inputParams = 'init.json'
$inputParamsFile = "$pathFiles\$inputParams"

$vnet1Name = "vnet1"
$vnet1AddressPrefix = "10.1.0.0/16 fd:0:1::/48"
$vnet1subnet1Name = "subnet1"
$gw1SubnetAddress = "10.1.0.0/24 fd:0:1:e::/64"
$vnet1subnet1Address = "10.1.1.0/24 fd:0:1:1::/64"

$vnet2Name = "on-prem-vnet2"
$vnet2AddressPrefix = "10.2.0.0/16 fd:0:2::/48 fd:0:3::/48"
$vnet2subnet1Name = "subnet1"
$gw2SubnetAddress = "10.2.0.0/24 fd:0:2:e::/64"
$vnet2subnet1Address = "10.2.1.0/24 fd:0:2:1::/64"

$vmPublisher = "canonical"
$vmOffer = "ubuntu-24_04-lts"
$vmSKU = "server"
$vmVersion = "latest"
$vmSize = "Standard_B2s"

try {
    $arrayParams = (Get-Content -Raw $inputParamsFile | ConvertFrom-Json)
    $subscriptionName = $arrayParams.subscriptionName
    $rgName = $arrayParams.rgName
    $location = $arrayParams.location
    $adminUsername = $arrayParams.adminUsername
    $adminPassword = $arrayParams.adminPassword
}
catch {
    Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
    Exit
}

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit } else { Write-Host '  subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                     else { Write-Host '  resource group name...: '$rgName -ForegroundColor Yellow }
if (!$location) { Write-Host 'variable $location is null' ; Exit }                 else { Write-Host '  location..............: '$location -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }       else { Write-Host '  adminUsername.........: '$adminUsername -ForegroundColor Yellow }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }       else { Write-Host '  adminPassword.........: '$adminPassword -ForegroundColor Yellow }

# Set the subscription
az account set --subscription $subscriptionName

## VM1 configuration ##
$vm1 = @{
    rgName        = $rgName
    location      = $location
    vnetName      = $vnet1Name
    subnet1Name   = $vnet1subnet1Name
    subnet2Name   = 'GatewaySubnet'
    addrPrefix    = $vnet1AddressPrefix
    subnet1Prefix = $vnet1subnet1Address
    subnet2Prefix = $gw1SubnetAddress
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

## VM2 configuration ##
$vm2 = @{
    rgName        = $rgName
    location      = $location
    vnetName      = $vnet2Name
    subnet1Name   = $vnet2subnet1Name
    subnet2Name   = 'GatewaySubnet'
    addrPrefix    = $vnet2AddressPrefix
    subnet1Prefix = $vnet2subnet1Address
    subnet2Prefix = $gw2SubnetAddress
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

Write-Host "$(Get-Date) - All VMs created successfully" -ForegroundColor Green
