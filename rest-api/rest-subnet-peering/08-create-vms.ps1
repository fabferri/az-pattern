# The script creates an Azure VM by REST API
# actions in sequence:
#  - create a resource group
#  - create a VNet
#  - create a NSG
#  - create public IP 
#  - create a NIC
#  - create an ubuntu VM
#
$hub1vm1Name = 'hub1vm1'
$spoke1vm1Name = 'spoke1vm1'
$spoke2vm1Name = 'spoke2vm1'
$vmSize = 'Standard_B1s'
$publisher ="canonical"
$offer = 'ubuntu-24_04-lts'
$sku= 'server'
$version = 'latest'
#
# read the value of input variable through the script read-jsonfile.ps1
& $PSScriptRoot/00-read-jsonfile.ps1
#
########################### CONNECT TO AZURE
$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
$subscriptionId=$subscr.Id

$Context = Get-AzContext
if ($null -eq  $Context) {
    Write-Information "Need to login"
    Connect-AzAccount -Subscription $SubscriptionId
}
else
{
    Write-Host "Context exists"
    Write-Host "Current credential is $($Context.Account.Id)"
    if ($Context.Subscription.Id -ne $SubscriptionId) {
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


function createVM_REST {
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $location,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $ResourceGroup,
        [Parameter(Mandatory=$true, Position=2)]
        [string] $vnetName,
        [Parameter(Mandatory=$true, Position=3)]
        [string] $subnetName,
        [Parameter(Mandatory=$true, Position=4)]
        [string] $vmName,
        [Parameter(Mandatory=$true, Position=5)]
        [string] $vmSize,
        [Parameter(Mandatory=$true, Position=6)]
        [string] $administratorUsername,
        [Parameter(Mandatory=$true, Position=7)]
        [string] $administratorPassword,
        [Parameter(Mandatory=$true, Position=8)]
        [string] $publisher,
        [Parameter(Mandatory=$true, Position=9)]
        [string] $offer,
        [Parameter(Mandatory=$true, Position=10)]
        [string] $sku
    )

    $pubIPName = $vmName + '-pubIP'
    $nsgName = $vmName + '-nsg'
    $nicName = $vmName + '-nic'
    $vmOSDiskName = $vmName + '-OS'
############ Create a resouce group
$uri = "https://management.azure.com/subscriptions/$SubscriptionID/"
$uri += "resourcegroups/$ResourceGroup/?api-version=2021-04-01"

$bodyNewRG = @"
{
    "location": "$location"
}
"@

$result1 = Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $bodyNewRG

Write-Host ($result1 | ConvertTo-Json  -Depth 9) -ForegroundColor Cyan

############  Get VNet
$uri = "https://management.azure.com/subscriptions/$SubscriptionID/"
$uri += "resourcegroups/$ResourceGroup/providers/Microsoft.Network/virtualNetworks/$vnetName/?api-version=2023-09-01"

$result2 = Invoke-RestMethod -Method Get -ContentType "application/json" -Uri $uri -Headers $headers 
Write-Host ($result2 | ConvertTo-Json  -Depth 9) -ForegroundColor Green

############  Create nsg
$uri = "https://management.azure.com/subscriptions/$SubscriptionID/"
$uri += "resourcegroups/$ResourceGroup/providers/Microsoft.Network/networkSecurityGroups/$nsgName/?api-version=2023-09-01"
$bodyNSG = @"
{
  "properties": {
    "securityRules": [
      {
        "name": "SSH-inbound",
        "properties": {
          "protocol": "Tcp",
          "sourceAddressPrefix": "*",
          "destinationAddressPrefix": "*",
          "access": "Allow",
          "destinationPortRange": "22",
          "sourcePortRange": "*",
          "priority": 200,
          "direction": "Inbound"
        }
      }
    ]
  },
  "location": "$location"
}
"@
$result3 = Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $bodyNSG
Write-Host ($result3 | ConvertTo-Json  -Depth 9) -ForegroundColor Green


############ create public IP
$uri = "https://management.azure.com/subscriptions/$SubscriptionID/"
$uri += "resourcegroups/$ResourceGroup/providers/Microsoft.Network/publicIPAddresses/$pubIPName/?api-version=2023-09-01"
$bodyPubIP = @"
{
  "properties": {
    "publicIPAllocationMethod": "Static",
    "idleTimeoutInMinutes": 10,
    "publicIPAddressVersion": "IPv4"
  },
  "sku": {
    "name": "Standard",
    "tier": "Regional"
  },
  "location": "$location"
}
"@
$result4 = Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $bodyPubIP
Write-Host ($result4 | ConvertTo-Json  -Depth 9) -ForegroundColor Green

############  Create NIC
$uri = "https://management.azure.com/subscriptions/$SubscriptionID/"
$uri += "resourcegroups/$ResourceGroup/providers/Microsoft.Network/networkInterfaces/$nicName/?api-version=2023-09-01"

$bodyNIC = @"
{
  "properties": {
    "enableAcceleratedNetworking": false,
    "ipConfigurations": [
      {
        "name": "ipcfg1",
        "properties": {
          "publicIPAddress": {
            "id": "/subscriptions/$SubscriptionID/resourceGroups/$ResourceGroup/providers/Microsoft.Network/publicIPAddresses/$pubIPName"
          },
          "subnet": {
            "id": "/subscriptions/$SubscriptionID/resourceGroups/$ResourceGroup/providers/Microsoft.Network/virtualNetworks/$vnetName/subnets/$subnetName"
          }
        }
      }
    ],
    "networkSecurityGroup": {
      "id": "/subscriptions/$SubscriptionID/resourceGroups/$ResourceGroup/providers/Microsoft.Network/networkSecurityGroups/$nsgName"
    }
  },
  "location": "$location"
}
"@

$result5 = Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $bodyNIC
Write-Host ($result5 | ConvertTo-Json  -Depth 9) -ForegroundColor Green


############  Create vm
$uri = "https://management.azure.com/subscriptions/$SubscriptionID/"
$uri += "resourcegroups/$ResourceGroup/providers/Microsoft.Compute/virtualMachines/$vmName/?api-version=2023-09-01"

$bodyVM = @"
{
  "location": "$location",
  "properties": {
    "hardwareProfile": {
      "vmSize": "$vmSize"
    },
    "storageProfile": {
      "imageReference": {
        "publisher": "$publisher",
        "offer": "$offer",
        "sku": "$sku",
        "version": "$version"
    },
      "osDisk": {
        "caching": "ReadWrite",
        "managedDisk": {
          "storageAccountType": "Standard_LRS"
        },
        "name": "$vmOSDiskName",
        "createOption": "FromImage"
      }
    },
    "osProfile": {
      "adminUsername": "$administratorUsername",
      "computerName": "$vmName",
      "adminPassword": "$administratorPassword"
    },
    "networkProfile": {
      "networkInterfaces": [
        {
          "id": "/subscriptions/$SubscriptionID/resourceGroups/$ResourceGroup/providers/Microsoft.Network/networkInterfaces/$nicName",
          "properties": {
            "primary": true
          }
        }
      ]
    }
  }
}
"@
$result6 = Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $bodyVM
Write-Host ($result6 | ConvertTo-Json  -Depth 9) -ForegroundColor Green
}


createVM_REST -location $locationhub1 `
  -ResourceGroup $ResourceGroupName `
  -vnetName $hub1Name `
  -subnetName $hub1subnet1Name `
  -vmName $hub1vm1Name `
  -vmSize $vmSize `
  -administratorUsername $adminUsername `
  -administratorPassword $adminPassword `
  -publisher $publisher `
  -offer $offer `
  -sku $sku

  createVM_REST -location $locationspoke1 `
  -ResourceGroup $ResourceGroupName `
  -vnetName $spoke1Name `
  -subnetName $spoke1subnet1Name `
  -vmName $spoke1vm1Name `
  -vmSize $vmSize `
  -administratorUsername $adminUsername `
  -administratorPassword $adminPassword `
  -publisher $publisher `
  -offer $offer `
  -sku $sku

  createVM_REST -location $locationspoke2 `
  -ResourceGroup $ResourceGroupName `
  -vnetName $spoke2Name `
  -subnetName $spoke2subnet1Name `
  -vmName $spoke2vm1Name `
  -vmSize $vmSize `
  -administratorUsername $adminUsername `
  -administratorPassword $adminPassword `
  -publisher $publisher `
  -offer $offer `
  -sku $sku