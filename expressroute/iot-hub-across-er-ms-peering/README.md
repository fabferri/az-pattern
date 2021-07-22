<properties
pageTitle= 'Azure IoT Hub with transit across ExpressRoute Microsoft peering'
description= "Azure IoT Hub with transit across ExpressRoute Microsoft peering"
documentationcenter: na
services="networking"
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
   ms.date="28/08/2020"
   ms.author="fabferri" />

# Azure IoT Hub with transit across ExpressRoute Microsoft peering 
This article describes how to deploy an Azure IoT Hub, and how an IoT client in dotnet core in on-premises network can sends messages to the IoT Hub through ExpressRoute Microsoft peering. 
To verify messages between IoT client and Azure IoT Hub pass through the ExpressRoute Microsoft peering, a traffic capture is executed in the customer edge router connected to the ExpressRoute circuit. 

The following network diagram shows the configuration.

[![1]][1]


## <a name="EnableIPForwarding"></a>1. Description of ARM template to deploy the IoT Hub
The IoT hub is created by the ARM template **az-iotHub.json**. The ARM template make the following actions:
* create an Azure Storage account
* create an IoT Hub with auto-route messages to storage account when the body message contains level="storage"
* define the fallback route for sending the messages that don't satisfy any of the existing routes to the built-in-Event Hubs

An IoT Hub has a default built-in-endpoint (messages/events) with Event Hubs. This endpoint is currently only exposed using the AMQP protocol on port 5671.

Let's discuss the logic of ARM template to deploy the IoT hub.
```json
   "properties": {
      "ipFilterRules": [],
      "eventHubEndpoints": {
         "events": {
            "retentionTimeInDays": "[variables('iotHubMessageRetentionInDays')]",
            "partitionCount": "[parameters('d2cPartitions')]"
         }
      },
      ...
   }
```

### <a name="ip filter rules"></a>1.a ipFilterRules object
The **ipFilterRules** is an IP filter to configure rules for rejecting or accepting traffic from specific IoT devices. The IP filter rules apply to all connections from devices. The ARM template doesn't set an IP filter. 

### <a name="ip filter rules"></a>1.b eventHubEndpoints object
Event Hubs provides message streaming through a partitioned consumer pattern in which each consumer only reads a message stream from a specific partition. Event Hubs retains data for a configured retention time that applies across all partitions in the Event Hub. Events expire on a time basis; you cannot explicitly delete them.

[![2]][2]

* **retentionTimeInDays**: how long in days messages are retained by IoT Hub. [default: 1 day, max value: 7 days]
* **partitionCount**: define the number of partitions for device-to-cloud event ingestion

### <a name="ip filter rules"></a>1.c Message routing
The IoT messages/events can be routed to a specific custom endpoint, by linking the endpoints to the IoT Hub. IoT Hub support the following custom endpoints:
* blob storage, 
* Service Bus Queues, 
* Service Bus Topics,
* Event Hubs 

**_Note: apart from the built-in-Event Hubs compatible endpoint, you can also route data to custom endpoints of type Event Hubs._**

In the **az-iotHub.json**, the messages are routed to a storage account in storage container. 
```json
                "routing": {
                    "endpoints": {
                        "storageContainers": [
                            {
                                "connectionString": "[concat('DefaultEndpointsProtocol=https;AccountName=',variables('storageAccountName'),';EndpointSuffix=',environment().suffixes.storage,';AccountKey=',listKeys(resourceId('Microsoft.Storage/storageAccounts', variables('storageAccountName')), '2019-06-01').keys[0].value)]",
                                "containerName": "[variables('storageContainerName')]",
                                "fileNameFormat": "{iotHub}/{partition}/{YYYY}/{MM}/{DD}/{HH}/{mm}",
                                "batchFrequencyInSeconds": 100,
                                "maxChunkSizeInBytes": 104857600,
                                "encoding": "json",
                                "name": "[variables('storageEndpoint')]"
                            }
                        ]
                    },
                    "routes": [
                        {
                            "name": "storageRoute",
                            "source": "DeviceMessages",
                            "condition": "level=\"storage\"",
                            "endpointNames": [
                                "[variables('storageEndpoint')]"
                            ],
                            "isEnabled": true
                        }
                    ],
                    "fallbackRoute": {
                        "name": "$fallback",
                        "source": "DeviceMessages",
                        "condition": "true",
                        "endpointNames": [
                            "events"
                        ],
                        "isEnabled": true
                    }
                }
```

