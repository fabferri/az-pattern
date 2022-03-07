# The script creates an Azure VM by REST API
# actions in sequence:
#  - create a resource group
#  - create a VNet
#  - create a NSG
#  - create public IP 
#  - create a NIC
#  - create an ubuntu VM
#
# input variables:
#
#   $subscriptionName = AZURe_SUBSCRIPTION NAME
#   $location = AZURE_REGION_NAME
#   $ResourceGroup = RESOURCE_GROUP_NAME
#   $vnetName = VNET_NAME
#   $vnetAddressSpace = ADDRESS_SPACE_VNET
#   $subnet1Name = NAME_SUBNET1
#   $subnet2Name = NAME_SUBNET2
#   $subnet1AddressPrefix = ADDRESS_PREFIX_SUBNET1
#   $subnet2AddressPrefix = ADDRESS_PREFIX_SUBNET2
#   $vmName = AZURE_VIRTUAL_MACHINE_NAME 
#   $pubIPName = PUBLIC_IP_NAME_AZURE_VM
#   $nsgName = NETWORK_SECURITY_GROUP_NAME_APPIED_TO_THE_NIC
#   $nicName = NIC_NAME_AZURE_VM
#   $administratorUsername = ADMINISTRATOR_USERNAME
#   $administratorPassword = AMINISTRATOR_PASSWORD
#   $vmOSDiskName = OS_DISK_NAME
#   $publisher = NAME_PUBLISHER_IMAGE
#   $offer = NAME_OFFER_IMAGE
#   $sku = VERSION_IMAGE
# ------------------------------------------
# these Az modules required
# https://docs.microsoft.com/powershell/azure/install-az-ps
# Import-Module Az.Accounts 
# ------------------------------------------
$subscriptionName = 'ExpressRoute-Lab'
$location = 'eastus'
$ResourceGroup = 'my-rg1'
$vnetName = 'vnet1'
$vnetAddressSpace = '10.0.0.0/24'
$subnet1Name = 'subnet1'
$subnet2Name = 'subnet2'
$subnet1AddressPrefix = '10.0.0.0/25'
$subnet2AddressPrefix = '10.0.0.128/25'
$vmName = 'vm1' 
$pubIPName = 'vm1' + '-pubIP'
$nsgName = $vmName + '-nsg'
$nicName = $vmName + '-nic'
$administratorUsername = 'ADMINISTRATOR_USERNAME'
$administratorPassword = 'AMINISTRATOR_PASSWORD'
$vmOSDiskName = $vmName + '-OS'
$publisher = 'canonical'
$offer = '0001-com-ubuntu-server-focal'
$sku = '20_04-lts'
#
#
######################################  CONNECT TO AZURE
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
$uri += "resourcegroups/"
$uri += "$ResourceGroup/?api-version=2021-04-01"

$bodyNewRG = @"
{
    "location": "$location"
}
"@

$result1 = Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $bodyNewRG

Write-Host ($result1 | ConvertTo-Json  -Depth 9) -ForegroundColor Cyan

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
$result2 = Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $bodyVnet
Write-Host ($result2 | ConvertTo-Json  -Depth 9) -ForegroundColor Green

###################################### Create nsg
$uri = "https://management.azure.com/subscriptions/$SubscriptionID/"
$uri += "resourcegroups/$ResourceGroup/providers/Microsoft.Network/networkSecurityGroups/$nsgName/?api-version=2021-05-01"
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



###################################### public IP
$uri = "https://management.azure.com/subscriptions/$SubscriptionID/"
$uri += "resourcegroups/$ResourceGroup/providers/Microsoft.Network/publicIPAddresses/$pubIPName/?api-version=2021-05-01"
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




###################################### Create NIC
$uri = "https://management.azure.com/subscriptions/$SubscriptionID/"
$uri += "resourcegroups/$ResourceGroup/providers/Microsoft.Network/networkInterfaces/$nicName/?api-version=2021-05-01"

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
            "id": "/subscriptions/$SubscriptionID/resourceGroups/$ResourceGroup/providers/Microsoft.Network/virtualNetworks/$vnetName/subnets/$subnet1Name"
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


###################################### Create vm
$uri = "https://management.azure.com/subscriptions/$SubscriptionID/"
$uri += "resourcegroups/$ResourceGroup/providers/Microsoft.Compute/virtualMachines/$vmName/?api-version=2021-11-01"

$bodyVM = @"
{
  "location": "$location",
  "properties": {
    "hardwareProfile": {
      "vmSize": "Standard_B1s"
    },
    "storageProfile": {
      "imageReference": {
        "publisher": "$publisher",
        "offer": "$offer",
        "sku": "$sku",
        "version": "latest"
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