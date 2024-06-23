# The script creates an Azure VNet by REST API
# actions in sequence:
#  - create a resource group
#  - create a VNet peering between hub1 and spoke2
#
# read the value of variable through the script read-jsonfile.ps1
& $PSScriptRoot/read-jsonfile.ps1
write-host $locationhub1
write-host $peeringhub1Tospoke1
write-host $peeringspoke1Tohub1
write-host $peeringhub1Tospoke2
write-host $peeringspoke2Tohub1

########################### CONNECT TO AZURE
$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
$subscriptionId=$subscr.Id

$Context = Get-AzContext
if ($null -eq $Context) {
    Write-Information "Need to login"
    Connect-AzAccount -Subscription $subscriptionId
}
else
{
    Write-Host "Context exists"
    Write-Host "Current credential is $($Context.Account.Id)"
    if ($Context.Subscription.Id -ne $subscriptionId) {
        $result = Select-AzSubscription -Subscription $subscriptionId
        Write-Host "Current subscription is $($result.Subscription.Name)"
    }
    else {
        Write-Host "Current subscription is $($Context.Subscription.Name)"    
    }
}
########################################################################################
# ------------------------------------------
# get Bearer token for current user for Synapse Workspace API
$token = (Get-AzAccessToken -Resource "https://management.azure.com").Token
$headers = @{ Authorization = "Bearer $token" }
# ------------------------------------------



$uri = "https://management.azure.com/subscriptions/$subscriptionId/"
$uri += "resourcegroups/$ResourceGroupName/providers/Microsoft.Network/virtualNetworks/$hub1Name/virtualNetworkPeerings/$peeringhub1Tospoke2/?api-version=2023-11-01"

$bodyVnetPeering = @"
{
    "properties": {
       "remoteVirtualNetwork": {
          "id": "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/virtualNetworks/$spoke2Name"
        },
        "allowVirtualNetworkAccess": true,
        "allowForwardedTraffic": true,
        "allowGatewayTransit": false,
        "useRemoteGateways": false
    },
    "location": "$locationhub1"
  }
"@

$result = Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $bodyVnetPeering
write-host "$(Get-Date) - vnet peering: $peeringhub1Tospoke2 created" -ForegroundColor Cyan