| **RoutingStorageContainer** *property* | *description*|            
| :-------------------------- | :---------------------------------------------------- |
| **connectionString**        | The connection string of the storage account.         |
| **containerName**           | The name of storage container in the storage account. | 
| **fileNameFormat**          | File name format for the blob.                        | 
| **batchFrequencyInSeconds** | Time interval in seconds at which blobs are written to storage [60,720] |
| **maxChunkSizeInBytes**     | Maximum number of bytes for each blob written to storage, between [10485760(10MB) and 524288000(500MB)]|
| **encoding**                | Encoding that is used to serialize messages to blobs.|

The **routes** property specifies the rules to route the messages to the different custom endpoint. The selection of route is based on properties attached to the message IoT device. Messages/events that are not custom routed are sent to the default endpoint. 

By default, messages routed to the storage container have the following blob file name format {iotHub}/{partition}/{YYYY}/{MM}/{DD}/{HH}/{mm}. 
All parameters {iotHub}, {partition}, {YYYY}, {MM}, {DD}, {HH}, and {mm} are mandatory but can be reordered.

The fallback route sends all the messages/events that don't satisfy query conditions on any of the existing routes to the built-in-Event Hubs, that is compatible with Event Hubs. If message routing is turned on, you can enable the fallback route capability. Once a route is created, data stops flowing to the built-in-endpoint, unless a route is created to that endpoint. If there are no routes to the built-in-endpoint and a fallback route is enabled, only messages that don't match any query conditions on routes will be sent to the built-in-endpoint. Also, if all existing routes are deleted, fallback route must be enabled to receive all data at the built-in-endpoint.

**NOTE: If you're using message routing and you disable this fallback route, messages that don't match any routing query are dropped.**


[![3]][3]

To apply message routing query based on message body, the following conditions are required:
1. the message has to be JSON 
2. the message needs to be encoded in either UTF-8, UTF-16 or UTF-32
3. the contentType must be set to "application/JSON" 
If these properties are not specified, IoT Hub won't evaluate the query expression on the message body.

When the IoT hub is deployed, it is possible to get the public endpoint of IoT Hub:

```powershell
PS C:\> Resolve-DnsName exHub-gure3apqd6cju.azure-devices.net

Name                           Type   TTL   Section    NameHost
----                           ----   ---   -------    --------
exHub-gure3apqd6cju.azure-devi CNAME  900   Answer     ihsu-prod-db-001.cloudapp.net
ces.net

Name       : ihsu-prod-db-001.cloudapp.net
QueryType  : A
TTL        : 60
Section    : Answer
IP4Address : 40.127.132.17
```

## <a name="Manual registration IoT device"></a>2. Manual Registration of IoT device
IoT client is authorized to send messaged to the IoT Hub only is the device is registered. To make a manual registration of IoT client in IoT Hub, run the powershell command: **register-device.ps1**

Registration of IoT Hub is independent from IoT device and it can be done before writing the code for IoT client.

At the end of registration of device, the powershell script **register-device.ps1** writes the value connection string of the IoT Hub in a text file **connstring.txt**. The connection string is useful in next steps to connect the IoT client to the IoT Hub. 


## <a name="Manual registration IoT device"></a>3. IoT client
The IoT client, written in dotnet core, collects the following data:
* byte sent to the network interface (NIC) of the IoT client,
* byte received to the network interface (NIC) of the IoT client,
* the list of TCP actives connection.
To run the IoT device (client) code, we need of two parameters: name of NIC of IoT client and connection string of the IoT Hub.

To discover the name of Ethernet interface of IoT client, we can use the powershell command:
```powershel
get-netipinterface
```
The **register-device.ps1** script stores the IoT Hub connection string in the text file. The connection string can be fetched by powershell command: 
```powershell
$connString=Get-AzIotHubDeviceConnectionString -ResourceGroupName $rgName -IotHubName $iothub.Name -DeviceId $deviceId
```
The folder **iot-device** contains the IoT client files.

