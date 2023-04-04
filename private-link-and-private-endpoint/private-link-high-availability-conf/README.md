<properties
pageTitle= 'Azure Private Link service in high availability configuration through Azure functions' 
description= "Private Link service in high availability configuration through Azure functions"
documentationcenter: na
services=""
documentationCenter="github"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="howto-Azure-examples"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="Azure private link, Azure function, Azure load balancer"
   ms.date="31/03/2023"
   ms.review=""
   ms.author="fabferri" />

# Azure Private Link service in high availability configuration through Azure functions

The article describes a configuration with two Azure Private Link service deployed in two different provider vnets and single consumer vnet able to access both of Private link service:

[![1]][1]

The intent is to create an Azure Private link configuration in high availability. the high avaiability is achived by two Azure Private Links. The administrator can designate a Private Link service as primary and the other as secondary. The idea is to use mainly the primary Private Link service and switchover to the secondary Private Link service when the primary won't be accessible. <br>
Let describe the main characteristics of the configuration.
- In the consumer vnet are present two private endpoints **ep1** and **ep2**, to reach out respectively the primary and secondary Private Link services 
- A private DNS zone is linked to the consumer vnet. In our case the private DNS zone manage and resolve the domain name **mydom.net**. In the consumer vnet, each private endpoint associated with the private link service can be resolve through A records of private DNS zone. Three A records are registered in the private DNS zone: 
    - one A record maps the name **ep1** to the IP of private endpoint connected to the private link service 1 
    - one A record maps the name **ep2** to the IP of private endpoint connected to the private link service 2,
    - one A record maps the name **ep** to the IP of the designated primary endpoint
- In each provider vnet is deployed the Private Link service, connected to an Azure Standard Load Balancer configured in HA ports. The backend of load balancer is configured to balance the traffic to two Ubuntu VMs. An apache server is installed in each VM, configured to answer to HTTP requests on default TCP port 80 
- an azure function is configured with vnet integration to access to the consumer vnet. The Azure function requires access Azure storage account where store the configuration file. A storage account is created with this purpose; to keep private the communication private between the Azure function and the storage account four endpoints are create in the consumer vnet. The private endpoints allow to the function to access to blobs, files, tables and queues in the Azure storage account with private transit through the consumer vnet.
- the Azure function is configured with timer trigger to run on a specified schedule. A powershell runs a specific time interval sending HTTP request to **http://ep.mydom.net**. 
- In the specific deployment the **ep** endpoint is associated with the IP: 10.0.5.4 of the primary endpoint. The HTTP requests coming from powershell, running in azure function, are sent to the primary endpoint ep1 and forwarded to the Primary Link service 1
- The switchover from primary endpoint **ep1** to secondary endpoint **ep2** happens when both of the VMs in the provider1 vnet don't answer to load balancer health probe or when the VMs have apache server down.

The network details inclusive of IP address networks is shown below:

[![2]][2]

When the azure function won't be able to reach out the VMs in **vnet1Producer**, the powershell in Azure function will change the IP address in the DNS A record **ep**: <br>
<ins>Origin setting:</ins> <br>

| DNS private zone |||
| ---------------- |-|-|
| Name             | Type | Value |
| ep               | A | 10.0.5.4 |

<ins>In the switchover the A record is changed into:</ins> <br>
| DNS private zone |||
| ---------------- |-|-|
| Name             | Type | Value |
| ep               | A | 10.0.5.5 |

<br>

The diagram below shows the transit of HTTP connection initialized from the powershell in Azure function to the private endpoint. The diagram shows the transit when the HTTP request can reach out the web server in the producer vnet. 

[![3]][3]

## <a name="list of project files"></a>1. Project files

| File name                 | Description                                                                      |
| ------------------------- | -------------------------------------------------------------------------------- |
| **init.json**             | it contains the input variables setting used for the full deployment             |
| **provider1.json**        | ARM template to deploy the provider1 vnet with private link service1, load balancer in HA and backend Ubuntu VMs <br> Apache web server is installed in the VMs through custom script extension                      |
| **provider1.ps1**         | powershell script to run **provider1.json**                                      |
| **provider2.json**        | ARM template to deploy the provider2 vnet with private link service2, load balancer in HA and backend Ubuntu VMs <br> Apache web server is installed in the VMs through custom script extension                      |
| **provider1.ps1**         | powershell script to run **provider2.json**                                      |
| **consumer.json.json**    | ARM template to deploy the consumer vnet with private endpoints **ep1** and **ep2** to access to the private link services1 nd private link service2 |
| **function.json**         | ARM template to deploy Azure function, storage account, private endpoints for the storage account |
| **function.ps1**          | powershell script to run **function.json**                                       |
| **check.sh**              | bash script to be copied in the vm1Consumer  to send HTTP requests to the private endpoint **ep** |

