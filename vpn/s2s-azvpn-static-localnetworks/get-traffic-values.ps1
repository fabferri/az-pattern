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

  $connName1 = $conn1.Name
  $connName2 = $conn2.Name
  $connName3 = $conn3.Name
  $connName4 = $conn4.Name
  $ingress1 = $conn1.IngressBytesTransferred
  $ingress2 = $conn2.IngressBytesTransferred
  $ingress3 = $conn3.IngressBytesTransferred
  $ingress4 = $conn4.IngressBytesTransferred
  $egress1 = $conn1.EgressBytesTransferred
  $egress2 = $conn2.EgressBytesTransferred
  $egress3 = $conn3.EgressBytesTransferred
  $egress4 = $conn4.EgressBytesTransferred
  $tmp1 = (" - " + "Connection: $connName1, byteIngress: $ingress1, byteEgress: $egress1").ToString()
  $tmp2 = (" - " + "Connection: $connName2, byteIngress: $ingress2, byteEgress: $egress2").ToString()
  $tmp3 = (" - " + "Connection: $connName3, byteIngress: $ingress3, byteEgress: $egress3").ToString()
  $tmp4 = (" - " + "Connection: $connName4, byteIngress: $ingress4, byteEgress: $egress4").ToString()
  $tmp5 = "---------------------------------------------------"

  $str1 = [DateTime]::Now.ToString("yyyyMMdd-HH:mm:ss") + $tmp1
  $str2 = [DateTime]::Now.ToString("yyyyMMdd-HH:mm:ss") + $tmp2
  $str3 = [DateTime]::Now.ToString("yyyyMMdd-HH:mm:ss") + $tmp3
  $str4 = [DateTime]::Now.ToString("yyyyMMdd-HH:mm:ss") + $tmp4
  $str5 = $tmp5
  Out-File -FilePath $logFile -Append -inputobject $str1
  Out-File -FilePath $logFile -Append -inputobject $str2
  Out-File -FilePath $logFile -Append -inputobject $str3
  Out-File -FilePath $logFile -Append -inputobject $str4
  Out-File -FilePath $logFile -Append -inputobject $str5
  write-host $str1 -ForegroundColor Green
  write-host $str2 -ForegroundColor Green
  write-host $str3 -ForegroundColor Green
  write-host $str4 -ForegroundColor Green
  write-host $str5 -ForegroundColor Yellow

  Start-Sleep -Seconds 20
} while ($i -ne 10) 

