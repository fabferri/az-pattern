###
### powershell script to create Azure VNet and Azure VM
### The script uses two powershell functions to create VNet and Azure VM
### when the function to create the VM is invokes, it checkes the existance of the Azure VNet. if the Azure VNet doesn't exist, the script create it.
###
### the variables used in the script are read from the file init.json
### the file init.json must contain the following variables:
###    "subscriptionName": "SUBSCRITION_NAME_GOES_HERE",
###    "rgName": "RESOURCE_GROUP_NAME_GOES_HERE",
###    "location": "LOCATION_GOES_HERE",
###    "adminUsername": "ADMINISTRATOR_USERNAME_GOES_HERE",
###    "adminPassword": "ADMINISTRATOR_PASSWORD_GOES_HERE"
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
        $vmPublicIP = New-AzPublicIpAddress -Name $vmPubIP -ResourceGroupName  $rgName -Location $location -AllocationMethod Static -Sku Standard -Tier Regional -Zone 1, 2, 3
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
        # Create IPv4 IP configuration (Primary)
        $ipConfig1 = New-AzNetworkInterfaceIpConfig -Name "ipconfig-ipv4" -Subnet $subnet -PublicIpAddress $vmPublicIP -Primary
        
        # Create IPv6 IP configuration
        $ipConfig2 = New-AzNetworkInterfaceIpConfig -Name "ipconfig-ipv6" -Subnet $subnet -PrivateIpAddressVersion IPv6
        
        # Create NIC with both IPv4 and IPv6 configurations
        $vmNIC = New-AzNetworkInterface -Name $nicName -ResourceGroupName $rgName -Location $location -IpConfiguration $ipConfig1, $ipConfig2 -NetworkSecurityGroup $nsg
    }

    Write-Host "$(Get-Date) - setting VM parameters" -ForegroundColor Cyan
    $adminSecurePassword = ConvertTo-SecureString -String $adminPassword -AsPlainText -Force
    $vmAdminCreds = New-Object System.Management.Automation.PSCredential( $adminUsername, $adminSecurePassword);

    $osDiskName = $vmName + "-OSdisk"
    $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize
    $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -ComputerName  $vmName -Credential $vmAdminCreds -Linux 
    $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName $publisher -Offer $offer -Skus $sku -Version $version
    $vmConfig = Set-AzVMOSDisk -VM $vmConfig -Name $osDiskName -CreateOption 'FromImage' -DeleteOption 'Delete'
    $vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable
    $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $vmNIC.Id -Primary -DeleteOption 'Delete'

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
} ## end of function CreateVM ##

################### start of the main script ###################
$pathFiles = Split-Path -Parent $PSCommandPath
$inputParams = 'init.json'
$inputParamsFile = "$pathFiles\$inputParams"


$vnet1Name = "vnet1"
$vnet1AddressPrefix = "10.1.0.0/16", "fd:0:1::/48"
$vnet1subnet1Name = "subnet1" 
$gw1SubnetAddress = @("10.1.0.0/24", "fd:0:1:e::/64")
$vnet1subnet1Address = @("10.1.1.0/24", "fd:0:1:1::/64")

$vnet2Name = "on-prem-vnet2"
$vnet2AddressPrefix = @("10.2.0.0/16", "fd:0:2::/48","fd:0:3::/48")
$vnet2subnet1Name = "subnet1" 
$gw2SubnetAddress = @("10.2.0.0/24", "fd:0:2:e::/64")
$vnet2subnet1Address = @("10.2.1.0/24", "fd:0:2:1::/64")


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
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '  subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                       else { Write-Host '  resource group name...: '$rgName -ForegroundColor Yellow }    
if (!$location) { Write-Host 'variable $location is null' ; Exit }                   else { Write-Host '  location..............: '$location -ForegroundColor Yellow }
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }         else { Write-Host '  adminUsername.........: '$adminUsername -ForegroundColor Yellow }
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }         else { Write-Host '  adminPassword.........: '$adminPassword -ForegroundColor Yellow }

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id


## qualification values of the Azure VM ##
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

## input values of the Azure VM ##
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


