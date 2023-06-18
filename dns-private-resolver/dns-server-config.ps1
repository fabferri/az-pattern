Try {
    Write-Host "Opening ICMPv4 Port"
    Get-NetFirewallRule -Name Allow_ICMPv4_in -ErrorAction Stop | Out-Null
    Write-Host "$(Get-Date) - ICMP Port is opened"
}
Catch {
    New-NetFirewallRule -DisplayName "Allow ICMPv4" -Name Allow_ICMPv4_in -Action Allow -Enabled True -Profile Any -Protocol ICMPv4 | Out-Null
    Write-Host "$(Get-Date) - ICMP Port aready opened"
}

$status = (Get-WindowsFeature -Name DNS).Installed
if ($status -eq $false) {
    Install-WindowsFeature -Name DNS -IncludeManagementTools
}

# check the status of the DNS service
$statusDNS = (get-service DNS).Status
if ( $statusDNS -eq 'Stopped') {
    try {
        Write-Host "$(Get-Date) - starting the DNS service"
        Start-Service DNS -ErrorAction Stop
    }
    catch {
        Write-Host "$(Get-Date) - issue to start the DNS service"
    }
}

# get the IPv4 address of the VM
$IPdns = (Get-NetIPAddress -InterfaceAlias Ethernet -AddressFamily IPv4 -Type Unicast).IPAddress

#setting in the DNS server as listen address the local IPv4
If ($null -ne $IPdns) {
    $DnsServerSettings = Get-DnsServerSetting -ALL
    $DnsServerSettings.ListeningIpAddress = @($IPdns)
    # commit the setting
    Set-DNSServerSetting $DnsServerSettings
}

############## uncomment the line below to enable DNS IP forwarder
#if ($null -eq ((get-DnsServerForwarder).IPAddress.IPAddressToString) ) {
#    try {
#        Write-Host "$(Get-Date) - configure IP forwarders"
#        # configure forwarder
#        $Forwarders = '1.1.1.1'
#        Set-DnsServerForwarder -IPAddress  $Forwarders -ErrorAction Stop
#    }
#    catch {
#        Write-Host "$(Get-Date) - issue to setting the forwarder"
#    }
#}
############## 

Try {
    #add conditional forwarder
    Add-DnsServerConditionalForwarderZone -Name privatelink.blob.core.windows.net -MasterServers "10.100.10.4" -ErrorAction Stop
}
catch {
    Write-Host "$(Get-Date) - conditional forwarding zone alreay exists"
}

try {
    # creates the non integrated zone using the first server as the primary server 
    Add-DnsServerPrimaryZone -Name "contoso.com" -DynamicUpdate None -ZoneFile "contoso.com.dns" -ErrorAction Stop
}
catch {
    Write-Host "$(Get-Date) - primary zone alreay exists"
}

try {
    # add A record for vm2
    Add-DnsServerResourceRecord -ZoneName "contoso.com" -A -Name "vm2" -IPv4Address "10.200.0.5" -ErrorAction Stop
}
catch {
    Write-Host "$(Get-Date) - A record for vm2 alreay exists"
}

try {
    #Create a file-backed reverse lookup zone
    Add-DnsServerPrimaryZone -NetworkID 10.200.0.0/24 -ZoneFile "0.200.10.in-addr.arpa.dns" -ErrorAction Stop
}
catch {
    Write-Host "$(Get-Date) - reverse lookup zone: '0.200.10.in-addr.arpa.dns' already exist"
}

try {
    #To add a PTR record to the Reverse Lookup Zone
    Add-DnsServerResourceRecordPtr -Name "5" -ZoneName "0.200.10.in-addr.arpa" -AllowUpdateAny -TimeToLive 01:00:00 -AgeRecord -PtrDomainName "vm2.contoso.com" -ErrorAction Stop
}
catch {
    Write-Host "$(Get-Date) - PTR to reverse lookup zonefor vm2 already exist"
}

try {
    # add A record for the DNS server
    Add-DnsServerResourceRecord -ZoneName "contoso.com" -A -Name "dns2" -IPv4Address "10.200.0.10" -ErrorAction Stop
}
catch {
    Write-Host "$(Get-Date) - A record for dns2 alreay exists"
}