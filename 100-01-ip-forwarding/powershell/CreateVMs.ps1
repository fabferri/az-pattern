## NOTE:
##   Before running the script set 
##   1. your Azure subscription name in the variable $subscriptionName
##   2. the name of your Azure resource group in the variable $rgName
##
## HOWTO run the script:
##
##  .\Createvm -adminUsername YOUR_USERNAME -adminPassword YOUR_PASSWORD
##
## where:
##   YOUR_USERNAME: username of the adminsitrator of Azure VMs
##   YOUR_PASSWORD: password of the administrator of Azure VMs
##  
## What the script does:
## - Create a Storage account
## - Create a folder in the storage account
## - Copy the script in the storage account folder
## - Create the Public IP Address
## - Create the VNet
## - Create the NIC
## - Create the VM
## - by VM script extension run the script in storage account to enable ip forwarding  
###########################################
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True, ValueFromPipeline = $false, HelpMessage = 'username administrator VMs', Position = 0)]
    [string]$adminUsername,
 
    [Parameter(Mandatory = $true, HelpMessage = 'password administrator VMs')]
    [string]$adminPassword
)

$parameters = @{
    "adminUsername" = $adminUsername;
    "adminPassword" = $adminPassword
}

#################### Input parameters
$subscriptionName = "Windows Azure MSDN - Visual Studio Ultimate"
$rgName        = "RG-300"                  # resource group name
$location      = "eastus"                  # Azure region                   
$adminName     = $adminUsername            # administrator
$adminPwd      = $adminPassword            # password
$vnetName      = "vnet1"                   # name VNet
$subnet1Name   = "subnet1"                 # name subnet1
$subnet2Name   = "subnet2"                 # name subnet2
$subnet3Name   = "subnet3"                 # name subnet3
$vnetPrefix    = @("10.0.1.0/24","10.0.2.0/24","10.0.3.0/24")   # address space vnet
$subnet1Prexif = "10.0.1.0/24"             # network prefix subnet1
$subnet2Prexif = "10.0.2.0/24"             # network prefix subnet2
$subnet3Prexif = "10.0.3.0/24"             # network prefix subnet3
$nsgName       = "nsg-vnet"                # name network security group
$vm1Name       = "nva"                     # name VM1
$vm2Name       = "vm2"                     # name VM2
$vm3Name       = "vm3"                     # name VM3
$IPvm1         = "10.0.1.10"               # internal IP VM1
$IPvm2         = "10.0.2.10"               # internal IP VM2
$IPvm3         = "10.0.3.10"               # internal IP VM3
$publisherName = "openlogic"               # image publisher
$offerName     = "CentOS"                  # linux distro
$skuName       = "7.5"                     # OS version
$version       = "latest"                  # last avaiabile build
$vmSize        = "Standard_B1s"            # size of the VM
$avSetName     = "avSet101"                # name of avaiability set
$scriptName    = "ipforwarding.sh"         # bash script to enable the ip forwarder on linux VM
$storagePrefix = "gensto"                  # prefix of the storage account name
$tag           = @{Name ="test-dev"; Value ="prj-forwarder-01"}
###########################################
## Array of VMs
## comment the line related to the VMs you do not want to deploy.
$vmArray = @( 
    [pscustomobject]@{ vmName = $vm1Name; nicName = $vm1Name + "-nic"; publicVipName = $vm1Name + "-pubIP"; publicIPAllocationMethod = "Static"; privateIP = $IPvm1; vnetName = $vnetName; subnetName = $subnet1Name; enableForwarding = $true} 
    [pscustomobject]@{ vmName = $vm2Name; nicName = $vm2Name + "-nic"; publicVipName = $vm2Name + "-pubIP"; publicIPAllocationMethod = "Static"; privateIP = $IPvm2; vnetName = $vnetName; subnetName = $subnet2Name; enableForwarding = $false} 
    [pscustomobject]@{ vmName = $vm3Name; nicName = $vm3Name + "-nic"; publicVipName = $vm3Name + "-pubIP"; publicIPAllocationMethod = "Static"; privateIP = $IPvm3; vnetName = $vnetName; subnetName = $subnet3Name; enableForwarding = $false} 
)

$pwd = ConvertTo-SecureString -String $adminPwd -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential( $adminName, $pwd);


$pathFiles = Split-Path -Parent $PSCommandPath