### <a name="Manual registration IoT device"></a>3.a Build and run the IoT client with Microsoft Visual Studio Code
Open Visual Studio Code and  edit the file **appsettings.json** stored in the folder **iot-client**. The file has the following structure:

```json
{
  "ConnectionStrings": {
    "connectionstring1": "HostName=exHub-gure3apqd6cju.azure-devices.net;DeviceId=dotnetDev1;SharedAccessKey=UPV1C5aRoS0+rtXCh3c/qgZf/2R7JRlDW3+IVSagqj8g="
  },
  "interfaces": {
    "interfaceName": "vEthernet (vSwitch1)"
  }
}
```
* **connectionstring1**: it is the connection string to connect to the IoT Hub
* **interfaceName**: it is the name of the NIC interface, running IoT client.

Set the values of **connection1** and **interfaceName** with your values.
The **appsettings.json** file is retrieved by ConfigurationBuilder() in **Microsoft.Extensions.Configuration.Json** namespace.

Inside Visual Studio Code, open a session terminal and run the commands:
```console
dotnet restore
dotnet add package Microsoft.Extensions.Configuration.Json
dotnet add package Microsoft.Azure.Devices.Client
dotnet run
```

### <a name="Manual registration IoT device"></a>3.b Build and run the IoT client with Microsoft Visual Studio 
In Visual Studio open the file **iot-device.csproj** in the folder **iot-client**; a full solution is automatically created. 

Edit the file **appsettings.json** and set your values of **connection1** and **interfaceName**.

Inside Visual Studio, open the NuGet package manager console and run the following commands:

```console
install-package Microsoft.Extensions.Configuration.Json
install-Package Microsoft.Azure.Devices.Client
```
then build the solution.

### <a name="IoT client"></a>3.c Overview of the IoT client
The purpose of client is a collection of network system counters to send in a message to the IoT hub.  
The counters byte sent, byte received in the NIC are available through:
* **NetworkInterface.GetIPv4Statistics().BytesSent**
* **NetworkInterface.GetIPv4Statistics().BytesReceived**

in **System.Net.NetworkInformation** namespace.

The list of active TCP connections are available through **IPGlobalProperties.GetIPGlobalProperties.GetActiveTcpConnections()** in **System.Net.NetworkInformation** namespace. 

The **GetActiveTcpConnections()** provides a set of pairs (LocalEndPoint, RemoteEndPoint). The list of pairs can be stored in Dictionary<string, string> or in List of tuples List<(string , string)>.

In the IoT client, all the telemetry data (byte sent, byte received, list of active TCP connections) are stored in a class:
```csharp
public class telemetry { 
        public long bytesSent { get; set; }
        public long bytesReceived { get; set; }
        public List<(string, string)> tcpConnections { get; set; }
    }
```
Using the JsonSerializer the telemetry class is converted into JSON and send to the IoT hub.


## <a name="EnableIPForwarding"></a>4. Traffic capture through ExpressRoute Microsoft peering
As best practice in production the CE1 and CE2 routers are configured to advertise via eBGP the same public network prefixes (NAT pool) to the primary and secondary link of the same ExpressRoute circuit, without AS path prepending. The traffic between on-premises and Azure pass through both of ExpressRoute physical links, in load balancing. 

In our case, we want to proof by traffic capture on the CE router, that traffic between the IoT client and IoT hub transit through the ExpressRoute Microsoft peering. It is convenient by BGP policy to force the traffic to transit through only one CE router. 

To force the traffic to pass through CE1, we can increase the AS PATH length on secondary link, by AS PATH prepending on the CE2.

[![4]][4]

In case our case the CE1 and CE2 operates with Cisco IOS-XE.

A snippet of BGP configuration on CE1 (IOS-XE router):
```console
vrf definition 10
 rd 65021:10
 address-family ipv4
 address-family ipv6
 !
interface TenGigabitEthernet0/1/0.101
 description Microsoft Peering to Azure
 encapsulation dot1Q 10 second-dot1q 101
 vrf forwarding 10
 ip address X.1.1.1 255.255.255.252
 bfd interval 300 min_rx 300 multiplier 3
 no bfd echo
 no shutdown
 !
router bgp 65021
 address-family ipv4 vrf 10
  ! MS peering
  neighbor X.1.1.2 remote-as 12076
  neighbor X.1.1.2 activate
  neighbor X.1.1.2 next-hop-self
  neighbor X.1.1.2 soft-reconfiguration inbound
 exit-address-family
```

