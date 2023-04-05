# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format.
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' property is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"

# value of variables locally assigned
#$rgName = 'plink-consumer'
#$targetIPPrimary = '10.0.5.4'
#$targetIPSecondary = '10.0.5.5'
#$dnsArecordName = 'ep'

# values from environment variables
$rgName = $env:rgName
$targetIPPrimary = $env:targetIPPrimary
$targetIPSecondary = $env:targetIPSecondary
$dnsArecordName = $env:dnsArecordName


$ListVM=(get-azvm -ResourceGroupName $rgName )| Select-Object -Property Name
Write-Host $ListVM
# Exit

Function DNS_A_RecordUpdate(){
    param(
      [string]$rgName, 
      [string]$targetIP,
      [string]$dnsArecordName
    )
$RecordSet = Get-AzPrivateDnsRecordSet -ResourceGroupName $rgName -ZoneName mydom.net -Name $dnsArecordName -RecordType A
$list = (Get-AzPrivateDnsRecordSet -ResourceGroupName $rgName -ZoneName mydom.net -Name $dnsArecordName -RecordType A).Records
if ( ($list.Count -eq 1) -and  ($list.Ipv4Address.Equals($targetIP)) )
{
    write-host 'no A record update- IP:'$targetIP
    Exit
}
foreach ($rec in $list)
{
   write-host $rec
   Remove-AzPrivateDnsRecordConfig -RecordSet $RecordSet -Ipv4Address $rec
} 
Add-AzPrivateDnsRecordConfig -Ipv4Address $targetIP -RecordSet $RecordSet
Set-AzPrivateDnsRecordSet -RecordSet $RecordSet
}



$urlPrimary = "http://" + $targetIPPrimary
$urlSecondary = "http://"+ $targetIPSecondary

$StatusCodePrimary = $null
try {
    $WebResponse = Invoke-WebRequest -uri $urlPrimary -UseBasicParsing -TimeoutSec 5  -ErrorAction Stop
    $StatusCodePrimary = $WebResponse.StatusCode
    write-host 'primary web site - status code: '$StatusCode
    DNS_A_RecordUpdate $rgName $targetIPPrimary $dnsArecordName
}
catch {
    write-host 'site NOT reachable' -ForegroundColor Yellow
    #$Error[0].Exception
    $StatusCodePrimary = ($_.Exception.Response.StatusCode.Value__)
    Write-Output "primary web - Status Code :"$StatusCodePrimary
    Write-Output "primary web site not reachable- switchover to secondary"

    try {
       $WebResponse = Invoke-WebRequest -uri $urlSecondary -UseBasicParsing -TimeoutSec 5  -ErrorAction Stop
       $StatusCodeSecondary = $WebResponse.StatusCode
       write-host 'secondary web site - status code: '$StatusCodeSecondary
       DNS_A_RecordUpdate $rgName $targetIPSecondary $dnsArecordName
    }
    catch {
       write-host 'secondary web site NOT reachable' 
       #$Error[0].Exception
       $StatusCodeSecondary = ($_.Exception.Response.StatusCode.Value__)
       Write-Output "secondary web site - Status Code :"$StatusCodeSecondary
       Write-Output "you cannnot apply the switchover - service failure"
    }
}
