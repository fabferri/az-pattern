# address space for the virtual networks
$vnet1Address = '10.1.0.0/16'
$vnet2Address = '10.2.0.0/16'
##### vpn parameters
$gw1Name = 'gw1'
$localNetgw1Name = 'localNetGw1'
$gw1Connection1Name = 'Connection1'
$gw1pubIP1Name = $gw1Name + 'pip'
$gw2Name = 'gw2'
$localNetgw2Name = 'localNetGw2'
$gw2Connection1Name = 'Connection2'
$gw2pubIP1Name = $gw2Name + 'pip'

##### Key Vault and Certificate parameters
$location = 'uksouth'
$gw1OutboundCertName = 'gw1-cert'
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

$seed = "$rgName-$gw1Name"
$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($seed))
$suffix = [System.BitConverter]::ToString($hash).Replace("-", "").Substring(0, 6).ToLower()
$keyVault1Name = "kv-$gw1Name-$suffix"

$seed = "$rgName-$gw2Name"
$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($seed))
$suffix = [System.BitConverter]::ToString($hash).Replace("-", "").Substring(0, 6).ToLower()
$keyVault2Name = "kv-$gw2Name-$suffix"

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

try {
    write-host (Get-Date)'- fetch vpn gateway1 - public IP1: '$gw1pubIP1Name
    $gw1publicIP1 = (Get-AzPublicIpAddress -Name $gw1pubIP1Name -ResourceGroupName $rgName).IPAddress
    write-host (Get-Date)' - Azure vpn Gateway1 public IP1 .: '$gw1publicIP1 -ForegroundColor Cyan
    
}
catch {
    write-host (Get-Date)'- vpn gateway1 - error to retrieve public IPs' -ForegroundColor Yellow
    Exit
}

try {
    write-host (Get-Date)'- fetch vpn gateway1 - public IP1: '$gw2pubIP1Name
    $gw2publicIP1 = (Get-AzPublicIpAddress -Name $gw2pubIP1Name -ResourceGroupName $rgName).IPAddress
    write-host (Get-Date)' - Azure VPN Gateway1 public IP1 .: '$gw2publicIP1 -ForegroundColor Cyan
    
}
catch {
    write-host (Get-Date)'- vpn gateway2 - error to retrieve public IPs' -ForegroundColor Yellow
    Exit
}


# Create LocalNetworkGateway
try {
    $localNetgw1 = Get-AzLocalNetworkGateway -name $localNetgw1Name -ResourceGroupName $rgName -ErrorAction Stop
    Write-Host (Get-date)"- local network gateway exists, skipping: "$localNetgw1.Name -ForegroundColor Green
}
catch {
    Write-Host (Get-date)"- creating local network gateway: "$localNetgw1Name -ForegroundColor Green
    $localNetgw1 = New-AzLocalNetworkGateway -name $localNetgw1Name `
        -ResourceGroupName $rgName `
        -location $location `
        -AddressPrefix $vnet1Address `
        -GatewayIpAddress $gw1publicIP1
}

# Create LocalNetworkGateway
try {
    $localNetgw2 = Get-AzLocalNetworkGateway -name $localNetgw2Name -ResourceGroupName $rgName -ErrorAction Stop
    Write-Host (Get-date)"- local network gateway exists, skipping: "$localNetgw2.Name -ForegroundColor Green
}
catch {
    Write-Host (Get-date)"- creating local network gateway: "$localNetgw2Name -ForegroundColor Green
    $localNetgw2 = New-AzLocalNetworkGateway -name $localNetgw2Name `
        -ResourceGroupName $rgName `
        -location $location `
        -AddressPrefix $vnet2Address `
        -GatewayIpAddress $gw2publicIP1
}

$gw1certOutbound = Get-AzKeyVaultCertificate -VaultName $keyVault1Name -Name $gw1OutboundCertName
$gw1OutboundCertUrl = $gw1certOutbound.Id
$gw1OutboundcertData = Get-AzKeyVaultCertificate -VaultName $keyVault1Name -Name $gw1OutboundCertName
$gw1OutboundcertBytes = [System.Convert]::ToBase64String($gw1OutboundcertData.Certificate.RawData)
$gw1OutboundcertSubjectName = $gw1OutboundcertData.Certificate.Subject -replace "^CN=", ""

