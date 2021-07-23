###
### Script to register an IoT device
###
###
### $rgName....: name of resource group with IoT hub deployment
### $fileName..: name of file to store the connection string
###
$rgName='iot-1'
$fileName='connstring.txt'
$deviceId='dotnetDev1'

try {
  Get-AzResourceGroup -Name $rgName -ErrorAction Stop
} 
catch {
  write-host "Resource group: $rgName not found" -ForegroundColor Yellow
  Exit
}

try {
  $iothub=Get-AzIotHub -ResourceGroupName $rgName -ErrorAction Stop
  if ([string]::IsNullOrWhiteSpace($iothub))
  {
    write-host "IoT hub not found in the resource group $rgName" -ForegroundColor Yellow
    Exit
  }
}
catch{
  write-host "issue to find out the IoT hub" -ForegroundColor Yellow
  Exit
}

#Create an edge enabled IoT device with default authorization (shared private key).
try {
  $dev=Get-AzIotHubDevice -ResourceGroupName $rgName -IotHubName $iothub.Name -DeviceId $deviceId -ErrorAction Stop
  if ([string]::IsNullOrWhiteSpace($dev))
  {
    Add-AzIotHubDevice -ResourceGroupName $rgName -IotHubName $iothub.Name -DeviceId $deviceId -AuthMethod "shared_private_key" -EdgeEnabled
    Write-Host "device $deviceId added to the IoT hub:"$iothub.Name
  }
}
catch {
  write-host "issue to add a device to the IoT hub:"$iothub.Name
  Exit
}

# get the device connection string for the device you just registered
$connString=Get-AzIotHubDeviceConnectionString -ResourceGroupName $rgName -IotHubName $iothub.Name -DeviceId $deviceId
Write-Host "Connection string:  "$connString.ConnectionString -ForegroundColor Yellow


#write connection string to a file
$pathFiles = Split-Path -Parent $PSCommandPath
Set-Content -Path "$pathFiles\$fileName" -Value $connString.ConnectionString

$primaryKey=(get-AzIotHubKey -ResourceGroupName $rgName -Name $iothub.Name -KeyName service).PrimaryKey
Write-Host ""
Write-Host "eventHubEndpoints.events.endpoint:"$iothub.Properties.EventHubEndpoints.Values.Endpoint -ForegroundColor Green
Write-Host ""

Write-Host "eventHubEndpoints.events.path:"$iothub.Properties.EventHubEndpoints.Values.Path -ForegroundColor Green
write-host ""

Write-Host "service - primary key:"$primaryKey -ForegroundColor Green
write-host ""
