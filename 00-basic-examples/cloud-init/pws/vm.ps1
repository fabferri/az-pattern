###########################################
##
## - create a VM in subnet2
##
##  .\scriptName -adminUsername YOUR_USERNAME -adminPassword YOUR_PASSWORD
##
## 
################# Input parameters #################
[CmdletBinding()]
param (
    [Parameter( Mandatory = $false, ValueFromPipeline=$false, HelpMessage='VMs administrator username')]
    [string]$adminUsername = "ADMINISTRATOR_USERNAME",
 
    [Parameter(Mandatory = $false, HelpMessage='VMs administrator password')]
    [string]$adminPassword = "ADMINISTRATOR_PASSWORD"
    )

###################### Variables ######################
$subscriptionName = "Pathfinders"       
$rgName = "RG-vm1"
$location = "uksouth"    
$vnetName = "vnet1"
$vnetPrefix = @("10.0.1.0/24","10.0.2.0/24","10.0.3.0/24")
$subnet1Prefix = "10.0.1.0/25"
$subnet2Prefix = "10.0.2.0/25"
$subnet3Prefix = "10.0.3.0/25"
$subnet1Name = "subnet1"   
$subnet2Name = "subnet2"
$subnet3Name = "subnet3"
##
$vmAdminName = $adminUsername
$vmadminPwd  = $adminPassword
$vmName = "vm1"
$vmPublicIPName = $vmName+"-pubIP"
$vmNICName  = $vmName+"-nic"
$vmPrivateIP = "10.0.2.10"                   # assign a static IP address in subnet2
$vmPublicIPName = $vmName + "-pubIP"
$vmPublisher = "Canonical"
$vmOffer = "UbuntuServer"
$vmSKU = "18.04-LTS"
$vmVersion = "latest"
$vmSize = "Standard_B1s"
$OSDiskCaching = "ReadWrite"
$storageAccountType = "Premium_LRS"
#
$nsgName = "nsg1"
#
$RGTagExpireDate = '03/25/21'
$RGTagContact = 'user1@contoso.com'
$RGTagNinja = 'user1'
$RGTagUsage = 'test cloud-init'
#
#
######################### MAIN #################################
$pathFiles      = Split-Path -Parent $PSCommandPath
$cloudInitFile  = "$pathFiles\cloud-init.txt"

## check if cloud-init.txt file is present in the directory read the content
If (Test-Path -Path $cloudInitFile) {
         Write-Host "$(Get-Date) - reading cloud-init file: $cloudInitFile" -ForegroundColor Cyan
        # The commands in this example get the contents of a file as one string, instead of an array of strings. 
        # By default, without the Raw dynamic parameter, content is returned as an array of newline-delimited strings
        $cloudInitContent = Get-Content $cloudInitFile -Raw
        Write-Host "$(Get-Date) - cloud-init file content: " -ForegroundColor Cyan
        Write-Host $cloudInitContent -ForegroundColor Yellow
}
Else {
    Write-Host "cloud-init file $cloudInitFile not found! -end of processing!"
    Exit
     }

## Convert the password from plaintext to  SecureString type
$adminSecurePassword = ConvertTo-SecureString -String $adminPassword -AsPlainText -Force
$vmCreds = New-Object System.Management.Automation.PSCredential( $adminUsername, $adminSecurePassword);

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

## Create Resource Group 
Write-Host "$(Get-Date) - Creating Resource Group: $rgName" -ForegroundColor Cyan
Try {
     $rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     Write-Host "$(Get-Date) - resource group $rgName exists...skipping" -foregroundcolor Green -backgroundcolor Black }
Catch {
     $rg = New-AzResourceGroup -Name $rgName  -Location $location  
     }

## Add Tag Values to the Resource Group
Set-AzResourceGroup -Name $RGName -Tag @{Expires=$RGTagExpireDate; Contacts=$RGTagContact; Pathfinder=$RGTagNinja; Usage=$RGTagUsage} | Out-Null



################# Create VNet
try {
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName -ErrorAction Stop -WarningAction SilentlyContinue
    Write-Host "$(Get-Date) -vnet: $vnetName already exists... skipping" -foregroundcolor Green -backgroundcolor Black
} catch {  
    $vnet = New-AzVirtualNetwork -Name $vnetName          `
                                  -ResourceGroupName $rgName   `
                                  -Location $location          `
                                  -AddressPrefix $vnetPrefix   `
                                  -Verbose -Force -WarningAction SilentlyContinue
    $subnet1 = Add-AzVirtualNetworkSubnetConfig -Name $subnet1Name -AddressPrefix $subnet1Prefix -VirtualNetwork $vnet -WarningAction SilentlyContinue
    $subnet2 = Add-AzVirtualNetworkSubnetConfig -Name $subnet2Name -AddressPrefix $subnet2Prefix -VirtualNetwork $vnet -WarningAction SilentlyContinue
    $subnet3 = Add-AzVirtualNetworkSubnetConfig -Name $subnet3Name -AddressPrefix $subnet3Prefix -VirtualNetwork $vnet -WarningAction SilentlyContinue
    Set-AzVirtualNetwork -VirtualNetwork $vnet -WarningAction SilentlyContinue | Out-Null
}

