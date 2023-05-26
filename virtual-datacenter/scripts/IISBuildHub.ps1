# IIS Server Post Build Config Script

Param(
[Parameter()]
[string]$User1,
[string]$Pass1,
[string]$User2,
[string]$Pass2)

# Turn On ICMPv4
Write-Host "Opening ICMPv4 Port"
Try {Get-NetFirewallRule -Name Allow_ICMPv4_in -ErrorAction Stop | Out-Null
     Write-Host "Port already open"}
Catch {New-NetFirewallRule -DisplayName "Allow ICMPv4" -Name Allow_ICMPv4_in -Action Allow -Enabled True -Profile Any -Protocol ICMPv4 | Out-Null
       Write-Host "Port opened"}
# Add additional local Admin accounts
$userList = @{
  $User1 = $Pass1
  $User2 = $Pass2
  }
foreach ($User in $userList.Keys) {
     Write-Host "Adding $User"
     $secPass = ConvertTo-SecureString $userList[$User] -AsPlainText -Force
     try {Get-LocalUser -Name $User -ErrorAction Stop | Out-Null
          Write-Host "$User exists, skipping"}
     catch {New-LocalUser -Name $User -Password $secPass -FullName $User -AccountNeverExpires -PasswordNeverExpires | Out-Null
            Write-Host "$User created"}
     try {Get-LocalGroupMember -Group 'Administrators' -Member $User -ErrorAction Stop | Out-Null
          Write-Host "$User already an admin, skipping"}
     catch {Add-LocalGroupMember -Group 'Administrators' -Member $User | Out-Null
            Write-Host "$User added the Administrators group"}
}

# Install IIS and NPS
Write-Host "Installing IIS" -ForegroundColor Cyan
Install-WindowsFeature Web-Server,Web-Asp-Net45

# Create Web App PagesWeb
Write-Host "Creating Web page and Web.Config file" -ForegroundColor Cyan
$ServerName = "$env:COMPUTERNAME"
$MainPage = '<%@ Page Language="vb" AutoEventWireup="false" %>
<%@ Import Namespace="System.IO" %>
<script language="vb" runat="server">
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        lblTime.Text = Now()
        lblName.Text = "' + $ServerName + '"
    End Sub
</script>

<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>Maximus Workshop Hub Site</title>
</head>
<body style="font-family: Optima,Segoe,Segoe UI,Candara,Calibri,Arial,sans-serif;">
  <form id="frmMain" runat="server">
    <div>
      <h1>Looks like you made it!</h1>
      This is a page from the inside (a web server on a private network),<br />
      and it is making its way to the outside! (If you are viewing this from the internet)<br />
      <br />
      The following sections show:
      <ul style="margin-top: 0px;">
        <li> Serving Server - Shows server name, indicating location of the actual server</li>
        <li> Local Server Time - Shows if this page is or isnt cached anywhere</li>
        <li> Image from the Internet - Doesn''t really show anything, but it made me happy to see this when the app worked</li>
      </ul>
      <div style="border: 2px solid #8AC007; border-radius: 25px; padding: 20px; margin: 10px; width: 650px;">
        <b>Serving from Server</b>: <asp:Label runat="server" ID="lblName" /></div>
      <div style="border: 2px solid #8AC007; border-radius: 25px; padding: 20px; margin: 10px; width: 650px;">
        <b>Local Web Server Time</b>: <asp:Label runat="server" ID="lblTime" /></div>
      <div style="border: 2px solid #8AC007; border-radius: 25px; padding: 20px; margin: 10px; width: 650px;">
        <b>Image File Linked from the Internet (from your browser)</b>:<br />
        <br />
        <img src="http://sd.keepcalm-o-matic.co.uk/i/keep-calm-you-made-it-7.png" alt="You made it!" width="150" length="175"/></div>
    </div>
  </form>
</body>
</html>'

$WebConfig ='<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <defaultDocument>
      <files>
        <add value="Home.aspx" />
      </files>
    </defaultDocument>
  </system.webServer>
</configuration>'

$MainPage | Out-File -FilePath "C:\inetpub\wwwroot\Home.aspx" -Encoding ascii
$WebConfig | Out-File -FilePath "C:\inetpub\wwwroot\Web.config" -Encoding ascii

# Make sure the IIS settings take
Write-Host "Restarting the W3SVC" -ForegroundColor Cyan
Restart-Service -Name W3SVC

Write-Host
Write-Host "Web App Creation Successfull!" -ForegroundColor Green
Write-Host