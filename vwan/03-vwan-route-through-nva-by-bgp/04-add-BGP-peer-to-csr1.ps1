##### Script to generate the IPSec configuration of Cisco CSR
##### Before running 
##### 
#####

$pathFiles  = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"

$pathFiles = Split-Path -Parent $PSCommandPath
$templateFile = "$pathFiles\$armTemplateFile"

# reading the input parameter file $inputParams and convert the values in hashtable 
If (Test-Path -Path $pathFiles\$inputParams) 
{
     # convert the json into PSCustomObject
     $jsonObj = Get-Content -Raw $pathFiles\$inputParams | ConvertFrom-Json
     if ($null -eq $jsonObj) {
          Write-Host "file $inputParams is empty"
          Exit
     }
     # convert the PSCustomObject in hashtable
     if ($jsonObj -is [psobject]) {
          $hash = @{}
          foreach ($property in $jsonObj.PSObject.Properties) {
               $hash[$property.Name] = $property.Value
          }
     }
     foreach ($key in $hash.keys) {
          $message = '{0} = {1} ' -f $key, $hash[$key]
          Write-Output $message
          Try { New-Variable -Name $key -Value $hash[$key] -ErrorAction Stop }
          Catch { Set-Variable -Name $key -Value $hash[$key] }
     }
} 
else { Write-Warning "$inputParams file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit } else { Write-Host '   administrator username: '$adminUsername -ForegroundColor Green}
if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit } else { Write-Host '   administrator password: '$adminPassword -ForegroundColor Green}
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit } else { Write-Host '   subscription name..: '$subscriptionName -ForegroundColor Yellow}
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit } else { Write-Host '   resource group name: '$ResourceGroupName -ForegroundColor Yellow}
if (!$hub1location) { Write-Host 'variable $hub1location is null' ; Exit } else { Write-Host '   hub1 location......: '$hub1location -ForegroundColor Yellow}
if (!$hub2location) { Write-Host 'variable $hub2location is null' ; Exit } else { Write-Host '   hub2 location......: '$hub2location -ForegroundColor Yellow}
if (!$branch1location) { Write-Host 'variable $branch1location is null' ; Exit } else { Write-Host '   branch1 location...: '$branch1location -ForegroundColor Yellow}
if (!$branch2location) { Write-Host 'variable $branch2location is null' ; Exit } else { Write-Host '   branch2 location...: '$branch2location -ForegroundColor Yellow}
if (!$hub1Name) { Write-Host 'variable $hub1Name is null' ; Exit } else { Write-Host '   hub1 name..........: '$hub1Name -ForegroundColor Yellow}
if (!$hub2Name) { Write-Host 'variable $hub2Name is null' ; Exit } else { Write-Host '   hub2 name..........: '$hub2Name -ForegroundColor Yellow}
if (!$sharedKey) { Write-Host 'variable $sharedKey is null' ; Exit } else { Write-Host '   sharedKey..........: '$sharedKey -ForegroundColor Yellow}
if (!$mngIP) { Write-Host 'variable $mngIP is null' ; Exit } else { Write-Host '   mngIP..............: '$mngIP -ForegroundColor Yellow}
if (!$RGTagExpireDate) { Write-Host 'variable $RGTagExpireDate is null' ; Exit } else { Write-Host '   RGTagExpireDate....: '$RGTagExpireDate -ForegroundColor Yellow}
if (!$RGTagContact) { Write-Host 'variable $RGTagContact is null' ; Exit } else { Write-Host '   RGTagContact.......: '$RGTagContact -ForegroundColor Yellow}
if (!$RGTagNinja) { Write-Host 'variable $RGTagNinja is null' ; Exit } else { Write-Host '   RGTagNinja.........: '$RGTagNinja -ForegroundColor Yellow}
if (!$RGTagUsage) { Write-Host 'variable $RGTagUsage is null' ; Exit } else { Write-Host '   RGTagUsage.........: '$RGTagUsage -ForegroundColor Yellow}
$rgName=$ResourceGroupName


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id



######################### remote Cisco CSR
$hubRemoteASN="65515"                  # CSR-BGP ASN
try {
  $hubBGPPeer1=(Get-AzVirtualHub -ResourceGroupName $rgName -Name $hub1Name).VirtualRouterIps[0]
  $hubBGPPeer2=(Get-AzVirtualHub -ResourceGroupName $rgName -Name $hub1Name).VirtualRouterIps[1]
}
catch{
  write-host "hub1-BGP peering addresses not found:" -ForegroundColor Yellow 
  Exit
}
if (!$hubBGPPeer1) { Write-Host 'variable $hubBGPPeer1 is null' ; Exit } else { Write-Host '   hubBGPPeer1..........: '$hubBGPPeer1 -ForegroundColor Yellow}
if (!$hubBGPPeer2) { Write-Host 'variable $hubBGPPeer2 is null' ; Exit } else { Write-Host '   hubBGPPeer2..........: '$hubBGPPeer2 -ForegroundColor Yellow}
######################### local Cisco CSR
$localASN="65001"                       # CSR-BGP ASN
$priv_defGtwInternal="10.0.0.65"        # CSR-default gateway of the subnet attached to the INTERNAL NIC
####
$fileName="csr1-add-bgp-config.txt"     # filename of output txt file with CSR config

write-host ""
write-host "Remote hub1-BGP ASN...............: $hubRemoteASN" -ForegroundColor Cyan
write-host "Remote hub1-BGP peer address1.....: $hubBGPPeer1" -ForegroundColor Cyan
write-host "Remote hub1-BGP peer address2.....: $hubBGPPeer2" -ForegroundColor Cyan

write-host "local csr-BGP ASN............................: $localASN" -ForegroundColor Green
write-host "local csr-default gateway internal interface.: $priv_defGtwInternal" -ForegroundColor Green

write-host "local CSR-configuration file.................: $fileName" -ForegroundColor White
try {
 $choice=Read-Host "are you OK with the input parameters (y/Y)?"
 if ($choice.ToLower() -eq "y") {
   write-host "Create CSR config file"
   }
 } catch {
    write-host "wrong input parameters"
}


### assembly the configuration of Cisco CSR
$CSRConfig = @"
!
router bgp $localASN
 neighbor $hubBGPPeer1 remote-as $hubRemoteASN
 neighbor $hubBGPPeer1 ebgp-multihop 5
 neighbor $hubBGPPeer1 update-source GigabitEthernet2
 neighbor $hubBGPPeer2 remote-as $hubRemoteASN
 neighbor $hubBGPPeer2 ebgp-multihop 5
 neighbor $hubBGPPeer2 update-source GigabitEthernet2
 !
!
ip route $hubBGPPeer1 255.255.255.255 $priv_defGtwInternal
ip route $hubBGPPeer2 255.255.255.255 $priv_defGtwInternal

"@

#write the content of the CSR config in a file
$pathFiles = Split-Path -Parent $PSCommandPath
Set-Content -Path "$pathFiles\$fileName" -Value $CSRConfig 