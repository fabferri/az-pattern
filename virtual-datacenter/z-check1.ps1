$inputParams = 'init.json'
####################################################

$pathFiles = Split-Path -Parent $PSCommandPath
$parametersFile = "$pathFiles\$inputParams"

try {
    $arrayParams = (Get-Content -Raw $parametersFile | ConvertFrom-Json)
    $subscriptionName = $arrayParams.subscriptionName
    $rgName = $arrayParams.rgName
    $location = $arrayParams.location
    $locationonprem = $arrayParams.locationonprem
    $locationhub = $arrayParams.locationhub
    $locationspoke1 = $arrayParams.locationspoke1
    $locationspoke2 = $arrayParams.locationspoke2
    $locationspoke3 = $arrayParams.locationspoke3

    $vnetHubName = $arrayParams.vnetHubName
    $vnetOnprem = $arrayParams.vnetOnprem
    $vnetspoke1 = $arrayParams.vnetspoke1
    $vnetspoke2 = $arrayParams.vnetspoke2
    $vnetspoke3 = $arrayParams.vnetspoke3
    $gateway1Name = $arrayParams.gateway1Name
    $gateway2Name = $arrayParams.gateway2Name
    $artifactsLocation = $arrayParams.artifactsLocation
    $adminUsername = $arrayParams.adminUsername
    $adminPassword = $arrayParams.adminPassword
    $user1Name = $arrayParams.user1Name
    $user1Password = $arrayParams.user1Password
    $user2Name = $arrayParams.user2Name
    $user2Password = $arrayParams.user2Password
  

    Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
    if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '  subscription name......: '$subscriptionName -ForegroundColor Yellow }
    if (!$rgName) { Write-Host 'variable $rgName is null' ; Exit }                       else { Write-Host '  resource group name....: '$rgName -ForegroundColor Yellow }
    if (!$location) { Write-Host 'variable $location is null' ; Exit }                   else { Write-Host '  location...............: '$location -ForegroundColor Yellow }
    if (!$locationonprem) { Write-Host 'variable $locationonprem is null' ; Exit }       else { Write-Host '  location on-premises...: '$locationonprem -ForegroundColor Yellow }
    if (!$locationhub) { Write-Host 'variable $locationhub is null' ; Exit }             else { Write-Host '  location locationhub...: '$locationhub -ForegroundColor Yellow }
    if (!$locationspoke1) { Write-Host 'variable $locationspoke1 is null' ; Exit }       else { Write-Host '  location locationspoke1: '$locationspoke1 -ForegroundColor Yellow }
    if (!$locationspoke2) { Write-Host 'variable $locationspoke2 is null' ; Exit }       else { Write-Host '  location locationspoke2: '$locationspoke2 -ForegroundColor Yellow }
    if (!$locationspoke3) { Write-Host 'variable $locationspoke3 is null' ; Exit }       else { Write-Host '  location locationspoke3: '$locationspoke3 -ForegroundColor Yellow }
    if (!$vnetHubName) { Write-Host 'variable $vnetHubName is null' ; Exit }             else { Write-Host '  vnetHubName............: '$vnetHubName -ForegroundColor Green }
    if (!$vnetOnprem) { Write-Host 'variable $vnetOnprem is null' ; Exit }               else { Write-Host '  vnetOnprem.............: '$vnetOnprem -ForegroundColor Green }
    if (!$vnetspoke1) { Write-Host 'variable $vnetspoke1 is null' ; Exit }               else { Write-Host '  vnetspoke1.............: '$vnetspoke1 -ForegroundColor Green } 
    if (!$vnetspoke2) { Write-Host 'variable $vnetspoke2 is null' ; Exit }               else { Write-Host '  vnetspoke2.............: '$vnetspoke2 -ForegroundColor Green }     
    if (!$vnetspoke3) { Write-Host 'variable $vnetspoke3 is null' ; Exit }               else { Write-Host '  vnetspoke3.............: '$vnetspoke3 -ForegroundColor Green }
    if (!$artifactsLocation) { Write-Host 'variable $artifactsLocation is null' ; Exit } else { Write-Host '  artifactsLocation......: '$artifactsLocation -ForegroundColor Green }  
    if (!$gateway1Name) { Write-Host 'variable $gateway1Name is null' ; Exit }           else { Write-Host '  gateway1Name...........: '$gateway1Name -ForegroundColor Green }
    if (!$gateway2Name) { Write-Host 'variable $gateway2Name is null' ; Exit }           else { Write-Host '  gateway2Name...........: '$gateway2Name -ForegroundColor Green }  
    if (!$adminUsername) { Write-Host 'variable $adminUsername is null' ; Exit }         else { Write-Host '  adminUsername..........: '$adminUsername -ForegroundColor Cyan }   
    if (!$adminPassword) { Write-Host 'variable $adminPassword is null' ; Exit }         else { Write-Host '  adminPassword..........: '$adminPassword -ForegroundColor Cyan }       
    if (!$user1Name) { Write-Host 'variable $user1Name is null' ; Exit }                 else { Write-Host '  user1Name..............: '$user1Name -ForegroundColor Cyan }   
    if (!$user1Password) { Write-Host 'variable $user1Password is null' ; Exit }         else { Write-Host '  user1Password..........: '$user1Password -ForegroundColor Cyan }
    if (!$user2Name) { Write-Host 'variable $user2Name is null' ; Exit }                 else { Write-Host '  user2Name..............: '$user2Name -ForegroundColor Cyan }   
    if (!$user2Password) { Write-Host 'variable $user2Password is null' ; Exit }         else { Write-Host '  user2Password..........: '$user2Password -ForegroundColor Cyan } 

}
catch {
    Write-Host 'error in reading the template file: '$parametersFile -ForegroundColor Yellow
    Exit
}



