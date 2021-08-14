<properties
pageTitle= 'UDR with service tags'
description= "UDR with service tags"
documentationcenter: na
services=""
documentationCenter="na"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="na"
   ms.date="28/06/2021"
   ms.author="fabferri" />

# UDR with service tags
A service tag represents a group of IP address prefixes associated to a given Azure service. Microsoft manages the address prefixes enclosed by the service tag and automatically updates the service tag as addresses change, minimizing the complexity of frequent updates to network security rules. You can use service tags to define network access controls on network security groups, Azure Firewall and UDRs.
<br>
The article describes a configuration with service tag in UDRs, to route the traffic to Azure service through a NVA.
The network diagram is shown below:

[![1]][1]


* single vnet with address space 10.0.0.0/24 and 5 subnets: external (10.0.0.0/27), internal (10.0.0.32/27), subnet3 (10.0.0.64/27), subnet4 (10.0.0.96/27), subnet5 (10.0.0.128/27)
* the nva has two NICs, nic1 is external interface (primary interface) with associated a public IP and nic2 is the internal interface (secondary interface). 
   * The nva OS has the default route 0.0.0.0/0 associated with primary interface nic1. 
   * *IPv4 forwarding* is enabled on the nva
   * in the nva *firewalld* is configured with NAT masquerade to translate the traffic coming from the VMs into the IP address associated with the external interface.
* UDRs are applied only to subnet3 and subnet4. The UDRs use service tags to route only the traffic to specific Azure services through the nva.
   * the UDR applied to the subnet3 point to the internal interface of the nva, to communicate with an storage account in eastus2 and a keyvault in eastus2 
   * the UDR applied to the subnet4 point to the internal interface of the nva, to reach out an Azure SQL DB in eastus2, an event hub in eastus2 and resource manager (Azure resource manager is not regional)




<br>

The effective routes applied to the nic of the vm70:
|Source	  |State	|Address Prefixes	            |Next Hop Type   	|Next Hop IP Address  |User Defined Route Name    |
|---------|---------|-------------------------------|-------------------|---------------------|---------------------------|
|Default  |Active	|10.0.0.0/24	                |Virtual network	|-	                  |-                          |
|Default  |Active	|0.0.0.0/0	                    |Internet	        |-	                  |-                          |
|User	  |Active	|191.239.224.0/26, 98 more  	|Virtual appliance  | 10.0.0.40	          |routeToStorage             |
|User	  |Active	|137.116.44.148/32, 21 more  	|Virtual appliance  | 10.0.0.40	          |routeToKeyVault            |
|User	  |Active	|10.0.0.96/27	                |Virtual appliance  | 10.0.0.40	          |routeToSubnet4             |

<br>

The effective routes applied to the nic of the vm100:
|Source	  |State	|Address Prefixes	            |Next Hop Type      |Next Hop IP Address  |User Defined Route Name    |
|---------|---------|-------------------------------|-------------------|---------------------|---------------------------|
|Default  |Active	|10.0.0.0/24	                |Virtual network	|-	                  |-                          |
|Default  |Active	|0.0.0.0/0	                    |Internet	        |-	                  |-                          |
|User	  |Active	|191.239.224.110/32, 46 more	|Virtual appliance  | 10.0.0.40	          |routeToSQL                 |
|User	  |Active	|191.237.129.158/32, 23 more	|Virtual appliance  | 10.0.0.40	          |routeToEventHub            |
|User	  |Active	|191.234.158.0/23, 166 more	    |Virtual appliance  | 10.0.0.40	          |routeToAzureResourceManager|
|User	  |Active	|10.0.0.64/27	                |Virtual appliance  | 10.0.0.40	          |routeToSubnet3             |



## <a name="ARM templates and scripts"></a>2. List of ARM templates and scripts

