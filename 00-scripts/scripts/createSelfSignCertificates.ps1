# Script to create the Root certificate and client certicates signed with root certificate.
# input paramenters:
#  $pwdCertificates: specifies the password for exported certificates
#
#  $numClientCert: specifies the number of client certificates 
#      To create more than 1 client certificate specificy the parameter -numClientCert
#      i.e. to create 4 client certificate run the following command:
#      .\createSelfSignCertificates.ps1 -numClientCert 4
#
#  $cpFlag: it is boolean flag: 
#           $true copy the digital certificate in storage account
#           $false does no copy the digital certificate in the storage account
# 
#
param(
    [Parameter(Mandatory = $false, HelpMessage = 'password certificate', ValueFromPipeline = $true)]
    [string]$pwdCertificates = '1234',
    [Parameter(Mandatory = $false, HelpMessage = 'number of client certificate', ValueFromPipeline = $true)]
    [int]$numClientCert,
    [Parameter(Mandatory = $false, HelpMessage = 'flag=$true to copy the value to storage account', ValueFromPipeline = $true)]
    [bool]$cpFlag = $true
)

if ($numClientCert -le 0) { $numClientCert = 1 }
write-host 'number client certificates: '$numClientCert

$storageContainerName='cert1'

# the variable specifies the local folder to store digital certificates
$certPath = 'C:\cert\'

$pathFolder = [string](Split-Path -Path $certPath -Parent)
$folderName = [string](Split-Path -Path $certPath -Leaf)
Write-Host 'folder to store digital certificates: '$pathFolder$folderName


# create a directory 'C:\cert'
New-Item -Path $pathFolder -Name $folderName -ItemType Directory -Force
Write-Host '' 
#
# Create self-signed Root Certificate
# The following example creates a self-signed root certificate named 'P2SRootCert' that is automatically installed in 'Certificates-Current User\Personal\Certificates'. 
# You can view the certificate by opening certmgr.msc, or Manage User Certificates.
$params = @{
    Type              = 'Custom'
    Subject           = 'CN=P2SRootCert'
    KeySpec           = 'Signature'
    KeyExportPolicy   = 'Exportable'
    KeyUsage          = 'CertSign'
    KeyUsageProperty  = 'Sign'
    KeyLength         = 2048
    HashAlgorithm     = 'sha256'
    NotAfter          = (Get-Date).AddMonths(24)
    CertStoreLocation = 'Cert:\CurrentUser\My'
}
Write-Host "$(Get-Date) - checking P2S Root certificate in Cert:\CurrentUser\My"
$certRoot = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq 'CN=P2SRootCert' }
If ($null -eq $certRoot) {
    $certRoot = New-SelfSignedCertificate @params
    Write-Host "$(Get-Date) - P2S Root certificate created"
}
Else { 
    Write-Host "$(Get-Date) - P2S Root certificate already exists, skipping" 
}


# fetch self-signed root certificate named 'P2SRootCert' from 'Certificates-Current User\Personal\Certificates'
$mypwd = ConvertTo-SecureString -String $pwdCertificates -Force -AsPlainText
$certRootThumbprint = (Get-ChildItem -Path "Cert:\CurrentUser\My" | where-Object  -Property Subject -eq  "CN=P2SRootCert" | Select-Object Thumbprint).Thumbprint
$certRoot = Get-ChildItem -Path "Cert:\CurrentUser\My\$certRootThumbprint"

# Export of the root certificate in format .pfx
# The private key is included in the export
Export-PfxCertificate -Cert $certRoot -FilePath $certPath'certRoot-with-privKey.pfx' -Password $mypwd 

