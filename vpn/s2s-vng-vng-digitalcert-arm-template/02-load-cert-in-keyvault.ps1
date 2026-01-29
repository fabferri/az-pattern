$inputParams = 'init.json'
$userToAccessToKeyvault = 'user@domain.com'

####################################################
$pathFiles = Split-Path -Parent $PSCommandPath
$inputParamsFile = "$pathFiles\$inputParams"

try {
  $arrayParams = (Get-Content -Raw $inputParamsFile | ConvertFrom-Json)
  $subscriptionName = $arrayParams.subscriptionName
  $rgName = $arrayParams.rgName
  $outboundCertificateFileNamePFX1 = $arrayParams.outboundCertificateFileNamePFX1
  $outboundCertificatePasswordPFX1 = $arrayParams.outboundCertificatePasswordPFX1
  $inboundCertificateFileNameCER1 = $arrayParams.inboundCertificateFileNameCER1
  $inboundCertificateSubjectName1 = $arrayParams.inboundCertificateSubjectName1

  $outboundCertificateFileNamePFX2 = $arrayParams.outboundCertificateFileNamePFX2
  $outboundCertificatePasswordPFX2 = $arrayParams.outboundCertificatePasswordPFX2
  $inboundCertificateFileNameCER2 = $arrayParams.inboundCertificateFileNameCER2
  $inboundCertificateSubjectName2 = $arrayParams.inboundCertificateSubjectName2
}
catch {
  Write-Host 'error in reading the parameters file: '$inputParamsFile -ForegroundColor Yellow
  Exit
}

# checking the values of variables from init.json
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }                               else { Write-Host '  subscription name..............: '$subscriptionName -ForegroundColor Yellow }
if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                                                   else { Write-Host '  resource group.................: '$rgName -ForegroundColor Yellow }
if (!$outboundCertificateFileNamePFX1) { Write-Host 'variable $outboundCertificateFileNamePFX1 is null' ; Exit } else { Write-Host '  outboundCertificateFileNamePFX1: '$outboundCertificateFileNamePFX1 -ForegroundColor Yellow }
if (!$outboundCertificatePasswordPFX1) { Write-Host 'variable $outboundCertificatePasswordPFX1 is null' ; Exit } else { Write-Host '  outboundCertificatePasswordPFX1: '$outboundCertificatePasswordPFX1 -ForegroundColor Yellow }
if (!$inboundCertificateFileNameCER1) { Write-Host 'variable $inboundCertificateFileNameCER1 is null' ; Exit }   else { Write-Host '  inboundCertificateFileNameCER1.: '$inboundCertificateFileNameCER1 -ForegroundColor Yellow }
if (!$inboundCertificateSubjectName1) { Write-Host 'variable $inboundCertificateSubjectName1 is null' ; Exit }   else { Write-Host '  inboundCertificateSubjectName1.: '$inboundCertificateSubjectName1 -ForegroundColor Yellow }

if (!$outboundCertificateFileNamePFX2) { Write-Host 'variable $outboundCertificateFileNamePFX2 is null' ; Exit } else { Write-Host '  outboundCertificateFileNamePFX2: '$outboundCertificateFileNamePFX2 -ForegroundColor Yellow }
if (!$outboundCertificatePasswordPFX2) { Write-Host 'variable $outboundCertificatePasswordPFX2 is null' ; Exit } else { Write-Host '  outboundCertificatePasswordPFX2: '$outboundCertificatePasswordPFX2 -ForegroundColor Yellow }
if (!$inboundCertificateFileNameCER2) { Write-Host 'variable $inboundCertificateFileNameCER2 is null' ; Exit }   else { Write-Host '  inboundCertificateFileNameCER2.: '$inboundCertificateFileNameCER2 -ForegroundColor Yellow }
if (!$inboundCertificateSubjectName2) { Write-Host 'variable $inboundCertificateSubjectName2 is null' ; Exit }   else { Write-Host '  inboundCertificateSubjectName2.: '$inboundCertificateSubjectName2 -ForegroundColor Yellow }

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id




