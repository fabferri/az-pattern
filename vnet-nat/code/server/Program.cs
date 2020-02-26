using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Sockets;
using System.Text;

namespace server
{

    class Program
    {
        // Create a TCP/IP socket.  
        private static readonly Socket serverSocket = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
        private static readonly List<Socket> clientSockets = new List<Socket>();
        private const int BUFFER_SIZE = 1048;
        private static int PORT = 6000;
        private static readonly byte[] buffer = new byte[BUFFER_SIZE];

        static void Main(string[] args)
        {
            if (args.Length != 0)
            {
                PORT = Int32.Parse(args[0]);
            }
            Console.Title = "Server";
            Console.WriteLine("server listen on port: {0}", PORT);
            SetupServer();
            Console.ReadLine(); // When we press enter close everything
            CloseAllSockets();
        }

        private static void SetupServer()
        {
            Console.WriteLine("Setting up server...");
            IPEndPoint localEndPoint = new IPEndPoint(IPAddress.Any, PORT);
            
            // Bind the socket to the local endpoint and listen for incoming connections.  
            serverSocket.Bind(localEndPoint);
            serverSocket.Listen(0);

            serverSocket.BeginAccept(AcceptCallback, null);
            Console.WriteLine("Server setup complete");
        }

        /// <summary>
        /// Close all connected client (we do not need to shutdown the server socket as its connections
        /// are already closed with the clients).
        /// </summary>
        private static void CloseAllSockets()
        {
            foreach (Socket socket in clientSockets)
            {
                socket.Shutdown(SocketShutdown.Both);
                socket.Close();
            }
            serverSocket.Close();
        }

        private static void AcceptCallback(IAsyncResult ar)
        {
            Socket socket;

            try
            {
                socket = serverSocket.EndAccept(ar);
            }
            catch (ObjectDisposedException) // I cannot seem to avoid this (on exit when properly closing sockets)
            {
                return;
            }

            clientSockets.Add(socket);
            socket.BeginReceive(buffer, 0, BUFFER_SIZE, SocketFlags.None, ReceiveCallback, socket);
            Console.WriteLine("Client connected, waiting for request...");
            serverSocket.BeginAccept(AcceptCallback, null);
        }

        private static void ReceiveCallback(IAsyncResult ar)
        {
            // Get the socket that handles the client request. 
            Socket current = (Socket)ar.AsyncState;
            int received;

            try
            {
                received = current.EndReceive(ar);
            }
            catch (SocketException)
            {
                Console.WriteLine("Client forcefully disconnected");
                // Don't shutdown because the socket may be disposed and its disconnected anyway.
                current.Close();
                clientSockets.Remove(current);
                return;
            }
            if (received > 0)
            {
                byte[] recBuf = new byte[received];
                Array.Copy(buffer, recBuf, received);
                string text = Encoding.ASCII.GetString(recBuf);
                Console.ForegroundColor = ConsoleColor.Green;
                string remotePort = ((IPEndPoint)current.RemoteEndPoint).Port.ToString();
                string remoteIpEndPoint = (current.RemoteEndPoint as IPEndPoint).Address.ToString();
                string stringReceived = text; // + " | remoteIP:" + remoteIpEndPoint + ", remotePort: " + remotePort;
                Console.WriteLine("Received: " + stringReceived);
                Console.ResetColor();

                if (text.ToLower() == "exit") // Client wants to exit gracefully
                {
                    // Always Shutdown before closing
                    current.Shutdown(SocketShutdown.Both);
                    current.Close();
                    clientSockets.Remove(current);
                    Console.WriteLine("Client disconnected");
                    return;
                }
                // DateTime currentTime = DateTime.Now;

                // to get the full datetime specify "dd-MMMM-yyyy HH:mm:ss.fff"
                string currentTime = DateTime.Now.ToString("HH:mm:ss.fff", System.Globalization.CultureInfo.InvariantCulture);
                string substringToSend= text.Substring(0, text.IndexOf('|'));
                string stringToSend = substringToSend + "| remoteIP:" + remoteIpEndPoint + ", remotePort: " + remotePort;
                

                Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine("Send....: {0}", stringToSend);
                Console.ResetColor();
                byte[] data = Encoding.ASCII.GetBytes(stringToSend);
                current.Send(data);
                
                 
            }

            current.BeginReceive(buffer, 0, BUFFER_SIZE, SocketFlags.None, ReceiveCallback, current);
        }
    }
}

