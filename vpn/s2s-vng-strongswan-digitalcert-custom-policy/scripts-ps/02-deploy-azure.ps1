#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Resources, Az.Network, Az.KeyVault, Az.Compute, Az.ManagedServiceIdentity
<#
.SYNOPSIS
    Creates all Azure infrastructure for the S2S VPN with digital certificates.

.DESCRIPTION
    Provisions the complete Azure environment for a site-to-site VPN between an
    Azure VPN Gateway (active-active, VpnGw1AZ) and an on-premises StrongSwan NVA.

    Resources created (in order):
      1. Resource Group
      2. VNet1 (Azure side) with GatewaySubnet + Tenant subnet
      3. VNet2 (NVA side) with nvaSubnet + subnetApp
      4. Public IPs for VPN Gateway (2x, zone-redundant) and NVA VM
      5. NSG for NVA (allows UDP 500/4500 for IKE/NAT-T, SSH for management)
      6. NVA VM (Ubuntu 24.04 LTS) with IP forwarding enabled
      7. User-Assigned Managed Identity for VPN Gateway Key Vault access
      8. Key Vault (RBAC mode) with imported leaf .pfx certificate
      9. VPN Gateway with active-active config and managed identity association
     10. Local Network Gateways (2x) pointing to NVA public IP + BGP addresses
     11. VPN Connections (2x) with custom IPsec/IKE policy (GCMAES256) and
         certificate-based authentication (outbound cert from Key Vault,
         inbound trust via StrongSwan Root CA)

    All parameters are read from init.json in the repository root.
    The Key Vault name is deterministically derived from rgName + gwName via SHA256.

    VPN connections use New-AzVirtualNetworkGatewayCertificateAuthentication and
    New-AzVirtualNetworkGatewayConnection -AuthenticationType Certificate.
    No ARM template or az CLI workaround needed.

    Reference:
      https://learn.microsoft.com/azure/vpn-gateway/site-to-site-certificate-authentication-gateway-powershell
      https://github.com/fabferri/az-pattern/tree/master/vpn/s2s-vng-vng-digitalcert-powershell

.NOTES
    Prerequisites:
      - Az PowerShell modules installed (Install-Module Az)
      - Logged in (Connect-AzAccount)
      - Run 01-create-certs.ps1 first to generate certificates
      - init.json present with all required parameters

    Outputs:
      - Prints VPN Gateway public IPs and BGP peering addresses at the end
      - These values are consumed by 02b-generate-strongswan-vars.ps1
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
$certPassword        = $params.certPassword

$vnetName            = $params.vnetName
$vnetAddress         = $params.vnetAddress
$gwSubnetAddress     = $params.gwSubnetAddress
$tenantSubnetName    = $params.tenantSubnetName
$tenantSubnetAddress = $params.tenantSubnetAddress

$gwName              = $params.gwName
$gwSku               = $params.gwSku
$gwGeneration        = $params.gwGeneration
$gwAsn               = $params.gwAsn

$nvaVnetName         = $params.nvaVnetName
$nvaVnetAddress      = $params.nvaVnetAddress
$nvaSubnetName       = $params.nvaSubnetName
$nvaSubnetAddress    = $params.nvaSubnetAddress
$nvaAppSubnetName    = $params.nvaAppSubnetName
$nvaAppSubnetAddress = $params.nvaAppSubnetAddress
$nvaPrivateIp        = $params.nvaPrivateIp
$nvaVmName           = $params.nvaVmName
$nvaVmSize           = $params.nvaVmSize
$nvaAsn              = $params.nvaAsn
$nvaBgpIp0           = $params.nvaBgpIp0
$nvaBgpIp1           = $params.nvaBgpIp1
$advertiseNetwork    = $params.advertiseNetwork

$certRootSubjectGw   = $params.certRootSubjectGw
$certRootSubjectSwan = $params.certRootSubjectSwan
$certLeafSubjectGw   = $params.certLeafSubjectGw
$certLeafSubjectSwan = $params.certLeafSubjectSwan

$certPath = Join-Path $pathFiles 'certs'

