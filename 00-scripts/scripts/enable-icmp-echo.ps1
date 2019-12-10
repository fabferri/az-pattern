# Turn On ICMPv4
Try {
    Get-NetFirewallRule -DisplayName "Allow ICMPv4" -ErrorAction Stop | Out-Null
    Write-Host "Port already open"
}
Catch {
    New-NetFirewallRule -Name "allow_ICMPv4_in" -DisplayName "Allow ICMPv4" -Direction Inbound -Action Allow -Enabled True -Profile Any -Protocol ICMPv4 | Out-Null
    Write-Host "Port opened"
}

# Turn On ICMPv6
Try {
    Get-NetFirewallRule -DisplayName "Allow ICMPv6" -ErrorAction Stop | Out-Null
    Write-Host "Port already open"
}
Catch {
    New-NetFirewallRule -Name "allow_ICMPv6_in" -DisplayName "Allow ICMPv6" -Direction Inbound -Action Allow -Enabled True -Profile Any -Protocol ICMPv6 | Out-Null
    Write-Host "Port opened"
}


# Turn off IE Enhanced security configuration
$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
Stop-Process -Name Explorer

# Enable incoming traffic for iperf3
Try {
    Get-NetFirewallRule -DisplayName "Allow iperf" -ErrorAction Stop | Out-Null
    Write-Host "Port already open"
}
Catch {
New-NetFirewallRule -Name "allow_iperf_in" -DisplayName "Allow iperf" -Direction Inbound -Action Allow -Enabled True -Profile Any -Protocol TCP -LocalPort 5200-5300 | Out-Null
    Write-Host "Port opened"
}
