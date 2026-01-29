# script to create the Root Certificates and leaf Certificates signed with root certificates.
# The script can run on Windows 11 or Windows Server
#
# input paramenters:
#   $pwdCertificates: specifies the password to export the digital certificates
# 
#
param(
    [Parameter(Mandatory = $false, HelpMessage = 'password certificate', ValueFromPipeline = $true)]
    [string]$pwdCertificates = '12345'

)

$certRootSubject1 = 'CN=VPNRootCA1'
$certRootSubject2 = 'CN=VPNRootCA2'
$certLeafSubject1 = 'CN=s2s-cert1'
$certLeafSubject2 = 'CN=s2s-cert2'

$certRootSubject = @($certRootSubject1, $certRootSubject2)
$certLeafSubject = @($certLeafSubject1, $certLeafSubject2)
$pwdLeaf = @($pwdCertificates, $pwdCertificates) 

$certRootArray = @()

# The variable specifies the local folder to store the digital certificates
$certPath = (Split-Path -Parent $PSCommandPath) + '\certs\'


$pathFolder = [string](Split-Path -Path $certPath -Parent)
$folderName = [string](Split-Path -Path $certPath -Leaf)
Write-Host "folder to store digital certificates: $pathFolder\$folderName"


# Create a local folder: .\certs'
New-Item -Path $pathFolder -Name $folderName -ItemType Directory -Force
Write-Host '' 


foreach ($rootSubj in $certRootSubject) {
    #
    # Create self-signed Root Certificate
    # It creates a self-signed root certificate that is automatically installed in 'Certificates-Current User\Personal\Certificates'.
    # You can view the certificate by opening certmgr.msc, or Manage User Certificates.
    $params = @{
        Type              = 'Custom'
        Subject           = $rootSubj
        KeySpec           = 'Signature'
        KeyExportPolicy   = 'Exportable'
        KeyUsage          = 'CertSign'
        KeyUsageProperty  = 'Sign'
        KeyLength         = 2048
        HashAlgorithm     = 'sha256'
        NotAfter          = (Get-Date).AddMonths(120)
        CertStoreLocation = 'Cert:\CurrentUser\My'
        TextExtension     = @('2.5.29.19={critical}{text}ca=1&pathlength=4')
    }


    # Check if the Root Certificates already exists in the store:  Cert:\CurrentUser\My 
    Write-Host "$(Get-Date) - checking  Root certificate $rootSubj in Cert:\CurrentUser\My"
    $certRoot = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq $rootSubj }
    If ($null -eq $certRoot) {
        # Create a new Root Certificate if it doesn't exist.
        $certRoot = New-SelfSignedCertificate @params
        Write-Host "$(Get-Date) - Root certificate $rootSubj created"
    }
    Else { 
        # Root Certificate already exists in the store, skipping operation
        Write-Host "$(Get-Date) - P2S Root certificate $rootSubj already exists, skipping" 
    }


    $certRootFileName = $rootSubj.Replace('CN=', '') 
    Write-Host "$(Get-Date) - Root certificate file name: $certRootFileName" -ForegroundColor Yellow
    # Save root certificate to file
    $FileRootCert = $certPath + $certRootFileName + '.cert'
    $certRoot = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq $rootSubj }
    If ($null -eq $certRoot) {
        Write-Host "$(Get-Date) - Root Certificate $rootSubj not found "
        write-host "stop processing!"
        Exit
    }
    Else { 
        # Export of the root certificate in format .cer 
        # The private key is not included in the export. Password is not required for the export.
        Export-Certificate -Cert $certRoot -FilePath $FileRootCert -Force | Out-Null
        Write-Host "$(Get-Date) - Create the file: $FileRootCert" -ForegroundColor Green
    }

    # Convert to Base64 cer file 
    $FileRootCer = $certPath + $certRootFileName + '.cer'
    Write-Host "$(Get-Date) - Creating root certificate in $FileRootCer" -ForegroundColor Green
    If (-not (Test-Path -Path $FileRootCer)) {
        certutil -encode $FileRootCert $FileRootCer | Out-Null
        Write-Host "$(Get-Date) - Created root $FileRootCer file"
    }
    Else { Write-Host "$(Get-Date) - Root $FileRootCer file exists, skipping" }

}

$index = 0
foreach ($leafSubj in $certLeafSubject) {
    write-host "grab root certificate"$certRootSubject[$index]

    $certRoot = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq $certRootSubject[$index] }
    If ($null -eq $certRoot) {
        Write-Host "$(Get-Date) - Root Certificate $certRootSubject[$index] not found "
        write-host "stop processing!"
        Exit
    }

    Write-Host "$(Get-Date) - start creation leaf cert: $certLeafSubject1" -ForegroundColor Yellow
    # Generate a leaf certificate
    # You generate a leaf certificate from the self-signed root certificate, and then export and install the client certificate. 
    # If the client certificate isn't installed, authentication fails.
    $params = @{
        Type              = 'Custom'
        Subject           = $leafSubj
        KeySpec           = 'Signature'
        KeyExportPolicy   = 'Exportable'
        KeyLength         = 2048
        HashAlgorithm     = 'sha256'
        NotAfter          = (Get-Date).AddMonths(120)
        CertStoreLocation = 'Cert:\CurrentUser\My'
        Signer            = $certRoot
        TextExtension     = @(
            '2.5.29.37={text}1.3.6.1.5.5.7.3.2,1.3.6.1.5.5.7.3.1')
    }
    # Create client cert
    $certClient = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq $leafSubj }
    If ($null -eq $certClient) {
        # getting client certificate
        New-SelfSignedCertificate @params
        Write-Host "$(Get-Date) - Leaf cert: $leafSubj created" -ForegroundColor Yellow
    }
    Else { Write-Host "$(Get-Date) - Leaf cert: $leafSubj already exists, skipping....." }



    $certLeafFileName = $leafSubj.Replace('CN=', '') 
    $certLeafFilePath = $certPath + $certLeafFileName + '.pfx'

    ### export user certificate in Personal Information Exchange - PKCS #12 (.PFX)
    $mypwd = ConvertTo-SecureString -String $pwdLeaf[$index] -Force -AsPlainText
    $certLeaf = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq $leafSubj }
    Export-PfxCertificate -cert $certLeaf -FilePath $certLeafFilePath -Password $mypwd

    $pwdFile = $certPath + 'cert-pwd.txt'
    Write-Host ''
    $line = "certificate: $certLeafFileName , password:  $pwdLeaf[$index]"

    if (!(Test-Path $pwdFile)) {
        Write-Host "Created a file to store password for certificates"
        Out-File -FilePath $pwdFile -Force 
    } 
    Add-Content -Path $pwdFile -Value $line

    $index++
}