$scriptFile = "$pathFiles\$scriptName"
write-host -ForegroundColor Green "Custom data file  : " $scriptFile  

####### Select the Azure subscription
Try {
    write-Host -ForegroundColor Cyan "Checking login" 
    $subscr = (Set-AzureRmContext -SubscriptionName $subscriptionName -ErrorAction Stop).Subscription
}
Catch {
    Login-AzureRmAccount 
    $subscr = Get-AzureRmSubscription -SubscriptionName $subscriptionName
    $subscr = (Set-AzureRmContext -Subscription $subscr.Id  -ErrorAction Stop).Subscription
}
Write-Host "Current Subcription:", $subscr.Name, " - ", $subscr.Id


Try {
    Write-Host "Checking resource Group:", $rgName
    $rg = Get-AzureRmResourceGroup -Name $rgName -Location $location -ErrorAction Stop
}
catch {
    $rg = New-AzureRmResourceGroup -Name $rgName -Location $location -Tag $tag -Force 
}

try {
    $storageAccount = Get-AzureRmStorageAccount -ResourceGroupName $rgName -ErrorAction Stop
}
catch { }

if ($storageAccount) { 
    write-host "Total number of storage accounts: "$storageAccount.Count
    for ($i = 0; $i -lt $storageAccount.Count; $i++) {
        if ($storageAccount[$i].StorageAccountName -match $storagePrefix) { 
            $storageAccountName = $storageAccount[$i].StorageAccountName
            Write-Host -ForegroundColor Green "existing storage account name: "$storageAccountName
        }
    }
} 
else {
    $myGUID = [System.Guid]::NewGuid()
    $b = $myGUID.ToString().Replace('-', '')
    $guid = $b.subString(0, 6) 
    $storageAccountName = $storagePrefix + $guid

    $storageAccount = New-AzureRmStorageAccount -ResourceGroupName $rgName `
        -Name $storageAccountName `
        -Location $location `
        -SkuName Standard_LRS `
        -Kind Storage
}


$storageAccount = Get-AzureRmStorageAccount -ResourceGroupName $rgName -Name $storageAccountName
$ctx = $storageAccount.Context
$containerName = "script"
$container = (Get-AzureStorageContainer -Context $ctx | Where-Object { $_.Name -eq $containerName })

if (!$container) {
    New-AzureStorageContainer -Name $containerName -Context $ctx -Permission Blob 
}

$blob = (Get-AzureStorageBlob  -Container $containerName -Context $ctx | Where-Object { $_.Name -eq $scriptName })

if (!$blob) {
    # upload the script file to the storage blob
    Set-AzureStorageBlobContent -File $scriptFile `
        -Container $containerName `
        -Blob $scriptName `
        -Context $ctx 
}
New-AzureStorageBlobSASToken -Container $containerName -Blob $scriptName -Permission r -Context $ctx
Get-AzureStorageBlob -Container $ContainerName -Context $ctx | select $scriptName 
Write-host -ForegroundColor Cyan  "Name storage account:"$storageAccountName

try {
    $avSet = Get-AzureRmAvailabilitySet -ResourceGroupName $rgName -Name $avSetName -ErrorAction Stop

}
catch {
    $avSet = New-AzureRmAvailabilitySet `
        -Location $location `
        -Name $avSetName `
        -ResourceGroupName $rgName `
        -Sku Aligned `
        -PlatformFaultDomainCount 2 `
        -PlatformUpdateDomainCount 2 `
        -Verbose
}

# Create an inbound network security group rule for SSH
$nsgRuleSSH = New-AzureRmNetworkSecurityRuleConfig -Name nsgSSH-rule  -Protocol Tcp `
    -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
    -DestinationPortRange 22 -Access Allow

# Create an inbound network security group rule for RDP
$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name nsgRDP-rule  -Protocol Tcp `
    -Direction Inbound -Priority 1010 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
    -DestinationPortRange 3389 -Access Allow

