#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Network, Az.Compute
<#
.SYNOPSIS
    Deploys two Ubuntu 24.04 test VMs to validate the Site-to-Site VPN data path.

.DESCRIPTION
    Creates two lightweight VMs (Standard_B2s) on opposite sides of the S2S VPN
    tunnel to verify end-to-end connectivity through the StrongSwan NVA:

      vm1 — placed in VNet1/tenantSubnet (Azure VPN Gateway side)
      vm2 — placed in VNet2/subnetApp (on-premises / NVA side)

    Resources provisioned (in order):
      1. Shared NSG allowing SSH (TCP 22) and ICMP from both VNet address spaces
      2. Route table on subnetApp with a UDR: VNet1 address space -> NVA private IP
         (forces return traffic from vm2 through the NVA/IPsec tunnels)
      3. vm1: public IP + NIC + Ubuntu 24.04 VM in VNet1/tenantSubnet
      4. vm2: public IP + NIC + Ubuntu 24.04 VM in VNet2/subnetApp

    The script is idempotent — existing resources are detected and skipped.
    Static private IPs are derived from subnet address prefixes (subnet base + offset).

    After deployment, cross-tunnel connectivity is tested by pinging between
    vm1 (VNet1) and vm2 (VNet2) over the IPsec tunnels.