write-host -ForegroundColor Yellow "vnet              : " $vnet.Name
write-host -ForegroundColor Yellow "vnet Address Space: " $vnet.AddressSpace.AddressPrefixes  
for($i=0;$i-le $vnet.Subnets.Count-1;$i++)
{
     $subnet=Get-AzVirtualNetworkSubnetConfig -Name $vnet.Subnets[$i].Name -VirtualNetwork $vnet -WarningAction SilentlyContinue
     write-host -ForegroundColor Yellow "subNet Name       : " $subnet.Name
     write-host -ForegroundColor Yellow "subNet Prefix     : " $subnet.AddressPrefix
}


################# Create VM ########################################
## Create a Public IP Address of the VM
try {
    Write-Host "$(Get-Date) - getting public IP: $vmPublicIPName" -foregroundcolor Green
    $vm_publicIP = Get-AzPublicIpAddress  -Name $vmPublicIPName -ResourceGroupName $rgName -ErrorAction Stop 
    Write-Host "$(Get-Date) - public IP: $vmPublicIPName already exists... skipping" -foregroundcolor Green -backgroundcolor Black
    } 
catch {
    $vm_publicIP = New-AzPublicIpAddress `
           -Name $vmPublicIPName `
           -ResourceGroupName $rgName `
           -Location $location `
           -AllocationMethod Dynamic `
           -Sku Basic `
           -Force -WarningAction SilentlyContinue
    write-host -foreground Yellow "$(Get-Date) - Public IP Address:" $vm_publicIP.Name " has been created"
}



$vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName
$subnet1Id=$vnet.Subnets[0].Id
$subnet2Id=$vnet.Subnets[1].Id
$subnet3Id=$vnet.Subnets[2].Id

## Create a NIC for the VM
try {
   Write-Host "$(Get-Date) - checking NIC of the VM" -foregroundcolor Green
   $vm_nic = get-AzNetworkInterface `
                -Name $vmNICName `
                -ResourceGroupName $rgName `
                -Location $location -ErrorAction Stop
   Write-Host "$(Get-Date) -  NIC of the VM aready exists... skipping" -foregroundcolor Green -backgroundcolor Black
} catch {
  $vm_nic = New-AzNetworkInterface `
                -Name $vmNICName `
                -ResourceGroupName $rgName `
                -Location $location  `
                -SubnetId $subnet2Id `
                -PublicIpAddressId $vm_publicIP.Id `
                -PrivateIpAddress $vmPrivateIP `
                -Force -Verbose 
   write-host  "$(Get-Date) - vm-NIC:"$vm_nic.Name "has been created." -foreground Yellow
}



