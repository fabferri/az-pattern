#######
$subscription = "YOUR_AZURE_SUBSCRIPTION_NAME"
$location     = "North Europe"
$rgVNet       = "VNetsRG"
#
$vnetName   = @("VNet1","VNet2","VNet3","VNet4","VNet5","VNet6","VNet7","VNet8","VNet9","VNet10","VNet11")
$subnetName = "Subnet1"

[string[]]$vnetAddr   = @() 
[string[]]$subnetAddr = @()
[string[]]$gwAddr     = @()
$vnetAddr += ,@("10.217.48.128/25")
$vnetAddr += ,@("10.217.48.0/28")
$vnetAddr += ,@("10.217.49.128/25")
$vnetAddr += ,@("10.217.49.0/28")
$vnetAddr += ,@("10.217.50.128/25")
$vnetAddr += ,@("10.217.50.0/28")
$vnetAddr += ,@("10.217.51.128/25")
$vnetAddr += ,@("10.217.51.0/28")
$vnetAddr += ,@("10.217.52.128/25")
$vnetAddr += ,@("10.217.52.0/28")
$vnetAddr += ,@("10.217.53.128/25")
$vnetAddr += ,@("10.217.53.0/28")
$vnetAddr += ,@("10.217.54.128/25")
$vnetAddr += ,@("10.217.54.0/28")
$vnetAddr += ,@("10.217.56.128/25")
$vnetAddr += ,@("10.217.56.0/28")
$vnetAddr += ,@("10.217.57.128/25")
$vnetAddr += ,@("10.217.57.0/28")
$vnetAddr += ,@("10.217.58.128/25")
$vnetAddr += ,@("10.217.58.0/28")
$vnetAddr += ,@("10.217.59.128/25")
$vnetAddr += ,@("10.217.59.0/28")


 for($i=0; $i -lt $vnetAddr.length; $i++)
{
   if($i % 2 -ne 0)
   {  
      $subnetAddr += ,@($vnetAddr[$i])
      write-host -foregroundcolor Cyan "VNet    Subnet:" $vnetAddr[$i]
   }
   else
   {
      $gwAddr     += ,@($vnetAddr[$i])
      write-host -foregroundcolor Cyan "Gateway Subnet:" $vnetAddr[$i]
   }
}

for($i=0; $i -lt $subnetAddr.length; $i++)
{  
   write-host -foregroundcolor Yellow "VNet    Subnet:"  $subnetAddr[$i]
   write-host -foregroundcolor Green  "Gateway Subnet:"  $gwAddr[$i]
}


Get-AzureRmSubscription -SubscriptionName $subscription | Select-AzureRmSubscription
New-AzureRmResourceGroup -Name $rgVNet -Location $location

for($i=0; $i -lt $vnetName.length; $i++)
{
    $s1 = New-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddr[$i]
    $s2 = New-AzureRmVirtualNetworkSubnetConfig -Name "GatewaySubnet" -AddressPrefix $gwAddr[$i]
    $vnet1 = New-AzureRmVirtualNetwork  -Name $vnetName[$i]  -ResourceGroupName $rgVNet -Location $location -AddressPrefix $subnetAddr[$i],$gwAddr[$i] -Subnet $s1, $s2 -Verbose
}