# Derived names
$gwPubIp1Name        = "${gwName}pip1"
$gwPubIp2Name        = "${gwName}pip2"
$gwUserIdentityName  = "${gwName}-s2s-kv"
$gwOutboundCertName  = $certLeafSubjectGw
$localNetGw1Name     = "localNetGw-${gwName}-0"
$localNetGw2Name     = "localNetGw-${gwName}-1"
$conn1Name           = "conn-${gwName}-0"
$conn2Name           = "conn-${gwName}-1"
$nvaPubIpName        = "${nvaVmName}-pip"
$nvaNsgName          = "${nvaVmName}-nsg"

# Generate unique Key Vault name (same logic as bash script)
$seed = "$rgName-$gwName"
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($seed))
$suffix = ($hashBytes | Select-Object -First 3 | ForEach-Object { $_.ToString('x2') }) -join ''
$keyVaultName = "kv-${gwName}-${suffix}"

Log "- Configuration loaded from init.json"
Log "  Subscription: $subscriptionName"
Log "  Resource Group: $rgName"
Log "  Location: $location"
Log "  Key Vault: $keyVaultName"
Log " "

###############################################################################
# Verify certificates exist
###############################################################################
Log "- Verifying certificates exist"
foreach ($f in @("$certLeafSubjectGw.pfx", "$certRootSubjectSwan.cer")) {
    $filePath = Join-Path $certPath $f
    if (-not (Test-Path $filePath)) {
        Write-Error "Certificate file not found: $filePath. Please run 01-create-certs.sh first in Azure cloud shell or linux VM to generate certificates."
        exit 1
    }
}
Log "  Certificates verified"

###############################################################################
# Set subscription
###############################################################################
Log "- Setting subscription: $subscriptionName"
Set-AzContext -Subscription $subscriptionName | Out-Null

###############################################################################
# 1. Create Resource Group
###############################################################################
Log "- [1/12] Creating Resource Group: $rgName"
$rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
if ($rg) {
    Log "  Resource group exists, skipping"
} else {
    New-AzResourceGroup -Name $rgName -Location $location -Tag @{ usage = 's2s-digitalcertificates' } | Out-Null
}

###############################################################################
# 2. Create VNet1 (Azure side) with GatewaySubnet
###############################################################################
Log "- [2/12] Creating VNet1: $vnetName"
$vnet1 = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName -ErrorAction SilentlyContinue
if ($vnet1) {
    Log "  VNet exists, skipping"
} else {
    $gwSubnet = New-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -AddressPrefix $gwSubnetAddress
    $tenantSubnet = New-AzVirtualNetworkSubnetConfig -Name $tenantSubnetName -AddressPrefix $tenantSubnetAddress
    $vnet1 = New-AzVirtualNetwork `
        -ResourceGroupName $rgName `
        -Name $vnetName `
        -Location $location `
        -AddressPrefix $vnetAddress `
        -Subnet $gwSubnet, $tenantSubnet
}

###############################################################################
# 3. Create VNet2 (NVA side) with subnets
###############################################################################
Log "- [3/12] Creating VNet2: $nvaVnetName"
$vnet2 = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $nvaVnetName -ErrorAction SilentlyContinue
if ($vnet2) {
    Log "  VNet exists, skipping"
} else {
    $nvaSubnet = New-AzVirtualNetworkSubnetConfig -Name $nvaSubnetName -AddressPrefix $nvaSubnetAddress
    $appSubnet = New-AzVirtualNetworkSubnetConfig -Name $nvaAppSubnetName -AddressPrefix $nvaAppSubnetAddress
    $vnet2 = New-AzVirtualNetwork `
        -ResourceGroupName $rgName `
        -Name $nvaVnetName `
        -Location $location `
        -AddressPrefix $nvaVnetAddress `
        -Subnet $nvaSubnet, $appSubnet
}

###############################################################################
# 4. Create User-Assigned Managed Identity for VPN Gateway
###############################################################################
Log "- [4/12] Creating Managed Identity: $gwUserIdentityName"
$identity = Get-AzUserAssignedIdentity -ResourceGroupName $rgName -Name $gwUserIdentityName -ErrorAction SilentlyContinue
if ($identity) {
    Log "  Managed identity exists, skipping"
} else {
    $identity = New-AzUserAssignedIdentity -ResourceGroupName $rgName -Name $gwUserIdentityName -Location $location
}

$gwUserIdentityId = $identity.Id
$gwUserIdentityPrincipalId = $identity.PrincipalId
Log "  Identity Principal ID: $gwUserIdentityPrincipalId"

