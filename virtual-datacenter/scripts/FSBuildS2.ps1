# File Server Scale Set VM Post-Deploy Build Script
#
# 1. Open Firewall for ICMP
# 2. Add additional local Admin accounts
# 3. Install and Configure IIS
# 4. Test/Create Folders
# 5. Write out Rand.txt
# 6. Set Permissions on share
# 7. Create network share
#

Param(
[Parameter()]
[string]$User1,
[string]$Pass1,
[string]$User2,
[string]$Pass2
)

Start-Transcript -Path "C:\Workshop\MaxFSBuildS2.log"

# 1. Open Firewall for ICMP
Write-Host "Opening ICMPv4 Port"
Try {Get-NetFirewallRule -Name Allow_ICMPv4_in -ErrorAction Stop | Out-Null
     Write-Host "Port already open"}
Catch {New-NetFirewallRule -DisplayName "Allow ICMPv4" -Name Allow_ICMPv4_in -Action Allow -Enabled True -Profile Any -Protocol ICMPv4 | Out-Null
       Write-Host "Port opened"}

# 2. Add additional local Admin accounts
# Add additional local Admin accounts
$userList = @{}
# if $User1 and $Pass1 are not null, then add to the hash $userList
if (-not ([string]::IsNullOrEmpty($User1) -or [string]::IsNullOrEmpty($Pass1) )) {
  $userList.Add($User1, $Pass1)    
}
# if $User2 and $Pass2 are not null, then add to the hash $userList
if (-not ([string]::IsNullOrEmpty($User2) -or [string]::IsNullOrEmpty($Pass2) )) {
  $userList.Add($User2, $Pass2)
}

if ($userList.Count -gt 0) {
  write-host $userList
  foreach ($User in $userList.Keys) {
    Write-Host "Adding $User"
    $secPass = ConvertTo-SecureString $userList[$User] -AsPlainText -Force
    try {
      Get-LocalUser -Name $User -ErrorAction Stop | Out-Null
      Write-Host "  $User exists, skipping"
    }
    catch {
      New-LocalUser -Name $User -Password $secPass -FullName $User -AccountNeverExpires -PasswordNeverExpires | Out-Null
      Write-Host "  $User created"
    }
    try {
      Get-LocalGroupMember -Group 'Administrators' -Member $User -ErrorAction Stop | Out-Null
      Write-Host "  $User already an admin, skipping"
    }
    catch {
      Add-LocalGroupMember -Group 'Administrators' -Member $User | Out-Null
      Write-Host "  $User added the Administrators group"
    }
  }
}

# 3. Install IIS
Write-Host "Installing IIS and .Net 4.5, this can take some time, around 5+ minutes..." -ForegroundColor Cyan
Add-WindowsFeature Web-Server, Web-Mgmt-Console, Web-Asp-Net45


# Configure IIS
$WebConfig ='<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <defaultDocument>
      <files>
        <add value="Rand.txt" />
      </files>
    </defaultDocument>
  </system.webServer>
</configuration>'
$WebConfig | Out-File -FilePath "C:\inetpub\wwwroot\Web.config" -Encoding ascii

# 4. Test/Create Folders
Write-Host "Creating required folder"
$Dirs = @()
$Dirs += "C:\WebShare"
$Dirs += "C:\inetpub\wwwroot"
foreach ($Dir in $Dirs) {
    If (-not (Test-Path -Path $Dir)) {New-Item $Dir -ItemType Directory | Out-Null}
}

# 5. Write out Rand.txt
$FileContent = "Hello, I'm the contents of a remote file on $env:computername."
$Dirs = @()
$Dirs += "C:\WebShare"
$Dirs += "C:\inetpub\wwwroot"
foreach ($Dir in $Dirs) {
    $FileContent | Out-File -FilePath "$Dir\Rand.txt" -Encoding ascii
}


# 6. Set Permissions on share
$Acl = Get-Acl "C:\WebShare"
$AccessRule = New-Object system.security.accesscontrol.filesystemaccessrule("Everyone","ReadAndExecute, Synchronize","ContainerInherit, ObjectInherit","InheritOnly","Allow")
$Acl.SetAccessRule($AccessRule)
Set-Acl "C:\WebShare" $Acl

# 7. Create network share
Net Share WebShare=C:\WebShare "/grant:Everyone,READ"

# End Nicely
Write-Host "File Server Set up Successfull!"
Stop-Transcript