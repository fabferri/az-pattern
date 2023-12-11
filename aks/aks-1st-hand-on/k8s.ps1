$location='uksouth'
$rg='k8-1'
$aksName='aks-101'
$adminUsername='aksadmin'
az group create --name $rg --location $location

$SSH=(Get-Content ~\.ssh\id_rsa.pub)
az Deployment group create -f k8s.json -g $rg `
                --parameters linuxAdminUsername=$adminUsername sshRSAPublicKey=$SSH clusterName=$aksName agentCount=1 