**Files:**
| File name                                              | Description                                                       |
| ------------------------------------------------------ | ----------------------------------------------------------------- |
| **service-tag.json**                                   | ARM template to create the vnet with Azure VMs and UDRs           |
| **service-tag.ps1**                                    | powershell script to run **service-tag.json**                     |
| folder: SQL /file: **sql.json**                        | ARM template to create the Azure SQL server and Azure SQL DB      |
| folder: SQL /file: **sql.ps1**                         | deployment of ExpressRoute gateway and connection                 |
| folder: keyvault / file: **CreateServicePrinciple.ps1**   | powershell script to create a service principle            |
| folder: keyvault / file: **keyvault.json**                | ARM template to create the Azure keyvault                  |
| folder: keyvault / file: **keyvault.ps1**                 | powershell script to run **keyvault.json**                 |
| folder: keyvault / file: **keyvault-console-app**         | ARM template to deploy the spoke vnet in the mid layer (between the hub and the spoke in the leaves ) |
| folder: storage / file: bashscriptToGenerateRamdomFile.sh | bash script to generate large random binary files          |
| folder: storage / file: **storageSAS.ps1**                | powershell script to create a storage account and generate a Storage Access Signature (SAS) |
| folder: storage / file: storage-sas-value.txt             | text file generated from **storageSAS.ps1** <br> it contains SAS associated with the storage account|
| folder: eventhub / file: eventhub.ps1                     | powershell to create eventhub powershell. it  run **eventhub.json**|
| folder: eventhub / file: **eventhub.json**                | ARM template to create the Azure event hub                 |
| folder: eventhub / file: getEventHubConnectionString.ps1  | powershell to event hub connection string                  |


> **NOTE**
> The value of tags  **$RGTagExpireDate**, **$RGTagContact**,**$RGTagNinja**, **$RGTagUsage** associated with the resource group are optionals and only used to identify the specific project.
>
>


## <a name="firewalld"></a>1. nva setup
nva run with centOS 8.3
<br>

Let's activate the ip fowarding and **firewalld** in nva.

<br>
Enable ip forwarding in the nva:

```bash
sed -i -e '$a\net.ipv4.ip_forward = 1' /etc/sysctl.conf
sysctl --system
sysctl net.ipv4.ip_forward
```

the command **sysctl --system** reload the system settings from config files without reboot.

To route the traffic between subnet3 and subnet4 through the secondary network interface nic2 of the nva is required a static route:

```bash
[root@vnet1-nva ~]# nmcli connection show
NAME         UUID                                  TYPE      DEVICE
System eth0  5fb06bd0-0bb0-7ffb-45f1-d6edd65f3e03  ethernet  eth0
System eth1  9c92fad9-6ecb-3e6c-eb4d-8a47c6f50c04  ethernet  eth1

[root@vnet1-nva ~]# ip -4 route
default via 10.0.0.1 dev eth0 proto dhcp metric 100
10.0.0.0/27 dev eth0 proto kernel scope link src 10.0.0.10 metric 100
10.0.0.32/27 dev eth1 proto kernel scope link src 10.0.0.40 metric 101
168.63.129.16 via 10.0.0.1 dev eth0 proto dhcp metric 100
169.254.169.254 via 10.0.0.1 dev eth0 proto dhcp metric 100

[root@vnet1-nva ~]# nmcli connection modify "System eth1" +ipv4.routes "10.0.0.64/27 10.0.0.33"
[root@vnet1-nva ~]# nmcli connection modify "System eth1" +ipv4.routes "10.0.0.96/27 10.0.0.33"
[root@vnet1-nva ~]# nmcli connection up "System eth1"
Connection successfully activated (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/3)

[root@vnet1-nva ~]# ip -4 route
default via 10.0.0.1 dev eth0 proto dhcp metric 100
10.0.0.0/27 dev eth0 proto kernel scope link src 10.0.0.10 metric 100
10.0.0.32/27 dev eth1 proto kernel scope link src 10.0.0.40 metric 101
10.0.0.64/27 via 10.0.0.33 dev eth1 proto static metric 101
10.0.0.96/27 via 10.0.0.33 dev eth1 proto static metric 101
168.63.129.16 via 10.0.0.1 dev eth0 proto dhcp metric 100
169.254.169.254 via 10.0.0.1 dev eth0 proto dhcp metric 100

```

The command **nmcli connection up** restart the network connection.