Below a snippet of configuration on CE2 (IOS-XE):
```console
vrf definition 10
 rd 65021:10
 address-family ipv4
 address-family ipv6
 !
 interface TenGigabitEthernet0/1/0.101
  description Microsoft Peering to Azure
  encapsulation dot1Q 10 second-dot1q 101
  vrf forwarding 10
  ip address X.1.1.5 255.255.255.252
  bfd interval 300 min_rx 300 multiplier 3
  no bfd echo
  no shutdown
 !
router bgp 65021
 address-family ipv4 vrf 10
  ! MS peering
  neighbor X.1.1.6 remote-as 12076
  neighbor X.1.1.6 activate
  neighbor X.1.1.6 route-map PREPEND-1 out
  neighbor X.1.1.6 next-hop-self
  neighbor X.1.1.6 soft-reconfiguration inbound
 exit-address-family

route-map PREPEND-1 permit 10
  set as-path prepend 65021 65021
```

The firewall on-premises advertises in iBGP to the CE1 and CE2 the public advertisement prefix (NAT pool): X.198.12.64/32
IOS-XE supports traffic capture by **monitor capture** command.

The list of Cisco IOS-XE command to activate the capture on CE1 router is shown below:
```console
ip access-list extended iot-capture 
  permit ip host X.198.12.64 any
  permit ip any host X.198.12.64
 
monitor capture CAP interface TenGigabitEthernet0/1/0.101 both   
monitor capture CAP buffer circular size 3   
monitor capture CAP access-list iot-capture
show monitor capture CAP parameter
 
monitor capture CAP start
monitor capture CAP stop
show monitor capture CAP buffer brief
monitor capture CAP export tftp://10.0.0.1/CAP.pcap
```
Description of IOS-XE commands:
1. Define the location where the capture will occur:   
   **monitor capture CAP  interface GigabitEthernet0/0/1 both**

2. Define the buffer for the capture (buffer size is in MB)
   **monitor capture CAP buffer circular size 3** 

2. Associate a filter. The filter may be specified inline, or an ACL or class-map can be referenced: 
   **monitor capture CAP access-list iot-capture**
   
   Display the list of commands used to configure the capture named CAP: 
   **show monitor capture CAP parameter**

3. Start the capture: 
   **monitor capture CAP start**

4. The capture is now active. Allow it to collect the necessary data; to show captures in progress: 
   **show monitor capture**

5. Stop the capture: 
   **monitor capture CAP stop**

6. Examine the capture in a summary view: 
   **show monitor capture CAP buffer brief**

7. Examine the capture in a detailed view: 
   **show monitor capture CAP buffer detailed**

8. Examine the capture with dump packets in ASCII format:
   **show monitor capture CAP buffer dump**

9. In addition, export the capture in PCAP format for further analysis (optional): 
   **monitor capture CAP export tftp://10.0.0.1/CAP.pcap**   
  
   where 10.0.0.1 is the IP address of the tftp server.
   
   [Note: Wireshark can open exported pcap files. The capture export supports also FTP copy]

10. To clear the content of the packet buffer:  
   **monitor capture CAP clear**

11. Once the necessary data has been collected, remove the capture: 
   **no monitor capture CAP**


