#
# get the connection string
#
# $rgName: name of the resource group
# $eventHubNameSpace: name of the event hub name space
# 
$rgName= 'fab-servicetag1'
#
# getting the name of the event hub name space
$eventHubNameSpace= (Get-AzEventHubNamespace -ResourceGroupName $rgName).Name
Get-AzEventHubKey -ResourceGroupName $rgName -NamespaceName $eventHubNameSpace -AuthorizationRuleName RootManageSharedAccessKey