$vpnGwList = @('vpnGw1', 'vpnGw2')
foreach ($vpn in $vpnGwList) {
    try {
        write-host "$(get-date) - check status VPN Gateway...: $vpn"
        $status = (Get-AzVirtualNetworkGateway -Name $vpn -ResourceGroupName $rgName).ProvisioningState
        Write-Host "$(get-date) - status VPN Gateway.........: $status" -ForegroundColor Green
    }
    catch {
        write-host " error in fetch VPN Gateway $vpn"
        Exit
    }

    $config = (Get-AzVirtualNetworkGateway -Name $vpn -ResourceGroupName $rgName).ActiveActive
    Write-Host "$(get-date) - VPN GTW active-active config: $config" -ForegroundColor Green
}

###############################
$connectionList = @('gtw1-to-gtw2-pubIP1', 'gtw1-to-gtw2-pubIP2', 'gtw2-to-gtw1-pubIP1', 'gtw2-to-gtw1-pubIP2')
foreach ($conn in $connectionList) {
    write-host ''
    try {
        Write-Host "$(get-date) - check status VPN connection $conn "
        $status = (Get-AzVirtualNetworkGatewayConnection -Name $connectionList[0] -ResourceGroupName $rgName).TunnelConnectionStatus[0].ConnectionStatus
        Write-Host "$(get-date) - VPN connection $conn : "$status -ForegroundColor Green
        $tunnelName = (Get-AzVirtualNetworkGatewayConnection -Name $connectionList[0] -ResourceGroupName $rgName).TunnelConnectionStatus[0].Tunnel
        Write-Host "$(get-date) - tunnel name $conn....: "$tunnelName -ForegroundColor Green
    }
    catch {
        write-host " error in fetch VPN connection $conn"
        Exit
    }
    write-host ''
    try {
        Write-Host "$(get-date) - check status VPN connection $conn "
        $status = (Get-AzVirtualNetworkGatewayConnection -Name $connectionList[0] -ResourceGroupName $rgName).TunnelConnectionStatus[1].ConnectionStatus
        Write-Host "$(get-date) - VPN connection $conn : "$status -ForegroundColor Green
        $tunnelName = (Get-AzVirtualNetworkGatewayConnection -Name $connectionList[0] -ResourceGroupName $rgName).TunnelConnectionStatus[1].Tunnel
        Write-Host "$(get-date) - tunnel name $conn....: "$tunnelName -ForegroundColor Green
    }
    catch {
        write-host " error in fetch VPN connection $conn"
        Exit
    }
}
##################

