$location = 'uksouth'
$rg = 'k8-1'
$clusterName = 'aks5'
#
write-host 'Select the azure subscription' -ForegroundColor Green
az account set --subscription "AzureDemo"
#
write-host "create the resource group: $rg" -ForegroundColor Green
az group create --name $rg --location $location
#
write-host "$(date) - create the AKS cluster: $clusterName" -ForegroundColor Green
## --enable-file-driver:  enable the Azure Files CSI driver
az aks create -g $rg -n $clusterName  --node-count 2 --enable-managed-identity --generate-ssh-keys 
# 
##
write-host "$(date) - get the credential to access to the cluster: $clusterName" -ForegroundColor Cyan
az aks get-credentials --resource-group $rg --name $clusterName 

## Enable CSI storage drivers on an existing cluster
write-host "$(date) - update the cluster: $clusterName" -ForegroundColor Cyan
az aks update -g $rg -n $clusterName --enable-file-driver 