Let's start firewalld:
```bash
[root@vnet1-nva ~]# systemctl status firewalld
● firewalld.service - firewalld - dynamic firewall daemon
   Loaded: loaded (/usr/lib/systemd/system/firewalld.service; disabled; vendor preset: enabled)
   Active: inactive (dead)
     Docs: man:firewalld(1)

[root@vnet1-nva ~]# systemctl enable firewalld
[root@vnet1-nva ~]# systemctl start firewalld
```
Checking the zone selected as the default and the active zones:
```bash
[root@vnet1-nva ~]# firewall-cmd --get-default-zone
public

[root@vnet1-nva ~]# firewall-cmd --get-active-zones
public
  interfaces: eth0 eth1
```

Changing the firewalld configuration:
- association of internal interface eth1 with the **trust** zone, 
- enable NAT overload on **public** zone,
- save the configuration

```bash
firewall-cmd --zone=trusted --change-interface=eth1
firewall-cmd --zone=public --add-masquerade 
firewall-cmd --runtime-to-permanent
```
The inbound connection in SSH is already enabled in **public** zone:
```bash
[root@vnet1-nva ~]# firewall-cmd --zone=public --list-services
cockpit dhcpv6-client ssh

```
See ANNEX paragraph for more information on firewalld.

## <a name="azcopy"></a>2. Verifying Resource Manager traffic passes across the nva
* Install the azure powershell in the **vm100** (Windows Server 2019)
* run tcpdump in nva to capture the traffic in transit through the internal interface eth1: **tcpdump -i eth1 -n**
<br>

In **vm100**, run an Azure powershell command i.e. **Get-AzResourceGroup**. Below the tcpdump snippet in **nva**: 

```
21:02:42.411035 IP 10.0.0.100.50687 > 20.44.16.113.https: Flags [SEW], seq 2890795757, win 64240, options [mss 1418,nop,wscale 8,nop,nop,sackOK], length 0
21:02:42.412293 IP 20.44.16.113.https > 10.0.0.100.50687: Flags [S.E], seq 2721688330, ack 2890795758, win 65535, options [mss 1440,nop,wscale 8,nop,nop,sackOK], length 0
21:02:42.413097 IP 10.0.0.100.50687 > 20.44.16.113.https: Flags [.], ack 1, win 16426, length 0
21:02:42.413179 IP 10.0.0.100.50687 > 20.44.16.113.https: Flags [P.], seq 1:209, ack 1, win 16426, length 208
21:02:42.415746 IP 20.44.16.113.https > 10.0.0.100.50687: Flags [P.], seq 1:4009, ack 209, win 16426, length 4008
21:02:42.416661 IP 10.0.0.100.50687 > 20.44.16.113.https: Flags [.], ack 4009, win 16426, length 0
21:02:42.419709 IP 10.0.0.100.50687 > 20.44.16.113.https: Flags [P.], seq 209:367, ack 4009, win 16426, length 158
21:02:42.421934 IP 20.44.16.113.https > 10.0.0.100.50687: Flags [P.], seq 4009:4060, ack 367, win 16425, length 51
21:02:42.423306 IP 10.0.0.100.50687 > 20.44.16.113.https: Flags [P.], seq 367:3007, ack 4060, win 16426, length 2640
21:02:42.423771 IP 20.44.16.113.https > 10.0.0.100.50687: Flags [.], ack 3007, win 16426, length 0
21:02:42.497774 IP 20.44.16.113.https > 10.0.0.100.50687: Flags [P.], seq 4060:7147, ack 3007, win 16426, length 3087
21:02:42.498762 IP 10.0.0.100.50687 > 20.44.16.113.https: Flags [.], ack 7147, win 16426, length 0
```
<br>

By UDR:
```json
       {
            "type": "Microsoft.Network/routeTables/routes",
            "apiVersion": "2020-11-01",
            "name": "[concat(variables('RT_subnet4'), '/routeToAzureResourceManager')]",
            "properties": {
                "addressPrefix": "AzureResourceManager",
                "nextHopType": "VirtualAppliance",
                "nextHopIpAddress": "[variables('nva_nic2_privIP')]",
                "hasBgpOverride": true
            }
        }
```
the **Resource Manager** traffic is routed successful across the nva.

<br>


## <a name="azcopy"></a>2. Cheking the storage traffic across the nva

The network diagram below shows the traffic path from the linux vm70 to the storage account and keyvault in the Azure region eastus2:
[![2]][2]