try {
  $nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $rgName -Location $location -Name $nsgName -ErrorAction Stop
} catch {
  # Create a network security group
  $nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $rgName -Location $location `
    -Name $nsgName -SecurityRules $nsgRuleSSH, $nsgRuleRDP -Tag $tag -Force
}

# Create a subnet and assign the network security group
$subnet1 = New-AzureRmVirtualNetworkSubnetConfig -Name $subnet1Name -AddressPrefix $subnet1Prexif -NetworkSecurityGroupId $nsg.Id
$subnet2 = New-AzureRmVirtualNetworkSubnetConfig -Name $subnet2Name -AddressPrefix $subnet2Prexif -NetworkSecurityGroupId $nsg.Id
$subnet3 = New-AzureRmVirtualNetworkSubnetConfig -Name $subnet3Name -AddressPrefix $subnet3Prexif -NetworkSecurityGroupId $nsg.Id

$vnet = New-AzureRmVirtualNetwork -Name $vnetName `
    -ResourceGroupName $rgName `
    -Location $location `
    -AddressPrefix $vnetPrefix `
    -Subnet $subnet1,$subnet2,$subnet3 `
    -Verbose -Force 
##################################################################
#
# Check on existing Subnet
# 
$vnet = Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $rgName 

$subnet1 = Get-AzureRmVirtualNetworkSubnetConfig -Name $subnet1Name -VirtualNetwork $vnet  
$subnet2 = Get-AzureRmVirtualNetworkSubnetConfig -Name $subnet2Name -VirtualNetwork $vnet  
$subnet3 = Get-AzureRmVirtualNetworkSubnetConfig -Name $subnet3Name -VirtualNetwork $vnet  
write-host -ForegroundColor Yellow "VNet               : " $vnet.Name 
write-host -ForegroundColor Yellow "VNet Address Space : " $vnet.AddressSpace.AddressPrefixes  
write-host -ForegroundColor Yellow "Subnet1 Name       : " $subnet1.Name  
write-host -ForegroundColor Yellow "SubNet1 Prefix     : " $subnet1.AddressPrefix
write-host -ForegroundColor Yellow "Subnet2 Name       : " $subnet2.Name  
write-host -ForegroundColor Yellow "SubNet2 Prefix     : " $subnet2.AddressPrefix  
write-host -ForegroundColor Yellow "Subnet3 Name       : " $subnet3.Name  
write-host -ForegroundColor Yellow "SubNet3 Prefix     : " $subnet3.AddressPrefix  


for ($i = 0; $i -le $vnet.Subnets.Count - 1; $i++) {
    write-host "Subnet Indexing:" $vnet.Subnets[$i].Name
    if ($vnet.Subnets[$i].Name -eq $subnet1Name) {
        $subnetIndex = $i
        write-host -foreground Yellow "getting the Subnet Index:" $subnetIndex
    }
}


function createAzVM {
    Param
    (  [Parameter(Mandatory = $true)] [System.String]$rgName,
        [Parameter(Mandatory = $true)] [System.String]$location,
        [Parameter(Mandatory = $true)] [System.String]$vmName,
        [Parameter(Mandatory = $true)] [System.String]$vmSize,
        [Parameter(Mandatory = $true)] [System.Management.Automation.PSCredential]$creds,
        [Parameter(Mandatory = $true)] [System.String]$vnetName,
        [Parameter(Mandatory = $true)] [System.String]$subnetName,
        [Parameter(Mandatory = $true)] [System.String]$nicName,
        [Parameter(Mandatory = $true)] [System.String]$publicVipName,
        [Parameter(Mandatory = $true)] [ValidateSet('Dynamic', 'Static')] [System.String]$publicIPAllocationMethod,
        [Parameter(Mandatory = $true)] [System.String]$privateIP,
        [Parameter(Mandatory = $true)] [Boolean]$enableForwarding
    )

    $vnet = Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $rgName 
    $subnetId=(Get-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet).Id
    write-host -ForegroundColor Cyan "....subnet name:",$subnetName
    write-host -ForegroundColor Cyan "....subnet ID  :",$subnetId
    write-host -ForegroundColor Cyan "....privateIP  :",$privateIP

    ####### Create a Public IP Address
    $publicVip = New-AzureRmPublicIpAddress `
        -Name $publicVipName `
        -ResourceGroupName $rgName `
        -Location $location `
        -AllocationMethod Dynamic `
        -Tag $tag -Force
    ##################################################################

    $publicVip = Get-AzureRmPublicIpAddress  -Name $publicVipName -ResourceGroupName $rgName
    write-host -foreground Yellow "Allocate a Public IP Address:" $publicVip.Name

    ####### Create a NIC -Attach each NIC to related Subnet
    if ($enableForwarding) {

        $nic = New-AzureRmNetworkInterface `
            -Name $nicName `
            -ResourceGroupName $rgName `
            -Location $location `
            -SubnetId $subnetId `
            -PublicIpAddressId $publicVip.Id `
            -PrivateIpAddress $privateIP `
            -EnableIPForwarding `
            -Force -Verbose 

        write-host -foreground Yellow "NIC            :" $nic.Name "has been created."
    }
    else {
        $nic = New-AzureRmNetworkInterface `
            -Name $nicName `
            -ResourceGroupName $rgName `
            -Location $location `
            -SubnetId $subnetId `
            -PublicIpAddressId $publicVip.Id `
            -PrivateIpAddress $privateIP   `
            -EnableIPForwarding `
            -Force -Verbose 
        write-host -foreground Yellow "NIC            :" $nic.Name "has been created."
    }
    ##################################################################

    try {
        $vm = Get-AzureRmVM -Name $vmName -ResourceGroupName $rgName -ErrorAction Stop
        write-host -foregroundcolor Green -backgroundcolor Black "VM:" $vm.Name "already exists... skipping" 
    }
    catch {  
        $vmConfig = New-AzureRmVMConfig `
            -VMName $vmName `
            -VMSize $vmSize `
            -AvailabilitySetId $avSet.Id `
            -Verbose 

        $vmConfig = Set-AzureRmVMOperatingSystem `
            -VM $vmConfig `
            -Linux `
            -ComputerName $vmName `
            -Credential $creds `
            -Verbose 

        $diskName=$vmName+"-osDisk"
        $vmConfig = Set-AzureRmVMOSDisk -VM  $vmConfig -CreateOption FromImage -Name $diskName -Linux 

        $vmConfig = Add-AzureRmVMNetworkInterface `
            -VM $vmConfig `
            -Id $nic.Id `
            -Primary 

        $vmConfig = Set-AzureRmVMSourceImage `
            -VM $vmConfig `
            -PublisherName $script:publisherName `
            -Offer $script:offerName `
            -Skus $script:skuName `
            -Version $script:version -Verbose 

        $vmConfig = Set-AzureRmVMBootDiagnostics -VM $vmConfig -Disable -Verbose 

        New-AzureRmVM -VM $vmConfig `
            -ResourceGroupName $rgName `
            -Location $location -Tag $tag -verbose
    } # end catch
} # end of fuction createAzVM()



