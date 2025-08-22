# AZ CLI script to create Azure VMs in the related subnets.
# The script runs in powershell and required the AZ powershell module
#
$subscriptionName = 'Hybrid-PM-Test-2'
$rgName = 'test-GatewaySubnet-extension'
$location = 'uksouth'
$vm11Name = 'vm11'
$vm21Name = 'vm21'


$vnet1Name = 'vnet1'
$vnet2Name = 'vnet2'

$vnet1Subnet1Name = 'subnet11'
$vnet2Subnet1Name = 'subnet21'


$global:username = 'ADMINISTRATOR_USERNAME'
$global:adminPassword = 'ADMINISTRATOR_PASSWORD'
$global:vmSize = 'Standard_B1s'

$vmArray = @( 
    [pscustomobject]@{ rgName = $rgName; location = $location; vmName = $vm11Name; vnetName = $vnet1Name; subnetName = $vnet1Subnet1Name }
    [pscustomobject]@{ rgName = $rgName; location = $location; vmName = $vm21Name; vnetName = $vnet2Name; subnetName = $vnet2subnet1Name }
)


az account set --subscription $subscriptionName
az account show --output table
az group create --name $rgName --location $location


function createAzVM_azcli {
    Param
    (  [Parameter(Mandatory = $true)] [System.String]$rgName,
    [Parameter(Mandatory = $true)] [System.String]$location,
    [Parameter(Mandatory = $true)] [System.String]$vmName,
    [Parameter(Mandatory = $true)] [System.String]$vnetName,
    [Parameter(Mandatory = $true)] [System.String]$subnetName
    )

    $nicName = $vmName + "-nic"
    $pubIPName = $vmName + "-pip"
    $osDiskName = $vmName + '-OSdisk'

    az network public-ip create `
        --resource-group $rgName `
        --name $pubIPName `
        --allocation-method Static `
        --sku Standard `
        --tier Regional `
        --version IPv4 `
        --zone 1 2 3

    az network nic create `
        --resource-group $rgName `
        --name $nicName `
        --vnet-name $vnetName `
        --subnet $subnetName `
        --public-ip-address $pubIPName

    az vm create `
        --resource-group $rgName `
        --name $vmName `
        --image canonical:ubuntu-24_04-lts:server:latest `
        --public-ip-sku Standard `
        --admin-username $username `
        --size $vmSize `
        --nics $nicName `
        --authentication-type password `
        --admin-password $adminPassword `
        --data-disk-caching 'ReadWrite' `
        --os-disk-name $osDiskName
}

for ($i = 0; $i -lt $vmArray.Length; $i++) {
    createAzVM_azcli -rgName $vmArray[$i].rgName -location $vmArray[$i].location `
        -vmName $vmArray[$i].vmName -vnetName $vmArray[$i].vnetName -subnetName $vmArray[$i].subnetName
}

for ($i = 0; $i -lt $vmArray.Length; $i++) {
    Write-Host 'virtual machine: '$vmArray[$i].vmName
    az vm show --name $vmArray[$i].vmName --resource-group $vmArray[$i].rgName --query "{vmName:name,location:location}"  --output json
}
