<properties
pageTitle= 'Point-to-Site VPN configuration'
description= "Point-to-Site VPN configuration"
documentationcenter: na
services=""
documentationCenter="na"
authors="fabferri"
editor="fabferri"/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="na"
   ms.date="15/04/2024"
   ms.author="fabferri" />

# Workshop: Point-to-Site VPN configuration
This post contains ARM templates and scripts to create Point-to-Site VPN connection between an Azure VPN client and the Azure VPN  gateway. <br>
The materials reported in this post can be used in a workshop for a fast deployment, minimizing the manual steps. <br>
The final network configuration is reported in the diagram:

[![1]][1]

The setup to have a full working environment is organized in a sequence of steps. <br> 


### <a name="File list"></a>2. File list

| File name                | Description                                                           |
| ------------------------ | --------------------------------------------------------------------- |
| **init.json**            | define the value of input variables required for the full deployment  |
| **01-wincert-VM.json**   | ARM template to deploy a Windows Server 2022 VM and generate a self-signed root certificate |
| **01-wincert-VM.ps1**    | powershell script to run **01-wincert-VM.json**                                             |
| **02-vpn.json**          | ARM template to create an Azure vnet and Azure VPN Gateway                                  |
| **02-vpn.ps1**           | powershell script to run **02-vpn.json**                                                    |
| **03-downloadClientProfile.ps1** | powershell to script to download from the Azure VPN Gateway the  P2S VPN client user profile | 
| **04-az-clientVM.json**  | ARM template to create a new vnet (client vnet) a Windows 11 VM. This VM will be used to connect in P2S to the VPN Gateway |
| **04-az-clientVM.json**  | powershell to script to run **04-az-clientVM.json**                  |
| **createSelfSignCertificates.ps1** | powershell script to create self-signed root certificate and client certificate. <br> It is used in ARM template with powershell script extension|
| **downloadClientCert.ps1** | script to download from the storage account the client certificate and P2S user profile |

Download all the project files in you local host (desktop/laptop) to change the values of variables and run the full deployment.  

`NOTE` <br>
Before deploying the ARM template you should customize the value of variables in the **init.json** file. Below the meaning of the variables in the **init.json**:
```json
{
    "subscriptionName": "NAME_FO_THE_AZURE_SUBSCRIPTION",
    "rgNameCert": "RESOURCE_GROUP_NAME_WITH_VM_TO_GENERATE_ROOT_AND_CLIENT_CERTIFICATE",
    "rgNameVPN": "RESOURCE_GROUP_NAME_OF_VPN_GATEWAY",
    "vpnGtwName": "NAME_OF_THE_VPN_GATEWAY",
    "rgNameClient": "RESOURCE_GROUP_NAME_OF_THE_CLIENT",
    "location": "NAME_OF_THE_AZURE_REGION",
    "adminUsername": "ADMINISTRATOR_USERNAME_OF_THE_AZURE_VMs",
    "adminPassword": "ADMINISTRATOR_USERNAME_OF_THE_AZURE_VMs",
    "vmNameCert" : "VM_NAME_USED_TO_GENERATE_DIGITAL_CERTIFICATES",
    "vmNameClient": "VM_NAME_USED_TO_INSTALL_THE_VPN_CLIENT"
}
```
## <a name="deployment workflow"></a>3. Deployment workflow
The deployment can be executed with list of steps in sequence.

### <a name="1st step"></a>STEP1: Generation of self-signed digital certificate and client certificates
This 1st step is executed by ARM template **01-wincert-VM.json** <br>

[![2]][2]

The ARM template **01-wincert-VM.json** makes the following actions:
- spin up a Windows Server 2022 VM
- a powershell script extension runs the script **createSelfSignCertificates.ps1** that creates a self-signed digital root certificate and three digital clients certificates signed by root certificate. The digital certificates are exported in Windows VM local folder **C:\cert\\**
   - **certClient1.pfx**: client certificate 1, signed by root certificate. The file contains the private key of the client certificate.
   - **certClient2.pfx**: client certificate 2, signed by root certificate. The file contains the private key of the client certificate.
   - **certClient3.pfx**: client certificate 3, signed by root certificate. The file contains the private key of the client certificate.
   - **certpwd.txt**: password to access to the certificates
   - **certRoot-with-privKey.pfx**: self-signed root certificate with private key
   - **P2SRoot.cer**: root certificate Base-64 encoded containg only the public key certificate. A .cer file can contain only public key but not private key. Export executed by  **certutil** command
   - **P2SRoot.cert**:  Export root certificate from the certificate store into a file by **Export-Certificate** command.
