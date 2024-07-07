### The powershell script makes the following actions:
###  - create an Azure VNet
###  - create an Azure VM 
###  - create a user managed identity with contributor role and scope the Azure subscription 
###  - associated the user managed idenetity to the Azure VM
###
### Customize your script by assigment of your values to the variables
### 
###  $adminUsername = 'ADMINISTRATOR_USERNAME'
###  $adminPassword = 'ADMINISTRATOR_PASSWORD'
###  
### replace ADMINISTRATOR_USERNAME with the administrator username of the Azure VM
### replace ADMINISTRATOR_PASSWORD with the administrator username of the Azure VM
###
$subscriptionName = 'AzDev'
$rgName = 'rg-200'
$location = 'uksouth'
$vnetName = 'vnet1'
$subnet1Name = 'subnet1'
$subnet2Name = 'subnet2'
$addrPrefix = '10.0.0.0/22'
$subnet1Prefix = '10.0.1.0/24'
$subnet2Prefix = '10.0.2.0/24'
$publisher = 'MicrosoftWindowsServer'
$offer = 'WindowsServer'
$sku = '2022-Datacenter'
$version = 'latest'
$vmSize = 'Standard_B2s_v2'
$vmName = 'vm1'
$vmPubIP = "$vmName-pubIP"
$nicName = "$vmName-nic"
$nsgName = "$vmName-nsg"
$adminUsername = 'ADMINISTRATOR_USERNAME'
$adminPassword = 'ADMINISTRATOR_PASSWORD'
$userAssignedManagedIdentity = 'userAssignedIdentity-01'
# The variable $case can takes the following values: 
#     Contributor_Reader
#     Reader
#     Contributor
$case = 'Contributor_Reader'
####################
switch -Exact ($case) {
    Contributor_Reader {
        Write-Host 'role assigned to variable $case: '$case
    }
    Reader {
        Write-Host 'role assigned to variable $case: '$case
    }
    Contributor {
        Write-Host 'role assigned to variable $case: '$case
    }
    default {
        Write-Host 'Set the right option to assign the role.'
        Write-Host 'The variable $case can take the following values: Contributor_Reader OR Contributor OR Reader.'
        Exit
    }
}

# custom script extension to run the powershell script inside the VM after the boostrap
$scriptName = 'install-az-powershell.ps1'
$scriptLocation = 'https://raw.githubusercontent.com/fabferri/az-pattern/master/00-scripts/scripts/' + $scriptName
$scriptExe = ".\$scriptName"
$settingConfiguration = @{'fileUris' = [Object[]]"$scriptLocation"; 'commandToExecute' = "powershell.exe -ExecutionPolicy Unrestricted -Command $scriptExe" }
#
#
$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

##Create resource Group ##
Try {
    $rg = Get-AzResourceGroup -Name $rgName -ErrorAction Stop
    Write-Host 'Resource exists, skipping'
}
Catch { $rg = New-AzResourceGroup -Name $rgName -Location $location }

$subnet1 = @{
    Name          = $subnet1Name
    AddressPrefix = $subnet1Prefix
}

$subnetConfig1 = New-AzVirtualNetworkSubnetConfig @subnet1 

$subnet2 = @{
    Name          = $subnet2Name
    AddressPrefix = $subnet2Prefix
}

$subnetConfig2 = New-AzVirtualNetworkSubnetConfig @subnet2 
$net = @{
    Name              = $vnetName
    ResourceGroupName = $rgName
    Location          = $location
    AddressPrefix     = $addrPrefix
    Subnet            = $subnetConfig1, $subnetConfig2
}
Write-Host "$(Get-Date) - Creating vnet: $vnetName" -ForegroundColor Cyan
Try {
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName -ErrorAction Stop
    Write-Host "$(Get-Date) - vnet already exists, skipping"
}
Catch {
    $vnet = New-AzVirtualNetwork @net
}

## Create a rule for a network security group ##
$nsgrule1 = @{
    Name                     = 'SSH-in'
    Description              = 'allow-SSH-in'
    Protocol                 = '*'
    SourcePortRange          = '*'
    DestinationPortRange     = '22'
    SourceAddressPrefix      = '*'
    DestinationAddressPrefix = '*'
    Access                   = 'Allow'
    Priority                 = '200'
    Direction                = 'Inbound'
}
$rule1 = New-AzNetworkSecurityRuleConfig @nsgrule1