A large file is useful to see by tcpdump the traffic passes across the nva. To generate in the linux VM **vm70** a large binary file, run the bash script:
```bash
#!/bin/bash

res1=$(date +%s.%N)

for counter in {1..2}
do
## 1GB file size
## create a file with bs*count random bytes, in our case 1048576*1024 = 1GByte
dd if=/dev/urandom of="$HOME/test$counter.bin" bs=1048576 count=1024
done

res2=$(date +%s.%N)
dt=$(echo "$res2 - $res1" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

echo All done- generated $numFiles files
printf "Total runtime: %d:%02d:%02d:%02.4f\n" $dd $dh $dm $ds
```

Install azcopy tool in the **vm70**
```console
wget https://aka.ms/downloadazcopy-v10-linux
tar -xvf downloadazcopy-v10-linux
```
<br>
The syntax to upload a set of files by using a SAS token and wildcard (*) characters:

```
azcopy cp "/path/*foo/*.bin" "https://[account].blob.core.windows.net/[container]/[path/to/directory]?[SAS]"
```
<br>

* run tcpdump in nva to capture the traffic in transit through the internal interface eth1: **tcpdump -i eth1 -n**
* start the trasfer of binary file from vm70 to the storage blob, by command:
```
./azcopy cp "*.bin" "https://sto0account11111.blob.core.windows.net/folder1?sv=2019-07-07&sr=c&si=storage-policy&sig=aPhqDuOuCqfYKLKDgfGgl2PVSPEdzynABMZrHMGcK5U%3D"
```
<br>

To remove the blob in the storage account:
```
./azcopy rm  "https://sto0account11111.blob.core.windows.net/folder1?sv=2019-07-07&sr=c&si=storage-policy&sig=aPhqDuOuCqfYKLKDgfGgl2PVSPEdzynABMZrHMGcK5U%3D"
```


## <a name="azcopy"></a>2. Verifying keyvault traffic across the nva

The network diagram below shows the traffic path from the linux vm70 to the Azure keyvault in eastus2:

[![3]][3]


Download and install the .NET core SDK 3.1 in the linux **vm70**:
```
wget https://dot.net/v1/dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh -c 3.1
```
Add the path to dotnet:
```bash
export DOTNET_ROOT=$HOME/.dotnet
export PATH=$PATH:$DOTNET_ROOT
```
The preceding export commands only make the .NET CLI commands available for the terminal session in which it runs. You can edit your shell profile to permanently add the commands.
Edit the file **~/.bash_profile**  and add **$HOME/.dotnet** to the end of the existing PATH statement:

```bash
# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs
PATH=$PATH:$HOME/bin:$HOME/.dotnet
export PATH
```

Check the dotnet SDK version:
```
dotnet --version
3.1.410
```

<br>

Create a .NET application:
```console
dotnet new console --name keyvault-console-app
```
This command creates new app project files, including an initial C# code file (Program.cs), an XML configuration file (keyvault-console-app.csproj), and needed binaries.
<br>

Change to the newly created keyvault-console-app directory, and run the following command to build the project:

```console
dotnet build
```
<br>

Install the Azure Key Vault secret client library (**Azure.Security.KeyVault.Secrets**) for .NET:
```console
dotnet add package Azure.Security.KeyVault.Secrets
```
<br>

Install the Azure SDK client library for Azure Identity (**Azure.Identity**):
```console
dotnet add package Azure.Identity
```
<br>

Install the Nuget pakage **Microsoft.Extensions.Configuration.Json** to read the .json file:
```console
dotnet add package Microsoft.Extensions.Configuration.Json
```
<br>

Inside the project folder create a new file **jsconfig1.json** with name of keyvault and service principle to access to the keyvault: 
```json
{
  "keyvaultName": "kv00-jcrtni7alphga",
  "clientId": "826e2d2c-b982-481c-b9a7-5fdbb6d0fca9",
  "tenantId": "72f988bf-86f1-41af-91ab-2d7cd011db47",
  "clientSecret": "=1)2Z2kdGX)=E.Or"
}
```
Open the file **keyvault-console-app.csproj** and add a section <ItemGroup> to include the file **jsconfig1.json** in the project. 
<br>

