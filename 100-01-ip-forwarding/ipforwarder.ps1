# 
# powershell script to enable the ip forwarding on Windows 2016
#
#
Import-Module ServerManager
Add-WindowsFeature RemoteAccess, Routing, RSAT-RemoteAccess
Get-NetAdapter | Set-NetIPInterface -Forwarding Enabled
Set-Service RemoteAccess -StartupType Automatic
Start-Service RemoteAccess
