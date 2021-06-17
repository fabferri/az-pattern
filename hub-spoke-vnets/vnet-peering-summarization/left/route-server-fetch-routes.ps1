$initFile = 'init.txt'
$vrName = "rs-hub00" 
$peer1Name = "bgp-conn1"
$peer2Name = "bgp-conn2"

# Load Initialization Variables
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Write-Host "$(get-date) - reading files from the folder:"$ScriptDir -ForegroundColor Yellow
If (Test-Path -Path $ScriptDir\$initFile) {
        Get-Content $ScriptDir\$initFile | Foreach-Object{
        $var = $_.Split('=')
        Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
        Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}}}
Else {Write-Warning "$initFile not found, please change to the directory where these scripts reside ($ScriptDir) and ensure this file is present.";Return}

Write-Host "$(get-date) - reading from init.xt - subscriptioName: $subscriptionName " -ForegroundColor Cyan
Write-Host "$(get-date) - reading from init.xt - Resource Group.: $rgName " -ForegroundColor Cyan
Write-Host "$(get-date) - reading from init.xt - location.......: $location " -ForegroundColor Cyan



$ctx = (Get-AzContext).Name  
if ($ctx -ne "ExpressRouteLab") { 
  # select the Azure subscription
  $subscr = Get-AzSubscription -SubscriptionName $subscriptionName
  Set-AzContext -Subscription $subscr.Id -ErrorAction Stop
}

write-host "route advertised from Route Server to nva1:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerAdvertisedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name -WarningAction Ignore | ft

write-host "route learned from nva1:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerLearnedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name -WarningAction Ignore | ft


write-host "-------------------------------------------------" -ForegroundColor Yellow
write-host "-------------------------------------------------" -ForegroundColor Yellow

write-host "route advertised from Route Server to nva2:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerAdvertisedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer2Name -WarningAction Ignore | ft

write-host "route learned from nva2:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerLearnedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer2Name -WarningAction Ignore | ft