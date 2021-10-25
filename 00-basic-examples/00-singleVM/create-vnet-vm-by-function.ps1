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

## function to create the Azure VNet ##
Function CreateVNet(){
  param(
    [hashtable] $source
  )

## Create a resource Group ##
Try {$rg = Get-AzResourceGroup -Name $source['rgName'] -ErrorAction Stop
  Write-Host 'Resource exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $source['rgName'] -Location $source['location']}

$subnet1 = @{
  Name =  $source['subnet1Name']
  AddressPrefix =  $source['subnet1Prefix']
}

$subnetConfig1 = New-AzVirtualNetworkSubnetConfig @subnet1 

$subnet2 = @{
  Name =  $source['subnet2Name']
  AddressPrefix =  $source['subnet2Prefix']
}

$subnetConfig2 = New-AzVirtualNetworkSubnetConfig @subnet2 
$net = @{
  Name =  $source['vnetName']
  ResourceGroupName = $source['rgName']
  Location =  $source['location']
  AddressPrefix =  $source['addrPrefix']
  Subnet = $subnetConfig1,$subnetConfig2
}
Write-Host "$(Get-Date) - Creating vnet: $source['vnetName]" -ForegroundColor Cyan
Try {
  $vnet = Get-AzVirtualNetwork -ResourceGroupName $source['rgName'] -Name $source['vnetName'] -ErrorAction Stop
  Write-Host "$(Get-Date) - vnet already exists, skipping"
  }
Catch {
  $vnet = New-AzVirtualNetwork @net
  }

}

## function to create the Azure VM ##
Function CreateVM(){
  param(
    [hashtable] $source
  )

##Create resource Group ##
Try {$rg = Get-AzResourceGroup -Name $source['rgName'] -ErrorAction Stop
  Write-Host 'Resource exists, skipping'}
Catch {$rg = New-AzResourceGroup -Name $source['rgName'] -Location $location}


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
  Name =  $source['nsgName']
  ResourceGroupName = $source['rgName']
  Location = $source['location']
  SecurityRules = $rule1
}    

Write-Host "$(Get-Date) - Creating NSG: $source['nsgName']" -ForegroundColor Cyan
Try {
  $nsg = Get-AzNetworkSecurityGroup -Name $source['nsgName'] -ResourceGroupName $source['rgName'] -ErrorAction Stop
  Write-Host "$(Get-Date) - NSG exists, skipping"
  }
Catch {
  $nsg = New-AzNetworkSecurityGroup @nsg1
  }


$ip = @{
  Name =  $source['vmPubIP']
  ResourceGroupName =  $source['rgName']
  Location = $source['location']
  Sku = 'Basic'
  AllocationMethod = 'Dynamic'
}

Write-Host "$(Get-Date) - Creating public IP: $source['vmPubIP']" -ForegroundColor Cyan
Try {
   $vmPublicIP = Get-AzPublicIpAddress -ResourceGroupName $source['rgName'] -Name $source['vmPubIP'] -ErrorAction Stop
   Write-Host "$(Get-Date) - Public IP exists, skipping"
   }
Catch {
  $vmPublicIP = New-AzPublicIpAddress @ip
  }

Try {
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $source['rgName'] -Name $source['vnetName'] -ErrorAction Stop
    $subnet =  Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $source['subnet1Name'] -ErrorAction Stop
    Write-Host "$(Get-Date) - vnet exists, skipping"
    }
 Catch {
  $vnet_ = @{
    rgName = $source['rgName']
    location = $source['location']
    vnetName = $source['vnetName']
    subnet1Name = $source['subnet1Name']
    subnet2Name = $source['subnet2Name']
    addrPrefix  = $source['addrPrefix']
    subnet1Prefix = $source['subnet1Prefix']
    subnet2Prefix = $source['subnet2Prefix']
  }
  CreateVNet($vnet_)
}

$vnet = Get-AzVirtualNetwork -ResourceGroupName $source['rgName'] -Name $source['vnetName']
$subnet =  Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $source['subnet1Name']
$nsg =  Get-AzNetworkSecurityGroup -Name $source['nsgName'] -ResourceGroupName $source['rgName']
$nic= @{
  Name = $source['nicName']
  ResourceGroupName = $source['rgName']
  Location = $source['location']
  Subnet = $subnet
  PublicIpAddress = $vmPublicIP
  NetworkSecurityGroup = $nsg
}

Write-Host "$(Get-Date) - Creating NIC: $source['nicName']" -ForegroundColor Cyan
Try {
  $vmNIC = Get-AzNetworkInterface -ResourceGroupName $source['rgName'] -Name $source['nicName'] -ErrorAction Stop 
   Write-Host "$(Get-Date) - NIC exists, skipping"
  }
Catch {
  $vmNIC = New-AzNetworkInterface @nic 
  }

$adminSecurePassword = ConvertTo-SecureString -String $source['adminPassword'] -AsPlainText -Force
$vmAdminCreds = New-Object System.Management.Automation.PSCredential( $source['adminUsername'], $adminSecurePassword);

$osDiskName = $source['vmName'] +"-OSdisk"

$vmConf = @{
  VMName = $source['vmName']
  VMSize = $source['vmSize']
}

$vmConfig = New-AzVMConfig @vmConf
$vmOS= @{
  VM = $vmConfig
  ComputerName = $source['vmName']
  Credential = $vmAdminCreds
  Linux = $null
}
$vmConfig = Set-AzVMOperatingSystem @vmOS

$vmImage =@{
  VM = $vmConfig
  PublisherName = $source['publisher']
  Offer = $source['offer']
  Skus = $source['sku'] 
  Version = $source['version']
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


Try {
  $vm = Get-AzVM -Name $source['vmName'] -ResourceGroupName $source['rgName'] -ErrorAction Stop 
   Write-Host "$(Get-Date) - VM exists, skipping"
  }
Catch {
  New-AzVM  -VM $vmConfig `
          -ResourceGroupName $source['rgName'] `
          -Location $source['location']
  $vm = Get-AzVM -Name $source['vmName'] -ResourceGroupName $source['rgName'] 
  Write-Host -foreground Yellow "VM:" $vm.Name "has been deployed."
  }

}

## select Azure subscription ##
$subscriptionName = 'AzDev'
$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

## qualification values of the Azure VNet ##
$vnet1 = @{
  rgName = 'test1'
  location = 'UK South'
  vnetName = 'vnet1'
  subnet1Name = 'subnet1'
  subnet2Name = 'subnet2'
  addrPrefix  = '10.0.0.0/16'
  subnet1Prefix = '10.0.1.0/24'
  subnet2Prefix = '10.0.2.0/24'
}
CreateVNet($vnet1)

## qualification values of the Azure VM ##
$vm1 = @{
  rgName = 'test1'
  location = 'uksouth'
  vnetName = 'vnet1'
  subnet1Name = 'subnet1'
  subnet2Name = 'subnet2'
  addrPrefix  = '10.0.0.0/16'
  subnet1Prefix = '10.0.1.0/24'
  subnet2Prefix = '10.0.2.0/24'
  publisher = 'canonical'
  offer = '0001-com-ubuntu-server-focal'
  sku = '20_04-lts'
  version = 'latest'
  vmSize  = 'Standard_B1s'
  vmName = 'vm'
  vmPubIP = 'vm-pubIP'
  nicName= 'vm-nic'
  nsgName = 'vm-nsg'
  adminUsername = 'ADMINISTRATOR_USERNAME'
  adminPassword = 'ADMINISTRATOR_PASSWORD'
}
CreateVM($vm1)
