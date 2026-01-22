# Script to create VPN Gateway with certificate authentication using managed identity and Key Vault
# The script create a managed identity with readonly access to  Key Vault integration to access to the digital certificate required to establish a Connection
# $subscriptionName and $rgName collected by "init.json" file
#
$vnet2Name = 'vnet2'
$gw2Name = 'gw2'
$gw2pubIP1Name = $gw2Name + "pip"

$gw2UserIdentityName = 'gw2-s2s-kv'
$gw2ConfigName = 'gw2-config'
$location = 'uksouth'

$vnet2subnet1Name ='Tenant'
$vnetAddress = '10.2.0.0/16'
$gw2SubnetAddress = '10.2.0.0/24'
$vnet2subnet1Address = '10.2.1.0/24'
$gw2OutboundCertName = 'gw2-cert'


$pathFiles = Split-Path -Parent $PSCommandPath
$inputParams = 'init.json'
$inputParamsFile = "$pathFiles\$inputParams"

try {
     $arrayParams = (Get-Content -Raw $inputParamsFile | ConvertFrom-Json)
     $subscriptionName = $arrayParams.subscriptionName
     $rgName = $arrayParams.rgName
}
catch {
     Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
     Exit
}

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                       else { Write-Host '   resource group name...: '$rgName -ForegroundColor Yellow }    


$seed = "$rgName-$gw2Name"
$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($seed))
$suffix = [System.BitConverter]::ToString($hash).Replace("-", "").Substring(0, 6).ToLower()
$keyVault2Name = "kv-$gw2Name-$suffix"

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id


# Create Resource Group 
Write-Host $(Get-Date)'- Creating Resource Group' -ForegroundColor Cyan
Try {
    $rg = Get-AzResourceGroup -Name $rgName -ErrorAction Stop
    Write-Host 'Resource exists, skipping'
}
Catch {
    $rg = New-AzResourceGroup -Name $rgName -Location $location
}

# Add Tag Values to the Resource Group
Set-AzResourceGroup -Name $rgName -Tags @{ usage = "s2s-digitalcertificates" } | Out-Null

###
# Create Virtual Network
Write-Host (Get-Date)'- Creating Virtual Network' -ForegroundColor Cyan
Try {
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnet2Name -ErrorAction Stop
    Write-Host '  resource exists, skipping'
}
Catch {
    $vnet = New-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnet2Name -AddressPrefix $vnetAddress -Location $location
    # Add Subnets
    Write-Host (Get-Date)'- Adding subnets' -ForegroundColor Cyan
    Add-AzVirtualNetworkSubnetConfig -Name $vnet2subnet1Name -VirtualNetwork $vnet -AddressPrefix $vnet2subnet1Address | Out-Null
    Add-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet -AddressPrefix $gw2SubnetAddress | Out-Null
    Set-AzVirtualNetwork -VirtualNetwork $vnet | Out-Null
}

try {
    Write-Host (Get-Date)'- Getting managed identity: '$gw2UserIdentityName -ForegroundColor Cyan
    $gw2UserIdentity = Get-AzUserAssignedIdentity -ResourceGroupName $rgName -Name $gw2UserIdentityName -ErrorAction Stop
}
catch {
    Write-Host (Get-Date)'- Creating managed identity: '$gw2UserIdentityName -ForegroundColor Cyan
    # Create managed identity
    $gw2UserIdentity = New-AzUserAssignedIdentity -ResourceGroupName $rgName -Name $gw2UserIdentityName -Location $location
    Write-Host (Get-Date)'- Created managed identity: '$gw2UserIdentityName -ForegroundColor Cyan
}
$gw2UserIdentity = Get-AzUserAssignedIdentity -ResourceGroupName $rgName -Name $gw2UserIdentityName

# Create Key Vault with RBAC enabled
Write-Host (Get-Date)'- Creating Key Vault: '$keyVault2Name -ForegroundColor Cyan

$keyVault = Get-AzKeyVault -VaultName $keyVault2Name -ResourceGroupName $rgName
If ($keyVault -eq $null) {
    Write-Host (Get-Date)'- clearing any older Key Vaults (this may take 30 seconds or more).' -ForegroundColor Cyan
    Get-AzKeyVault -InRemovedState | Remove-AzKeyVault -InRemovedState -Force
    Write-Host (Get-Date)'- creating new Key Vault with RBAC enabled' -ForegroundColor Cyan
    $keyVault = New-AzKeyVault -VaultName $keyVault2Name -ResourceGroupName $rgName -Location $location
}
Else {
    Write-Host (Get-Date)'-  keyvault already exists, skipping creation: ' $keyVault2Name -ForegroundColor Cyan
}

# Refresh Key Vault object to ensure ResourceId is available
$keyVault = Get-AzKeyVault -VaultName $keyVault2Name -ResourceGroupName $rgName
Write-Host (Get-Date)'- Key Vault ResourceId: '$keyVault.ResourceId

# Grant managed identity access to Key Vault using RBAC
Write-Host (Get-Date)'- granting managed identity RBAC access to Key Vault: '$keyVault2Name

