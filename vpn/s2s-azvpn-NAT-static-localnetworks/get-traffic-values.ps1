#
# Script to get the the Byte in/Byte out associated with the connections
#
$inputParams = 'init.json'

$pathFiles = Split-Path -Parent $PSCommandPath
$fileName = "log" + [DateTime]::Now.ToString("yyyyMMdd-HHmmss") + ".txt"
$logFile = "$pathFiles\$fileName"


# reading the input parameter file $inputParams and convert the values in hashtable 
If (Test-Path -Path $pathFiles\$inputParams) {
  # convert the json into PSCustomObject
  $jsonObj = Get-Content -Raw $pathFiles\$inputParams | ConvertFrom-Json
  if ($null -eq $jsonObj) {
    Write-Host "file $inputParams is empty"
    Exit
  }
  # convert the PSCustomObject in hashtable
  if ($jsonObj -is [psobject]) {
    $hash = @{}
    foreach ($property in $jsonObj.PSObject.Properties) {
      $hash[$property.Name] = $property.Value
    }
  }
  foreach ($key in $hash.keys) {
    $message = '{0} = {1} ' -f $key, $hash[$key]
    # Write-Output $message
    Try { New-Variable -Name $key -Value $hash[$key] -ErrorAction Stop }
    Catch { Set-Variable -Name $key -Value $hash[$key] }
  }
} 
else { Write-Warning "$inputParams file not found, please change to the directory where these scripts reside ($pathFiles) and ensure this file is present."; Return }

# checking the values of variables
Write-Host "$(Get-Date) - values from file: $inputParams" -ForegroundColor Yellow
if (!$subscriptionName) { Write-Host 'variable $subscriptionName is null' ; Exit }   else { Write-Host '   subscription name.....: '$subscriptionName -ForegroundColor Yellow }
if (!$ResourceGroupName) { Write-Host 'variable $ResourceGroupName is null' ; Exit } else { Write-Host '   resource group name...: '$ResourceGroupName -ForegroundColor Yellow }
$rgName = $ResourceGroupName

$subscr = Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$i = 0
do {
  $i++
  $conn1 = Get-AzVirtualNetworkGatewayConnection -Name gtw1IP1-to-gtw2IP1 -ResourceGroupName $rgName
  $conn2 = Get-AzVirtualNetworkGatewayConnection -Name gtw1IP2-to-gtw2IP2 -ResourceGroupName $rgName
  $conn3 = Get-AzVirtualNetworkGatewayConnection -Name gtw1IP1-to-gtw3IP1 -ResourceGroupName $rgName
  $conn4 = Get-AzVirtualNetworkGatewayConnection -Name gtw1IP2-to-gtw3IP2 -ResourceGroupName $rgName

  $conn5 = Get-AzVirtualNetworkGatewayConnection -Name gtw2IP1-to-gtw1IP1 -ResourceGroupName $rgName
  $conn6 = Get-AzVirtualNetworkGatewayConnection -Name gtw2IP2-to-gtw1IP2 -ResourceGroupName $rgName
  $conn7 = Get-AzVirtualNetworkGatewayConnection -Name gtw3IP1-to-gtw1IP1 -ResourceGroupName $rgName
  $conn8 = Get-AzVirtualNetworkGatewayConnection -Name gtw3IP2-to-gtw1IP2 -ResourceGroupName $rgName



  $connName1 = $conn1.Name
  $connName2 = $conn2.Name
  $connName3 = $conn3.Name
  $connName4 = $conn4.Name
  $connName5 = $conn5.Name
  $connName6 = $conn6.Name
  $connName7 = $conn7.Name
  $connName8 = $conn8.Name

  $ingress1 = $conn1.IngressBytesTransferred
  $ingress2 = $conn2.IngressBytesTransferred
  $ingress3 = $conn3.IngressBytesTransferred
  $ingress4 = $conn4.IngressBytesTransferred
  $ingress5 = $conn5.IngressBytesTransferred
  $ingress6 = $conn6.IngressBytesTransferred
  $ingress7 = $conn7.IngressBytesTransferred
  $ingress8 = $conn8.IngressBytesTransferred
  $egress1 = $conn1.EgressBytesTransferred
  $egress2 = $conn2.EgressBytesTransferred
  $egress3 = $conn3.EgressBytesTransferred
  $egress4 = $conn4.EgressBytesTransferred
  $egress5 = $conn5.EgressBytesTransferred
  $egress6 = $conn6.EgressBytesTransferred
  $egress7 = $conn7.EgressBytesTransferred
  $egress8 = $conn8.EgressBytesTransferred

  $tmp1 = (" - " + "Connection: $connName1, byteIngress: $ingress1, byteEgress: $egress1").ToString()
  $tmp2 = (" - " + "Connection: $connName2, byteIngress: $ingress2, byteEgress: $egress2").ToString()
  $tmp3 = (" - " + "Connection: $connName3, byteIngress: $ingress3, byteEgress: $egress3").ToString()
  $tmp4 = (" - " + "Connection: $connName4, byteIngress: $ingress4, byteEgress: $egress4").ToString()
  $tmp5 = (" - " + "Connection: $connName5, byteIngress: $ingress5, byteEgress: $egress5").ToString()
  $tmp6 = (" - " + "Connection: $connName6, byteIngress: $ingress6, byteEgress: $egress6").ToString()
  $tmp7 = (" - " + "Connection: $connName7, byteIngress: $ingress7, byteEgress: $egress7").ToString()
  $tmp8 = (" - " + "Connection: $connName8, byteIngress: $ingress8, byteEgress: $egress8").ToString()
  $tmp9 = "---------------------------------------------------"

  $str1 = [DateTime]::Now.ToString("yyyyMMdd-HH:mm:ss") + $tmp1
  $str2 = [DateTime]::Now.ToString("yyyyMMdd-HH:mm:ss") + $tmp2
  $str3 = [DateTime]::Now.ToString("yyyyMMdd-HH:mm:ss") + $tmp3
  $str4 = [DateTime]::Now.ToString("yyyyMMdd-HH:mm:ss") + $tmp4
  $str5 = [DateTime]::Now.ToString("yyyyMMdd-HH:mm:ss") + $tmp5
  $str6 = [DateTime]::Now.ToString("yyyyMMdd-HH:mm:ss") + $tmp6
  $str7 = [DateTime]::Now.ToString("yyyyMMdd-HH:mm:ss") + $tmp7
  $str8 = [DateTime]::Now.ToString("yyyyMMdd-HH:mm:ss") + $tmp8
  $str9 = $tmp9
  Out-File -FilePath $logFile -Append -inputobject $str1
  Out-File -FilePath $logFile -Append -inputobject $str2
  Out-File -FilePath $logFile -Append -inputobject $str3
  Out-File -FilePath $logFile -Append -inputobject $str4
  Out-File -FilePath $logFile -Append -inputobject $str5
  Out-File -FilePath $logFile -Append -inputobject $str6
  Out-File -FilePath $logFile -Append -inputobject $str7
  Out-File -FilePath $logFile -Append -inputobject $str8
  Out-File -FilePath $logFile -Append -inputobject $str9
  write-host $str1 -ForegroundColor Magenta
  write-host $str2 -ForegroundColor Magenta
  write-host $str3 -ForegroundColor Green
  write-host $str4 -ForegroundColor Green
  write-host $str5 -ForegroundColor Yellow
  write-host $str6 -ForegroundColor Yellow
  write-host $str7 -ForegroundColor Cyan
  write-host $str8 -ForegroundColor Cyan
  write-host $str9 -ForegroundColor White

  Start-Sleep -Seconds 20
} while ($i -ne 10) 

