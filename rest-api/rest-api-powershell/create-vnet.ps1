# The script creates an Azure VNet by REST API
# actions in sequence:
#  - create a resource group
#  - create a VNet
#
# input variables:
#
#   $subscriptionName = AZURE_SUBSCRIPTION NAME
#   $location = AZURE_REGION_NAME
#   $ResourceGroup = RESOURCE_GROUP_NAME
#   $vnetName = VNET_NAME
#   $vnetAddressSpace = ADDRESS_SPACE_VNET
#   $subnet1Name = NAME_SUBNET1
#   $subnet2Name = NAME_SUBNET2
#   $subnet1AddressPrefix = ADDRESS_PREFIX_SUBNET1
#   $subnet2AddressPrefix = ADDRESS_PREFIX_SUBNET2
# ------------------------------------------
# these Az modules required
# https://docs.microsoft.com/powershell/azure/install-az-ps
# Import-Module Az.Accounts 
# ------------------------------------------
$subscriptionName = 'ExpressRoute-Lab'
$location = 'eastus'
$ResourceGroup = "testfab101-vnet"
$vnetName = 'vnet1'
$vnetAddressSpace = '10.0.0.0/24'
$subnet1Name = 'subnet1'
$subnet2Name = 'subnet2'
$subnet1AddressPrefix = '10.0.0.0/25'
$subnet2AddressPrefix = '10.0.0.128/25'
############################################### CONNECT TO AZURE
$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
$SubscriptionId=$subscr.Id

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
########################################################################################
# ------------------------------------------
# get Bearer token for current user for Synapse Workspace API
$token = (Get-AzAccessToken -Resource "https://management.azure.com").Token
$headers = @{ Authorization = "Bearer $token" }
# ------------------------------------------

###################################### Create a resouce group

$uri = "https://management.azure.com/subscriptions/$SubscriptionID/"
$uri += "resourcegroups/$ResourceGroup/?api-version=2021-04-01"

$bodyNewRG = @"
{
    "location": "$location"
}
"@

$result = Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $bodyNewRG

Write-Host ($result | ConvertTo-Json  -Depth 9) -ForegroundColor Cyan
###################################### Create VNet

$uri = "https://management.azure.com/subscriptions/$SubscriptionID/"
$uri += "resourcegroups/$ResourceGroup/providers/Microsoft.Network/virtualNetworks/$vnetName/?api-version=2021-05-01"


$bodyVnet = @"
{
    "properties": {
      "addressSpace": {
        "addressPrefixes": [
          "$vnetAddressSpace"
        ]
      },
      "subnets": [
        {
          "name": "$subnet1Name",
          "properties": {
            "addressPrefix": "$subnet1AddressPrefix"
          }
        },
        {
          "name": "$subnet2Name",
          "properties": {
            "addressPrefix": "$subnet2AddressPrefix"
          }
        }
      ],
      "bgpCommunities": {
        "virtualNetworkCommunity": "12076:20000"
      }
    },
    "location": "$location"
  }
"@

$result = Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $bodyVnet

Write-Host ($result | ConvertTo-Json  -Depth 9) -ForegroundColor Green