###############################################################################
# 5. Create Key Vault with RBAC
###############################################################################
Log "- [5/12] Creating Key Vault: $keyVaultName"
$kv = Get-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $rgName -ErrorAction SilentlyContinue
if ($kv) {
    Log "  Key Vault exists, skipping"
} else {
    # Purge any soft-deleted vault with the same name
    $deleted = Get-AzKeyVault -VaultName $keyVaultName -Location $location -InRemovedState -ErrorAction SilentlyContinue
    if ($deleted) {
        Log "  Purging soft-deleted Key Vault: $keyVaultName"
        Remove-AzKeyVault -VaultName $keyVaultName -InRemovedState -Force -Location $location -ErrorAction SilentlyContinue
    }
    $kv = New-AzKeyVault `
        -VaultName $keyVaultName `
        -ResourceGroupName $rgName `
        -Location $location
}

$keyVaultResourceId = $kv.ResourceId

###############################################################################
# 6. Assign RBAC roles on Key Vault
###############################################################################
Log "- [6/12] Assigning RBAC roles on Key Vault"

# Managed identity: Key Vault Secrets User
$secretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
$existing = Get-AzRoleAssignment -ObjectId $gwUserIdentityPrincipalId -RoleDefinitionId $secretsUserRoleId -Scope $keyVaultResourceId -ErrorAction SilentlyContinue
if (-not $existing) {
    New-AzRoleAssignment `
        -ObjectId $gwUserIdentityPrincipalId `
        -RoleDefinitionId $secretsUserRoleId `
        -Scope $keyVaultResourceId `
        -ObjectType ServicePrincipal | Out-Null
}

# Managed identity: Key Vault Certificate User
$certUserRoleId = 'db79e9a7-68ee-4b58-9aeb-b90e7c24fcba'
$existing = Get-AzRoleAssignment -ObjectId $gwUserIdentityPrincipalId -RoleDefinitionId $certUserRoleId -Scope $keyVaultResourceId -ErrorAction SilentlyContinue
if (-not $existing) {
    New-AzRoleAssignment `
        -ObjectId $gwUserIdentityPrincipalId `
        -RoleDefinitionId $certUserRoleId `
        -Scope $keyVaultResourceId `
        -ObjectType ServicePrincipal | Out-Null
}

# Current user: Key Vault Certificates Officer (to import PFX)
$certOfficerRoleId = 'a4417e6f-fecd-4de8-b567-7b0420556985'
$currentUser = (Get-AzADUser -SignedIn).Id
$newRolesAssigned = $false

$existingAssignment = Get-AzRoleAssignment -ObjectId $currentUser -RoleDefinitionId $certOfficerRoleId -Scope $keyVaultResourceId -ErrorAction SilentlyContinue
if (-not $existingAssignment) {
    New-AzRoleAssignment `
        -ObjectId $currentUser `
        -RoleDefinitionId $certOfficerRoleId `
        -Scope $keyVaultResourceId `
        -ObjectType User | Out-Null
    $newRolesAssigned = $true
} else {
    Log "  Certificates Officer role already assigned"
}

# Current user: Key Vault Secrets User (to read certificate secrets/private keys)
$existingSecretsUser = Get-AzRoleAssignment -ObjectId $currentUser -RoleDefinitionId $secretsUserRoleId -Scope $keyVaultResourceId -ErrorAction SilentlyContinue
if (-not $existingSecretsUser) {
    New-AzRoleAssignment `
        -ObjectId $currentUser `
        -RoleDefinitionId $secretsUserRoleId `
        -Scope $keyVaultResourceId `
        -ObjectType User | Out-Null
    $newRolesAssigned = $true
}

# Current user: Key Vault Certificate User (to read certificates)
$existingCertUser = Get-AzRoleAssignment -ObjectId $currentUser -RoleDefinitionId $certUserRoleId -Scope $keyVaultResourceId -ErrorAction SilentlyContinue
if (-not $existingCertUser) {
    New-AzRoleAssignment `
        -ObjectId $currentUser `
        -RoleDefinitionId $certUserRoleId `
        -Scope $keyVaultResourceId `
        -ObjectType User | Out-Null
    $newRolesAssigned = $true
}

# Verify RBAC propagation by polling Key Vault access (instead of blind sleep)
if ($newRolesAssigned) {
    Log "  Verifying RBAC propagation on Key Vault (polling up to 120s)..."
    $rbacReady = $false
    for ($i = 1; $i -le 12; $i++) {
        try {
            Get-AzKeyVaultCertificate -VaultName $keyVaultName -ErrorAction Stop | Out-Null
            $rbacReady = $true
            break
        } catch {
            Log "    RBAC not yet effective, retrying ($i/12)..."
            Start-Sleep -Seconds 10
        }
    }
    if (-not $rbacReady) {
        Write-Error "RBAC propagation timed out. Cannot access Key Vault: $keyVaultName"
        exit 1
    }
    Log "  RBAC propagation confirmed — Key Vault accessible"
} else {
    Log "  All roles already assigned, skipping propagation check"
}

###############################################################################
# 7. Import VPN Gateway leaf certificate into Key Vault
###############################################################################
Log "- [7/12] Importing certificate into Key Vault: $gwOutboundCertName"
$existingCert = Get-AzKeyVaultCertificate -VaultName $keyVaultName -Name $gwOutboundCertName -ErrorAction SilentlyContinue
if ($existingCert) {
    Log "  Certificate already exists in Key Vault, skipping"
} else {
    $pfxPath = Join-Path $certPath "$certLeafSubjectGw.pfx"
    $securePassword = ConvertTo-SecureString -String $certPassword -AsPlainText -Force
    Import-AzKeyVaultCertificate `
        -VaultName $keyVaultName `
        -Name $gwOutboundCertName `
        -FilePath $pfxPath `
        -Password $securePassword | Out-Null
    Log "  Certificate imported: $gwOutboundCertName"
}

###############################################################################
# 8. Create Public IPs for VPN Gateway (active-active = 2 PIPs)
###############################################################################
Log "- [8/12] Creating Public IPs for VPN Gateway"
foreach ($pipName in @($gwPubIp1Name, $gwPubIp2Name)) {
    $pip = Get-AzPublicIpAddress -ResourceGroupName $rgName -Name $pipName -ErrorAction SilentlyContinue
    if ($pip) {
        Log "  Public IP exists, skipping: $pipName"
    } else {
        New-AzPublicIpAddress `
            -ResourceGroupName $rgName `
            -Name $pipName `
            -Location $location `
            -AllocationMethod Static `
            -Sku Standard `
            -Tier Regional `
            -Zone @('1','2','3') | Out-Null
        Log "  Created: $pipName"
    }
}

