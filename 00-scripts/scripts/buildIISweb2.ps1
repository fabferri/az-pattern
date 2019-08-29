Param(
    [Parameter()]
    [string]$theAdmin,
    [string]$theSecret)

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

# Enable incoming traffic for iperf3
Try {
    Get-NetFirewallRule -DisplayName "Allow iperf" -ErrorAction Stop | Out-Null
    Write-Host "Port already open"
}
Catch {
New-NetFirewallRule -Name "allow_iperf_in" -DisplayName "Allow iperf" -Direction Inbound -Action Allow -Enabled True -Profile Any -Protocol TCP -LocalPort 5200-5300 | Out-Null
    Write-Host "Port opened"
}

# Install IIS
Write-Host "Installing IIS and .Net 4.5, this can take some time, around 5+ minutes..." -ForegroundColor Cyan
Install-WindowsFeature -Name @("Web-Server", "Web-WebServer", "Web-Common-Http", "Web-Default-Doc", "Web-Dir-Browsing", "Web-Http-Errors", "Web-Static-Content", "Web-Health", "Web-Http-Logging", "Web-Performance", "Web-Stat-Compression", "Web-Security", "Web-Filtering", "Web-App-Dev", "Web-ISAPI-Ext", "Web-ISAPI-Filter", "Web-Net-Ext", "Web-Net-Ext45", "Web-Asp-Net45", "Web-Mgmt-Tools", "Web-Mgmt-Console") 

# Turn off IE Enhanced security configuration
$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
Stop-Process -Name Explorer

# Create Web App PagesWeb
$MainPage = @"
<%@ Page Language="C#" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<script runat="server">
protected string GetTime()
{
    return DateTime.Now.ToString("h:mm:ss tt", System.Globalization.DateTimeFormatInfo.InvariantInfo);
}

protected string Getipv6()
{
  StringBuilder sb = new StringBuilder();
  string strHostName = System.Net.Dns.GetHostName();
  System.Net.IPHostEntry ipEntry = System.Net.Dns.GetHostEntry(strHostName);
  System.Net.IPAddress[] addr = ipEntry.AddressList;
  Console.WriteLine(addr[addr.Length-1].ToString());
  for (int i = 0; i <= addr.Length-1; i++)
   {  
        if (addr[i].AddressFamily == System.Net.Sockets.AddressFamily.InterNetworkV6)
        {
            sb.Append(addr[i].ToString()); 
            sb.Append("   ");
        }
   }
  return sb.ToString();
}

protected void Page_Load(object sender, EventArgs e)
  {
    StringBuilder sb = new StringBuilder();
    StringBuilder sb1 = new StringBuilder();
    sb.Append(Page.Request.UserHostAddress + "<br />");
    PageMessage.Text = sb.ToString();
    HostName.Text = System.Net.Dns.GetHostName().ToString();

    Application.Lock();
    if(Application["HitCount"]!=null)
      {
           Application["HitCount"]=(int)Application["HitCount"]+1;
           if ((int)Application["HitCount"] > (int.MaxValue-1000))
           {
              Application["HitCount"]=1;
           }
       }
    else
       {
            Application["HitCount"] =1;
       }
    Application.UnLock();
    sb1.Append( Application["HitCount"].ToString());
    lblInfo.Text=sb1.ToString();

    // get the IPv6 addresses and store in Repeter1
    System.Data.DataTable dt = new System.Data.DataTable();
    dt.Columns.Add("Names", Type.GetType("System.String"));
    string strHostName = System.Net.Dns.GetHostName();
    System.Net.IPHostEntry ipEntry = System.Net.Dns.GetHostEntry(strHostName);
    System.Net.IPAddress[] addr = ipEntry.AddressList;
    Console.WriteLine(addr[addr.Length-1].ToString());
    for (int i = 0; i <= addr.Length-1; i++)
    {  
         if (addr[i].AddressFamily == System.Net.Sockets.AddressFamily.InterNetworkV6)
         {
           dt.Rows.Add();
           dt.Rows[i]["Names"] = addr[i].ToString();
         }
    }
    dt.AcceptChanges();
    Repeater1.DataSource = dt;
    Repeater1.DataBind();   
  }
</script>


<html xmlns="http://www.w3.org/1999/xhtml" >
<head runat="server">
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
    <title>Web page Example</title>
<style type="text/css">

body {
  background-color: #F5F5F5;
  color: #555;
  text-align: left;
  font-size: 2em;
  font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
}
.text-1 {
  color: #eee;
  text-shadow: -1px 0 black, 0 1px black, 1px 0 black, 0 -1px black
}
.text-2 {
  color: white;
  text-shadow: 0.075em 0.08em 0.1em rgba(0, 0, 0, 1);
}
.text-3 {
  color: #54a;
  text-shadow: 0 0 0.5em #87F, 0 0 0.5em #87F, 0 0 0.5em #87F;
}
#border1 {
  border-width: 6px;
  border-style: solid;
  border-color: MediumBlue;
  padding: 20px;    
}

#grad1 {
  height: 80px;
  background-color: red; /* For browsers that do not support gradients */
  background-image: linear-gradient(OrangeRed 50%,white 90%) 

}
table, th, td {
  border: 1px solid black;
  border-collapse: collapse;
}
th, td {
  CELLPADDING: 0px;
}
</style>
</head>
<body>
<div id="grad1">
<h1 class="text text-2"> My Web - Test Page 2 </h1>
</div>
    <form id="form1" runat="server">
    <div id="grad1">
    <p class="text text-1">No. page counter: <asp:Label ID="lblInfo" runat="server" ForeColor="Yellow"></asp:Label></p>
    </div>
    <div id="border1"> <span style="color: Maroon">The current time is</span> <span style="color: Blue"><%=GetTime()%></span>.</div>
    <span style="color: Black">local hostname: </span><asp:Label id="HostName" runat="server" ForeColor="Blue"/> <br>
    <span style="color: Black"> local IPV6: </span>
    <asp:Repeater ID = "Repeater1" runat = "server" >
      <ItemTemplate >
        <table style="font-size:30px; width:50%;border: .01em solid #000000;table-layout: fixed; padding-left: 10px; padding-right: 10px;">
          <tr>
              <td style ="color:Red"><%# Eval("Names")%></td>
          </tr>
         </table>
       </ItemTemplate>
    </asp:Repeater>
    <br><span style="color: Black">remote host address: </span><asp:Label id="PageMessage" runat="server" ForeColor= "Red"/>
    </form>
</body>
</html>
"@

# Create Web Config
$WebConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.web>
    <compilation debug="true" strict="false" explicit="true" targetFramework="4.5" />
    <httpRuntime targetFramework="4.5" />
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
</configuration>
"@

$MainPage | Out-File -FilePath "C:\inetpub\wwwroot\Home.aspx" -Encoding ascii
$WebConfig | Out-File -FilePath "C:\inetpub\wwwroot\Web.config" -Encoding ascii

# Set App Pool to Clasic Pipeline to remote file access will work easier
Write-Host "Updaing IIS Settings" -ForegroundColor Cyan
c:\windows\system32\inetsrv\appcmd.exe set app "Default Web Site/" /applicationPool:".NET v4.5 Classic"
c:\windows\system32\inetsrv\appcmd.exe set config "Default Web Site/" /section:system.webServer/security/authentication/anonymousAuthentication  /userName:$theAdmin /password:$theSecret /commit:apphost

# Make sure the IIS settings take
Write-Host "Restarting the W3SVC" -ForegroundColor Cyan
Restart-Service -Name W3SVC

Write-Host
Write-Host "Web App Creation Successfull!" -ForegroundColor Green
Write-Host
