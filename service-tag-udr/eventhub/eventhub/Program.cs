// https://github.com/Azure/azure-sdk-for-net/tree/main/sdk/eventhub/Azure.Messaging.EventHubs/samples
// https://github.com/Azure/azure-sdk-for-net/blob/main/sdk/eventhub/Azure.Messaging.EventHubs/samples/Sample04_PublishingEvents.md

// When publishing, there is a limit to the size (in bytes) that can be sent to the Event Hubs service in a single operation.
// To accurately determine the size of an event, it must be measured in the format used by the active protocol as well as account for overhead.
// The size limit is controlled by the Event Hubs service and differs for different types of Event Hub instances.
// Because of this and because there is no accurate way for an application to calculate the size of an event, the client library offers the EventDataBatch to help.
// The EventDataBatch exists to provide a deterministic and accurate means to measure the size of a message sent to the service, minimizing the chance that a publishing operation will fail. 
// Because the batch works in cooperation with the service, it has an understanding of the maximum size and has the ability to measure the exact size of an event when serialized for publishing. 
// For the majority of scenarios, we recommend using the EventDataBatch to ensure that your application does not attempt to publish a set of events larger than the Event Hubs service allows. 
// All of the events that belong to an EventDataBatch are considered part of a single unit of work. When a batch is published, the result is atomic; either publishing was successful for all events in the batch, or it has failed for all events.
// Partial success or failure when publishing a batch is not possible.


using System;
using System.Text;
using System.IO;
using Microsoft.Extensions.Configuration;


using System.Threading;
using System.Threading.Tasks;
using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Producer;

using Azure.Messaging.EventHubs.Consumer;
using System.Linq;

namespace eventhub
{
    class Program
    {
        // connection string to the Event Hubs namespace
        private static string connectionString = "";

        // name of the event hub
        private static string eventHubName = "";

        // number of events to be sent to the event hub
        private static int numOfEvents = 10;

        // The Event Hubs client types are safe to cache and use as a singleton for the lifetime
        // of the application, which is best practice when events are being published or read regularly.
        static EventHubProducerClient producerClient;

        // get the value of connection string and event hub name from the .json file
        private static void GetParameters()
        {
            var builder = new ConfigurationBuilder()
               .SetBasePath(Directory.GetCurrentDirectory())
               .AddJsonFile("json1.json", optional: true, reloadOnChange: true);
            connectionString = builder.Build().GetSection("connectionString").Value;
            eventHubName = builder.Build().GetSection("eventHubName").Value;
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("pickup values from .json file");
            Console.WriteLine("   connection string: {0}", connectionString);
            Console.WriteLine("   event hub name: {0}", eventHubName);
            return;
        }

        // create events in firt partition
        private static async Task GenerateEventsPartition1(string connectionString, string eventHubName)
        {
            // Create a producer client that you can use to send events to an event hub
            producerClient = new EventHubProducerClient(connectionString, eventHubName);

            // get the first partition
            string firstPartition = (await producerClient.GetPartitionIdsAsync()).First();

            var batchOptions1 = new CreateBatchOptions
            {
                PartitionId = firstPartition
            };

            // Create a batch of events 
            using EventDataBatch eventBatch = await producerClient.CreateBatchAsync(batchOptions1);

            for (int i = 1; i <= numOfEvents; i++)
            {
                string time = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
                if (!eventBatch.TryAdd(new EventData(Encoding.UTF8.GetBytes($"{time} - Event {i}"))))
                {
                    // if it is too large for the batch
                    throw new Exception($"Event {i} is too large for the batch and cannot be sent.");
                }
            }
            try
            {
                // Use the producer client to send the batch of events to the event hub
                await producerClient.SendAsync(eventBatch);
                Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine("A batch of {0} events has been published.", numOfEvents.ToString());
                Console.ResetColor();
            }
            finally
            {
                await producerClient.DisposeAsync();
            }
        }

        // create events in first partition
        private static async Task GenerateEventsPartition2(string connectionString, string eventHubName)
        {
            // Create a producer client that you can use to send events to an event hub
            producerClient = new EventHubProducerClient(connectionString, eventHubName);

            // get the first partition
            string secondPartition = (await producerClient.GetPartitionIdsAsync()).Skip(1).First();

            var batchOptions2 = new CreateBatchOptions
            {
                PartitionId = secondPartition
            };

            // Create a batch of events 
            using EventDataBatch eventBatch = await producerClient.CreateBatchAsync(batchOptions2);

            for (int i = 1; i <= numOfEvents; i++)
            {
                string time = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");

                if (!eventBatch.TryAdd(new EventData(Encoding.UTF8.GetBytes($"{time} - Event {i}"))))
                {
                    // if it is too large for the batch
                    throw new Exception($"Event {i} is too large for the batch and cannot be sent.");
                }
            }
            try
            {
                // Use the producer client to send the batch of events to the event hub
                await producerClient.SendAsync(eventBatch);
                Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine("A batch of {0} events has been published.", numOfEvents.ToString());
                Console.ResetColor();
            }
            finally
            {
                await producerClient.DisposeAsync();
            }
        }


