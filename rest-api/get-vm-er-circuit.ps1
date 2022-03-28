$subscriptionName= 'ExpressRoute-lab'
$ResourceGroup = 'ASH-Cust30'
$vmName = 'ASH-Cust30-VM01'
$ercircuitName = "ASH-Cust30-ER"
############################################################### CONNECT TO AZURE
$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
$subscriptionId=$subscr.Id

$Context = Get-AzContext

if ($Context -eq $null) {
    Write-Information "Need to login"
    Connect-AzAccount -Subscription $SubscriptionId
}
else
{
    Write-Host "Context exists"
    Write-Host "Current credential is $($Context.Account.Id)"
    if ($Context.Subscription.Id -ne $SubscriptionId) {
        $result = Select-AzSubscription -Subscription $SubscriptionId
        Write-Host "Current subscription is $($result.Subscription.Name)"
    }
    else {
        Write-Host "Current subscription is $($Context.Subscription.Name)"    
    }
}
############################################################### 
# get Bearer token for current user for Synapse Workspace API
$token = (Get-AzAccessToken -Resource "https://management.azure.com").Token
$headers = @{ Authorization = "Bearer $token" }
# ------------------------------------------


$uri = "https://management.azure.com/subscriptions/$subscriptionId/"
$uri += "resourceGroups/$ResourceGroup/providers/Microsoft.Compute/"
$uri += "virtualMachines/$vmName/?api-version=2021-07-01"

$result = Invoke-RestMethod -Method Get -ContentType "application/json" -Uri $uri -Headers $headers

Write-Host ($result | ConvertTo-Json  -Depth 9) -ForegroundColor Yellow

############################################################### 

$uri = "https://management.azure.com/subscriptions/$subscriptionId/"
$uri += "resourceGroups/$ResourceGroup/providers/Microsoft.Network/"
$uri += "expressRouteCircuits/$ercircuitName/?api-version=2021-12-01"

$result = Invoke-RestMethod -Method Get -ContentType "application/json" -Uri $uri -Headers $headers

Write-Host ($result | ConvertTo-Json  -Depth 9) -ForegroundColor Cyan