try {
  $vm = Get-AzVM -Name $vmName -ResourceGroupName $rgName -ErrorAction Stop
  write-host "$(Get-Date) - vm:" $vm.Name "already exists... skipping" -foregroundcolor Green -backgroundcolor Black
} 
catch 
{
  $vm_Config = New-AzVMConfig `
                       -VMName $vmName `
                       -VMSize $vmSize `
                       -Verbose

  ## set the VM config inclusive of  cloud-init in CustomData qualifier
  $vm_Config = Set-AzVMOperatingSystem `
                       -VM $vm_Config `
                       -Linux `
                       -ComputerName $vmName `
                       -Credential $vmCreds `
                       -CustomData $cloudInitContent `
                       -Verbose

  ## set the name of the OS disk
  $vm_diskName=$vmName+"-OS"
  $vm_Config = Set-AzVMOSDisk -VM  $vm_Config `
                       -CreateOption FromImage `
                       -Name $vm_diskName `
                       -Linux `
                       -Caching $OSDiskCaching `
                       -StorageAccountType $storageAccountType

  $vm_Config = Set-AzVMSourceImage `
                       -VM $vm_Config `
                       -PublisherName $vmPublisher `
                       -Offer $vmOffer  `
                       -Skus $vmSKU `
                       -Version $vmVersion -Verbose 

  $vm_Config = Add-AzVMNetworkInterface `
                       -VM $vm_Config `
                       -Id $vm_nic.Id `
                       -Primary 

  ## disable the diagnostic at boot
  $vm_Config = Set-AzVMBootDiagnostic -VM $vm_Config -Disable -Verbose 
  
  write-host  "$(Get-Date) - Creation of the vm:"$vmName  -foreground Yellow
  $vm=New-AzVM -VM $vm_Config `
            -ResourceGroupName $rgName `
            -Location $location `
            -verbose
  write-host  "$(Get-Date) - the vm:"$vmName "has been created"  -foreground Yellow
}

## create the nsg
try 
  {
  $nsg=get-AzNetworkSecurityGroup -ResourceGroupName $rgName -Name $nsgName -ErrorAction Stop
  Write-Host "$(Get-Date) - NSG: "$nsgName "already exists... skipping" -foregroundcolor  Green -backgroundcolor Black
  }
catch 
  {
  Write-Host "$(Get-Date) - creating NSG rules" -foregroundcolor Green -backgroundcolor Black
  ## Create an inbound network security group rule for port 22
  $nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name nsgSSH-rule  -Protocol Tcp `
    -Direction Inbound -Priority 500 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
    -DestinationPortRange 22 -Access Allow
  
  ## Create an inbound network security group rule for port 3389
  $nsgRuleRDP = New-AzNetworkSecurityRuleConfig -Name nsgRDP-rule  -Protocol Tcp `
    -Direction Inbound -Priority 600 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
    -DestinationPortRange 3389 -Access Allow

  ## Create an inbound network security group rule for port 80
  $nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name nsgHTTP-rule  -Protocol Tcp `
    -Direction Inbound -Priority 700 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
    -DestinationPortRange 80 -Access Allow

  ## Create a network security group
  Write-Host "$(Get-Date) - creating NSG:"$nsgName -foregroundcolor Yellow
  $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $rgName -Location $location `
       -Name $nsgName -SecurityRules $nsgRuleSSH,$nsgRuleRDP,$nsgRuleHTTP -Tag $tag -Force -WarningAction SilentlyContinue
}

## check if the security rules exist in nsg; if a rule doesn't exist it will be added
try{
      $rule1=(Get-AzNetworkSecurityRuleConfig -Name nsgSSH-rule -NetworkSecurityGroup $nsg -ErrorAction Stop).Name 
      write-host "$(Get-Date) - security rule: nsgSSH-rule already exists....skipping" -foregroundcolor Green -backgroundcolor Black
   }    
catch {
      $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $rgName -Name $nsgName 
      write-host "$(Get-Date) - adding security rule: nsgSSH-rule" -ForegroundColor Yellow
      $nsgRuleSSH = Add-AzNetworkSecurityRuleConfig -Name nsgSSH-rule  -Protocol Tcp `
          -Direction Inbound -Priority 500 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
          -DestinationPortRange 22 -Access Allow -NetworkSecurityGroup $nsg
          Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg 
   }


try{
      $rule2=(Get-AzNetworkSecurityRuleConfig -Name nsgRDP-rule -NetworkSecurityGroup $nsg -ErrorAction Stop).Name 
      write-host "$(Get-Date) - security rule: nsgRDP-rule already exists....skipping" -foregroundcolor Green -backgroundcolor Black
   }    
catch {
      $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $rgName -Name $nsgName 
      write-host "$(Get-Date) - adding security rule: nsgRDP-rule" -ForegroundColor Yellow
      $nsgRuleRDP = Add-AzNetworkSecurityRuleConfig -Name nsgRDP-rule  -Protocol Tcp `
          -Direction Inbound -Priority 600 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
          -DestinationPortRange 3389 -Access Allow -NetworkSecurityGroup $nsg
          Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg 
    }
  
try{
      $rule3=(Get-AzNetworkSecurityRuleConfig -Name nsgHTTP-rule -NetworkSecurityGroup $nsg -ErrorAction Stop).Name 
       write-host "$(Get-Date) - security rule: nsgHTTP-rule already exists....skipping" -foregroundcolor Green -backgroundcolor Black
   }    
catch {
      $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $rgName -Name $nsgName 
      write-host "$(Get-Date) - adding security rule: nsgHTTP-rule" -ForegroundColor Yellow
      $nsgRuleHTTP = Add-AzNetworkSecurityRuleConfig -Name nsgHTTP-rule  -Protocol Tcp `
          -Direction Inbound -Priority 700 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
          -DestinationPortRange 80 -Access Allow -NetworkSecurityGroup $nsg
          Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg 
    }


## it associates NSG to a subnets
Write-Host "$(Get-Date) - associating NSG to a subnet" -foregroundcolor Yellow
$vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName -WarningAction SilentlyContinue
$subnet1 = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnet1Name -WarningAction SilentlyContinue
$subnet2 = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnet2Name -WarningAction SilentlyContinue
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $rgName -Name $nsgName -WarningAction SilentlyContinue
#
## $subnet1.NetworkSecurityGroup = $nsg
$subnet2.NetworkSecurityGroup = $nsg
Set-AzVirtualNetwork -VirtualNetwork $vnet -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
Write-Host "$(Get-Date) - NSG has been associated with the subnet:"$subnet2Name -foregroundcolor Yellow

