# The script creates an Azure VNet by REST API
# actions in sequence:
#  - create a resource group
#  - create a VNet and subnet
#
# input variables:
#  $locationhub1= 'uksouth'
#  $hub1Name= 'hub1'
#  $hub1AddressSpace2= '192.168.0.0/24'
#  $hub1subnet1Name= 'subnet1'
#  $hub1subnet2Name= 'subnet2'
#  $hub1subnet3Name= 'subnet3'
#  $hub1subnet1AddressPrefix= '10.0.0.0/27'
#  $hub1subnet2AddressPrefix= '192.168.0.0/24'
#  $hub1subnet3AddressPrefix= '10.0.0.224/27'
#
# the input variables are read and created as global variables through the script: read-jsonfile.ps1
############################################### CONNECT TO AZURE

# read the value of variable through the script read-jsonfile.ps1
& $PSScriptRoot/read-jsonfile.ps1
write-host $locationhub1
write-host $hub1Name
write-host $hub1AddressSpace1
write-host $hub1AddressSpace2
write-host $hub1subnet1Name
write-host $hub1subnet2Name
write-host $hub1subnet3Name
write-host $hub1subnet1AddressPrefix
write-host $hub1subnet2AddressPrefix
write-host $hub1subnet3AddressPrefix

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
$SubscriptionId=$subscr.Id

$Context = Get-AzContext
if ($null -eq $Context) {
    Write-Information "Need to login"
    Connect-AzAccount -Subscription $SubscriptionId
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

###################################### Create a resouce group

$uri = "https://management.azure.com/subscriptions/$subscriptionId/"
$uri += "resourcegroups/$ResourceGroupName/?api-version=2021-04-01"

$bodyNewRG = @"
{
    "location": "$locationhub1"
}
"@

$result = Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $bodyNewRG

Write-Host ($result | ConvertTo-Json  -Depth 9) -ForegroundColor Cyan
###################################### Create VNet

$uri = "https://management.azure.com/subscriptions/$subscriptionID/"
$uri += "resourcegroups/$ResourceGroupName/providers/Microsoft.Network/virtualNetworks/$hub1Name/?api-version=2023-09-01"


$bodyVnet = @"
{
    "properties": {
      "addressSpace": {
        "addressPrefixes": [
          "$hub1AddressSpace1",
          "$hub1AddressSpace2"
        ]
      },
      "subnets": [
        {
          "name": "$hub1subnet1Name",
          "properties": {
            "addressPrefix": "$hub1subnet1AddressPrefix"
          }
        },
        {
          "name": "$hub1subnet2Name",
          "properties": {
            "addressPrefix": "$hub1subnet2AddressPrefix"
          }
        },
        {
          "name": "$hub1subnet3Name",
          "properties": {
            "addressPrefix": "$hub1subnet3AddressPrefix"
          }
        }
      ]
    },
    "location": "$locationhub1"
  }
"@

$result = Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $bodyVnet
Write-Host ($result | ConvertTo-Json  -Depth 9) -ForegroundColor Green