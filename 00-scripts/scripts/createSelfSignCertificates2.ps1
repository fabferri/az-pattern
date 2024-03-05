New-Item -Path 'C:\' -Name 'cert1' -ItemType Directory -Force
#
# Create self-signed Root Certificate
# The following example creates a self-signed root certificate named 'P2SRootCert' that is automatically installed in 'Certificates-Current User\Personal\Certificates'. 
# You can view the certificate by opening certmgr.msc, or Manage User Certificates.
$params = @{
    Type = 'Custom'
    Subject = 'CN=P2SRootCert'
    KeySpec = 'Signature'
    KeyExportPolicy = 'Exportable'
    KeyUsage = 'CertSign'
    KeyUsageProperty = 'Sign'
    KeyLength = 2048
    HashAlgorithm = 'sha256'
    NotAfter = (Get-Date).AddMonths(24)
    CertStoreLocation = 'Cert:\CurrentUser\My'
}
Write-Host "$(Get-Date) - Creating P2S root cert"
$certRoot = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq 'CN=P2SRootCert' }
If ($null -eq $certRoot) {
   $certRoot = New-SelfSignedCertificate @params
   Write-Host "$(Get-Date) - P2S root cert created"
}
Else { 
    Write-Host "$(Get-Date) - P2S root cert exists, skipping" 
}


# fetch self-signed root certificate named 'P2SRootCert' from 'Certificates-Current User\Personal\Certificates'
$mypwd = ConvertTo-SecureString -String '1234' -Force -AsPlainText
$certRootThumbprint= (Get-ChildItem -Path "Cert:\CurrentUser\My" | where-Object  -Property Subject -eq  "CN=P2SRootCert" | Select-Object Thumbprint).Thumbprint
$certRoot=Get-ChildItem -Path "Cert:\CurrentUser\My\$certRootThumbprint"
Export-PfxCertificate -Cert $certRoot -FilePath C:\cert1\certRoot-with-privKey.pfx -Password $mypwd 

# Generate a client certificate
# Each client computer that connects to a VNet using Point-to-Site must have a client certificate installed. 
# You generate a client certificate from the self-signed root certificate, and then export and install the client certificate. 
# If the client certificate isn't installed, authentication fails.
$params = @{
       Type = 'Custom'
       Subject = 'CN=P2SChildCert'
       DnsName = 'P2SChildCert'
       KeySpec = 'Signature'
       KeyExportPolicy = 'Exportable'
       KeyLength = 2048
       HashAlgorithm = 'sha256'
       NotAfter = (Get-Date).AddMonths(18)
       CertStoreLocation = 'Cert:\CurrentUser\My'
       Signer = $certRoot
       TextExtension = @('2.5.29.37={text}1.3.6.1.5.5.7.3.2')
   }
# Create client cert
Write-Host "$(Get-Date) - Creating P2S Client cert"
$certClient = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq 'CN=P2SChildCert' }
If ($null -eq $certClient) {
    # getting client certificate
  New-SelfSignedCertificate @params
  Write-Host "$(Get-Date) - P2S Client cert created"
}
Else { Write-Host "$(Get-Date) - P2S Client cert exists, skipping" }



# Save root certificate to file
Write-Host "$(Get-Date) - Saving root certificate to .cert file"
$FileCert = "C:\cert1\P2SRoot.cert"
If (-not (Test-Path -Path $FileCert)) {
     # The private key is not included in the export
     Export-Certificate -Cert $certRoot -FilePath $FileCert | Out-Null
     Write-Host "$(Get-Date) - root certificate .cert file saved"
}
Else { Write-Host "$(Get-Date) - root certificate .cert file exists, skipping" }

# Convert to Base64 cer file
Write-Host "$(Get-Date) - Creating root certificate in .cer file"
$FileCer = "C:\cert1\P2SRoot2.cer"
If (-not (Test-Path -Path $FileCer)) {
     certutil -encode $FileCert $FileCer | Out-Null
     Write-Host "$(Get-Date) - Created root cer file"
}
Else { Write-Host "$(Get-Date) - Root cer file exists, skipping" }


####### export user certificate in Personal Information Exchange - PKCS #12 (.PFX)
$mypwd = ConvertTo-SecureString -String '1234' -Force -AsPlainText
$certClient = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq 'CN=P2SChildCert' }
Export-PfxCertificate -cert $certClient -FilePath C:\cert1\certClient.pfx -Password $mypwd

### to see the thumbprint of exported user certificate
# (Get-PfxData -FilePath C:\cert1\certClient.pfx -Password $mypwd ).EndEntityCertificates[0]

#Install-PackageProvider -Name NuGet -Confirm:$false -Force 
#Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser 
#Install-Module -Name Az -Repository PSGallery -Scope AllUsers -Force 

$ContainerName='cert1'
$localFolder = 'C:\cert1'

# You just connected to Azure using a managed identity.
Connect-AzAccount -Identity

# get storage acocunt name and resource group name
$storageAccountName=(Get-AzStorageAccount).StorageAccountName
$resourceGroupName=(Get-AzStorageAccount).ResourceGroupName
$Context=(Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName).Context

foreach ($fileName in (Get-ChildItem -File -Recurse -Path $localFolder).Name)
{
  $blob1 = @{
    File             = "$localFolder\$fileName"
    Container        = $ContainerName
    Blob             = $fileName
    Context          = $Context
    StandardBlobTier = 'Hot'
  }
  Set-AzStorageBlobContent @blob1 -Force
}