        private static async Task ReadEventsPartition1(string connectionString,string eventHubName)
        {
            // Reading Events
            // The ReadEventsAsync method of the EventHubConsumerClient allows events to be read from each partition 
            var consumerGroup = EventHubConsumerClient.DefaultConsumerGroupName;
            var consumer = new EventHubConsumerClient(
                consumerGroup,
                connectionString,
                eventHubName);
            try
            {

                // Reading events
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("Read events from partition 0");

                using CancellationTokenSource cancellationSource = new CancellationTokenSource();

                string firstPartition = (await consumer.GetPartitionIdsAsync(cancellationSource.Token)).First();
                EventPosition startingPosition = EventPosition.Earliest;

                int loopTicks = 0;
                int maximumTicks = 100;

                var options = new ReadEventOptions
                {
                    MaximumWaitTime = TimeSpan.FromSeconds(5)
                };

                await foreach (PartitionEvent partitionEvent in consumer.ReadEventsFromPartitionAsync(
                    firstPartition,
                    startingPosition,
                    options))
                {
                    if (partitionEvent.Data != null)
                    {
                        string readFromPartition = partitionEvent.Partition.PartitionId;
                        byte[] eventBodyBytes = partitionEvent.Data.EventBody.ToArray();
                        string eventContent = Encoding.UTF8.GetString(eventBodyBytes);
                        Console.WriteLine($"Read event of length { eventBodyBytes.Length } from { readFromPartition }, Received event: {eventContent}");
                    }
                    else
                    {
                        Console.WriteLine("Wait time elapsed; no event was available.");
                        break;
                    }

                    loopTicks++;

                    if (loopTicks >= maximumTicks)
                    {
                        break;
                    }
                }
            }
            catch (TaskCanceledException)
            {
                // This is expected if the cancellation token is
                // signaled.
            }
            finally
            {
                await consumer.CloseAsync();
            }
        }
        private static async Task ReadEventsPartition2(string connectionString, string eventHubName)
        {
            // Reading Events
            // The ReadEventsAsync method of the EventHubConsumerClient allows events to be read from each partition 
            var consumerGroup = EventHubConsumerClient.DefaultConsumerGroupName;
            var consumer = new EventHubConsumerClient(
                consumerGroup,
                connectionString,
                eventHubName);
            try
            {
                // Reading events
                using CancellationTokenSource cancellationSource = new CancellationTokenSource();
                string secondPartition = (await consumer.GetPartitionIdsAsync(cancellationSource.Token)).Skip(1).First();

                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("Read events from partition: {0}", secondPartition);

                EventPosition startingPosition = EventPosition.Earliest;

                int loopTicks = 0;
                int maximumTicks = 100;

                var options = new ReadEventOptions
                {
                    MaximumWaitTime = TimeSpan.FromSeconds(5)
                };

                await foreach (PartitionEvent partitionEvent in consumer.ReadEventsFromPartitionAsync(
                    secondPartition,
                    startingPosition,
                    options))
                {
                    if (partitionEvent.Data != null)
                    {
                        string readFromPartition = partitionEvent.Partition.PartitionId;
                        byte[] eventBodyBytes = partitionEvent.Data.EventBody.ToArray();
                        string eventContent = Encoding.UTF8.GetString(eventBodyBytes);
                        Console.WriteLine($"Read event of length { eventBodyBytes.Length } from { readFromPartition }, Received event: {eventContent}");
                    }
                    else
                    {
                        Console.WriteLine("Wait time elapsed; no event was available.");
                        break;
                    }

                    loopTicks++;

                    if (loopTicks >= maximumTicks)
                    {
                        break;
                    }
                }
            }
            catch (TaskCanceledException)
            {
                // This is expected if the cancellation token is
                // signaled.
            }
            finally
            {
                await consumer.CloseAsync();
            }
        }
        static async Task Main()
        {
            GetParameters();
            await GenerateEventsPartition1(connectionString, eventHubName);
            await GenerateEventsPartition2(connectionString, eventHubName);
            await ReadEventsPartition1(connectionString, eventHubName);
            await ReadEventsPartition2(connectionString, eventHubName);
            Console.ResetColor();
        }
    }
}
