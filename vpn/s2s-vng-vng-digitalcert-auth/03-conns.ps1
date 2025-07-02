## script to create vnets, VMs and VPN Gateways
################# Input parameters #################
$deploymentName = 'deploy-connections'
$armTemplateFile = '03-conns.json'
$inputParams = 'init.json'
####################################################
$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"
$inputParamsFile = "$pathFiles\$inputParams"

try {
     $arrayParams = (Get-Content -Raw $inputParamsFile | ConvertFrom-Json)
     $subscriptionName = $arrayParams.subscriptionName
     $rgName = $arrayParams.rgName
     $location1 = $arrayParams.location1
     $location2 = $arrayParams.location2
     $gateway1Name = $arrayParams.gateway1Name
     $gateway2Name = $arrayParams.gateway2Name
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
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }  else { Write-Host '  subscription name...: '$subscriptionName -ForegroundColor Yellow }
if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                      else { Write-Host '  resource group......: '$rgName -ForegroundColor Yellow }
if (!$location1) { Write-Host 'variable $location1 is null' ; Exit }                else { Write-Host '  location1...........: '$location1 -ForegroundColor Yellow }
if (!$location2) { Write-Host 'variable $location2 is null' ; Exit }                else { Write-Host '  location2...........: '$location2 -ForegroundColor Yellow }
if (!$gateway1Name) { Write-Host 'variable $gateway1Name is null' ; Exit }          else { Write-Host '  gateway1Name........: '$gateway1Name -ForegroundColor Cyan } 
if (!$gateway2Name) { Write-Host 'variable $gateway2Name is null' ; Exit }          else { Write-Host '  gateway2Name........: '$gateway2Name -ForegroundColor Cyan } 
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

#reading the inbound certificate from file (root certificate)
$FilePath = "$pathFiles\certs\$inboundCertificateFileNameCER1"
# remove the first and last lines (-----BEGIN CERTIFICATE----- and -----END CERTIFICATE-----) and then join the rest to a single string.
$inboundAuthCertificateChain1=(Get-Content -Path $FilePath | Select -Skip 1 | Select -SkipLast 1).Trim() -join ""
Write-Host $inboundAuthCertificateChain1 -ForegroundColor Green


$certName1 = $inboundCertificateSubjectName1
$kv = Get-AzKeyVault -ResourceGroupName $rgName
$kvName = $kv.VaultName
$kvCert1 = Get-AzKeyVaultCertificate -VaultName $kvName -Name $certName1
if (!$kvCert1) {
     Write-Host "Certificate $certName1 not found in Key Vault $kvName. Exiting..." -ForegroundColor Yellow
     Exit
}
Write-Host "Certificate Name......: "$kvCert1.Name
Write-Host "Certificate Identifier: "($kvCert1.Id).Replace(":443", "")



#reading the inbound certificate from file (root certificate)
$FilePath = "$pathFiles\certs\$inboundCertificateFileNameCER2"
# remove the first and last lines (-----BEGIN CERTIFICATE----- and -----END CERTIFICATE-----) and then join the rest to a single string.
$inboundAuthCertificateChain2=(Get-Content -Path $FilePath | Select -Skip 1 | Select -SkipLast 1).Trim() -join ""
Write-Host $inboundAuthCertificateChain2 -ForegroundColor Green


$certName2 = $inboundCertificateSubjectName2
$kv = Get-AzKeyVault -ResourceGroupName $rgName
$kvName = $kv.VaultName
$kvCert2 = Get-AzKeyVaultCertificate -VaultName $kvName -Name $certName2
if (!$kvCert2) {
     Write-Host "Certificate $certName2 not found in Key Vault $kvName. Exiting..." -ForegroundColor Yellow
     Exit
}
Write-Host "Certificate Name......: "$kvCert2.Name
Write-Host "Certificate Identifier: "($kvCert2.Id).Replace(":443", "")


$location = $location1
$parameters = @{
     "location1"                         = $location1;
     "location2"                         = $location2;
     "gateway1Name"                      = $gateway1Name;
     "gateway2Name"                      = $gateway2Name;
     "outboundAuthCertificate1"           = ($kvCert1.Id).Replace(":443", "");
     "inboundAuthCertificateSubjectName1" = $kvCert1.Name;
     "inboundAuthCertificateChain1"       = $inboundAuthCertificateChain1
     "outboundAuthCertificate2"           = ($kvCert2.Id).Replace(":443", "");
     "inboundAuthCertificateSubjectName2" = $kvCert2.Name;
     "inboundAuthCertificateChain2"       = $inboundAuthCertificateChain2
}

# Create Resource Group
Write-Host (Get-Date)' - ' -NoNewline
Write-Host 'Creating Resource Group' -ForegroundColor Cyan
Try {
     Get-AzResourceGroup -Name $rgName -ErrorAction Stop
     Write-Host 'Resource exists, skipping'
}
Catch { New-AzResourceGroup -Name $rgName -Location $location }

$StartTime = Get-Date
Write-Host "$StartTime - ARM template:"$templateFile -ForegroundColor Yellow
New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $rgName -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose 

$EndTime = Get-Date
$TimeDiff = New-TimeSpan $StartTime $EndTime
$Mins = $TimeDiff.Minutes
$Secs = $TimeDiff.Seconds
$runTime = '{0:00}:{1:00} (M:S)' -f $Mins, $Secs
write-host "runtime...: "$runTime.ToString() -ForegroundColor Yellow
write-host "start time: "$startTime -ForegroundColor Yellow
write-host "end time..: "$EndTime -ForegroundColor Yellow