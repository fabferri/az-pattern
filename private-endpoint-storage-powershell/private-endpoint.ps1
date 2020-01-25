#
# Create a private endpoint to access to a storage account
# 
# At the end of execution of the script the private link is deployed.
# Connect to the VM, open a command shell and run the command:
#
#
# Example: nslookup <NAME_OF_STORAGE_ACCOUNT>.blob.core.windows.net
# C:\> nslookup strg91ef4365626a.blob.core.windows.net
# Server:  UnKnown
# Address:  168.63.129.16
#
# Non-authoritative answer:
# Name:     strg91ef4365626a.privatelink.blob.core.windows.net
# Address:  10.0.0.5
# Aliases:  strg91ef4365626a.blob.core.windows.net  
#
#
$subscriptionName='AzDev'               # Name of the Azure subscription
$rgName='privLink-2'                    # Name of the resource group
$location='eastus'                      # name of the Azure region
$vnetName='vnet1'                       # name of the azure vnet
$addrPrefix='10.0.0.0/24'               # address prefix of the Azure vnet
$subnetName='subnet1'                   # name of the subnet
$subnetAddrPrefix='10.0.0.0/26'         # address prefix of the subnet
$nsgName='nsg1'                         # name of the NSG associated wit the NIC of the VM
$vmName='vm1'                           # name of the Azure VM
$pubIPName_VM=$vmName+'-pubIP'          # name of the public IP associated to the VM
$adminUSername='ADMINISTRATOR_USERNAME' # Azure VM administrator username
$adminPwd='ADMININISTRATOR_PASSWORD'    # Azure VM administrator password
$storageAccountType='Standard_LRS'      # type of storage account
$vmSize='Standard_DS1_v2'               # size of the VM
$privateEndpointName='privEP-storage'   # name private endpoint
$autoregistration=$false                # boolean value: $true or $false
###$autoregistration=$true              # boolean value: $true or $false

# selection of Azure subscription ID
$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

#Create a resource group
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating Resource Group: $rgName " -ForegroundColor Cyan
Try {
    $rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
    Write-Host '  resource exists, skipping'
    }
Catch {
    $rg = New-AzResourceGroup -Name $rgName  -Location $location
    }


# Create a VNet
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating virtual network: $vnetName " -ForegroundColor Cyan
Try {
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName -ErrorAction Stop
        Write-Host "  resource exists, skipping"
    }
Catch {
        $vnet = New-AzVirtualNetwork -ResourceGroupName $rgName -Location $location -Name $vnetName -AddressPrefix $addrPrefix
        # add a subnet
        # subnet needs to have the private endpoint network policy flag set to Disabled!
        $subnetConfig = Add-AzVirtualNetworkSubnetConfig `
          -Name $subnetName `
          -AddressPrefix $subnetAddrPrefix `
          -PrivateEndpointNetworkPoliciesFlag "Disabled" `
          -VirtualNetwork $vnet

        # commit the subnet configuration to the vnet
        Set-AzVirtualNetwork -VirtualNetwork $vnet
    }

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating the network security group: $nsgName " -ForegroundColor Cyan

try{
   get-AzNetworkSecurityGroup -ResourceGroupName $rgName -Name $nsgName -ErrorAction Stop | Out-Null
}
catch {
   # Create an inbound network security group rule for port 3389
   $nsgRuleRDP = New-AzNetworkSecurityRuleConfig `
     -Name 'RDP-rule' `
     -Protocol Tcp `
     -Direction Inbound `
     -Priority 500 `
     -SourceAddressPrefix * `
     -SourcePortRange * `
     -DestinationAddressPrefix * `
     -DestinationPortRange 3389 `
     -Access Allow

   $nsgRuleSSH = New-AzNetworkSecurityRuleConfig `
     -Name 'SSH-rule' `
     -Protocol Tcp `
     -Direction Inbound `
     -Priority 600 `
     -SourceAddressPrefix * `
     -SourcePortRange * `
     -DestinationAddressPrefix * `
     -DestinationPortRange 3389 `
     -Access Allow
   $nsg = New-AzNetworkSecurityGroup `
     -ResourceGroupName $rgName `
     -Location $location `
     -Name $nsgName `
     -SecurityRules $nsgRuleRDP,$nsgRuleSSH 
}
### Create a VM configuration
$vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName -ErrorAction Stop
$adminSecPwd = ConvertTo-SecureString $adminPwd -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential -ArgumentList ($adminUSername, $adminSecPwd)

$NICName= $vmName+ '-NIC'
$OSDiskName=$vmName+ '-OS'
$PIP = New-AzPublicIpAddress -Name $pubIPName_VM  -ResourceGroupName $rgName -Location $location -AllocationMethod Dynamic
$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $rgName -Location $location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $PIP.Id -NetworkSecurityGroupId $nsg.Id
$vm = New-AzVMConfig -VMName $vmName -VMSize $vmSize
$vm = Set-AzVMOperatingSystem -VM $vm -Windows -ComputerName $vmName -Credential $creds -ProvisionVMAgent -EnableAutoUpdate
$vm = Set-AzVMBootDiagnostic -VM $vm -Disable
$vm = Add-AzVMNetworkInterface -VM $vm -Id $NIC.Id
$vm = Set-AzVMSourceImage -VM $vm -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2019-Datacenter' -Version latest
$vm = Set-AzVMOSDisk -VM $vm -Name $OSDiskName -Windows -CreateOption 'FromImage'

