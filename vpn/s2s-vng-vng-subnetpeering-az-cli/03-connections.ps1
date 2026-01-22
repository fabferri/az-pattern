# AZ CLI script to deploy VPN Connection for S2S IPsec tunnels
# The script runs in powershell and required the AZ powershell module
#
$subscriptionName='Hybrid-PM-Test-2'
$rg='test-subnetpeering'
$location='uksouth'

$localNetGtw11= 'lngw11-to-gw1'
$localNetGtw12= 'lngw12-to-gw1'

$localNetGtw21= 'lngw21-to-gw2'
$localNetGtw22= 'lngw22-to-gw2'

$vpnGw1Name='gw1'
$vpnGw2Name='gw2'

$vpnGw1pip1= "$vpnGw1Name-pip1"
$vpnGw1pip2= "$vpnGw1Name-pip2"
$vpnGw2pip1= "$vpnGw2Name-pip1"
$vpnGw2pip2= "$vpnGw2Name-pip2"
$vpngw1ASN= 65001
$vpngw2ASN= 65002

$conn11= 'conn11'
$conn12= 'conn12'
$conn21= 'conn21'
$conn22= 'conn22'

$sharedSecret ='YOUR_SHARED_SECRET_FOR_THE_SITE_TO_SITE_VPN_TUNNEL'

# select the Azure subscription
az account set --subscription $subscriptionName

$vpnGw1BgpIPs= az network vnet-gateway show --name $vpnGw1Name --resource-group $rg --query "bgpSettings.bgpPeeringAddress" --output tsv
$vpnGw2BgpIPs= az network vnet-gateway show --name $vpnGw2Name --resource-group $rg --query "bgpSettings.bgpPeeringAddress" --output tsv

$bgp_tmp1=$vpnGw1BgpIPs.Split(",")
$gw1BGPIP1=$bgp_tmp1[0]
$gw1BGPIP2=$bgp_tmp1[1]

$bgp_tmp2=$vpnGw2BgpIPs.Split(",")
$gw2BGPIP1=$bgp_tmp2[0]
$gw2BGPIP2=$bgp_tmp2[1]
write-host "Gateway $vpnGw1Name instance0-BGP IP: "$gw1BGPIP1 -ForegroundColor Cyan
write-host "Gateway $vpnGw1Name instance1-BGP IP: "$gw1BGPIP2 -ForegroundColor Cyan
write-host "Gateway $vpnGw2Name instance0-BGP IP: "$gw2BGPIP1 -ForegroundColor Cyan
write-host "Gateway $vpnGw2Name instance1-BGP IP: "$gw2BGPIP2 -ForegroundColor Cyan

$vpngw1PubIP1= az network public-ip show -g $rg -n $vpnGw1pip1 --query "ipAddress" --output tsv
$vpngw1PubIP2= az network public-ip show -g $rg -n $vpnGw1pip2 --query "ipAddress" --output tsv
$vpngw2PubIP1= az network public-ip show -g $rg -n $vpnGw2pip1 --query "ipAddress" --output tsv
$vpngw2PubIP2= az network public-ip show -g $rg -n $vpnGw2pip2 --query "ipAddress" --output tsv


write-host  "Gateway $vpnGw1Name instance0-pubIP IP1: "$vpngw1PubIP1 -ForegroundColor Cyan
write-host  "Gateway $vpnGw1Name instance1-pubIP IP2: "$vpngw1PubIP2 -ForegroundColor Cyan
write-host  "Gateway $vpnGw2Name instance0-pubIP IP1: "$vpngw2PubIP1 -ForegroundColor Cyan
write-host  "Gateway $vpnGw2Name instance1-pubIP IP2: "$vpngw2PubIP2 -ForegroundColor Cyan


write-host  "$(Get-Date) - Creating local gateway: "$localNetGtw11 -ForegroundColor Cyan
az network local-gateway create `
  --name $localNetGtw11 `
  --resource-group $rg `
  --location $location `
  --gateway-ip-address $vpngw1PubIP1 `
  --asn $vpngw1ASN `
  --bgp-peering-address $gw1BGPIP1

write-host  "$(Get-Date) - Creating local gateway: "$localNetGtw12 -ForegroundColor Cyan
az network local-gateway create `
  --name $localNetGtw12 `
  --resource-group $rg `
  --location $location `
  --gateway-ip-address $vpngw1PubIP2 `
  --asn $vpngw1ASN `
  --bgp-peering-address $gw1BGPIP2

write-host  "$(Get-Date) - Creating local gateway: "$localNetGtw21 -ForegroundColor Cyan
az network local-gateway create `
  --name $localNetGtw21 `
  --resource-group $rg `
  --location $location `
  --gateway-ip-address $vpngw2PubIP1 `
  --asn $vpngw2ASN `
  --bgp-peering-address $gw2BGPIP1

write-host  "$(Get-Date) - Creating local gateway: "$localNetGtw22 -ForegroundColor Cyan
az network local-gateway create `
  --name $localNetGtw22 `
  --resource-group $rg `
  --location $location `
  --gateway-ip-address $vpngw2PubIP2 `
  --asn $vpngw2ASN `
  --bgp-peering-address $gw2BGPIP2


write-host  "$(Get-Date) - Creating connection: "$conn11 -ForegroundColor Yellow
az network vpn-connection create `
  --name $conn11 `
  --resource-group $rg `
  --vnet-gateway1 $vpnGw1Name `
  --local-gateway2 $localNetGtw21 `
  --enable-bgp `
  --shared-key $sharedSecret

write-host  "$(Get-Date) - Creating connection: "$conn12 -ForegroundColor Yellow
az network vpn-connection create `
  --name $conn12 `
  --resource-group $rg `
  --vnet-gateway1 $vpnGw1Name `
  --local-gateway2 $localNetGtw22 `
  --enable-bgp `
  --shared-key $sharedSecret

write-host  "$(Get-Date) - Creating connection: "$conn21 -ForegroundColor Yellow
az network vpn-connection create `
  --name $conn21 `
  --resource-group $rg `
  --vnet-gateway1 $vpnGw2Name `
  --local-gateway2 $localNetGtw11 `
  --enable-bgp `
  --shared-key $sharedSecret

write-host  "$(Get-Date) - Creating connection: "$conn22 -ForegroundColor Yellow
az network vpn-connection create `
  --name $conn22 `
  --resource-group $rg `
  --vnet-gateway1 $vpnGw2Name `
  --local-gateway2 $localNetGtw12 `
  --enable-bgp `
  --shared-key $sharedSecret