# Assign "Key Vault Secrets User" role (for get/list secrets)
$secretsUserRoleId = "4633458b-17de-408a-b874-0445c86b69e6"  # Key Vault Secrets User
New-AzRoleAssignment -ObjectId $gw2UserIdentity.PrincipalId -RoleDefinitionId $secretsUserRoleId -Scope $keyVault.ResourceId -ErrorAction SilentlyContinue

# Assign "Key Vault Certificate User" role (for get/list certificates)
$certUserRoleId = "db79e9a7-68ee-4b58-9aeb-b90e7c24fcba"  # Key Vault Certificate User
New-AzRoleAssignment -ObjectId $gw2UserIdentity.PrincipalId -RoleDefinitionId $certUserRoleId -Scope $keyVault.ResourceId -ErrorAction SilentlyContinue

Write-Host (Get-Date)'- RBAC role assignments created for managed identity'

$currentUser = (Get-AzContext).Account.Id
Write-Host (Get-Date)'- getting user account ID: '$currentUser

# Get current user's Object ID for RBAC assignment
$currentUserObjectId = (Get-AzADUser -UserPrincipalName $currentUser).Id

# Assign "Key Vault Certificates Officer" role (for full certificate management)
$certOfficerRoleId = "a4417e6f-fecd-4de8-b567-7b0420556985"  # Key Vault Certificates Officer

# Check if role assignment exists
$existingAssignment = Get-AzRoleAssignment -ObjectId $currentUserObjectId `
    -RoleDefinitionId $certOfficerRoleId `
    -Scope $keyVault.ResourceId -ErrorAction SilentlyContinue

if (-not $existingAssignment) {
    Write-Host (Get-Date)"- Creating Role assignment for current user to Key Vault Certificates Officer role" -ForegroundColor Green
    New-AzRoleAssignment -ObjectId $currentUserObjectId -RoleDefinitionId $certOfficerRoleId -Scope $keyVault.ResourceId 
    Write-Host (Get-Date)"- Role assignment created"
    # Wait for access policy propagation
    Write-Host (Get-Date)'- waiting 30 seconds for access policy changes to propagate...' -ForegroundColor Yellow
    Start-Sleep -Seconds 30
}
else {
    Write-Host (Get-Date)'- Role assignment already exists, skipping'
}

Write-Host (Get-Date)'- RBAC role assignment created for user: '$currentUser



# Import certificate in keyvault
write-host (Get-date)'- import certificate in keyvault: '$keyVault2Name -ForegroundColor Green
$cert2FilePath = "$pathFiles\certs\s2s-cert2.pfx"
$certPassword = ConvertTo-SecureString -String "12345" -Force -AsPlainText
Import-AzKeyVaultCertificate -VaultName $keyVault2Name -Name $gw2OutboundCertName `
    -FilePath $cert2FilePath -Password $certPassword

# public IP VPN GTW
try {
    Write-Host (Get-date)"- getting public ip exists: "$gw2pubIP1Name -ForegroundColor Cyan
    $gw2pubIP1 = Get-AzPublicIpAddress -ResourceGroupName $rgName -name $gw2pubIP1Name -ErrorAction Stop
    Write-Host (Get-date)"- public ip exists, skipping: "$gw2pubIP1.Name -ForegroundColor Cyan
}
catch {
    $gw2pubIP1 = New-AzPublicIpAddress -ResourceGroupName $rgName -name $gw2pubIP1Name -location $location -AllocationMethod Static -Sku Standard -Tier Regional -Zone @("1", "2", "3")
    write-host (Get-date)"- public ip created: "$gw2pubIP1.Name -ForegroundColor Cyan
}

# Get the virtual network and GatewaySubnet
$vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnet2Name
$gw2Subnet = Get-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet

# Create VirtualNetworkGateway with managed identity
$gw2IpConfig = New-AzVirtualNetworkGatewayIpConfig -Name $gw2ConfigName -PublicIpAddress $gw2pubIP1 -Subnet $gw2Subnet
try {
    Write-Host (Get-date)"- checking if the vpn gateway exists: "$gw2Name -ForegroundColor Green
    $gw2 = Get-AzVirtualNetworkGateway -ResourceGroupName $rgName -name $gw2Name -ErrorAction Stop
    Write-Host (Get-date)"- vpn gateway exists, skipping: "$gw2.Name -ForegroundColor Green
}
catch {
    Write-Host (Get-date)"- creating vpn gateway: "$gw2Name -ForegroundColor Green
    $gw2 = New-AzVirtualNetworkGateway -ResourceGroupName $rgName -name $gw2Name `
        -location $location `
        -IpConfigurations $gw2IpConfig `
        -GatewayType Vpn `
        -VpnType RouteBased `
        -EnableBgp $false `
        -GatewaySku VpnGw2AZ `
        -VpnGatewayGeneration Generation2 `
        -UserAssignedIdentityId $gw2UserIdentity.Id
    $gw2 = Get-AzVirtualNetworkGateway -ResourceGroupName $rgName -name $gw2Name
    write-host (Get-date)"- vpn gateway created: "$gw2.Name -ForegroundColor Green
}

write-host (Get-date)"- vpn gateway status: "$gw2.ProvisioningState -ForegroundColor Green
write-host (Get-date)"- vpn gateway with managed identity: "$gw2.Identity -ForegroundColor Green

