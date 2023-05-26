
###################################################
##
## start the Application Gateway 3 in spoke3     ##
##
###################################################
$subscriptionName ="AzDev"
$rgName = "rg-work3"
$appGtwName = "appGtw3"

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$appGtw=Get-AzApplicationGateway -Name $appGtwName -ResourceGroupName $rgName
$appGtw.OperationalState

Start-AzApplicationGateway -ApplicationGateway $appGtw 
$appGtw=Get-AzApplicationGateway -Name $appGtwName -ResourceGroupName $rgName
$appGtw.OperationalState