## Create a rule for a network security group ##
$nsgrule2 = @{
    Name                     = 'RDP-in'
    Description              = 'allow-RDP-in'
    Protocol                 = '*'
    SourcePortRange          = '*'
    DestinationPortRange     = '3389'
    SourceAddressPrefix      = '*'
    DestinationAddressPrefix = '*'
    Access                   = 'Allow'
    Priority                 = '300'
    Direction                = 'Inbound'
}
$rule2 = New-AzNetworkSecurityRuleConfig @nsgrule2

$nsg = @{
    Name              = $nsgName
    ResourceGroupName = $rgName
    Location          = $location
    SecurityRules     = @($rule1, $rule2) 
}

Write-Host "$(Get-Date) - Creating NSG: $nsgName" -ForegroundColor Cyan
Try {
    $nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $rgName -ErrorAction Stop
    Write-Host "$(Get-Date) - NSG exists, skipping"
}
Catch {
    $nsg = New-AzNetworkSecurityGroup @nsg
}


$ip = @{
    Name              = $vmPubIP
    ResourceGroupName = $rgName
    Location          = $location
    Sku               = 'Standard'
    Tier              = 'Regional'
    AllocationMethod  = 'Static'
}

# create a public IP
Write-Host "$(Get-Date) - Creating public IP: $vmPubIP" -ForegroundColor Cyan
Try {
    $vmPublicIP = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $vmPubIP -ErrorAction Stop
    Write-Host "$(Get-Date) - Public IP exists, skipping"
}
Catch {
    $vmPublicIP = New-AzPublicIpAddress @ip
}

$vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName
$subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnet1Name
$nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $rgName
$nic = @{
    Name                 = $nicName
    ResourceGroupName    = $rgName
    Location             = $location
    Subnet               = $subnet
    PublicIpAddress      = $vmPublicIP
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

$osDiskName = $vmName + "-OSdisk"

$vmConf = @{
    VMName = $vmName
    VMSize = $vmSize
}
  
$vmConfig = New-AzVMConfig @vmConf
$vmOS = @{
    VM           = $vmConfig
    ComputerName = $vmName 
    Credential   = $vmAdminCreds
    Windows      = $null
}
$vmConfig = Set-AzVMOperatingSystem @vmOS

$vmImage = @{
    VM            = $vmConfig
    PublisherName = $publisher 
    Offer         = $offer 
    Skus          = $sku 
    Version       = $version
}
$vmConfig = Set-AzVMSourceImage @vmImage
                      
$vmDisk = @{
    VM           = $vmConfig
    Name         = $osDiskName
    CreateOption = 'FromImage'
}
$vmConfig = Set-AzVMOSDisk @vmDisk
                
$vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable

$vmNetworkInterface = @{
    VM      = $vmConfig
    Id      = $vmNIC.Id
    Primary = $null
}

$vmConfig = Add-AzVMNetworkInterface  @vmNetworkInterface

Write-Host "$(Get-Date) - Creating vm: $vmName" -ForegroundColor Cyan
Try {
    $vm = Get-AzVM -Name $vmName -ResourceGroupName $rgName  -ErrorAction Stop 
    Write-Host "$(Get-Date) - vm exists, skipping"
}
Catch {
    New-AzVM  -VM $vmConfig -ResourceGroupName $rgName -Location $location
}

Write-Host "$(Get-Date) - applying a custom script extension to the vm: $vmName" -ForegroundColor Cyan
try {
    Get-AzVMExtension -ResourceGroupName $rgName -VMName $vmName -Name 'deploy-pwsh'-ErrorAction Stop
}
catch {
    # running custom script extension 
    Set-AzVMExtension -ResourceGroupName $rgName -VMName $vmName -Location $location `
        -Name 'deploy-pwsh' -Publisher 'Microsoft.Compute' `
        -ExtensionType 'CustomScriptExtension' `
        -TypeHandlerVersion '1.10' `
        -Settings $settingConfiguration -ErrorAction Stop | Out-Null 
}
Write-Host "$(Get-Date) - Create a user-assigned managed identity: $userAssignedManagedIdentity" -ForegroundColor Cyan

# Create a user-assigned managed identity
Try {
    # check if the user-assigned identity exists
    Get-AzUserAssignedIdentity -ResourceGroupName $rgName -Name $userAssignedManagedIdentity -ErrorAction Stop
    Write-Host "$(Get-Date) - user-assigned managed identity: $userAssignedManagedIdentity already exists. skipping" -ForegroundColor Cyan
}
catch {
    # create a user-assigned identity if it doesn't exist
    New-AzUserAssignedIdentity -ResourceGroupName $rgName -Name $userAssignedManagedIdentity -Location $location -SubscriptionId $subscr.Id
}
#
# List user-assigned managed identities
Get-AzUserAssignedIdentity -ResourceGroupName $rgName

# Delete a user-assigned managed identity. uncomment the line below:
# Remove-AzUserAssignedIdentity -ResourceGroupName $rgName -Name $userAssignedManagedIdentity

# get the subscription Id
$subscriptionId = $subscr.id

Start-Sleep -Seconds 60
$UAMI = (Get-AzUserAssignedIdentity -ResourceGroupName $rgName -Name $userAssignedManagedIdentity).PrincipalId

Write-Host "$(Get-Date) - create the role assigned to user-assigned managed identity: $UAMI" -ForegroundColor Yellow 
$roleNameAssigned = (Get-AzRoleAssignment -ObjectId $UAMI -ResourceGroupName $rgName).RoleDefinitionName
if ($null -eq $roleNameAssigned) {
    switch -Exact ($case) {
        Contributor_Reader {
            # assign two roles:
            # the role or Contributor with scope Resource Group
            # the role of Reader with scope Subscription
            New-AzRoleAssignment -ObjectId $UAMI `
                -RoleDefinitionName Contributor `
                -Scope "/subscriptions/$subscriptionId/resourcegroups/$rgName"
            New-AzRoleAssignment -ObjectId $UAMI `
                -RoleDefinitionName Reader `
                -Scope "/subscriptions/$subscriptionId"
        }
        Reader {
            # assign the role of Reader with scope Subscription
            New-AzRoleAssignment -ObjectId $UAMI `
                -RoleDefinitionName Reader `
                -Scope "/subscriptions/$subscriptionId"
        }
        Contributor {
            # assign the role of Contributor with scope Resource Group
            New-AzRoleAssignment -ObjectId $UAMI `
                -RoleDefinitionName Contributor `
                -Scope "/subscriptions/$subscriptionId/resourcegroups/$rgName"
        }
        default {
            Write-Host 'set the right option to assign the role. '
            Write-Host 'The variable $case can take the following values: Contributor_Reader OR Contributor OR Reader'
            Exit
        }
    }
}
else {
    if ($roleNameAssigned -eq "Contributor") {
        Write-Host "$(Get-Date) - role already assigned to user-assigned managed identity:  $userAssignedManagedIdentity" -ForegroundColor Cyan 
    }
}

# get the Id of the user-managed identity
$userId = (Get-AzUserAssignedIdentity -ResourceGroupName $rgName -Name $userAssignedManagedIdentity).Id
$usrClientId = (Get-AzUserAssignedIdentity -ResourceGroupName $rgName -Name $userAssignedManagedIdentity).ClientId

# fetch the exiting VM
$vm = Get-AzVM -ResourceGroupName $rgName -Name $vmName 
# collect the user-managed idenenity assigne dto the vm
$userIdVM = (Get-AzVM -ResourceGroupName $rgName -Name $vmName).Identity.UserAssignedIdentities.Keys

Write-Host "$(Get-Date) - assign the User Assigned Identity ID: $usrClientId to the vm: $vmName" -ForegroundColor Yellow
# assign the user-managed identity to the VM 
if ($userId -eq $userIdVM) {
    Write-Host "$(Get-Date) - user-assigned: $userAssignedManagedIdentity already associated to the vm: $vm" -ForegroundColor Cyan 
}
else {
    try {
        Update-AzVM -ResourceGroupName $rgName -VM $vm -IdentityType SystemAssignedUserAssigned -IdentityId $userId -ErrorAction Stop
    }
    catch {
        write-host "error in assign user-managed idenenity: $userAssignedManagedIdentity to the VM: $vmName"
    }
}