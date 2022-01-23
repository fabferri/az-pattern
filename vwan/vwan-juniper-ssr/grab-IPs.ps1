#  Grab the private and public IP addresses of all interfaces of session smart routers r1, r2, r3
#
####################################################
$inputParams = 'init.json'
$r1MngName = 'r1-mgmt'
$r1PubName = 'r1-public'
$r1PrivName = 'r1-private'

$r2MngName = 'r2-mgmt'
$r2PubName = 'r2-public'
$r2PrivName = 'r2-private'

$r3MngName = 'r3-mgmt'
$r3PubName = 'r3-public'
$r3PrivName = 'r3-private'
$fileName = "List-IPs.txt"            # filename of output txt file 
####################################################
$pathFiles      = Split-Path -Parent $PSCommandPath


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
#          Write-Output $message
          Try { New-Variable -Name $key -Value $hash[$key] -ErrorAction Stop }
          Catch { Set-Variable -Name $key -Value $hash[$key] }
     }
} 
else { Write-Warning "$inputParams file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit } else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$resourceGroupName) { Write-Host 'variable $resourceGroupName is null' ; Exit } else { Write-Host '   resource group name...: '$resourceGroupName -ForegroundColor Yellow }
$rgName = $resourceGroupName


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$r1_managementNIC_PrivIP = (Get-AzNetworkInterface -Name $r1MngName -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress
$r1_publicNIC_PrivIP = (Get-AzNetworkInterface -Name $r1PubName -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress
$r1_privateNIC_PrivIP = (Get-AzNetworkInterface -Name $r1PrivName -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress
$r1_managementNIC_PublicIP = (Get-AzPublicIpAddress -Name $r1MngName -ResourceGroupName $rgName).IpAddress
$r1_publicNIC_PublicIP = (Get-AzPublicIpAddress -Name $r1PubName -ResourceGroupName $rgName).IpAddress
write-host "*********** r1:"
write-host "     NIC-management - Private IP:"$r1_managementNIC_PrivIP -ForegroundColor Yellow
write-host "     NIC-public     - Private IP:"$r1_publicNIC_PrivIP  -ForegroundColor Yellow
write-host "     NIC-private    - Private IP:"$r1_privateNIC_PrivIP  -ForegroundColor Yellow
write-host "     NIC-management - Public IP :"$r1_managementNIC_PublicIP  -ForegroundColor Green
write-host "     NIC-public     - Public IP :"$r1_publicNIC_PublicIP  -ForegroundColor Green
write-host "--------------------------------"
write-host ""

$r2_managementNIC_PrivIP = (Get-AzNetworkInterface -Name $r2MngName -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress
$r2_publicNIC_PrivIP = (Get-AzNetworkInterface -Name $r2PubName -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress
$r2_privateNIC_PrivIP = (Get-AzNetworkInterface -Name $r2PrivName -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress
$r2_managementNIC_PublicIP = (Get-AzPublicIpAddress -Name $r2MngName -ResourceGroupName $rgName).IpAddress
$r2_publicNIC_PublicIP = (Get-AzPublicIpAddress -Name $r2PubName -ResourceGroupName $rgName).IpAddress
write-host "*********** r2:"
write-host "     NIC-management - Private IP:"$r2_managementNIC_PrivIP -ForegroundColor Yellow
write-host "     NIC-public     - Private IP:"$r2_publicNIC_PrivIP  -ForegroundColor Yellow
write-host "     NIC-private    - Private IP:"$r2_privateNIC_PrivIP  -ForegroundColor Yellow
write-host "     NIC-management - Public IP :"$r2_managementNIC_PublicIP  -ForegroundColor Green
write-host "     NIC-public     - Public IP :"$r2_publicNIC_PublicIP  -ForegroundColor Green
write-host "--------------------------------"
write-host ""

$r3_managementNIC_PrivIP = (Get-AzNetworkInterface -Name $r3MngName -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress
$r3_publicNIC_PrivIP = (Get-AzNetworkInterface -Name $r3PubName -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress
$r3_privateNIC_PrivIP = (Get-AzNetworkInterface -Name $r3PrivName -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress
$r3_managementNIC_PublicIP = (Get-AzPublicIpAddress -Name $r3MngName -ResourceGroupName $rgName).IpAddress
$r3_publicNIC_PublicIP = (Get-AzPublicIpAddress -Name $r3PubName -ResourceGroupName $rgName).IpAddress
write-host "*********** r3:"
write-host "     NIC-management - Private IP:"$r3_managementNIC_PrivIP -ForegroundColor Yellow
write-host "     NIC-public     - Private IP:"$r3_publicNIC_PrivIP  -ForegroundColor Yellow
write-host "     NIC-private    - Private IP:"$r3_privateNIC_PrivIP  -ForegroundColor Yellow
write-host "     NIC-management - Public IP :"$r3_managementNIC_PublicIP  -ForegroundColor Green
write-host "     NIC-public     - Public IP :"$r3_publicNIC_PublicIP  -ForegroundColor Green
write-host "--------------------------------"
write-host ""

$logContent = @"

*********** r1:"
     NIC-management - Private IP:"$r1_managementNIC_PrivIP 
     NIC-public     - Private IP:"$r1_publicNIC_PrivIP 
     NIC-private    - Private IP:"$r1_privateNIC_PrivIP  
     NIC-management - Public IP :"$r1_managementNIC_PublicIP  
     NIC-public     - Public IP :"$r1_publicNIC_PublicIP 
------------------------------------------------
*********** r2:"
     NIC-management - Private IP:"$r2_managementNIC_PrivIP 
     NIC-public     - Private IP:"$r2_publicNIC_PrivIP  
     NIC-private    - Private IP:"$r2_privateNIC_PrivIP  
     NIC-management - Public IP :"$r2_managementNIC_PublicIP  
     NIC-public     - Public IP :"$r2_publicNIC_PublicIP  
     ------------------------------------------------
*********** r3:"
     NIC-management - Private IP:"$r3_managementNIC_PrivIP
     NIC-public     - Private IP:"$r3_publicNIC_PrivIP
     NIC-private    - Private IP:"$r3_privateNIC_PrivIP
     NIC-management - Public IP :"$r3_managementNIC_PublicIP
     NIC-public     - Public IP :"$r3_publicNIC_PublicIP
     ------------------------------------------------
"@

#write the content into a file
$pathFiles = Split-Path -Parent $PSCommandPath
Set-Content -Path "$pathFiles\$fileName" -Value $logContent
