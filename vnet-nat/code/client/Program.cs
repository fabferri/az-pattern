// https://stackoverflow.com/questions/9397729/how-do-you-get-list-of-running-threads-in-c
// https://paulselles.wordpress.com/2014/02/12/task-parallelism-passing-values-into-a-tasks/
// https://stackoverflow.com/questions/8127316/passing-a-method-parameter-using-task-factory-startnew
// https://stackoverflow.com/questions/1584062/how-to-wait-for-thread-to-finish-with-net
// https://docs.microsoft.com/en-us/dotnet/api/system.threading.cancellationtokensource?view=netframework-4.8
// https://docs.microsoft.com/en-us/dotnet/api/system.threading.tasks.task.waitall?view=netframework-4.8
// https://docs.microsoft.com/en-us/dotnet/api/system.threading.tasks.taskfactory.startnew?view=netframework-4.8#System_Threading_Tasks_TaskFactory_StartNew_System_Action_System_Object__System_Object_System_Threading_CancellationToken_System_Threading_Tasks_TaskCreationOptions_System_Threading_Tasks_TaskScheduler_
using System;
using System.Net.Sockets;
using System.Net;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Collections.Generic;

namespace client
{
    class Program
    {
    //    private static readonly Socket ClientSocket = new Socket
    //        (AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);

        private static int PORT = 6000;
        private static int sleepingTime = 60000; // sleeping time in msec
        private static IPAddress ipAddressServer = IPAddress.Loopback;
        private static int numTasks = 20; 
        static void Main(string[] args)
        {
            var tasks = new List<Task>();
            if (args.Length != 0)
            {
                    try
                    {
                        ipAddressServer = IPAddress.Parse(args[0]);
                    }
                    catch (FormatException e)
                    {
                        Console.WriteLine("error to convert parse IP address: {0}", e.Message);
                    }
                if (args.Length == 2)
                {
                    PORT = Int32.Parse(args[1]);
                }
                if(args.Length == 3)
                {
                    PORT = Int32.Parse(args[1]);
                    numTasks = Int32.Parse(args[2]);
                }
                if (args.Length == 4)
                {
                    PORT = Int32.Parse(args[1]);
                    numTasks = Int32.Parse(args[2]);
                    sleepingTime = Int32.Parse(args[3]);
                }
            }
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("server.exe <remoteIP> <remotePort> <NumTasks> <sleepTime-in msec>");
            Console.WriteLine("server.exe {0} {1} {2} {3}", ipAddressServer, PORT, numTasks, sleepingTime);
            Console.ResetColor();
            Console.Write("Press <Enter> to continue - any other key to exit");
            if (Console.ReadKey().Key != ConsoleKey.Enter) { System.Environment.Exit(1); }

            // Construct started tasks
            for (int i = 0; i < numTasks; i++)
            {
                int index = i;
                tasks.Add(Task.Factory.StartNew((Object obj) =>
                {
                    var data = (dynamic)obj;
                    doStuff(data.id);
                },
                    new { id = index }
                ) );
            }
            try
            {
                Task.WaitAll(tasks.ToArray());
            }
            catch (AggregateException e)
            {
                foreach (var ie in e.InnerExceptions)
                {
                    if (ie is OperationCanceledException)
                    {
                        Console.WriteLine("The word scrambling operation has been cancelled.");
                        break;
                    }
                    else
                    {
                        Console.WriteLine(ie.GetType().Name + ": " + ie.Message);
                    }
                }
            }
            finally
            {
            }
        }
        static void doStuff(int i)
        {
             Socket ClientSocket = new Socket
            (AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);

            // Returns the ID of the currently executing Task
            // Thread.ManagedThreadId : Gets a unique identifier for the current managed thread.
            Console.WriteLine("Task={0}, i={1}, Thread={2}", Task.CurrentId, i,  Thread.CurrentThread.ManagedThreadId);
            
            //do stuff here
            Console.Title = "Client ";
            Console.WriteLine("connect to the server: {0} port {1}", ipAddressServer, PORT);
            ConnectToServer(ClientSocket);
            RequestLoop(ClientSocket);
            Exit(ClientSocket);
        }
        private static void ConnectToServer(Socket ClientSocket)
        {
            int attempts = 0;

            while (!ClientSocket.Connected)
            {
                try
                {
                    attempts++;
                    Console.WriteLine("Connection attempt " + attempts);
                    // Change IPAddress.Loopback to a remote IP to connect to a remote host.
                    //   ClientSocket.Connect(IPAddress.Loopback, PORT);
                    ClientSocket.Connect(ipAddressServer, PORT);
                }
                catch (SocketException)
                {
                    Console.Clear();
                }
            }

            // Console.Clear();
            Console.WriteLine("Connected");
        }

        private static void RequestLoop(Socket ClientSocket)
        {
            Random random = new Random();
            while (true)
            {
                SendRequest( ClientSocket);
                ReceiveResponse( ClientSocket);
                int sendingInterval = random.Next(sleepingTime - (int)(sleepingTime * 0.1), sleepingTime + (int)(sleepingTime * 0.1));
                Thread.Sleep(sendingInterval);
            }
        }

        /// <summary>
        /// Close socket and exit program.
        /// </summary>
        private static void Exit(Socket ClientSocket)
        {
            SendString(ClientSocket, "exit"); // Tell the server we are exiting
            ClientSocket.Shutdown(SocketShutdown.Both);
            ClientSocket.Close();
            Environment.Exit(0);
        }

        private static void SendRequest(Socket ClientSocket)
        {
            string remotePort = ((IPEndPoint)ClientSocket.RemoteEndPoint).Port.ToString();
            string remoteIpEndPoint = (ClientSocket.RemoteEndPoint as IPEndPoint).Address.ToString();
            string taskinfo = "TaskId=" + Task.CurrentId.ToString() + " ThreadId= " + Thread.CurrentThread.ManagedThreadId.ToString();

            // to get the full date "dd-MMMM-yyyy hh:mm:ss.fff"
            //string request = DateTime.Now.ToString("HH:mm:ss.fff", System.Globalization.CultureInfo.InvariantCulture) + taskinfo;
            string request = taskinfo+ " | remoteIP:" + remoteIpEndPoint + ", remotePort: " + remotePort;
            Console.ForegroundColor = ConsoleColor.Cyan;
            
            Console.WriteLine("Send....: {0}", request);
            Console.ResetColor();
            SendString(ClientSocket, request);

            if (request.ToLower() == "exit")
            {
                Exit(ClientSocket);
            }
            
        }

        /// <summary>
        /// Sends a string to the server with ASCII encoding.
        /// </summary>
        private static void SendString(Socket ClientSocket, string text)
        {
            byte[] buffer = Encoding.ASCII.GetBytes(text);
            ClientSocket.Send(buffer, 0, buffer.Length, SocketFlags.None);
        }

        private static void ReceiveResponse(Socket ClientSocket)
        {
            var buffer = new byte[2048];
            int received = ClientSocket.Receive(buffer, SocketFlags.None);
            if (received == 0) return;
            var data = new byte[received];
            Array.Copy(buffer, data, received);
            string text = Encoding.ASCII.GetString(data);
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("Received: {0}", text);
            Console.ResetColor();
        }
    }
}