###############################################################################
# 9. Create VPN Gateway (active-active with managed identity)
###############################################################################
Log "- [9/12] Creating VPN Gateway: $gwName (this may take 30-45 minutes)"
$existingGw = Get-AzVirtualNetworkGateway -ResourceGroupName $rgName -Name $gwName -ErrorAction SilentlyContinue
if ($existingGw) {
    Log "  VPN Gateway exists, skipping"
} else {
    # Get subnet reference
    $vnet1 = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName
    $gwSubnet = Get-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet1

    # Get public IPs
    $pip1 = Get-AzPublicIpAddress -ResourceGroupName $rgName -Name $gwPubIp1Name
    $pip2 = Get-AzPublicIpAddress -ResourceGroupName $rgName -Name $gwPubIp2Name

    # IP configurations for active-active
    $ipConfig1 = New-AzVirtualNetworkGatewayIpConfig -Name 'ipconfig1' -SubnetId $gwSubnet.Id -PublicIpAddressId $pip1.Id
    $ipConfig2 = New-AzVirtualNetworkGatewayIpConfig -Name 'ipconfig2' -SubnetId $gwSubnet.Id -PublicIpAddressId $pip2.Id

    # Create VPN Gateway with user-assigned managed identity for Key Vault access
    New-AzVirtualNetworkGateway `
        -ResourceGroupName $rgName `
        -Name $gwName `
        -Location $location `
        -IpConfigurations $ipConfig1, $ipConfig2 `
        -GatewayType Vpn `
        -VpnType RouteBased `
        -GatewaySku $gwSku `
        -VpnGatewayGeneration $gwGeneration `
        -EnableBgp $true `
        -Asn $gwAsn `
        -EnableActiveActiveFeature `
        -UserAssignedIdentityId $gwUserIdentityId | Out-Null
    Log "  VPN Gateway created: $gwName (with managed identity $gwUserIdentityName)"
}

