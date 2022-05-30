# getting the public IPs of the Azure VPN Gateway
#
#
#
$subscriptionName  = "AzDev"
$rg_vpn            = "rg-vpn" 
$vpnName           = "vpnGw" 
$publicIP1_VPN     = "vpnGwIP1"
$publicIP2_VPN     = "vpnGwIP2"


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

try {
 $IP1Gtw=Get-AzPublicIpAddress -Name $publicIP1_VPN -ResourceGroupName $rg_vpn -ErrorAction Stop
 $IP2Gtw=Get-AzPublicIpAddress -Name $publicIP2_VPN -ResourceGroupName $rg_vpn -ErrorAction Stop
 write-host "VPN Gateway-IP1...: "$IP1Gtw.IpAddress -ForegroundColor Yellow -BackgroundColor Black
 write-host "VPN Gateway-IP2...: "$IP2Gtw.IpAddress -ForegroundColor Yellow -BackgroundColor Black
}
catch{
  write-host "VPN public IP Addresses not found:" -ForegroundColor Yellow 
  write-host " -Check the resource group...:"$rg_vpn   -ForegroundColor Yellow
  write-host " -check the VPN-public IP1...:"$publicIP1_VPN -ForegroundColor Yellow
  write-host " -check the VPN-public IP2...:"$publicIP2_VPN -ForegroundColor Yellow
}
try {
 $gtw=Get-AzVirtualNetworkGateway -Name $vpnName -ResourceGroupName $rg_vpn -ErrorAction stop
 $bgpPeeringIP1,$bgpPeeringIP2 = ($gtw.BgpSettings.BgpPeeringAddress).split(',')
 write-host "BGP peering-IP1...: "$bgpPeeringIP1 -ForegroundColor Yellow -BackgroundColor Black
 write-host "BGP peering-IP2...: "$bgpPeeringIP2 -ForegroundColor Yellow -BackgroundColor Black
}
catch {
  write-host "VPN gateway not found:" -ForegroundColor Yellow 
  write-host " -Check the resource group...:"$rg_vpn  -ForegroundColor Yellow
  write-host " -check the VNP name.........:"$vpnName -ForegroundColor Yellow
}