`Note:` A **.pfx** file, also recognized as a Personal Information Exchange file, contains a variety of cryptographic information, including certificates, certificate chains, root authority certificates, and private keys.

The list of Azure resources created in this step are shown below:

[![3]][3]

At the end of running, login in the Windows server and check in the folder **C:\cert** the presence of digital certificates:

[![4]][4]


### <a name="2nd step"></a>STEP2: Deployment of the Azure VPN Gateway 
The 2nd step is executed by ARM template **02-vpn.json** <br>
[![5]][5]

The ARM template **02-vpn.json** makes the following actions:
- download from the storage account the root certificate **P2SRoot.cer** to the local host (laptop/desktop) in **cert** folder
- create a new vnet and deploy the Azure VPN Gateway in the **GatewaySubnet** in configuration active-passive
- set the P2S tunnel type **IKEv2 and OpenVPN (SSL)** and authentication type **Azure Certificate**
- adding in the Azure VPN Gateway the P2S client address pool and the root certificate (with public key) 

At the end of step2, the VPN gateway is configured as shown below:

[![6]][6]

### <a name="3rd step"></a>STEP3: download the P2S client profile from the VPN Gateway to the local script folder 
The 3rd step is executed by **03-downloadClientProfile.ps1**

[![7]][7]

The script **03-downloadClientProfile.ps1** makes the following actions:
- through Azure powershell download the P2S client profile from Azure VPN Gateway. The file is downloaded in the local folder **client** and then unzipped.
- the local file **client\AzureVPN\azurevpnconfig.xml** is copied to the storage blob

### <a name="4th step"></a>STEP4: Creation of new vnet and Windows 11 VM with Azure VPN client
The 4th step is executed by ARM template **04-az-clientVM.json**

[![8]][8]

The script **04-az-clientVM.json** makes the following actions:
- create a new vnet and spin up a Windows 11 VM. This VM is used as client to connect in P2S VPN to the VPN Gateway
- create a system management identity with ontributor role on the storage account
- run a powershell script extension **downloadClientCert.ps1** to download the client certificate from the storage account to the Windows 11 VM. 
   - The digital client certificate for P2S VPN is stored to the local folder **C:\cert** of Windows 11 Azure VM.
   - the P2S user profile **azurevpnconfig.xml** is downloaded from the Azure storage account to the local folder **C:\cert** of Windows 11 Azure VM

At the end of **04-az-clientVM.json** deployment:
- connect in RDP to the Windows 11 VM
- run the following commands to enable the powershell script execution: `Set-ExecutionPolicy -ExecutionPolicy Bypass`
- in the folder **C:\cert** run the script: **C:\cert>.\loadClientCert.ps1 -clientCertSeq 3** <br>
   NOTE: the powershell script **loadClientCert.ps1** required as input value the number of client certificate; in the local folder **C:\cert** is present the file **certClient3.pfx**. The input value to pass to the **loadClientCert.ps1** is then **3**
- checking the digital certificate load in the Windows 11 client. <br>
  In Windows there are two commands to open the snap-in for digital certificates:
   - **certmgr.msc**: access to the certificates for the current user
   - **certlm.msc**: certificates for certificate for the device
   To check the digital certificate load in personal folder, run the command **certmgr.msc**:
