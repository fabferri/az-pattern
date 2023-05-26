# IIS Server Post Build Config Script

Param(
[Parameter()]
[string]$User1,
[string]$Pass1,
[string]$User2,
[string]$Pass2,
[string]$PEPName)

Write-Host "PEPName: $PEPName"

# Turn On ICMPv4
Write-Host "Opening ICMPv4 Port"
Try {Get-NetFirewallRule -Name Allow_ICMPv4_in -ErrorAction Stop | Out-Null
     Write-Host "Port already open"}
Catch {New-NetFirewallRule -DisplayName "Allow ICMPv4" -Name Allow_ICMPv4_in -Action Allow -Enabled True -Profile Any -Protocol ICMPv4 | Out-Null
       Write-Host "Port opened"}

# Add additional Local Admins
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

# Install IIS
Write-Host "Installing IIS and .Net 4.5, this can take some time, around 5+ minutes..." -ForegroundColor Cyan
Add-WindowsFeature Web-Server, Web-Mgmt-Console, Web-Asp-Net45

# Create Web App PagesWeb
Write-Host "Creating Web page and Web.Config file" -ForegroundColor Cyan
$ServerName = "$env:COMPUTERNAME"
$MainPage = '<%@ Page Language="vb" AutoEventWireup="false" %>
<%@ Import Namespace="System.IO" %>
<script language="vb" runat="server">
  Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
  '' Test Endpoints (Private EP)
   
    Dim urlPvEP as String = "' + $PEPName + '.privatelink.web.core.windows.net"
    Dim IsEndPointReady as Boolean = False
    Dim testSocket as New System.Net.Sockets.TcpClient()
    Dim i as Integer
    
    '' Test Private Endpoint
    testSocket = New System.Net.Sockets.TcpClient()
    testSocket.ConnectAsync(urlPvEP, 80)
    Do While Not testSocket.Connected
      Threading.Thread.Sleep(250)
      i=i+1
      If i >= 12 Then Exit Do '' Wait 3 seconds and exit
    Loop
    IsEndPointReady = testSocket.Connected.ToString()
    testSocket.Close

    '' Get Private Endpoint File Server File
    If IsEndPointReady Then
      Dim objHttp = CreateObject("WinHttp.WinHttpRequest.5.1")
      objHttp.Open("GET", "http://' + $PEPName + '.privatelink.web.core.windows.net", False)
      objHttp.Send
      lblEndPoint.Text = objHttp.ResponseText
      objHttp = Nothing
    Else
      lblEndPoint.Text = "<font color=red>Content not reachable, this resource is created in Module 6.</font>"
    End if

    '' Add Server Name and Time
    lblName.Text = "' + $ServerName + '"
    lblTime.Text = Now()
  End Sub
</script>

<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
  <title>Maximus Workshop App Gateway Site</title>
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
        <li> Local Server Time - Shows if this page is or isnt cached anywhere</li>
        <li> Private Endpoint - Retrieves contents of a file in the storage account behind the Private Endpoint created in Module 6</li>
        <li> Image from the Internet - Doesn''t really show anything, but it makes me happy to see this when everything works</li>
      </ul>
      <div style="border: 2px solid #8AC007; border-radius: 25px; padding: 20px; margin: 10px; width: 650px;">
        <b>Serving from Server</b>: <asp:Label runat="server" ID="lblName" /></div>
      <div style="border: 2px solid #8AC007; border-radius: 25px; padding: 20px; margin: 10px; width: 650px;">
        <b>Local Web Server Time</b>: <asp:Label runat="server" ID="lblTime" /></div>
      <div style="border: 2px solid #8AC007; border-radius: 25px; padding: 20px; margin: 10px; width: 650px;">
        <b>Private Endpoint</b>: <asp:Label runat="server" ID="lblEndPoint" /></div>
      <div style="border: 2px solid #8AC007; border-radius: 25px; padding: 20px; margin: 10px; width: 650px;">
        <b>Image File Linked from the Internet</b>:<br />
        <br />
        <img src="http://sd.keepcalm-o-matic.co.uk/i/keep-calm-you-made-it-7.png" alt="You made it!" width="150" length="175"/></div>
    </div>
  </form>
</body>
</html>'

$WebConfig ='<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.web>
    <compilation debug="true" strict="false" explicit="true" targetFramework="4.8" />
    <httpRuntime targetFramework="4.8" />
    <identity impersonate="true" />
    <customErrors mode="Off"/>
  </system.web>
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

# Set App Pool to Clasic Pipeline to remote file access will work easier
Write-Host "Updaing IIS Settings" -ForegroundColor Cyan
c:\windows\system32\inetsrv\appcmd.exe set app "Default Web Site/" /applicationPool:".NET v4.5 Classic"
c:\windows\system32\inetsrv\appcmd.exe set config "Default Web Site/" /section:system.webServer/security/authentication/anonymousAuthentication  /userName:$User1 /password:$Pass1 /commit:apphost

# Make sure the IIS settings take
Write-Host "Restarting the W3SVC" -ForegroundColor Cyan
Restart-Service -Name W3SVC

Write-Host
Write-Host "Web App Creation Successfull!" -ForegroundColor Green
Write-Host