$gw = Get-AzVirtualNetworkGateway -ResourceGroupName $rgName -Name $gwName
Log "  VPN Gateway provisioning state: $($gw.ProvisioningState)"
Log "  VPN Gateway managed identity: $($gw.Identity.UserAssignedIdentities.Keys -join ', ')"

###############################################################################
# 10. Create NVA VM (Ubuntu 24.04 LTS + NSG)
###############################################################################
Log "- [10/12] Creating NVA VM: $nvaVmName"

# Create NSG for NVA
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $rgName -Name $nvaNsgName -ErrorAction SilentlyContinue
if ($nsg) {
    Log "  NSG exists, skipping: $nvaNsgName"
} else {
    $rfc1918Rule = New-AzNetworkSecurityRuleConfig -Name 'AllowRFC1918' -Priority 100 `
        -Access Allow -Direction Inbound -Protocol '*' `
        -SourceAddressPrefix '10.0.0.0/8' -SourcePortRange '*' `
        -DestinationAddressPrefix '10.0.0.0/8' -DestinationPortRange '*'

    $sshRule = New-AzNetworkSecurityRuleConfig -Name 'AllowSSH' -Priority 1000 `
        -Access Allow -Direction Inbound -Protocol Tcp `
        -SourceAddressPrefix '*' -SourcePortRange '*' `
        -DestinationAddressPrefix '*' -DestinationPortRange 22

    $ikeRule = New-AzNetworkSecurityRuleConfig -Name 'AllowIKE' -Priority 1010 `
        -Access Allow -Direction Inbound -Protocol Udp `
        -SourceAddressPrefix '*' -SourcePortRange '*' `
        -DestinationAddressPrefix '*' -DestinationPortRange 500

    $nattRule = New-AzNetworkSecurityRuleConfig -Name 'AllowNATT' -Priority 1020 `
        -Access Allow -Direction Inbound -Protocol Udp `
        -SourceAddressPrefix '*' -SourcePortRange '*' `
        -DestinationAddressPrefix '*' -DestinationPortRange 4500

    $rfc1918OutRule = New-AzNetworkSecurityRuleConfig -Name 'AllowRFC1918-Out' -Priority 100 `
        -Access Allow -Direction Outbound -Protocol '*' `
        -SourceAddressPrefix '10.0.0.0/8' -SourcePortRange '*' `
        -DestinationAddressPrefix '10.0.0.0/8' -DestinationPortRange '*'

    $nsg = New-AzNetworkSecurityGroup `
        -ResourceGroupName $rgName `
        -Name $nvaNsgName `
        -Location $location `
        -SecurityRules $rfc1918Rule, $sshRule, $ikeRule, $nattRule, $rfc1918OutRule
}

# Create NVA public IP
$nvaPip = Get-AzPublicIpAddress -ResourceGroupName $rgName -Name $nvaPubIpName -ErrorAction SilentlyContinue
if ($nvaPip) {
    Log "  NVA public IP exists, skipping"
} else {
    $nvaPip = New-AzPublicIpAddress `
        -ResourceGroupName $rgName `
        -Name $nvaPubIpName `
        -Location $location `
        -AllocationMethod Static `
        -Sku Standard
}

# Create NVA VM
$existingVm = Get-AzVM -ResourceGroupName $rgName -Name $nvaVmName -ErrorAction SilentlyContinue
if ($existingVm) {
    Log "  NVA VM exists, skipping"
} else {
    $vnet2 = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $nvaVnetName
    $nvaSubnet = Get-AzVirtualNetworkSubnetConfig -Name $nvaSubnetName -VirtualNetwork $vnet2
    $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $rgName -Name $nvaNsgName

    # Create NIC
    $nvaNicName = "${nvaVmName}-nic"
    $nvaNic = New-AzNetworkInterface `
        -ResourceGroupName $rgName `
        -Name $nvaNicName `
        -Location $location `
        -SubnetId $nvaSubnet.Id `
        -PublicIpAddressId $nvaPip.Id `
        -NetworkSecurityGroupId $nsg.Id `
        -PrivateIpAddress $nvaPrivateIp `
        -EnableIPForwarding

    $secureAdminPassword = ConvertTo-SecureString -String $adminPassword -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($adminUsername, $secureAdminPassword)

    $vmConfig = New-AzVMConfig -VMName $nvaVmName -VMSize $nvaVmSize
    $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Linux -ComputerName $nvaVmName -Credential $cred
    $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName 'Canonical' -Offer 'ubuntu-24_04-lts' -Skus 'server' -Version 'latest'
    $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nvaNic.Id
    $vmConfig = Set-AzVMOSDisk -VM $vmConfig -Name "${nvaVmName}-OS" -CreateOption FromImage -Caching ReadWrite -DeleteOption Delete
    $vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable

    New-AzVM -ResourceGroupName $rgName -Location $location -VM $vmConfig | Out-Null
    Log "  NVA VM created"
}

