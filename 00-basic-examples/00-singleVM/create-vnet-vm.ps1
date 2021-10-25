###
### powershell script to create Azure VNet and Azure VM
###
### Customize your script by assigment of right values to the variables
### 
###  $adminUsername = 'ADMINISTRATOR_USERNAME'
###  $adminPassword = 'ADMINISTRATOR_PASSWORD'
###  
### replace ADMINISTRATOR_USERNAME with the administrator username of the Azure VM
### replace ADMINISTRATOR_PASSWORD with the administrator username of the Azure VM
###
###
$subscriptionName = 'AzDev'
$rgName = 'test1'
$location = 'UK South'
$vnetName = 'vnet1'
$subnet1Name = 'subnet1'
$subnet2Name = 'subnet2'
$addrPrefix  = '10.0.0.0/16'
$subnet1Prefix = '10.0.1.0/24'
$subnet2Prefix = '10.0.2.0/24'
$publisher = 'canonical'
$offer = '0001-com-ubuntu-server-focal'
$sku = '20_04-lts'
$version = 'latest'
$vmSize  = 'Standard_B1s'
$vmName = 'vm'
$vmPubIP = 'vm-pubIP'
$nicName= 'vm-nic'
$nsgName = 'vm-nsg'
$adminUsername = 'ADMINISTRATOR_USERNAME'
$adminPassword = 'ADMINISTRATOR_PASSWORD'
####################


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

##Create resource Group ##
Try {$rg = Get-AzResourceGroup -Name $rgName -ErrorAction Stop
    Write-Host 'Resource exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $rgName -Location $location}

$subnet1 = @{
    Name = $subnet1Name
    AddressPrefix = $subnet1Prefix
}

$subnetConfig1 = New-AzVirtualNetworkSubnetConfig @subnet1 

$subnet2 = @{
    Name = $subnet2Name
    AddressPrefix = $subnet2Prefix
}

$subnetConfig2 = New-AzVirtualNetworkSubnetConfig @subnet2 
$net = @{
    Name = $vnetName
    ResourceGroupName = $rgName
    Location = $location
    AddressPrefix = $addrPrefix
    Subnet = $subnetConfig1,$subnetConfig2
}
Write-Host "$(Get-Date) - Creating vnet: $vnetName" -ForegroundColor Cyan
Try {
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName -ErrorAction Stop
    Write-Host "$(Get-Date) - vnet already exists, skipping"
    }
Catch {
    $vnet = New-AzVirtualNetwork @net
    }

## Create network security group ##
$nsgrule1 = @{
        Name = 'rule-SSH-in'
        Description = 'allow-SSH-in'
        Protocol = '*'
        SourcePortRange = '*'
        DestinationPortRange = '22'
        SourceAddressPrefix = '*'
        DestinationAddressPrefix = '*'
        Access = 'Allow'
        Priority = '100'
        Direction = 'Inbound'
    }
$rule1 = New-AzNetworkSecurityRuleConfig @nsgrule1

$nsg1 = @{
    Name = $nsgName
    ResourceGroupName = $rgName
    Location = $location
    SecurityRules = $rule1
}    

Write-Host "$(Get-Date) - Creating NSG: $nsgName" -ForegroundColor Cyan
Try {
    $nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $rgName -ErrorAction Stop
    Write-Host "$(Get-Date) - NSG exists, skipping"
    }
Catch {
    $nsg = New-AzNetworkSecurityGroup @nsg1
    }


$ip = @{
    Name = $vmPubIP
    ResourceGroupName = $rgName
    Location = $location
    Sku = 'Basic'
    AllocationMethod = 'Dynamic'
}

Write-Host "$(Get-Date) - Creating public IP: $vmPubIP" -ForegroundColor Cyan
Try {
     $vmPublicIP = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $vmPubIP -ErrorAction Stop
     Write-Host "$(Get-Date) - Public IP exists, skipping"
     }
Catch {
    $vmPublicIP = New-AzPublicIpAddress @ip
    }



$vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName
$subnet =  Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnet1Name
$nsg =  Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $rgName
$nic= @{
    Name = $nicName
    ResourceGroupName = $rgName
    Location = $location
    Subnet = $subnet
    PublicIpAddress = $vmPublicIP
    NetworkSecurityGroup = $nsg
}

Write-Host "$(Get-Date) - Creating NIC: $nicName" -ForegroundColor Cyan
Try {
    $vmNIC = Get-AzNetworkInterface -ResourceGroupName $rgName -Name $nicName -ErrorAction Stop 
     Write-Host "$(Get-Date) - NIC exists, skipping"
    }
Catch {
    $vmNIC = New-AzNetworkInterface @nic 
    }



$adminSecurePassword = ConvertTo-SecureString -String $adminPassword -AsPlainText -Force
$vmAdminCreds = New-Object System.Management.Automation.PSCredential( $adminUsername, $adminSecurePassword);

$osDiskName = $vmName +"-OSdisk"

$vmConf = @{
    VMName = $vmName
    VMSize = $vmSize
}
  
$vmConfig = New-AzVMConfig @vmConf
$vmOS= @{
    VM = $vmConfig
    ComputerName = $vmName 
    Credential = $vmAdminCreds
    Linux = $null
}
$vmConfig = Set-AzVMOperatingSystem @vmOS

$vmImage =@{
    VM = $vmConfig
    PublisherName = $publisher 
    Offer = $offer 
    Skus = $sku 
    Version = $version
}
$vmConfig = Set-AzVMSourceImage @vmImage
                      
$vmDisk = @{
    VM = $vmConfig
    Name = $osDiskName
    CreateOption = 'FromImage'
}
$vmConfig = Set-AzVMOSDisk @vmDisk
                
$vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable

$vmNetworkInterface = @{
    VM = $vmConfig
    Id = $vmNIC.Id
    Primary = $null
}

$vmConfig = Add-AzVMNetworkInterface  @vmNetworkInterface

New-AzVM  -VM $vmConfig `
            -ResourceGroupName $rgName `
            -Location $location


$vm = Get-AzVM -Name $vmName -ResourceGroupName $rgName 
write-host -foreground Yellow "VM:" $vm.Name "has been deployed."


Write-Host "$(Get-Date) - Creating vm: $vmName" -ForegroundColor Cyan
Try {
    $vm = Get-AzVM -Name $vmName -ResourceGroupName $rgName  -ErrorAction Stop 
     Write-Host "$(Get-Date) - vm exists, skipping"
    }
Catch {
    New-AzVM  -VM $vmConfig -ResourceGroupName $rgName -Location $location
    }