# getting Application Gateway public IP
$appGtwfrontEndURI = ((Get-AzApplicationGateway -Name appGtw1 -ResourceGroupName $rgName).FrontendIPConfigurations.publicIPAddress.Id).ToString()
$appGtwPubIPName = ($appGtwfrontEndURI -Split "/")[-1]
write-host "$(get-date) - Application Gateway public IP name: "$appGtwPubIPName

$appGTWpubIP = (Get-AzPublicIpAddress -Name  $appGtwPubIPName -ResourceGroupName $rgName).IpAddress
write-host "$(get-date) - Application Gateway public IP ....: "$appGtwPubIP

# connect to the public web site in spoke1
# request web page by safari client
# invoke-webRequest -Uri "http://$appGtwPubIP" -userAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Safari)
$site = Invoke-WebRequest -Method GET -Uri "http://$appGtwPubIP" -userAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)
Write-Host "web site - Status Code: "$site.StatusCode -ForegroundColor Magenta
# $site.Headers
Write-host "web content...........: "$site.Content -ForegroundColor Cyan

# Get status load balancer
$lbName = 'lb'
try {
    $status = (Get-AzLoadBalancer -ResourceGroupName $rgName -Name $lbName).ProvisioningState
    write-host "$(get-date) - status Load balancer $lbName :"$status -ForegroundColor Green
}
catch {
    write-host "$(get-date) - error in fetch lead balancer $lbName" -ForegroundColor Red
    Exit
}

### Front end private IP load balancer
try {

    $lbFrontEndIP = (Get-AzLoadBalancer -ResourceGroupName $rgName -Name lb).FrontendIpConfigurations.PrivateIpAddress
    write-host "$(get-date) - Load balancer FrontEnd IP: "$lbFrontEndIP -ForegroundColor Green
    if ($lbFrontEndIP -eq '10.2.2.50') { Write-Host "$(get-date) - value Load balancer FrontEnd IP: 10.2.2.50 expected!" -ForegroundColor Green }
}
catch {
    write-host "$(get-date) - error front end IP load balancer $lbName" -ForegroundColor Red
    Exit
}

# Check the health probe (it should be set to HTTP)
try {

    $lbHealthProbe = (Get-AzLoadBalancer -ResourceGroupName $rgName -Name lb).Probes.Port
    write-host "$(get-date) - Load balancer Health Probe port: "$lbHealthProbe
    if ($lbHealthProbe -eq '80') { Write-Host "$(get-date) - value Load balancer health probe port: 80 expected!" -ForegroundColor Green }
}
catch {
    write-host "$(get-date) - error front end IP load balancer $lbName" -ForegroundColor Red
    Exit
}

Write-Host ''

#(Get-AzApplicationGateway -Name appGtw1 -ResourceGroupName $rgName).BackendAddressPools.BackendAddressesText
#(Get-AzNetworkInterface -Name spoke1-vm1-nic -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress
#(Get-AzNetworkInterface -Name spoke1-vm2-nic -ResourceGroupName $rgName).IpConfigurations.PrivateIpAddress

write-host "$(get-date) - static web in storage accounts:" -ForegroundColor Blue 
$web1=(Get-AzStorageAccount -ResourceGroupName $rgName)[0].PrimaryEndpoints.Web
$web2=(Get-AzStorageAccount -ResourceGroupName $rgName)[1].PrimaryEndpoints.Web

# content in 
$site1WebStorage = Invoke-WebRequest -Method GET -Uri "$web1" -userAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)
write-host "$(get-date) - content web: " $site1WebStorage.Content -ForegroundColor Magenta

$site2WebStorage = Invoke-WebRequest -Method GET -Uri "$web2" -userAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)
write-host "$(get-date) - content web: " $site2WebStorage.Content -ForegroundColor Magenta