# Ensure IP forwarding on NVA NIC
$vm = Get-AzVM -ResourceGroupName $rgName -Name $nvaVmName
$nvaNicId = $vm.NetworkProfile.NetworkInterfaces[0].Id
$nvaNicName = ($nvaNicId -split '/')[-1]
$nvaNic = Get-AzNetworkInterface -ResourceGroupName $rgName -Name $nvaNicName
if (-not $nvaNic.EnableIPForwarding) {
    $nvaNic.EnableIPForwarding = $true
    Set-AzNetworkInterface -NetworkInterface $nvaNic | Out-Null
}
Log "  IP forwarding enabled on NVA NIC: $nvaNicName"

###############################################################################
# 11. Create Local Network Gateways (pointing to NVA BGP IPs)
###############################################################################
Log "- [11/12] Creating Local Network Gateways"
$nvaPubIp = (Get-AzPublicIpAddress -ResourceGroupName $rgName -Name $nvaPubIpName).IpAddress
Log "  NVA Public IP: $nvaPubIp"

# Local Network Gateway for tunnel 0
$lng1 = Get-AzLocalNetworkGateway -ResourceGroupName $rgName -Name $localNetGw1Name -ErrorAction SilentlyContinue
if ($lng1) {
    Log "  Local Network Gateway exists, skipping: $localNetGw1Name"
} else {
    New-AzLocalNetworkGateway `
        -ResourceGroupName $rgName `
        -Name $localNetGw1Name `
        -Location $location `
        -GatewayIpAddress $nvaPubIp `
        -Asn $nvaAsn `
        -BgpPeeringAddress $nvaBgpIp0 | Out-Null
    Log "  Created: $localNetGw1Name (BGP: $nvaBgpIp0)"
}

# Local Network Gateway for tunnel 1
$lng2 = Get-AzLocalNetworkGateway -ResourceGroupName $rgName -Name $localNetGw2Name -ErrorAction SilentlyContinue
if ($lng2) {
    Log "  Local Network Gateway exists, skipping: $localNetGw2Name"
} else {
    New-AzLocalNetworkGateway `
        -ResourceGroupName $rgName `
        -Name $localNetGw2Name `
        -Location $location `
        -GatewayIpAddress $nvaPubIp `
        -Asn $nvaAsn `
        -BgpPeeringAddress $nvaBgpIp1 | Out-Null
    Log "  Created: $localNetGw2Name (BGP: $nvaBgpIp1)"
}

###############################################################################
# 12. Create VPN Connections with custom IPsec/IKE policy + certificate auth
###############################################################################
Log "- [12/12] Creating VPN Connections with certificate authentication"

# Get outbound certificate URL from Key Vault
$kvCert = Get-AzKeyVaultCertificate -VaultName $keyVaultName -Name $gwOutboundCertName
$gwOutboundCertUrl = $kvCert.Id
Log "  Outbound cert URL: $gwOutboundCertUrl"