The full content of the file **keyvault-console-app.csproj**:
```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>netcoreapp3.1</TargetFramework>
    <RootNamespace>keyvault_console_app</RootNamespace>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Azure.Identity" Version="1.4.0" />
    <PackageReference Include="Azure.Security.KeyVault.Secrets" Version="4.2.0" />
    <PackageReference Include="Microsoft.Extensions.Configuration.Json" Version="5.0.0" />
  </ItemGroup>

  <ItemGroup>
    <None Update="jsconfig1.json">
      <CopyToOutputDirectory>Always</CopyToOutputDirectory>
    </None>
  </ItemGroup>

</Project>
```
Edit the file **Program.cs**:
```csharp
using System;
using System.IO;
using Microsoft.Extensions.Configuration;
using System.Threading.Tasks;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Azure;
using System.Collections.Generic;

namespace keyvault_console_app
{
    class Program
    {
        static async Task Main(string[] args)
        {
            //// keyvault name
            string keyVaultName = "";

            //// Client ID from the output of service pricipal creation output
            string clientId = "";

            //// Tenant ID from the output of service pricipal creation output
            string tenantId = "";

            //// Password from the output of service pricipal creation output
            string clientSecret = "";
            
            Dictionary<string, string> listValues = new Dictionary<string, string>();
            Console.WriteLine($"reading variable from the file jsconfig1.json");
            listValues = GetParameters();
            foreach (KeyValuePair<string, string> kvp in listValues)
            {
                switch (kvp.Key)
                {
                    case "keyvaultName":
                        keyVaultName = kvp.Value;
                        Console.WriteLine($"keyvaultName= \"{kvp.Value}\"");
                        break;
                    case "clientId":
                        clientId = kvp.Value;
                        Console.WriteLine($"clientId= \"{kvp.Value}\"");
                        break;
                    case "tenantId":
                        tenantId = kvp.Value;
                        Console.WriteLine($"tenantId= \"{kvp.Value}\"");
                        break;
                    case "clientSecret":
                        clientSecret = kvp.Value;
                        Console.WriteLine($"clientSecret= \"{kvp.Value}\"");
                        break;
                    default:
                        Console.WriteLine("ERROR in reading .json file");
                        System.Environment.Exit(0);
                        break;
                }
            }

            var kvUri = $"https://{keyVaultName}.vault.azure.net";
           
            // var client = new SecretClient(new Uri(kvUri), new DefaultAzureCredential());
            var client = new SecretClient(vaultUri: new Uri(kvUri), credential: new ClientSecretCredential(tenantId, clientId, clientSecret));

            // list all the deleted and non-purged secrets, assuming Azure Key Vault is soft delete-enabled.
            IEnumerable<DeletedSecret> secretsDeleted = client.GetDeletedSecrets();
            foreach (DeletedSecret secretDel in secretsDeleted)
            {
                Console.WriteLine($"deleted secret: {secretDel.Name} , recovery Id: {secretDel.RecoveryId}");
            }
            
            // purge deleted secrets
            foreach (DeletedSecret secretDel in secretsDeleted)
            {
                Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine("deleting secret: {0}", secretDel.Name);
                await client.PurgeDeletedSecretAsync(secretDel.Name);
                
                Console.WriteLine(" done.");
            }
            
            Console.WriteLine("-----------------------------------------");
            Console.ResetColor();

            // Create a new dictionary of strings, with string keys.
            //
            Dictionary<string, string> secretValues = new Dictionary<string, string>();
            secretValues.Add("secret01", "AAAA-BBBB-CCCC-DDDD-101");
            secretValues.Add("secret02", "EEEE-FFFF-GGGG-HHHH-101");
            secretValues.Add("secret03", "LLLL-MMMM-NNNN-OOOO-101");
            secretValues.Add("secret04", "PPPP-QQQQ-RRRR-SSSS-101");
            secretValues.Add("secret05", "TTTT-VVVV-WWWW-XXXX-101");
            secretValues.Add("secret06", "XXXX-YYYY-ZZZZ-AAAA-101");
            secretValues.Add("secret07", "BBBB-CCCC-DDDD-EEEE-101");
            secretValues.Add("secret08", "FFFF-GGGG-HHHH-IIII-101");
            secretValues.Add("secret09", "JJJJ-KKKK-LLLL-MMMM-101");
            secretValues.Add("secret10", "NNNN-OOOO-PPPP-QQQQ-101");
            secretValues.Add("secret11", "AAAA-BBBB-CCCC-DDDD-102");
            secretValues.Add("secret12", "EEEE-FFFF-GGGG-HHHH-102");
            secretValues.Add("secret13", "LLLL-MMMM-NNNN-OOOO-102");
            secretValues.Add("secret14", "PPPP-QQQQ-RRRR-SSSS-102");
            secretValues.Add("secret15", "TTTT-VVVV-WWWW-XXXX-102");
            secretValues.Add("secret16", "XXXX-YYYY-ZZZZ-AAAA-102");
            secretValues.Add("secret17", "BBBB-CCCC-DDDD-EEEE-102");
            secretValues.Add("secret18", "FFFF-GGGG-HHHH-IIII-102");
            secretValues.Add("secret19", "JJJJ-KKKK-LLLL-MMMM-102");
            secretValues.Add("secret20", "NNNN-OOOO-PPPP-QQQQ-102");
            secretValues.Add("secret21", "AAAA-BBBB-CCCC-DDDD-103");
            secretValues.Add("secret22", "EEEE-FFFF-GGGG-HHHH-103");
            secretValues.Add("secret23", "LLLL-MMMM-NNNN-OOOO-103");
            secretValues.Add("secret24", "PPPP-QQQQ-RRRR-SSSS-103");
            secretValues.Add("secret25", "TTTT-VVVV-WWWW-XXXX-103");
            secretValues.Add("secret26", "XXXX-YYYY-ZZZZ-AAAA-103");
            secretValues.Add("secret27", "BBBB-CCCC-DDDD-EEEE-103");
            secretValues.Add("secret28", "FFFF-GGGG-HHHH-IIII-103");
            secretValues.Add("secret29", "JJJJ-KKKK-LLLL-MMMM-103");
            secretValues.Add("secret30", "NNNN-OOOO-PPPP-QQQQ-103");


            Dictionary<string, string> secretDictionary = new Dictionary<string, string>();
            AsyncPageable<SecretProperties> allSecrets1 = client.GetPropertiesOfSecretsAsync();
            await foreach (SecretProperties secretProperties in allSecrets1)
            {
                var fetchSecret = await client.GetSecretAsync(secretProperties.Name);
                secretDictionary.Add(fetchSecret.Value.Name, fetchSecret.Value.Value);
            }
            
            foreach (KeyValuePair<string, string> kvp in secretValues)
            {

                string value = "";
                if (secretDictionary.TryGetValue(kvp.Key, out value))
                
                {
                    Console.WriteLine("secret in keyvault: Key = {0}, Value = {1}", kvp.Key, kvp.Value);
                }
                else
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("---> adding secret: Key = {0}, Value = {1}", kvp.Key, kvp.Value);
                    await client.SetSecretAsync(kvp.Key, kvp.Value);
                    Console.ResetColor();
                }
            }
            Console.ResetColor();
            Console.WriteLine("press a key to continue");
            Console.ReadKey();

            string[] listSecretNameToUpdate = { "secret15", "secret16", "secret17", "secret18", "secret19" };
            foreach (string secretName_ in listSecretNameToUpdate)
            {
                // update secrets
                await foreach (SecretProperties secret in client.GetPropertiesOfSecretVersionsAsync(secretName_))
                {
                    // Secret versions may also be disabled if compromised and new versions generated, so skip disabled versions, too.
                    if (!secret.Enabled.GetValueOrDefault())
                    {
                        continue;
                    }
                    System.DateTime moment = DateTime.Now;
                    int minute = moment.Minute;
                    int second = moment.Second;
                    string sVal = secretName_ +"-"+ minute.ToString("00") + second.ToString("00")+"-AAAAAAA";

                    KeyVaultSecret oldSecret = await client.GetSecretAsync(secret.Name, secret.Version);
                    if (sVal != oldSecret.Value)
                    {
                        Console.ForegroundColor = ConsoleColor.Green;
                        Console.WriteLine($"update the secret: {sVal} ...");
                        await client.SetSecretAsync(secret.Name,  sVal);
                        Console.ResetColor();
                    }
                }
            }

            // list of secrets to delete
            string[] listSecretName = { "secret15", "secret16", "secret17", "secret18", "secret19" };
            foreach (string secretName_ in listSecretName)
            {
                Console.Write($"Deleting your secret {secretName_} ...");
                DeleteSecretOperation operation = await client.StartDeleteSecretAsync(secretName_);
                // You only need to wait for completion if you want to purge or recover the secret.
                await operation.WaitForCompletionAsync();
                Console.WriteLine(" done.");
            }


            // list all the deleted and non-purged secrets, assuming Azure Key Vault is soft delete-enabled.
            IEnumerable<DeletedSecret> secretsDeleted_ = client.GetDeletedSecrets();
            // purge deleted secrets
            foreach (DeletedSecret secretDel in secretsDeleted_)
            {
                Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine("purge deleted secret: {0}", secretDel.Name);
                await client.PurgeDeletedSecretAsync(secretDel.Name);
                Console.WriteLine(" done.");
                Console.ResetColor();
            }

        }

        // read the file "jsconfig1.json" and load the key, value pairs in the dictionary
        private static Dictionary<string,string> GetParameters()
        {
            var builder = new ConfigurationBuilder()
               .SetBasePath(Directory.GetCurrentDirectory())
               .AddJsonFile("jsconfig1.json", optional: true, reloadOnChange: true);
            var val1 = builder.Build().GetSection("keyvaultName").Value;
            var val2 = builder.Build().GetSection("clientId").Value;
            var val3 = builder.Build().GetSection("tenantId").Value;
            var val4 = builder.Build().GetSection("clientSecret").Value;
            Dictionary<string, string> listValues = new Dictionary<string, string>();
            listValues.Add("keyvaultName", val1);
            listValues.Add("clientId", val2);
            listValues.Add("tenantId", val3);
            listValues.Add("clientSecret", val4);
            return listValues;
        }
    }
}
```
> NOTE
> The KeyVaultClient Class doesn't contain a method to get all secrets including their values. The GetSecrets method 'List secrets in a specified key vault' and returns a list with items of type SecretItem, which doesn't contain the value but only contains secret metadata. To get all values of all secrets, you have to iterate the list and get every one explicitly.

