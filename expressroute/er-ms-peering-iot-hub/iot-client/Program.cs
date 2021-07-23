// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.

// This application uses the Azure IoT Hub device SDK for .NET
// For samples see: https://github.com/Azure/azure-iot-sdk-csharp/tree/master/iothub/device/samples

using System;
using System.IO;
using Microsoft.Extensions.Configuration;

using System.Net.NetworkInformation;
using System.Threading.Tasks;

using Microsoft.Azure.Devices.Client;
using Newtonsoft.Json;
using System.Text;
using System.Globalization;
using System.Collections.Generic;

namespace iot_device
{
    public class telemetry { 
        public long bytesSent { get; set; }
        public long bytesReceived { get; set; }
        public List<(string, string)> tcpConnections { get; set; }
    }
    class Program 
    {
        private static DeviceClient s_deviceClient;
         //   private static Dictionary<string, string> currentTcpConnection = new Dictionary<string, string>();
        private static List<(string localEndPoint, string remoteEndPoint)> currentTcpConnection = new List<( string , string )>();

        private static string connectionString, interfaceName;
        
        // acquire values from the appsetting.json file:
        // - the device connection string to authenticate the device with your IoT hub
        // - the name of local NIC card to use in telemetry data
        private static void GetAppSettings()
        {
            var builder = new ConfigurationBuilder()
               .SetBasePath(Directory.GetCurrentDirectory())
               .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true);
            connectionString = builder.Build().GetSection("ConnectionStrings").GetSection("connectionString1").Value;
            interfaceName = builder.Build().GetSection("interfaces").GetSection("interfaceName").Value;
        }
        private static async void SendDeviceToCloudMessagesAsync()
        {
            // Initial telemetry values
            while (Console.KeyAvailable == false) 
            {
                long currentBytesSent = 0;
                long currentBytesReceived = 0;
                //
                if (!NetworkInterface.GetIsNetworkAvailable())
                    return;

                NetworkInterface[] interfaces = NetworkInterface.GetAllNetworkInterfaces();
                foreach (NetworkInterface ni in interfaces)
                {
                    if (ni.Name == interfaceName)
                    {
                        currentBytesSent = ni.GetIPv4Statistics().BytesSent;
                        currentBytesReceived = ni.GetIPv4Statistics().BytesReceived;
                    }
                }
                // delete all elements
                currentTcpConnection.Clear();

                // getting active TCP Connections
                IPGlobalProperties properties = IPGlobalProperties.GetIPGlobalProperties();
                TcpConnectionInformation[] connections = properties.GetActiveTcpConnections();
                foreach (TcpConnectionInformation c in connections)
                {
                    if ((c.LocalEndPoint.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork) && (c.LocalEndPoint.Address.ToString() != "127.0.0.1"))
                    {
                       //  Console.WriteLine("{0} <==> {1}", c.LocalEndPoint.ToString(), c.RemoteEndPoint.ToString());
                       // currentTcpConnection.Add(c.LocalEndPoint.ToString(), c.RemoteEndPoint.ToString());
                        currentTcpConnection.Add( (c.LocalEndPoint.ToString(), c.RemoteEndPoint.ToString()) );
                    }
                }
                var telemetryDataPoint = new telemetry()
                {
                    bytesSent = currentBytesSent,
                    bytesReceived = currentBytesReceived,
                    tcpConnections = currentTcpConnection
                };

                var messageString = JsonConvert.SerializeObject(telemetryDataPoint);
                var message = new Message(Encoding.ASCII.GetBytes(messageString));

                // Add a custom application property to the message.
                // An IoT hub can filter on these properties without access to the message body.
                message.Properties.Add("time", DateTime.Now.ToString("yy-MM-dd-HH-mm-ss", DateTimeFormatInfo.InvariantInfo));
                // uncomment the line below if you want to route to a storage account
                //  message.Properties.Add("level", "storage");

                // Send the telemetry message
                await s_deviceClient.SendEventAsync(message);
                Console.WriteLine("{0} > Sending message: {1}", DateTime.Now, messageString);
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("--------------------------------------------");
                Console.ResetColor();
                await Task.Delay(1000);
            }
        }
        static void Main(string[] args)
        {
            GetAppSettings();
            Console.WriteLine($"connection string.: {connectionString}");
            Console.WriteLine($"interface name....: {interfaceName}");

            // Connect to the IoT hub using the MQTT protocol
            s_deviceClient = DeviceClient.CreateFromConnectionString(connectionString, TransportType.Mqtt);
            // Async method to send simulated telemetry
            SendDeviceToCloudMessagesAsync();
            Console.ReadLine();
        }
    }
  
}