# Read inbound Root CA (StrongSwan's Root CA) as base64.
# Use the PEM-encoded .cer file and strip PEM headers to get raw Base64 content.
$rootSwanCerPath = Join-Path $certPath "$certRootSubjectSwan.cer"
$inboundCertRaw = Get-Content -Path $rootSwanCerPath -Raw
$inboundCertBase64 = $inboundCertRaw -replace '-----BEGIN CERTIFICATE-----', '' `
    -replace '-----END CERTIFICATE-----', ''
$inboundCertChain = @($inboundCertBase64)

# Inbound cert subject = CN of StrongSwan's LEAF cert (bare CN, no "CN=" prefix)
$inboundCertSubject = $certLeafSubjectSwan

# Wait for VPN Gateway BGP IPs
Log "  Waiting for VPN Gateway provisioning to complete..."
$gwBgpIp0 = $null
$gwBgpIp1 = $null
for ($attempt = 1; $attempt -le 30; $attempt++) {
    $gw = Get-AzVirtualNetworkGateway -ResourceGroupName $rgName -Name $gwName
    if ($gw.BgpSettings.BgpPeeringAddresses.Count -ge 2) {
        $gwBgpIp0 = $gw.BgpSettings.BgpPeeringAddresses[0].DefaultBgpIpAddresses[0]
        $gwBgpIp1 = $gw.BgpSettings.BgpPeeringAddresses[1].DefaultBgpIpAddresses[0]
    }
    if ($gwBgpIp0 -and $gwBgpIp1) { break }
    Log "  BGP peering IPs not yet assigned, retrying ($attempt/30)..."
    Start-Sleep -Seconds 20
}

$gwPubIp1 = (Get-AzPublicIpAddress -ResourceGroupName $rgName -Name $gwPubIp1Name).IpAddress
$gwPubIp2 = (Get-AzPublicIpAddress -ResourceGroupName $rgName -Name $gwPubIp2Name).IpAddress

Log "  VPN Gateway Public IP 1: $gwPubIp1 (BGP: $gwBgpIp0)"
Log "  VPN Gateway Public IP 2: $gwPubIp2 (BGP: $gwBgpIp1)"

# Build custom IPsec/IKE policy (GCMAES256 for both IKE and ESP)
# Note: New-AzIpsecPolicy cmdlet does not accept GCMAES256 for -IkeEncryption
# (ValidateSet bug), but the Azure REST API supports it. Construct the object
# directly to bypass cmdlet validation.
$ipsecPolicy = [Microsoft.Azure.Commands.Network.Models.PSIpsecPolicy]::new()
$ipsecPolicy.SALifeTimeSeconds = 3600
$ipsecPolicy.SADataSizeKilobytes = 102400000
$ipsecPolicy.IpsecEncryption = 'GCMAES256'
$ipsecPolicy.IpsecIntegrity = 'GCMAES256'
$ipsecPolicy.IkeEncryption = 'GCMAES256'
$ipsecPolicy.IkeIntegrity = 'SHA256'
$ipsecPolicy.DhGroup = 'DHGroup14'
$ipsecPolicy.PfsGroup = 'PFS2048'

# Create certificate authentication object
# Reference: https://learn.microsoft.com/azure/vpn-gateway/site-to-site-certificate-authentication-gateway-powershell
$certAuth = New-AzVirtualNetworkGatewayCertificateAuthentication `
    -OutboundAuthCertificate $gwOutboundCertUrl `
    -InboundAuthCertificateSubjectName $inboundCertSubject `
    -InboundAuthCertificateChain $inboundCertChain

Log "  Certificate authentication object created"
Log "    Outbound cert URL: $gwOutboundCertUrl"
Log "    Inbound cert subject: $inboundCertSubject"
Log "    Inbound cert chain count: $($inboundCertChain.Count)"

# Get gateway and local network gateway objects
$gw = Get-AzVirtualNetworkGateway -ResourceGroupName $rgName -Name $gwName
$lng1 = Get-AzLocalNetworkGateway -ResourceGroupName $rgName -Name $localNetGw1Name
$lng2 = Get-AzLocalNetworkGateway -ResourceGroupName $rgName -Name $localNetGw2Name

# -----------------------------------------------------------------------------
# Both local network gateways point to the same NVA public IP. Azure rejects
# creating a SECOND connection to an LNG with the same IP when one already
# exists (MultipleConnectionsToLocalNetworkGatewaysWithSameIpAddress).
# Submitting both creations in parallel (via -AsJob) avoids the sequential
# validation check — the same approach the ARM template uses.
# -----------------------------------------------------------------------------

# Skip only if BOTH connections already exist with Certificate authentication.
$conn1Existing = Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $rgName -Name $conn1Name -ErrorAction SilentlyContinue
$conn2Existing = Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $rgName -Name $conn2Name -ErrorAction SilentlyContinue