The *dotnet restore* command uses NuGet to restore dependencies as well as project-specific tools that are specified in the project file.
```console
dotnet restore
```
<br>

Run the code:
```console
dotnet run
```


## <a name="EventHub"></a>5. Verifying Azure Event Hub traffic across the nva 

The network diagram below shows the traffic path from the Windows vm100 to the event hub in the Azure region eastus2:

[![5]][5]

* run the **eventhub.ps1** to deploy the event hub.
* download and install the .NET core SDK 3.1 in the vm100 (Windows VM)
* in vm100 open the command line and inside the folder of C# project run the following commands:
```console
dotnet build
dotnet add package Azure.Messaging.EventHubs
dotnet add package Microsoft.Extensions.Configuration
dotnet add package Microsoft.Extensions.Configuration.Json
```
* Verifying the content **eventhub.csproj** :
```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>netcoreapp3.1</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Azure.Messaging.EventHubs" Version="5.5.0" />
    <PackageReference Include="Microsoft.Extensions.Configuration" Version="5.0.0" />
    <PackageReference Include="Microsoft.Extensions.Configuration.Json" Version="5.0.0" />
  </ItemGroup>

  <ItemGroup>
    <None Update="json1.json">
      <CopyToOutputDirectory>Always</CopyToOutputDirectory>
    </None>
  </ItemGroup>

</Project>
```
* run the script getEventHubConnectionString.ps1 to get the value of connection string to the event hub.
* edit json1.json and set the value of the "connectionString":
```json
{
  "connectionString": "Endpoint=sb://eh-ns-jcrtni7alphga.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=MArFDAQLcmj+Clvc9f7FysjHzr7Yu+Yqo9yqmOiFlh9=",
  "eventHubName": "eh"
}
```
* in vm100 run the commands:
```console
dotnet restore
dotnet run
```
<br>

