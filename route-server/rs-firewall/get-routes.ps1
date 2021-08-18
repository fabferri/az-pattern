$vrName = 'routesrv1' 
$peer1Name = 'bgp-conn1'
$peer2Name = "bgp-conn2"

$pathFiles = Split-Path -Parent $PSCommandPath

#Reading the resource group name from the file init.txt
If (Test-Path -Path $pathFiles\init.txt) {
    Get-Content $pathFiles\init.txt | Foreach-Object{
    $var = $_.Split('=')
    Try {New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop}
    Catch {Set-Variable -Name $var[0].Trim() -Value $var[1].Trim()}
    }
}
Else {Write-Warning "init.txt file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return}

if (!$mngIP) { Write-Host 'variable $mngIP is null' ; Exit }
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit }
if (!$location1) { Write-Host 'variable $location1 is null' ; Exit }
if (!$location2) { Write-Host 'variable $location2 is null' ; Exit }
if (!$location3) { Write-Host 'variable $location3 is null' ; Exit }
$rgName=$ResourceGroupName

Write-Host 'management IP..........:'$mngIP -ForegroundColor Yellow
Write-Host 'azure subscription name:'$subscriptionName -ForegroundColor Yellow
Write-Host 'azure resource group...:'$rgName -ForegroundColor Yellow
Write-Host 'azure location1........:'$location1 -ForegroundColor Yellow
Write-Host 'azure location2........:'$location2 -ForegroundColor Yellow
Write-Host 'azure location3........:'$location3 -ForegroundColor Yellow

# select the Azure subscription
$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Set-AzContext -Subscription $subscr.Id -ErrorAction Stop


write-host "route advertised to nva1:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerAdvertisedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name -WarningAction Ignore | Format-Table

write-host "route learned from nva1:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerLearnedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer1Name -WarningAction Ignore | Format-Table

write-host "-------------------------------------------------" -ForegroundColor Yellow

write-host "route advertised to nva2:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerAdvertisedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer2Name -WarningAction Ignore | ft

write-host "route learned from nva2:" -ForegroundColor Yellow
Get-AzVirtualRouterPeerLearnedRoute -ResourceGroupName $rgName -VirtualRouterName $vrName -PeerName $peer2Name -WarningAction Ignore | ft