if ($conn1Existing -and $conn1Existing.AuthenticationType -eq 'Certificate' -and
    $conn2Existing -and $conn2Existing.AuthenticationType -eq 'Certificate') {
    Log "  Both connections exist with Certificate auth, skipping"
} else {
    # Remove any partial/failed connections so both can be (re)created in parallel.
    foreach ($connName in @($conn1Name, $conn2Name)) {
        $existing = Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $rgName -Name $connName -ErrorAction SilentlyContinue
        if ($existing) {
            Log "  Removing existing connection: $connName"
            Remove-AzVirtualNetworkGatewayConnection -ResourceGroupName $rgName -Name $connName -Force | Out-Null
        }
    }

    # Create both connections in parallel with certificate auth + custom IPsec + BGP.
    Log "  Creating both connections in parallel (Certificate auth + custom IPsec + BGP)..."
    $job1 = New-AzVirtualNetworkGatewayConnection `
        -ResourceGroupName $rgName `
        -Name $conn1Name `
        -Location $location `
        -VirtualNetworkGateway1 $gw `
        -LocalNetworkGateway2 $lng1 `
        -ConnectionType IPsec `
        -ConnectionProtocol IKEv2 `
        -AuthenticationType 'Certificate' `
        -CertificateAuthentication $certAuth `
        -IpsecPolicies @($ipsecPolicy) `
        -EnableBgp $true `
        -UsePolicyBasedTrafficSelectors $false -AsJob

    $job2 = New-AzVirtualNetworkGatewayConnection `
        -ResourceGroupName $rgName `
        -Name $conn2Name `
        -Location $location `
        -VirtualNetworkGateway1 $gw `
        -LocalNetworkGateway2 $lng2 `
        -ConnectionType IPsec `
        -ConnectionProtocol IKEv2 `
        -AuthenticationType 'Certificate' `
        -CertificateAuthentication $certAuth `
        -IpsecPolicies @($ipsecPolicy) `
        -EnableBgp $true `
        -UsePolicyBasedTrafficSelectors $false -AsJob

    # Wait for both jobs to complete and verify results
    Log "  Waiting for both connections to complete..."
    $jobs = @($job1, $job2)
    $elapsed = 0
    while (@($jobs | Where-Object { $_.State -eq 'Running' }).Count -gt 0) {
        Start-Sleep -Seconds 10
        $elapsed += 10
        $runningCount = @($jobs | Where-Object { $_.State -eq 'Running' }).Count
        Log "  Jobs still running: $runningCount/2 (elapsed: ${elapsed}s)"
    }

    $allSucceeded = $true
    foreach ($job in $jobs) {
        $connName = if ($job -eq $job1) { $conn1Name } else { $conn2Name }
        if ($job.State -eq 'Completed') {
            $result = $job | Receive-Job
            Log "  Created: $connName (Certificate auth, state: $($job.State))"
        } else {
            $allSucceeded = $false
            $jobError = $job | Receive-Job -ErrorAction SilentlyContinue 2>&1
            $errorMsg = ($jobError | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }) |
                Select-Object -First 1 -ExpandProperty Exception |
                Select-Object -ExpandProperty Message
            Log "  FAILED: $connName (state: $($job.State)) — $errorMsg"
        }
    }

    # Clean up jobs
    $jobs | Remove-Job -Force

    if (-not $allSucceeded) {
        throw "One or more VPN connection creations failed. Check the log above for details."
    }

    Log "  Both connections configured with certificate authentication"
}

###############################################################################
# Summary
###############################################################################
Log " "
Log "==========================================="
Log "  Azure deployment complete!"
Log "==========================================="
Log " "
Log "VPN Gateway:     $gwName (active-active)"
Log "  Public IP 1:   $gwPubIp1 (BGP: $gwBgpIp0)"
Log "  Public IP 2:   $gwPubIp2 (BGP: $gwBgpIp1)"
Log "  ASN:           $gwAsn"
Log " "
Log "NVA VM:          $nvaVmName"
Log "  Public IP:     $nvaPubIp"
Log "  Private IP:    $nvaPrivateIp"
Log "  ASN:           $nvaAsn"
Log " "
Log "Key Vault:       $keyVaultName"
Log "Cert URL:        $gwOutboundCertUrl"
Log " "
Log "Next step: Run 03-configure-strongswan.ps1 to configure the NVA VM"
Log "  SSH: ssh ${adminUsername}@${nvaPubIp}"