In the nva run the command to watch the traffic from/to the vm100: **tcpdump -n -i eth1** 
<br>
The tcpdump shows the traffic to/from azure even hub pass cross nva. Below a snippet of the capture:

```
[root@vnet1-nva ~]# tcpdump -n -i eth1
dropped privs to tcpdump
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth1, link-type EN10MB (Ethernet), capture size 262144 bytes
20:50:17.429884 IP 10.0.0.100.63007 > 52.167.109.203.amqps: Flags [SEW], seq 3689503649, win 64240, options [mss 1418,nop,wscale 8,nop,nop,sackOK], length 0
20:50:17.431456 IP 52.167.109.203.amqps > 10.0.0.100.63007: Flags [S.E], seq 3088634124, ack 3689503650, win 65535, options [mss 1440,nop,wscale 8,nop,nop,sackOK], length 0
20:50:17.432716 IP 10.0.0.100.63007 > 52.167.109.203.amqps: Flags [.], ack 1, win 16426, length 0
20:50:17.487081 IP 10.0.0.100.63007 > 52.167.109.203.amqps: Flags [P.], seq 1:199, ack 1, win 16426, length 198
20:50:17.490259 IP 52.167.109.203.amqps > 10.0.0.100.63007: Flags [P.], seq 1:4280, ack 199, win 16426, length 4279
20:50:17.491271 IP 10.0.0.100.63007 > 52.167.109.203.amqps: Flags [.], ack 4280, win 16426, length 0
20:50:17.496190 IP 10.0.0.100.63007 > 52.167.109.203.amqps: Flags [P.], seq 199:357, ack 4280, win 16426, length 158
20:50:17.498561 IP 52.167.109.203.amqps > 10.0.0.100.63007: Flags [P.], seq 4280:4331, ack 357, win 16425, length 51
```