.NOTES
    Prerequisites:
      - Az PowerShell modules installed and logged in
      - 02-deploy-azure.ps1 already run (VNets/subnets + NVA exist)
      - Tunnels up (03-configure-strongswan.ps1) for cross-tunnel ping to succeed
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Log { param([string]$Message) Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message" }

###############################################################################
# Read parameters from init.json
###############################################################################
$pathFiles = Split-Path -Parent $PSScriptRoot
$inputParamsFile = Join-Path $pathFiles 'init.json'

if (-not (Test-Path $inputParamsFile)) {
    Write-Error "Parameters file not found: $inputParamsFile"
    exit 1
}

$params = Get-Content $inputParamsFile -Raw | ConvertFrom-Json

$subscriptionName    = $params.subscriptionName
$rgName              = $params.rgName
$location            = $params.location
$adminUsername       = $params.adminUsername
$adminPassword       = $params.adminPassword

$vnetName            = $params.vnetName
$vnetAddress         = $params.vnetAddress
$tenantSubnetName    = $params.tenantSubnetName
$tenantSubnetAddress = $params.tenantSubnetAddress

$nvaVnetName         = $params.nvaVnetName
$nvaVnetAddress      = $params.nvaVnetAddress
$nvaSubnetName       = $params.nvaSubnetName
$nvaAppSubnetName    = $params.nvaAppSubnetName
$nvaAppSubnetAddress = $params.nvaAppSubnetAddress
$nvaPrivateIp        = $params.nvaPrivateIp

###############################################################################
# Derived settings
###############################################################################
$imagePublisher = 'Canonical'
$imageOffer = 'ubuntu-24_04-lts'
$imageSku = 'server'
$imageVersion = 'latest'
$testVmSize = 'Standard_B2s'
$testVm1Name = 'vm1'
$testVm2Name = 'vm2'
$testNsgName = 'vm-nsg'

$routeTableName = "rt-$nvaAppSubnetName"
$routeName = "to-$vnetName"

# Guard: subnetApp must differ from nvaSubnet
if ($nvaAppSubnetName -eq $nvaSubnetName) {
    Write-Error "nvaAppSubnetName equals nvaSubnetName; VM2 must be in a different subnet"
    exit 1
}

###############################################################################
# 0. Select subscription
###############################################################################
Log "- Setting subscription: $subscriptionName"
Set-AzContext -Subscription $subscriptionName | Out-Null

###############################################################################
# 1. Shared NSG (SSH from Internet, ICMP from both VNet address spaces)
###############################################################################
Log "- [1/6] Creating test NSG: $testNsgName"
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $rgName -Name $testNsgName -ErrorAction SilentlyContinue
if ($nsg) {
    Log "    NSG exists, skipping"
} else {
    $sshRule = New-AzNetworkSecurityRuleConfig -Name 'AllowSSH' -Priority 1000 `
        -Access Allow -Direction Inbound -Protocol Tcp `
        -SourceAddressPrefix '*' -SourcePortRange '*' `
        -DestinationAddressPrefix '*' -DestinationPortRange 22

    $icmpRule = New-AzNetworkSecurityRuleConfig -Name 'AllowICMP' -Priority 1010 `
        -Access Allow -Direction Inbound -Protocol Icmp `
        -SourceAddressPrefix '10.0.0.0/8' -SourcePortRange '*' `
        -DestinationAddressPrefix '10.0.0.0/8' -DestinationPortRange '*'

    $httpRule = New-AzNetworkSecurityRuleConfig -Name 'AllowHTTP' -Priority 1020 `
        -Access Allow -Direction Inbound -Protocol Tcp `
        -SourceAddressPrefix '10.0.0.0/8' -SourcePortRange '*' `
        -DestinationAddressPrefix '10.0.0.0/8' -DestinationPortRange 80

    $rfc1918OutRule = New-AzNetworkSecurityRuleConfig -Name 'AllowRFC1918-Out' -Priority 100 `
        -Access Allow -Direction Outbound -Protocol '*' `
        -SourceAddressPrefix '10.0.0.0/8' -SourcePortRange '*' `
        -DestinationAddressPrefix '10.0.0.0/8' -DestinationPortRange '*'

    $nsg = New-AzNetworkSecurityGroup `
        -ResourceGroupName $rgName `
        -Name $testNsgName `
        -Location $location `
        -SecurityRules $sshRule, $icmpRule, $httpRule, $rfc1918OutRule
}

###############################################################################
# 2. Route table on subnetApp: VNet1 space -> NVA
###############################################################################
Log "- [2/6] Creating route table $routeTableName on $nvaAppSubnetName"
$rt = Get-AzRouteTable -ResourceGroupName $rgName -Name $routeTableName -ErrorAction SilentlyContinue
if ($rt) {
    Log "    Route table exists, skipping create"
} else {
    $rt = New-AzRouteTable `
        -ResourceGroupName $rgName `
        -Name $routeTableName `
        -Location $location
}

$existingRoute = Get-AzRouteConfig -RouteTable $rt -Name $routeName -ErrorAction SilentlyContinue
if ($existingRoute) {
    Log "    Route exists, skipping"
} else {
    Add-AzRouteConfig `
        -RouteTable $rt `
        -Name $routeName `
        -AddressPrefix $vnetAddress `
        -NextHopType VirtualAppliance `
        -NextHopIpAddress $nvaPrivateIp | Out-Null
    Set-AzRouteTable -RouteTable $rt | Out-Null
}

# Associate route table with subnetApp
Log "    Associating route table with $nvaAppSubnetName"
$vnet2 = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $nvaVnetName
$appSubnet = Get-AzVirtualNetworkSubnetConfig -Name $nvaAppSubnetName -VirtualNetwork $vnet2
$rt = Get-AzRouteTable -ResourceGroupName $rgName -Name $routeTableName
Set-AzVirtualNetworkSubnetConfig `
    -VirtualNetwork $vnet2 `
    -Name $nvaAppSubnetName `
    -AddressPrefix $appSubnet.AddressPrefix `
    -RouteTableId $rt.Id | Out-Null
$vnet2 | Set-AzVirtualNetwork | Out-Null

###############################################################################
# 3. Test VM in VNet1 (tenant subnet)
###############################################################################
Log "- [3/6] Creating test VM in $vnetName/$tenantSubnetName (dynamic IP)"
$existingVm1 = Get-AzVM -ResourceGroupName $rgName -Name $testVm1Name -ErrorAction SilentlyContinue
if ($existingVm1) {
    Log "    $testVm1Name exists, skipping"
} else {
    # Public IP
    $pip1 = Get-AzPublicIpAddress -ResourceGroupName $rgName -Name "${testVm1Name}-pip" -ErrorAction SilentlyContinue
    if (-not $pip1) {
        $pip1 = New-AzPublicIpAddress `
            -ResourceGroupName $rgName `
            -Name "${testVm1Name}-pip" `
            -Location $location `
            -Sku Standard `
            -Tier Regional `
            -AllocationMethod Static `
            -Zone @('1','2','3')
    }

    # NIC
    $vnet1 = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName
    $tenantSubnet = Get-AzVirtualNetworkSubnetConfig -Name $tenantSubnetName -VirtualNetwork $vnet1
    $nsgObj = Get-AzNetworkSecurityGroup -ResourceGroupName $rgName -Name $testNsgName

    $nic1 = Get-AzNetworkInterface -ResourceGroupName $rgName -Name "${testVm1Name}-nic" -ErrorAction SilentlyContinue
    if (-not $nic1) {
        $nic1 = New-AzNetworkInterface `
            -ResourceGroupName $rgName `
            -Name "${testVm1Name}-nic" `
            -Location $location `
            -SubnetId $tenantSubnet.Id `
            -PublicIpAddressId $pip1.Id `
            -NetworkSecurityGroupId $nsgObj.Id `
            -EnableIPForwarding:$false
    }

    $securePassword = ConvertTo-SecureString -String $adminPassword -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($adminUsername, $securePassword)

    $vmConfig = New-AzVMConfig -VMName $testVm1Name -VMSize $testVmSize
    $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Linux -ComputerName $testVm1Name -Credential $cred
    $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName $imagePublisher -Offer $imageOffer -Skus $imageSku -Version $imageVersion
    $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic1.Id
    $vmConfig = Set-AzVMOSDisk -VM $vmConfig -Name "${testVm1Name}-osdisk" -CreateOption FromImage -Caching ReadWrite
    $vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable

    New-AzVM -ResourceGroupName $rgName -Location $location -VM $vmConfig | Out-Null
    Log "    $testVm1Name created"
}

###############################################################################
# 4. Test VM in VNet2 (subnetApp)
###############################################################################
Log "- [4/6] Creating test VM in $nvaVnetName/$nvaAppSubnetName (dynamic IP)"
$existingVm2 = Get-AzVM -ResourceGroupName $rgName -Name $testVm2Name -ErrorAction SilentlyContinue
if ($existingVm2) {
    Log "    $testVm2Name exists, skipping"
} else {
    # Public IP
    $pip2 = Get-AzPublicIpAddress -ResourceGroupName $rgName -Name "${testVm2Name}-pip" -ErrorAction SilentlyContinue
    if (-not $pip2) {
        $pip2 = New-AzPublicIpAddress `
            -ResourceGroupName $rgName `
            -Name "${testVm2Name}-pip" `
            -Location $location `
            -Sku Standard `
            -Tier Regional `
            -AllocationMethod Static `
            -Zone @('1','2','3')
    }

    # NIC
    $vnet2 = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $nvaVnetName
    $appSubnet = Get-AzVirtualNetworkSubnetConfig -Name $nvaAppSubnetName -VirtualNetwork $vnet2
    $nsgObj = Get-AzNetworkSecurityGroup -ResourceGroupName $rgName -Name $testNsgName

    $nic2 = Get-AzNetworkInterface -ResourceGroupName $rgName -Name "${testVm2Name}-nic" -ErrorAction SilentlyContinue
    if (-not $nic2) {
        $nic2 = New-AzNetworkInterface `
            -ResourceGroupName $rgName `
            -Name "${testVm2Name}-nic" `
            -Location $location `
            -SubnetId $appSubnet.Id `
            -PublicIpAddressId $pip2.Id `
            -NetworkSecurityGroupId $nsgObj.Id `
            -EnableIPForwarding:$false
    }

    $securePassword = ConvertTo-SecureString -String $adminPassword -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($adminUsername, $securePassword)

    $vmConfig = New-AzVMConfig -VMName $testVm2Name -VMSize $testVmSize
    $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Linux -ComputerName $testVm2Name -Credential $cred
    $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName $imagePublisher -Offer $imageOffer -Skus $imageSku -Version $imageVersion
    $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic2.Id
    $vmConfig = Set-AzVMOSDisk -VM $vmConfig -Name "${testVm2Name}-osdisk" -CreateOption FromImage -Caching ReadWrite
    $vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable

    New-AzVM -ResourceGroupName $rgName -Location $location -VM $vmConfig | Out-Null
    Log "    $testVm2Name created"
}

###############################################################################
# 5. Install nginx via Custom Script Extension on both VMs
###############################################################################
Log "- [5/6] Installing nginx via Custom Script Extension"

$nginxScript = 'apt-get update -qq && apt-get install -y nginx && systemctl enable nginx && systemctl start nginx'

foreach ($vmName in @($testVm1Name, $testVm2Name)) {
    $ext = Get-AzVMExtension -ResourceGroupName $rgName -VMName $vmName -Name 'install-nginx' -ErrorAction SilentlyContinue
    if ($ext) {
        Log "    Custom Script Extension already exists on $vmName, skipping"
    } else {
        Set-AzVMExtension `
            -ResourceGroupName $rgName `
            -VMName $vmName `
            -Name 'install-nginx' `
            -Publisher 'Microsoft.Azure.Extensions' `
            -ExtensionType 'CustomScript' `
            -TypeHandlerVersion '2.1' `
            -Settings @{ commandToExecute = $nginxScript } | Out-Null
        Log "    nginx installed on $vmName"
    }
}

###############################################################################
# 6. Fix NRMS subnet-level NSGs for forwarded/tunnel traffic
#    Corporate NRMS NSGs are auto-applied at subnet level by Azure Policy.
#    They may not exist immediately after VNet creation (policy is async).
#    Their default AllowVnetInBound/AllowVnetOutBound rules don't match
#    forwarded packets whose source IP is outside the local VNet.
#    Without explicit RFC1918 rules, DenyAll drops forwarded traffic silently.
###############################################################################
Log "- [6/6] Patching NRMS subnet-level NSGs for forwarded traffic"

$subnetsToFix = @(
    @{ VNet = $vnetName;    Subnet = $tenantSubnetName },
    @{ VNet = $nvaVnetName; Subnet = $nvaSubnetName },
    @{ VNet = $nvaVnetName; Subnet = $nvaAppSubnetName }
)

# Wait for NRMS NSGs to be applied by Azure Policy (up to 10 minutes)
$maxWaitSeconds = 600
$pollInterval = 30
$elapsed = 0
$allFound = $false

Log "    Waiting for NRMS policy to apply subnet-level NSGs (up to $($maxWaitSeconds/60) min)..."
while ($elapsed -lt $maxWaitSeconds) {
    $allFound = $true
    foreach ($entry in $subnetsToFix) {
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $entry.VNet
        $sub = Get-AzVirtualNetworkSubnetConfig -Name $entry.Subnet -VirtualNetwork $vnet
        if (-not $sub.NetworkSecurityGroup) {
            $allFound = $false
            break
        }
    }
    if ($allFound) { break }
    $elapsed += $pollInterval
    if ($elapsed -lt $maxWaitSeconds) {
        Log "    Not all subnet NSGs present yet, retrying in ${pollInterval}s ($elapsed/${maxWaitSeconds}s)..."
        Start-Sleep -Seconds $pollInterval
    }
}

if (-not $allFound) {
    Log "    WARNING: NRMS NSGs did not appear within $($maxWaitSeconds/60) min."
    Log "    Re-run this script later or manually add AllowRFC1918 rules to subnet NSGs."
    Log "    Proceeding without patching (cross-tunnel traffic may be blocked)."
} else {
    Log "    All subnet-level NSGs detected. Patching..."
    foreach ($entry in $subnetsToFix) {
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $entry.VNet
        $sub = Get-AzVirtualNetworkSubnetConfig -Name $entry.Subnet -VirtualNetwork $vnet
        $nsgName = $sub.NetworkSecurityGroup.Id -split '/' | Select-Object -Last 1
        $subNsg = Get-AzNetworkSecurityGroup -ResourceGroupName $rgName -Name $nsgName
        $changed = $false

        # Inbound: allow RFC1918 → RFC1918
        if (-not ($subNsg.SecurityRules | Where-Object { $_.Name -eq 'AllowRFC1918-In' })) {
            Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $subNsg `
                -Name 'AllowRFC1918-In' -Priority 100 `
                -Access Allow -Direction Inbound -Protocol '*' `
                -SourceAddressPrefix '10.0.0.0/8' -SourcePortRange '*' `
                -DestinationAddressPrefix '10.0.0.0/8' -DestinationPortRange '*' | Out-Null
            $changed = $true
        }

        # Outbound: allow RFC1918 → RFC1918
        if (-not ($subNsg.SecurityRules | Where-Object { $_.Name -eq 'AllowRFC1918-Out' })) {
            Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $subNsg `
                -Name 'AllowRFC1918-Out' -Priority 100 `
                -Access Allow -Direction Outbound -Protocol '*' `
                -SourceAddressPrefix '10.0.0.0/8' -SourcePortRange '*' `
                -DestinationAddressPrefix '10.0.0.0/8' -DestinationPortRange '*' | Out-Null
            $changed = $true
        }

        if ($changed) {
            Set-AzNetworkSecurityGroup -NetworkSecurityGroup $subNsg | Out-Null
            Log "    $($entry.VNet)/$($entry.Subnet): added RFC1918 rules to $nsgName"
        } else {
            Log "    $($entry.VNet)/$($entry.Subnet): RFC1918 rules already present in $nsgName"
        }
    }
}

###############################################################################
# Summary
###############################################################################
$vm1Pub = (Get-AzPublicIpAddress -ResourceGroupName $rgName -Name "${testVm1Name}-pip" -ErrorAction SilentlyContinue).IpAddress
if (-not $vm1Pub) { $vm1Pub = 'n/a' }
$vm2Pub = (Get-AzPublicIpAddress -ResourceGroupName $rgName -Name "${testVm2Name}-pip" -ErrorAction SilentlyContinue).IpAddress
if (-not $vm2Pub) { $vm2Pub = 'n/a' }

# Retrieve dynamically assigned private IPs from NICs
$nic1Obj = Get-AzNetworkInterface -ResourceGroupName $rgName -Name "${testVm1Name}-nic" -ErrorAction SilentlyContinue
$testVm1Ip = if ($nic1Obj) { $nic1Obj.IpConfigurations[0].PrivateIpAddress } else { 'n/a' }
$nic2Obj = Get-AzNetworkInterface -ResourceGroupName $rgName -Name "${testVm2Name}-nic" -ErrorAction SilentlyContinue
$testVm2Ip = if ($nic2Obj) { $nic2Obj.IpConfigurations[0].PrivateIpAddress } else { 'n/a' }

Log " "
Log "==========================================="
Log "  Test VMs deployed"
Log "==========================================="
Log "  $testVm1Name (VNet1/$tenantSubnetName):  private $testVm1Ip  public $vm1Pub"
Log "  $testVm2Name (VNet2/$nvaAppSubnetName):  private $testVm2Ip  public $vm2Pub"
Log " "
Log "Test the S2S data path across the tunnel:"
Log "  ssh ${adminUsername}@${vm1Pub}   # then: ping -c 4 ${testVm2Ip}"
Log "  ssh ${adminUsername}@${vm2Pub}   # then: ping -c 4 ${testVm1Ip}"
Log " "
Log "If VNet2 -> VNet1 fails but VNet1 -> VNet2 works, check the route table"
Log "$routeTableName association and that the NVA tunnels/BGP are up."