[![9]][9]
[![10]][10]
- download the [Azure VPN client for Windows](https://aka.ms/azvpnclientdownload)
- install the VPN client
- import the P2S user profile
- establish the P2S tunnel with Azure VPN Gateway 

[![11]][11]

### <a name="5th step"></a>STEP5: deployment of Azure VM in the VPN Gateway vnet
The 6th step is executed by **05-vms.json** <br>
The ARM template creates a VM in the vnet and by custom script extension install nginx:

[![12]][12]

when the deployment is completed, connect to the VM and check out with curl the connection in http to the the nginx running in the VM:
```console
http://127.0.0.1
systemctl check nginx
```



### <a name="6th step"></a>STEP6: verification of P2S VPN
Connect in RDP to the client VM, veryfing that P2S VPN tunnel is up.
By curl, run a query to the nginx server installed in the vm 10.0.0.10 in vnet-gtw 

[![13]][13]

### <a name="7th step"></a>STEP7: setup P2S always-on user tunnel
The always-on P2S connection is based on [VPNv2 CSP](https://learn.microsoft.com/en-us/windows/client-management/mdm/vpnv2-csp) <br>
The **VPNv2** configuration service provider allows the Mobile Device Management (MDM) server to configure the VPN profile. <br>
Install in the Windows 11 client the powershell module:

```powershell
Install-Module -Name AOVPNTools
Get-command -Module AOVPNTools
```

From the VPN client profile with authentication with digital certificate, grab the URL of the P2S VPN Gateway. <br>
The URL to access to the P2S VPN Gateway has the following structure:
```console
azuregateway-<GUID>.vpn.azure.com
```

and paste in the following XML template:
```xml
<VPNProfile>  
   <NativeProfile>  
      <Servers>azuregateway-<GUID>.vpn.azure.com</Servers>  
      <NativeProtocolType>IKEv2</NativeProtocolType>  
      <Authentication>  
        <UserMethod>Eap</UserMethod>
        <Eap>
          <Configuration>
            <EapHostConfig xmlns="http://www.microsoft.com/provisioning/EapHostConfig">
              <EapMethod>
                <Type xmlns="http://www.microsoft.com/provisioning/EapCommon">13</Type>
                <VendorId xmlns="http://www.microsoft.com/provisioning/EapCommon">0</VendorId>
                <VendorType xmlns="http://www.microsoft.com/provisioning/EapCommon">0</VendorType>
                <AuthorId xmlns="http://www.microsoft.com/provisioning/EapCommon">0</AuthorId>
              </EapMethod>
              <Config xmlns="http://www.microsoft.com/provisioning/EapHostConfig">
                <Eap xmlns="http://www.microsoft.com/provisioning/BaseEapConnectionPropertiesV1">
                  <Type>13</Type>
                  <EapType xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV1">
                      <CredentialsSource>
                        <CertificateStore>
                          <SimpleCertSelection>true</SimpleCertSelection>
                        </CertificateStore>
                      </CredentialsSource>
                      <ServerValidation>
                        <DisableUserPromptForServerValidation>false</DisableUserPromptForServerValidation>
                        <ServerNames></ServerNames>
                      </ServerValidation>
                      <DifferentUsername>false</DifferentUsername>
                      <PerformServerValidation xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV2">false</PerformServerValidation>
                      <AcceptServerName xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV2">false</AcceptServerName>
                  </EapType>
                </Eap>
              </Config>
            </EapHostConfig>
          </Configuration>
        </Eap>
      </Authentication>  
      <RoutingPolicyType>SplitTunnel</RoutingPolicyType>  
      <!-- disable the addition of a class based route for the assigned IP address on the VPN interface -->
     <DisableClassBasedDefaultRoute>true</DisableClassBasedDefaultRoute>  
   </NativeProfile> 
   <!-- define a route to the remote vnet where is deployed the VPN Gateway -->  
   <Route>  
     <Address>10.0.0.0</Address>  
     <PrefixSize>24</PrefixSize>  
   </Route>  
   <!-- need to specify always on = true --> 
   <AlwaysOn>true</AlwaysOn>
   <RememberCredentials>true</RememberCredentials>
   <!--new node to register client IP address in DNS to enable manage out -->
   <RegisterDNS>true</RegisterDNS>
</VPNProfile>
```

To create an aways-on P2S VPN connection run the command:
```powershell
New-AovpnConnection -xmlFilePath .\always-on-userTunnel.xml
```
A default name of profile is assigned to connection called: **Always On VPN**

```powershell
Get-VpnConnection -Name "Always On VPN"


Name                  : Always On VPN
ServerAddress         : azuregateway-<GUID>.vpn.azure.com
AllUserConnection     : False
Guid                  : {5EE0C50C-A32F-4B57-A4B1-28C9801C0FEC}
TunnelType            : Ikev2
AuthenticationMethod  : {Eap}
EncryptionLevel       : Required
L2tpIPsecAuth         :
UseWinlogonCredential : False
EapConfigXmlStream    : #document
ConnectionStatus      : Connected
RememberCredential    : True
SplitTunneling        : True
DnsSuffix             :
IdleDisconnectSeconds : 0
```

[![14]][14]

To remove the connection:
```powershell
Remove-AovpnConnection -ProfileName "Always on VPN"
```


`Tag: Point-to-Site VPN` <br>
`date: 15-04-2024`

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/step01.png "step1: creation of digital certificates"
[3]: ./media/deployment-step01.png "step1: deployment"
[4]: ./media/digitalCertificates-step01.png
[5]: ./media/step02.png "step2"
[6]: ./media/deployment-step02.png "step2"
[7]: ./media/step03.png "step3"
[8]: ./media/step04.png "step4"
[9]: ./media/step4-clientCertificate.png "step4: client certificate"
[10]: ./media/step4-rootCertificate.png "step4: root certificate"
[11]: ./media/vpn-client-connection.png "step4: Azure VPN client connection"
[12]: ./media/step5.png "step5: Azure VMs in vnet of the Azure VPN Gateway"
[13]: ./media/step6.png "step6: verification of P2S VPN"
[14]: ./media/always-on.png "always-on P2S VPN"

<!--Link References-->

