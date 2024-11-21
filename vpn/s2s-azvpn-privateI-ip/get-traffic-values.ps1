#
# Script to get the the Byte in/Byte out associated with the connections
#
$initFile = "init.txt"
####################################################
$pathFiles = Split-Path -Parent $PSCommandPath

#Reading the resource group name from the file init.txt
If (Test-Path -Path $pathFiles\$initFile) {
    Get-Content $pathFiles\$initFile | Foreach-Object {
        $var = $_.Split('=')
        Try { New-Variable -Name $var[0].Trim() -Value $var[1].Trim() -ErrorAction Stop }
        Catch { if ($var[0] -ne "") { Set-Variable -Name $var[0].Trim() -Value $var[1].Trim() } }
    }
}
Else { Write-Warning "$initFile file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }
if (!$ResourceGroupName) { Write-Host "variable $ResourceGroupName is null"; Exit }
$rgName = $ResourceGroupName
write-host  "reading Resource Group name $ResourceGroupName from the file init.txt " -ForegroundColor yellow

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
  # counters are updated every 5 minutes
  Start-Sleep -Seconds 30
} while($i -ne 10) 

