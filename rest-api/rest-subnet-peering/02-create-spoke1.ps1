# The script creates an Azure VNet by REST API
# actions in sequence:
#  - create a resource group
#  - create a VNet and subnet
#
# input variables:
# $locationspoke1= 'uksouth'
# $spoke1Name= 'spoke1'
# $spoke1AddressSpace2= '192.168.1.0/24'
# $spoke1subnet1Name= 'subnet1'
# $spoke1subnet2Name= 'subnet2'
# $spoke1subnet3Name= 'subnet3'
# $spoke1subnet1AddressPrefix= '10.1.0.0/27'
# $spoke1subnet2AddressPrefix= '192.168.1.0/24'
# $spoke1subnet3AddressPrefix= '10.1.0.224/27'
#
# the input variables are read and created as global variables through the script: read-jsonfile.ps1


# read the value of variable through the script read-jsonfile.ps1
& $PSScriptRoot/read-jsonfile.ps1
write-host $locationspoke1
write-host $spoke1Name
write-host $spoke1AddressSpace1
write-host $spoke1AddressSpace2
write-host $spoke1subnet1Name
write-host $spoke1subnet2Name
write-host $spoke1subnet3Name
write-host $spoke1subnet1AddressPrefix
write-host $spoke1subnet2AddressPrefix
write-host $spoke1subnet3AddressPrefix

############################################### CONNECT TO AZURE


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


#############################################################
# get Bearer token for current user for Synapse Workspace API
$token = (Get-AzAccessToken -Resource "https://management.azure.com").Token
$headers = @{ Authorization = "Bearer $token" }
# ------------------------------------------

###################################### Create a resouce group

$uri = "https://management.azure.com/subscriptions/$subscriptionId/"
$uri += "resourcegroups/$ResourceGroupName/?api-version=2021-04-01"

$bodyNewRG = @"
{
    "location": "$locationspoke1"
}
"@

$result = Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $bodyNewRG

Write-Host ($result | ConvertTo-Json  -Depth 9) -ForegroundColor Cyan
###################################### Create VNet

$uri = "https://management.azure.com/subscriptions/$subscriptionId/"
$uri += "resourcegroups/$ResourceGroupName/providers/Microsoft.Network/virtualNetworks/$spoke1Name/?api-version=2023-09-01"


$bodyVnet = @"
{
    "properties": {
      "addressSpace": {
        "addressPrefixes": [
          "$spoke1AddressSpace1",
          "$spoke1AddressSpace2"
        ]
      },
      "subnets": [
        {
          "name": "$spoke1subnet1Name",
          "properties": {
            "addressPrefix": "$spoke1subnet1AddressPrefix"
          }
        },
        {
          "name": "$spoke1subnet2Name",
          "properties": {
            "addressPrefix": "$spoke1subnet2AddressPrefix"
          }
        },
        {
          "name": "$spoke1subnet3Name",
          "properties": {
            "addressPrefix": "$spoke1subnet3AddressPrefix"
          }
        }
      ]
    },
    "location": "$locationspoke1"
  }
"@

$result = Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $bodyVnet
Write-Host ($result | ConvertTo-Json  -Depth 9) -ForegroundColor Green