$gw2certOutbound = Get-AzKeyVaultCertificate -VaultName $keyVault2Name -Name $gw2OutboundCertName
$gw2OutboundCertUrl = $gw2certOutbound.Id
$gw2OutboundcertData = Get-AzKeyVaultCertificate -VaultName $keyVault2Name -Name $gw2OutboundCertName
$gw2OutboundcertBytes = [System.Convert]::ToBase64String($gw2OutboundcertData.Certificate.RawData)
$gw2OutboundcertSubjectName = $gw2OutboundcertData.Certificate.Subject -replace "^CN=", ""

# Read Inbound Certificate Chain files
Write-Host (Get-date)"- reading inbound certificate chain files" -ForegroundColor Green
$inboundCert1Path = "$pathFiles\certs\VPNRootCA1.cer"
$inboundCert2Path = "$pathFiles\certs\VPNRootCA2.cer"
$inboundCert1Data = Get-Content -Path $inboundCert1Path -Raw
$inboundCert2Data = Get-Content -Path $inboundCert2Path -Raw

# Remove PEM headers if present and get Base64 only
$inboundCert1Base64 = $inboundCert1Data -replace "-----BEGIN CERTIFICATE-----", "" -replace "-----END CERTIFICATE-----", ""
$inboundCert2Base64 = $inboundCert2Data -replace "-----BEGIN CERTIFICATE-----", "" -replace "-----END CERTIFICATE-----", ""
#$certChain = @($inboundCert1Base64, $inboundCert2Base64) 

$certChain1 = @( $inboundCert1Base64) 
$certChain2 = @( $inboundCert2Base64) 
Write-Host (Get-date)"- inbound certificate chain1 count: " $certChain1.Count -ForegroundColor Green
Write-Host (Get-date)"- inbound certificate chain2 count: " $certChain2.Count -ForegroundColor Green

# Create Certificate Authentication Object
Write-Host (Get-date)"- creating gw1 certificate authentication object" -ForegroundColor Green
$gw1certAuth = New-AzVirtualNetworkGatewayCertificateAuthentication `
    -OutboundAuthCertificate $gw1OutboundCertUrl `
    -InboundAuthCertificateSubjectName $gw2OutboundcertSubjectName `
    -InboundAuthCertificateChain $certChain2

# Verify certificate authentication object properties
Write-Host "gw1 - OutboundcertURL..................: "$gw1certAuth.OutboundAuthCertificate
Write-Host "gw1 - Inbound certificate subjectName..: "$gw1certAuth.InboundAuthCertificateSubjectName
Write-Host "gw1 - InboundAuthCertificatechain count: "$gw1certAuth.InboundAuthCertificateChain.Count
Write-Host "gw1 - InboundAuthCertificatechain[0]...: "$gw1certAuth.InboundAuthCertificateChain[0]
Write-Host "gw1 - InboundAuthCertificatechain[1]...: "$gw1certAuth.InboundAuthCertificateChain[1]


# Create Certificate Authentication Object
Write-Host (Get-date)"- creating gw2 certificate authentication object" -ForegroundColor Green
$gw2certAuth = New-AzVirtualNetworkGatewayCertificateAuthentication `
    -OutboundAuthCertificate $gw2OutboundCertUrl `
    -InboundAuthCertificateSubjectName $gw1OutboundcertSubjectName `
    -InboundAuthCertificateChain $certChain1

# Verify certificate authentication object properties
Write-Host "gw2 - OutboundcertURL..................: "$gw2certAuth.OutboundAuthCertificate
Write-Host "gw2 - Inbound certificate subjectName..: "$gw2certAuth.InboundAuthCertificateSubjectName
Write-Host "gw2 - InboundAuthCertificatechain count: "$gw2certAuth.InboundAuthCertificateChain.Count
Write-Host "gw2 - InboundAuthCertificatechain[0]...: "$gw2certAuth.InboundAuthCertificateChain[0]
Write-Host "gw2 - InboundAuthCertificatechain[1]...: "$gw2certAuth.InboundAuthCertificateChain[1]

