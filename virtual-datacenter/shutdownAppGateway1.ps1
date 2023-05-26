###################################################
##
## Shudown the Application Gateway 1 in spoke1   ##
##
###################################################
$subscriptionName ="AzDev"
$rgName = "rg-work3"
$appGtwName ="appGtw1"

# select tthe Azur subscription
$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

# get the application Gateway
$appGtw = Get-AzApplicationGateway -Name $appGtwName -ResourceGroupName $rgName
$appGtw.OperationalState

# stop the application Gateway
Stop-AzApplicationGateway -ApplicationGateway $appGtw 
$appGtw=Get-AzApplicationGateway -Name $appGtwName -ResourceGroupName $rgName
$appGtw.OperationalState