for ($i = 1; $i -le $numClientCert; $i++) {
    $certSubject = 'CN=P2SChildCert' + ([string]$i)
    $certDnsName = 'P2SChildCert' + ([string]$i)
    # Generate a client certificate
    # Each client computer that connects to a VNet using Point-to-Site must have a client certificate installed. 
    # You generate a client certificate from the self-signed root certificate, and then export and install the client certificate. 
    # If the client certificate isn't installed, authentication fails.
    $params = @{
        Type              = 'Custom'
        Subject           = $certSubject
        DnsName           = $certDnsName
        KeySpec           = 'Signature'
        KeyExportPolicy   = 'Exportable'
        KeyLength         = 2048
        HashAlgorithm     = 'sha256'
        NotAfter          = (Get-Date).AddMonths(18)
        CertStoreLocation = 'Cert:\CurrentUser\My'
        Signer            = $certRoot
        TextExtension     = @('2.5.29.37={text}1.3.6.1.5.5.7.3.2')
    }
    # Create client cert
    $certClient = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq $certSubject }
    If ($null -eq $certClient) {
        # getting client certificate
        New-SelfSignedCertificate @params
        Write-Host "$(Get-Date) - P2S Client cert: $certSubject created"
    }
    Else { Write-Host "$(Get-Date) - P2S Client cert: $certSubject already exists, skipping" }
}

# Save root certificate to file
$FileCert = $certPath + 'P2SRoot.cert'
$certRoot = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq 'CN=P2SRootCert' }
If ($null -eq $certRoot) {
    Write-Host "$(Get-Date) - Root Certificate 'CN=P2SRootCert' not found "
    write-host "stop processing!"
    Exit
}
Else { 
    # Export of the root certificate in format .cer 
    # The private key is not included in the export
    Export-Certificate -Cert $certRoot -FilePath $FileCert -Force | Out-Null
    Write-Host "$(Get-Date) - Create the file: $FileCert"
}

# Convert to Base64 cer file
$FileCer = $certPath + 'P2SRoot.cer'
Write-Host "$(Get-Date) - Creating root certificate in $FileCer"
If (-not (Test-Path -Path $FileCer)) {
    certutil -encode $FileCert $FileCer | Out-Null
    Write-Host "$(Get-Date) - Created root cer file"
}
Else { Write-Host "$(Get-Date) - Root cer file exists, skipping" }

for ($i = 1; $i -le $numClientCert; $i++) {

    $certSubject = 'CN=P2SChildCert' + ([string]$i)
    $certFilePath = $certPath + 'certClient' + ([string]$i) + '.pfx'

    ####### export user certificate in Personal Information Exchange - PKCS #12 (.PFX)
    $mypwd = ConvertTo-SecureString -String $pwdCertificates -Force -AsPlainText
    $certClient = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq $certSubject }
    Export-PfxCertificate -cert $certClient -FilePath $certFilePath -Password $mypwd

    ### to see the thumbprint of exported user certificate
    # (Get-PfxData -FilePath "$certPath\certClient.pfx" -Password $mypwd ).EndEntityCertificates[0]
}

$pwdFile = $certPath + 'certpwd.txt'
Write-Host ''
Write-Host 'write password file: '$pwdFile
Out-File -FilePath $pwdFile -Force -InputObject $pwdCertificates


if ($cpFlag -eq $false) { Exit}

### install NuGet, Az.Account module , Az.Storage module 
Write-Host "Installing Azurepowershell Modules"
try {
    Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Stop | Out-Null
    Write-Host "  NuGet already registered, skipping"
}
catch {
    Install-PackageProvider -Name NuGet -Scope AllUsers  -Force | Out-Null
    Write-Host "  NuGet registered"
}

if ($null -ne (Get-Module Az.Accounts -ListAvailable)) {
    Write-Host "  Az.Account module already installed, skipping"
}
else {
    Install-Module Az.Accounts -Scope AllUsers -Force | Out-Null
    Write-Host "  Az.Account module installed"
}

if ($null -ne (Get-Module Az.Storage -ListAvailable)) {
    Write-Host "  Az.Storage module already installed, skipping"
}
else {
    Install-Module Az.Storage -Scope AllUsers -Force | Out-Null
    Write-Host "  Az.Storage module installed"
}

# You just connected to Azure using a managed identity.
Connect-AzAccount -Identity

# get storage account name and resource group name
$storageAccountName=(Get-AzStorageAccount).StorageAccountName
$resourceGroupName=(Get-AzStorageAccount).ResourceGroupName
$context=(Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName).Context

$localFolder=$pathFolder+ $folderName
foreach ($fileName in (Get-ChildItem -File -Recurse -Path $localFolder).Name)
{
  $blob1 = @{
    File             = "$certPath$fileName"
    Container        = $storageContainerName
    Blob             = $fileName
    Context          = $Context
    StandardBlobTier = 'Hot'
  }
  Set-AzStorageBlobContent @blob1 -Force
}