###  Create the VM
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating the Virtual Machine $vmName" -ForegroundColor Cyan
try {
      Get-AzVM -ResourceGroupName $rgName -Name $vmName -ErrorAction Stop | Out-Null
      Write-Host "  resource exists, skipping"
     }
catch {
       New-AzVM -ResourceGroupName $rgName -Location $location -VM $vm -ErrorAction Stop | Out-Null
     }


########### Create a storage account
# generate a unique name for the storage account
$tail=([guid]::NewGuid().tostring()).replace("-","").Substring(0,12)
$storageAccountName = 'strg'+ $tail

# checking the resource group where is deployed the storage account
try {     
      Get-AzResourceGroup -Name $rgName -Location $location -ErrorAction Stop  
      Write-Host 'RG already exists... skipping' -foregroundcolor Yellow -backgroundcolor Black
    } 
catch {     
      $rg = New-AzResourceGroup -Name $rgName -Location $location  -Force
    }

### check the existance of a storage account in the resource group
$s=Get-AzStorageAccount -ResourceGroupName $rgName

# check if $s has $null as value
if (!$s) { 
   
   # create a new storage account
   try { 
       $storageAccount =Get-AzStorageAccount -ResourceGroupName $rgName –StorageAccountName $storageAccountName -ErrorAction Stop 
        Write-Host 'Storage account'$storageAccount.StorageAccountName 'already exists... skipping' -foregroundcolor Yellow -backgroundcolor Black
   } 
   catch{
       # Create a new storage account.
       $storageAccount =New-AzStorageAccount -ResourceGroupName $rgName –StorageAccountName $storageAccountName -Location $Location -Type $storageAccountType
       Write-Host (Get-Date)' - ' -NoNewline
       Write-Host 'Create the storage account: '$storageAccount.StorageAccountName  -foregroundcolor Yellow -backgroundcolor Black
   }
} 
else {
  $storageAccount = $s[0]
}

Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating the private endpoint $privateEndpointName" -ForegroundColor Cyan

# Create a Private Endpoint for the storage account in your Virtual Network
try {
     Get-AzPrivateEndpoint -ResourceGroupName $rgName -Name $privateEndpointName -ErrorAction Stop | Out-Null
    }
catch{
   
   # the private link service connection object is created in memory
   $privateEndpointConnection = New-AzPrivateLinkServiceConnection -Name 'myConnection' `
      -PrivateLinkServiceId $storageAccount.Id `
      -GroupId 'blob'
  
   $vnet = Get-AzVirtualNetwork -ResourceGroupName  $rgName -Name $vnetName 
 
   $subnet = $vnet `
      | Select -ExpandProperty subnets `
      | Where-Object  {$_.Name -eq $subnetName }  
 
   $privateEndpoint = New-AzPrivateEndpoint -ResourceGroupName $rgName `
      -Name $privateEndpointName `
      -Location $location `
      -Subnet  $subnet `
      -PrivateLinkServiceConnection $privateEndpointConnection
}

### Configure the Private DNS Zone
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Creating the private DNS zone: privatelink.blob.core.windows.net" -ForegroundColor Cyan
$zone = New-AzPrivateDnsZone -ResourceGroupName $rgName `
  -Name "privatelink.blob.core.windows.net" 

if ($autoregistration)
{
$link  = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $rgName `
  -ZoneName 'privatelink.blob.core.windows.net' `
  -Name 'mylink' `
  -VirtualNetworkId $vnet.Id -EnableRegistration
}
else {
$link  = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $rgName `
  -ZoneName 'privatelink.blob.core.windows.net' `
  -Name 'mylink' `
  -VirtualNetworkId $vnet.Id 
}



write-host "Manual Registration of private link in private DNS zone" -ForegroundColor Green -BackgroundColor Black
# get the nic associated with the private endpoint
$nic = Get-AzResource -ResourceId $privateEndpoint.NetworkInterfaces[0].Id -ApiVersion "2019-09-01" 
foreach ($ipconfig in $nic.properties.ipConfigurations) { 
     foreach ($fqdn in $ipconfig.properties.privateLinkConnectionProperties.fqdns) { 
        Write-Host "$($ipconfig.properties.privateIPAddress) $($fqdn)"  
        $recordName = $fqdn.split('.',2)[0] 
        $dnsZone = $fqdn.split('.',2)[1] 
        New-AzPrivateDnsRecordSet -Name $recordName -RecordType A -ZoneName "privatelink.blob.core.windows.net"  `
          -ResourceGroupName $rgName -Ttl 600 `
          -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $ipconfig.properties.privateIPAddress)  
   } 
} 

