#!/bin/bash
subscriptionName='AzureDemo'
rgName='rg-1'
location='uksouth'
vmName='vm1'
username='ADMINISTRATOR_USERNAME'
adminPassword='ADMINISTRATOR_PASSWORD'
nsgName='nsg1'
vnetName='vnet1'
subnetName='subnet1'
nicName="$vmName-nic"
pubIPName="$vmName-pubIP"
osDiskName="$vmName-OS"

az account set --subscription $subscriptionName
az account show --output table
az group create --name $rgName --location $location

az network nsg create \
--name $nsgName \
--resource-group $rgName \
--location $location 

az network nsg rule create \
   --resource-group $rgName \
   --nsg-name $nsgName \
   --name SSH-Inbound \
   --direction Inbound \
   --priority 200 \
   --source-address-prefixes '*' \
   --source-port-ranges '*' \
   --destination-address-prefixes 'VirtualNetwork' \
   --destination-port-ranges 22 \
   --access Allow \
   --protocol Tcp \
   --description "Allow incoming SSH connections"


az network nsg rule create \
   --resource-group $rgName \
   --nsg-name $nsgName \
   --name RDP-Inbound \
   --direction Inbound \
   --priority 300 \
   --source-address-prefixes '*' \
   --source-port-ranges '*' \
   --destination-address-prefixes 'VirtualNetwork' \
   --destination-port-ranges 3389 \
   --access Allow \
   --protocol Tcp \
   --description "Allow incoming RDP connections"


az network vnet create \
    --resource-group $rgName \
    --name $vnetName \
    --address-prefix 10.0.0.0/16 \
    --subnet-name $subnetName \
    --subnet-prefix 10.0.1.0/24

az network public-ip create \
     --resource-group $rgName \
     --name $pubIPName \
     --allocation-method Static \
     --sku Standard \
     --tier Regional \
     --version IPv4 \
     --zone 1 2 3

az network nic create \
     --resource-group $rgName \
     --name $nicName \
	 --vnet-name $vnetName \
	 --subnet $subnetName \
	 --network-security-group $nsgName \
     --public-ip-address $pubIPName

az vm create \
    --resource-group $rgName \
    --name $vmName \
    --image Canonical:0001-com-ubuntu-server-jammy:22_04-lts:latest \
    --public-ip-sku Standard \
    --admin-username $username \
	--size Standard_B2s \
	--nics $nicName \
	--authentication-type password \
	--admin-password $adminPassword \
    --data-disk-caching 'ReadWrite' \
    --os-disk-name $osDiskName

	
az vm show --name $vmName --resource-group $rgName