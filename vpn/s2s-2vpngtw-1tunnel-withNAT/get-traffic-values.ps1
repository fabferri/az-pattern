#
# Script to get the the Byte in/Byte out associated with the connections
#
$subscriptionName = "AzDev"     
$location = "eastus"
$rgName = "vpn1"

$pathFiles      = Split-Path -Parent $PSCommandPath
$fileName="log"+[DateTime]::Now.ToString("yyyyMMdd-HHmmss") +".txt"

$logFile   = "$pathFiles\$fileName"

$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$i=0
do 
{
  $i++
  $conn1=Get-AzVirtualNetworkGatewayConnection -Name gtw1-to-gtw2-pubIP1 -ResourceGroupName $rgName
  $conn2=Get-AzVirtualNetworkGatewayConnection -Name gtw1-to-gtw2-pubIP2 -ResourceGroupName $rgName
  
  $connName1=$conn1.Name
  $connName2=$conn2.Name
  $ingress1=$conn1.IngressBytesTransferred
  $ingress2=$conn2.IngressBytesTransferred
  $tmp1=(" - " +"Connection: $connName1, byteIngress: $ingress1").ToString() 
  $tmp2=(" - " +"Connection: $connName2, byteIngress: $ingress2").ToString() 
  $str1=[DateTime]::Now.ToString("yyyyMMdd-HH:mm:ss")+$tmp1
  $str2=[DateTime]::Now.ToString("yyyyMMdd-HH:mm:ss")+$tmp2
  Out-File -FilePath $logFile -Append -inputobject $str1
  Out-File -FilePath $logFile -Append -inputobject $str2
  write-host $str1 -ForegroundColor Green
  write-host $str2 -ForegroundColor Green
  
} while($i -ne 10) 

