
###################################################
##
## stop the Application Gateway 3 in spoke3     ##
##
###################################################
$subscriptionName ="AzDev"
$rgName = "rg-work3"
$appGtwName ="appGtw3"

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$appGtwName="appGtw3"
$appGtw=Get-AzApplicationGateway -Name $appGtwName -ResourceGroupName $rgName
$appGtw.OperationalState

Stop-AzApplicationGateway -ApplicationGateway $appGtw 
$appGtw=Get-AzApplicationGateway -Name $appGtwName -ResourceGroupName $rgName
$appGtw.OperationalState