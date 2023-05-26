###################################################
##
## start the Application Gateway 1 in spoke1     ##
##
###################################################
$subscriptionName ="AzDev"
$rgName = "rg-work3"
$appGtwName ="appGtw1"

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$appGtwName="appGtw1"
$appGtw=Get-AzApplicationGateway -Name $appGtwName -ResourceGroupName $rgName
$appGtw.OperationalState

Start-AzApplicationGateway -ApplicationGateway $appGtw
$appGtw=Get-AzApplicationGateway -Name $appGtwName -ResourceGroupName $rgName
$appGtw.OperationalState