**NOTE**<br />
In Azure event hub the shortest possible event retention period is 1 day (24 hours). If you specify a retention period of one day, the event will become unavailable exactly 24 hours after it has been accepted. **You cannot explicitly delete events.**

<br>

## <a name="firewalld"></a>5. ANNEX: firewalld commands
firewalld uses the concepts of zones and services, that simplify the traffic management. Zones are predefined sets of rules. Network interfaces and sources can be assigned to a zone. The traffic allowed depends on the network your computer is connected to and the security level this network is assigned. 

Two predefined zones are:

**external** zone<br>
For use on external networks with masquerading enabled, especially for routers. You do not trust the other computers on the network to not harm your computer. Only selected incoming connections are accepted. 

**trusted** zone<br>
All network connections are accepted. 
<br>
<br>
* Status of the firewalld service: 
```console
systemctl status firewalld
firewall-cmd --state
```

* To list all the relevant information for the default zone: 
```console
firewall-cmd --list-all
```
* To specify the zone for which to display the settings:
```console
firewall-cmd --list-all --zone=external
```

* To see which zone is currently selected as the default by typing:
```console
firewall-cmd --get-default-zone
```

* An active zone is any zone that is configured with an interface and/or a source. To list active zones:
```console
firewall-cmd --get-active-zones
```

* default zone’s configuration:
```console
firewall-cmd --list-all
```

* To get a list of the available zones:
```console
firewall-cmd --get-zones
```

* Changing the zone of an interface:
```console
firewall-cmd --zone=home --change-interface=eth0
```

* List all predefined services: 
```console
firewall-cmd --get-services 
```

* Add the service to the allowed services: 
```console
firewall-cmd --add-service=<service-name>
```

* To get a list of open ports in the current zone: 
```console
firewall-cmd --list-ports
```

* Add a port to the allowed ports to open it for incoming traffic: 
```console
firewall-cmd --zone=public --add-port=<port-number>/<port-type> 
```
The _port-type_ are either tcp, udp, sctp, or dccp

* Make the new settings persistent: 
firewall-cmd --runtime-to-permanent

To create the rule to accept incoming connection on TCP port 22:
```console
firewall-cmd --zone=public --add-port=22/tcp --permanent 
```
--permanent flag keeps the rule persistent to reload of firewall configuration.

* Reload the firewall configuration:
```console
firewall-cmd –reload
```

<!--Image References-->
[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/storage.png "traffic from linux VM to the storage account"
[3]: ./media/keyvault.png "traffic from linux VM to kayvault"
[4]: ./media/sql.png "traffic from linux VM to the SQL DB"
[5]: ./media/eventhub.png "traffic path from windows VM to the event hub"

<!--Link References-->