for ($i = 0; $i -lt $vmArray.Length; $i++) {
    try {
        $vm = Get-AzureRmVM -Name $vmName -ResourceGroupName $rgName -ErrorAction Stop
        write-host -foreground Yellow "VM:" $vm.Name " already exists."
    }
    catch {

        createAzVM -rgName $rgName `
            -location $location `
            -vmname $vmArray[$i].vmName `
            -vmSize $vmSize `
            -creds $creds `
            -vnet $vmArray[$i].vnetName `
            -subnetName $vmArray[$i].subnetName `
            -nicName $vmArray[$i].nicName `
            -publicVipName $vmArray[$i].publicVipName `
            -publicIPAllocationMethod $vmArray[$i].publicIPAllocationMethod `
            -privateIP $vmArray[$i].privateIP `
            -enableForwarding  $vmArray[$i].enableForwarding

    } #end catch
} #end for


$Text = [IO.File]::ReadAllText("$scriptFile")
write-host -ForegroundColor Green "file content  : $Text"
$EncodedText = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($scriptFile))

$extensionName = "IPforwarder"
$scriptLocation = "https://$storageAccountName.blob.core.windows.net/$ContainerName/" + $scriptName
Write-Host -ForegroundColor Cyan "script location: "$scriptLocation


#$publicConfiguration = @{"fileUris" = [Object[]]"$scriptLocation";"commandToExecute" = "sh $scriptName"}
$publicConfiguration = @{"fileUris" = @($scriptLocation); "commandToExecute" = "sh $scriptName"} 
Set-AzureRmVMExtension -ResourceGroupName $rg.ResourceGroupName -VMName $vm1Name -Location $rg.Location `
    -Name $extensionName                    `
    -Publisher 'Microsoft.Azure.Extensions' `
    -ExtensionType 'CustomScript'           `
    -TypeHandlerVersion '2.0'               `
    -Settings $publicConfiguration  -Verbose -ErrorAction Continue

Get-AzureRmVMExtension -ResourceGroupName $rg.ResourceGroupName -VMName $vm1Name -Name $extensionName -Status -Verbose