Below the capture in the CE1 router, by command: **show monitor capture CAP buffer brief**
```console
CE-01#show monitor capture CAP buffer brief
 ----------------------------------------------------------------------------
 #   size   timestamp     source             destination      dscp    protocol
 ----------------------------------------------------------------------------
   0  435    0.000000   X.198.12.64     ->  40.127.132.17    0  BE   TCP
   1  131    0.084988   40.127.132.17   ->  X.198.12.64      0  BE   TCP
   2   62    0.129983   X.198.12.64     ->  40.127.132.17    0  BE   TCP
   3  435    1.126993   X.198.12.64     ->  40.127.132.17    0  BE   TCP
   4  131    1.216984   40.127.132.17   ->  X.198.12.64      0  BE   TCP
   5   62    1.270983   X.198.12.64     ->  40.127.132.17    0  BE   TCP
   6  435    2.259982   X.198.12.64     ->  40.127.132.17    0  BE   TCP
   7  131    2.361981   40.127.132.17   ->  X.198.12.64      0  BE   TCP
   8   62    2.403971   X.198.12.64     ->  40.127.132.17    0  BE   TCP
   9  435    3.402980   X.198.12.64     ->  40.127.132.17    0  BE   TCP
  10  131    3.487967   40.127.132.17   ->  X.198.12.64      0  BE   TCP
  11   62    3.531971   X.198.12.64     ->  40.127.132.17    0  BE   TCP
  12  435    4.526966   X.198.12.64     ->  40.127.132.17    0  BE   TCP
  13  131    4.600967   40.127.132.17   ->  X.198.12.64      0  BE   TCP
  14   62    4.655957   X.198.12.64     ->  40.127.132.17    0  BE   TCP
  15  435    5.639967   X.198.12.64     ->  40.127.132.17    0  BE   TCP
  16  131    5.726953   40.127.132.17   ->  X.198.12.64      0  BE   TCP
  17   62    5.769950   X.198.12.64     ->  40.127.132.17    0  BE   TCP
  18  435    6.768958   X.198.12.64     ->  40.127.132.17    0  BE   TCP
  19  131    6.866996   40.127.132.17   ->  X.198.12.64      0  BE   TCP
  20   62    6.913991   X.198.12.64     ->  40.127.132.17    0  BE   TCP
  21  435    7.905996   X.198.12.64     ->  40.127.132.17    0  BE   TCP
  ....
  ....
  
```
Below a screenshot with the capture in pcap format (wireshark), exported to from CE1 route to the tftp server:

[![5]][5]

The capture shows:
* traffic between the two public IP addresses X.198.12.64 (public advertised network from CE routes to Microsoft network) and  40.127.13.17 (public endpoint of Azure IoT hub).
* destination TCP port on IoT hub is 8883
* the transport layer uses TLS 1.2
* application data protocol is mqtt 


## <a name="EnableIPForwarding"></a>5. Reading the telemetry data from your Azure IoT Hub
The folder **iot-reader-telemetry** contains rhe dotnet core project to read the event in IoT Hub.

Open the file .csproj in Visual Studio.

To read the telmetry application data in IoT hub are required:
* Event Hub name
* Event Hubs-compatible path, 
* Event Hub-compatible service primary key

Those values are stored in **appsetting.json** file:
```json
{
  "eventHubEndpoints": {
    "EventHubsCompatibleEndpoint": "sb://iothub-ns-exhub-gure-4153936-7b0c2b900d.servicebus.windows.net/",
    "EventHubName": "exhub-gure3apqd6cju"
  },
  "IotHubSasKeyName": {
    "IotHubSasKeyName": "service",
    "IotHubSasKey": "FCWSIkDxwesfu+A3TdmYeNc29M1Tj/zD3jiT8ikV38E="
  }
}
```
Retrieve the values by powershell commands:
```powershell
$iothub=Get-AzIotHub -ResourceGroupName $rgName
$iothub.Name
$iothub.Properties.EventHubEndpoints.Values.Endpoint
$primaryKey=(get-AzIotHubKey -ResourceGroupName $rgName -Name $iothub.Name -KeyName service).PrimaryKey
```
and set them in the **appsettings.json**.

In the NuGet package manager, add to the project the following packages:
```console
Install-Package Microsoft.Extensions.Configuration.Json
Install-Package Azure.Messaging.EventHubs -Version 5.2.0-preview.3
```
and build the solution.

The following screenshot shows the output as the back-end application in IoT Hub receives telemetry sent by the IoT device:

[![6]][6]

<!--Image References-->

[1]: ./media/network-diagram.png "network diagram"
[2]: ./media/event-hub-partitions.png "event Hub partitions"
[3]: ./media/iot-hub-routing.png "routing message in IoT Hub"
[4]: ./media/er-ms-peering.png "network diagram ExpressRoute Microsoft peering"
[5]: ./media/capture-ms-peering.png "capture traffic pass through ExpressRoute Microsoft peering"
[6]: ./media/read-events-iot-hub.png "telemetry data from Azure IoT Hub"
<!--Link References-->