# Check if the Key Vault exists
try {
  if ((Get-AzKeyVault -ResourceGroupName $rgName).count -ne 1) {
    Write-Host "Key Vault not found in resource group $rgName. Exiting..." -ForegroundColor Red
    Exit
  } 
  else {
    $kv = Get-AzKeyVault -ResourceGroupName $rgName
    $kvName = $kv.VaultName
    $kvLocation = $kv.Location
    Write-Host "Key Vault Name: $kvName, Location: $kvLocation" -ForegroundColor Cyan
    Write-host "Set priviledge to the user $userToAccessToKeyvault to access the Key Vault"
    # set priviledge to the user to access the Key Vault
    Set-AzKeyVaultAccessPolicy -VaultName $kvName -UserPrincipalName $userToAccessToKeyvault `
      -PermissionsToCertificates all, get, list, delete, create, import, update, managecontacts, getissuers, listissuers, setissuers, deleteissuers, manageissuers, recover, purge `
      -PermissionsToSecrets all, get, list, set, delete, backup, restore, recover, purge
  }

}
catch {
  Write-Host "Error retrieving Key Vault" -ForegroundColor Red
  Exit
}

try {
  $pfxFileFullPath1 = "$pathFiles\certs\$outboundCertificateFileNamePFX1"
  $certName = $inboundCertificateSubjectName1
  $pfxPassword1 = ConvertTo-SecureString -String $outboundCertificatePasswordPFX1 -AsPlainText -Force

}
catch {
  Write-Host 'error in reference the file: '$outboundCertificateFileNamePFX1 -ForegroundColor Yellow
  Exit
}

# Check if the Key Vault already has the certificate
try {
  #Get-AzKeyVaultCertificate -VaultName $kvName -Name $certName -ErrorAction Stop
  if ((Get-AzKeyVaultCertificate -VaultName $kvName -Name $certName).count -gt 0) {
    Write-Host "Certificate $certName already imported into Key Vault $kvName. skipping...." -ForegroundColor Green
  }
  else {
    Write-Host "Certificate $certName not found in Key Vault $kvName. Importing..." -ForegroundColor Yellow
     # Import the certificate
    Import-AzKeyVaultCertificate -VaultName $kvName -Name $inboundCertificateSubjectName1 -FilePath $pfxFileFullPath1 -Password $pfxPassword1
    Write-Host "Certificate $certName imported into Key Vault $kvName." -ForegroundColor Green
  }
}
catch {
  Write-Host "error in import the certificate: $certName in Key Vault $kvName. Exit" -ForegroundColor Red
  Exit
}

$kvCert = Get-AzKeyVaultCertificate -VaultName $kvName -Name $certName
Write-Host "Certificate Name......: "$kvCert.Name
Write-Host "Certificate Identifier: "($kvCert.Id).Replace(":443", "")
write-host "Certificate Subject...: "$kvCert.Certificate.Subject
write-host "Certificate issuer....: "$kvCert.Certificate.Issuer
##################

try {
  $pfxFileFullPath2 = "$pathFiles\certs\$outboundCertificateFileNamePFX2"
  $certName = $inboundCertificateSubjectName2
  $pfxPassword2 = ConvertTo-SecureString -String $outboundCertificatePasswordPFX2 -AsPlainText -Force

}
catch {
  Write-Host 'error in reference the file: '$outboundCertificateFileNamePFX2 -ForegroundColor Yellow
  Exit
}

# Check if the Key Vault already has the certificate
try {
  #Get-AzKeyVaultCertificate -VaultName $kvName -Name $certName -ErrorAction Stop
  if ((Get-AzKeyVaultCertificate -VaultName $kvName -Name $certName).count -gt 0) {
    Write-Host "Certificate $certName already imported into Key Vault $kvName. skipping...." -ForegroundColor Green
  }
  else {
    Write-Host "Certificate $certName not found in Key Vault $kvName. Importing..." -ForegroundColor Yellow
     # Import the certificate
    Import-AzKeyVaultCertificate -VaultName $kvName -Name $inboundCertificateSubjectName2 -FilePath $pfxFileFullPath2 -Password $pfxPassword2
    Write-Host "Certificate $certName imported into Key Vault $kvName." -ForegroundColor Green
  }
}
catch {
  Write-Host "error in import the certificate: $certName in Key Vault $kvName. Exit" -ForegroundColor Red
  Exit
}

$kvCert = Get-AzKeyVaultCertificate -VaultName $kvName -Name $certName
Write-Host "Certificate Name......: "$kvCert.Name
Write-Host "Certificate Identifier: "($kvCert.Id).Replace(":443", "")
write-host "Certificate Subject...: "$kvCert.Certificate.Subject
write-host "Certificate issuer....: "$kvCert.Certificate.Issuer