try {
    Write-Host (Get-Date)"- collecting existing vpn connection: "$gw1Connection1Name -ForegroundColor Green
    $vpnConnnection1 = Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $rgname -name $gw1Connection1Name -ErrorAction Stop
    Write-Host (Get-Date)"- Connection $gw1Connection1Name exists, skipping creation"
}
catch {
    Write-Host (Get-Date)"- creating vpn connection: "$gw1Connection1Name -ForegroundColor Cyan
    $gw1 = Get-AzVirtualNetworkGateway -name $gw1Name -ResourceGroupName $rgName
    # Create VirtualNetworkGatewayConnection with Certificate Authentication
    $vpnConnnection1 = New-AzVirtualNetworkGatewayConnection -name $gw1Connection1Name `
        -ResourceGroupName $rgname `
        -location $location `
        -VirtualNetworkGateway1 $gw1 `
        -LocalNetworkGateway2 $localNetgw2 `
        -ConnectionType IPsec -RoutingWeight 3 `
        -AuthenticationType "Certificate" `
        -CertificateAuthentication $gw1certAuth
}

try {
    Write-Host (Get-Date)"- collecting existing vpn connection: "$gw2Connection1Name -ForegroundColor Green
    $vpnConnnection2 = Get-AzVirtualNetworkGatewayConnection  -name $gw2Connection1Name -ResourceGroupName $rgname-ErrorAction Stop
    Write-Host (Get-Date)"- Connection $gw2Connection1Name exists, skipping creation"
}
catch {
    Write-Host (Get-Date)"- creating vpn connection: "$gw2Connection1Name -ForegroundColor Cyan
    $gw2 = Get-AzVirtualNetworkGateway -name $gw2Name -ResourceGroupName $rgName
    # Create VirtualNetworkGatewayConnection with Certificate Authentication
    $vpnConnnection2 = New-AzVirtualNetworkGatewayConnection -name $gw2Connection1Name `
        -ResourceGroupName $rgname `
        -location $location `
        -VirtualNetworkGateway1 $gw2 `
        -LocalNetworkGateway2 $localNetgw1 `
        -ConnectionType IPsec -RoutingWeight 3 `
        -AuthenticationType "Certificate" `
        -CertificateAuthentication $gw2certAuth
}

# Verify connection was created successfully
Write-host (Get-Date)"- checking vpn connection: "$gw1Connection1Name -ForegroundColor Green
$vpnConnnection1 = Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $rgname -name $gw1Connection1Name
write-host "resource group............: "$vpnConnnection1.ResourceGroupName -ForegroundColor Green
write-host "gw1 - connection name.....: "$vpnConnnection1.Name  -ForegroundColor Green
write-host "gw1 - auth type...........: "$vpnConnnection1.AuthenticationType -ForegroundColor Green
write-host "gw1 - cert authetication..: "$vpnConnnection1.CertificateAuthentication -ForegroundColor Green
write-host "gw1 - outboundCertUrl.....: "$vpnConnnection1.CertificateAuthentication.OutboundAuthCertificate -ForegroundColor Green
write-host "gw1 - Inbound CertSubject.: "$vpnConnnection1.CertificateAuthentication.InboundAuthCertificateSubjectName -ForegroundColor Green
write-host '--------------------------------------------------------------------------'
$vpnConnnection2 = Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $rgname -name $gw2Connection1Name
Write-host (Get-Date)"- checking vpn connection: "$gw2Connection1Name -ForegroundColor Green
write-host "resource group............: "$vpnConnnection2.ResourceGroupName -ForegroundColor Green
write-host "gw1 - connection name.....: "$vpnConnnection2.Name -ForegroundColor Green
write-host "gw1 - auth type...........: "$vpnConnnection2.AuthenticationType -ForegroundColor Green
write-host "gw1 - cert authetication..: "$vpnConnnection2.CertificateAuthentication -ForegroundColor Green
write-host "gw1 - outboundCertUrl.....: "$vpnConnnection2.CertificateAuthentication.OutboundAuthCertificate -ForegroundColor Green
write-host "gw1 - Inbound CertSubject.: "$vpnConnnection2.CertificateAuthentication.InboundAuthCertificateSubjectName -ForegroundColor Green



# List connections and verify
$list = Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $rgname -Name "*"
write-host (Get-Date)"- Total number of vpn Connections: "$list.Count