Before running the powershell scripts, customize the values of input variables in the **init.json**:
```json
{
"provider1SubscriptionName": "AZURE_SUBSCRIPTION_NAME_TO_DEPLOY_PROVIDER1_NET",
"provider2SubscriptionName": "AZURE_SUBSCRIPTION_NAME_TO_DEPLOY_PROVIDER2_NET",
"consumerSubscriptionName": "AZURE_SUBSCRIPTION_NAME_TO_DEPLOY_CONSUMER_NET",
"Provider1ResourceGroupName": "RESOURCE_GROUP_NAME_PROVIDER1",
"Provider2ResourceGroupName": "RESOURCE_GROUP_NAME_PROVIDER2",
"ConsumerResourceGroupName": "RESOURCE_GROUP_NAME_CONSUMER",
"provider1Location": "AZURE_REGION_PROVIDER1_NET",
"provider2Location": "AZURE_REGION_PROVIDER2_NET",
"consumerLocation": "AZURE_REGION_CONSUMER_NET",
"adminUsername": "ADMINISTRATOR_USERNAME",
"adminPassword": "ADMINISTRATOR_PASSWORD"
}

```
Utilization of file **init.json** helps to keep the values of variables consistent across the deployments.
<br>

The sequence for the full project deployment is shown above:

[![5]][5]

**NOTE** <br>
The ARM template **function.json** configures the function app with a system-assigned identity and create a role assignment granting that identity the **Contributor** permission on the Resource Group of the consumer vnet. This is required to the azure function app to access to the storage accont but also to run the powershell sending HTTP request to the private endpoint **ep**. The json snippet for role assignment is shown below:
```json
{
      "type": "Microsoft.Authorization/roleAssignments",
      "apiVersion": "2021-04-01-preview",
      "name": "[guid(resourceId('Microsoft.Resources/resourceGroups', resourceGroup().name) )]",
      "dependsOn": [
        "[resourceId('Microsoft.Web/sites', parameters('functionAppName'))]"
      ],
      "properties": {
        "roleDefinitionId": "[variables('role')[parameters('builtInRoleType')]]",
        "principalId": "[reference(resourceId('Microsoft.Web/sites', parameters('functionAppName')), '2019-08-01', 'Full').identity.principalId]"
      }
    },
```
A system-assigned identity is tied to your function app and is deleted if your function app is deleted.

## <a name="Azure function"></a>2. Configuration of the Azure function
Configuration of Azure function can be done in three steps: 
- configuration of Application files
- setting the function app environment variables
- setup of the Azure function

### <a name="Azure function"></a>2.1 Configuration of the Application files
Before the creation of the function, as first action is required the configuration of Application files. <br>
A function app provides an execution context in Azure in which your functions run.
The **host.json** file contains runtime-specific configurations and is in the root folder of the function app. 

[![6]][6]

The **requirements.psd1** file is used to automatically download required modules. In our case the Azure powershell module **Az**

[![7]][7]



### <a name="Azure function"></a>2.2 Setting the function app environment variables
The Application settings maintains settings that are used by your function app. Definition of the following function app environment variables:
```
Variable Name: rgName            Value: plink-consumer
Variable Name: targetIPPrimary   Value: 10.0.5.4 
Variable Name: targetIPSecondary Value: 10.0.5.5 
Variable Name: dnsArecordName    Value: ep 
```
[![8]][8]

[![9]][9]

[![10]][10]

[![11]][11]

[![12]][12]

### <a name="Azure function"></a>2.3 Setup of the Azure function
Create the Azure function:

[![13]][13]

As function type select **Timer trigger**; in the schedule specify the schedule time the function is triggered.

[![14]][14]

As shown in the picture above the schedule is set to 10 minute (the syntax follow the cron syntax).

In the **run.ps1** paste the powershell script:


```powershell
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

```

[![15]][15]







`Tags: Azure private link, Azure functions, HA ` <br>
`date: 31-03-23`

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/network-diagram2.png "full network diagram with BGP peering with csr1 in hub vnet"
[3]: ./media/network-diagram3.png "powershell in Azure function checking the connection through the primary private link and secondary private link"
[4]: ./media/network-diagram4.png "route filters in nva1"
[5]: ./media/sequence.png "setup sequence"
[5]: ./media/azfunction01.png "azure function setup"
[6]: ./media/azfunction02.png "azure function setup"
[7]: ./media/azfunction03.png "azure function setup"
[8]: ./media/funcAppConfig01.png "configuration of environment variable"
[9]: ./media/funcAppConfig02.png "configuration of environment variable"
[10]: ./media/funcAppConfig03.png "configuration of environment variable"
[11]: ./media/funcAppConfig04.png "configuration of environment variable"
[12]: ./media/funcAppConfig05.png "configuration of environment variable"
[13]: ./media/azfunction04.png "azure function setup"
[14]: ./media/azfunction05.png "azure function setup"
[15]: ./media/azfunction06.png "azure function setup"

<!--Link References-->

