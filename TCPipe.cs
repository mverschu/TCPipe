// File: TcpProxy.cs
using System;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;

class TcpProxy
{
    static void Main(string[] args)
    {
        if (args.Length != 3)
        {
            Console.WriteLine("Usage: TCPipe.exe <listenPort> <remoteHost> <remotePort>");
            return;
        }

        int listenPort = int.Parse(args[0]);
        string remoteHost = args[1];
        int remotePort = int.Parse(args[2]);

        TcpListener listener = new TcpListener(IPAddress.Any, listenPort);
        listener.Start();
        Console.WriteLine($"Listening on 0.0.0.0:{listenPort} -> {remoteHost}:{remotePort}");

        while (true)
        {
            TcpClient client = listener.AcceptTcpClient();
            Console.WriteLine($"Client connected: {client.Client.RemoteEndPoint}");
            Task.Run(() => HandleClient(client, remoteHost, remotePort));
        }
    }

    static void HandleClient(TcpClient client, string remoteHost, int remotePort)
    {
        try
        {
            TcpClient remote = new TcpClient(remoteHost, remotePort);
            NetworkStream clientStream = client.GetStream();
            NetworkStream remoteStream = remote.GetStream();

            // Bidirectional forwarding
            Task t1 = Task.Run(() => CopyStream(clientStream, remoteStream));
            Task t2 = Task.Run(() => CopyStream(remoteStream, clientStream));

            Task.WaitAll(t1, t2);

            client.Close();
            remote.Close();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error: {ex.Message}");
            try { client.Close(); } catch { }
        }
    }

    static void CopyStream(NetworkStream from, NetworkStream to)
    {
        byte[] buffer = new byte[8192];
        try
        {
            int bytesRead;
            while ((bytesRead = from.Read(buffer, 0, buffer.Length)) > 0)
            {
                to.Write(buffer, 0, bytesRead);
                to.Flush();
            }
        }
        catch { } // Ignore errors (closed stream, etc.)
    }
}
