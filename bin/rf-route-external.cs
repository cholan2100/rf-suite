using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;

public class Program
{
    private static TcpListener _listener;
    private static bool _running = true;
    private static string _targetIp = "127.0.0.1";
    private static int _targetPort = 8000;
    private static long _connCount = 0;

    public static void Main(string[] args)
    {
        string listenIp = "0.0.0.0";
        int listenPort = 8000;

        if (args.Length > 0 && !string.IsNullOrEmpty(args[0]))
            listenIp = args[0];
        if (args.Length > 1 && !string.IsNullOrEmpty(args[1]))
            listenPort = int.Parse(args[1]);
        if (args.Length > 2 && !string.IsNullOrEmpty(args[2]))
            _targetIp = args[2];
        if (args.Length > 3 && !string.IsNullOrEmpty(args[3]))
            _targetPort = int.Parse(args[3]);

        Console.CancelKeyPress += (s, e) => {
            _running = false;
            try { _listener.Stop(); } catch {}
        };

        try
        {
            _listener = new TcpListener(IPAddress.Parse(listenIp), listenPort);
            _listener.Server.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
            _listener.Start();
        }
        catch (Exception ex)
        {
            Console.WriteLine("[Fatal Error] Failed to bind " + listenIp + ":" + listenPort + " - " + ex.Message);
            return;
        }

        Console.WriteLine("[RF SaaS Router] Standalone TCP Router Online");
        Console.WriteLine("[RF SaaS Router] Listening on:   " + listenIp + ":" + listenPort);
        Console.WriteLine("[RF SaaS Router] Target Backend: " + _targetIp + ":" + _targetPort + " (with 127.0.0.1 fallback)");
        Console.WriteLine("[RF SaaS Router] Ready for local and external LAN connections.");

        AcceptLoopAsync().Wait();
    }

    private static async Task AcceptLoopAsync()
    {
        while (_running)
        {
            try
            {
                TcpClient client = await _listener.AcceptTcpClientAsync();
                long id = Interlocked.Increment(ref _connCount);
                Task t = ForwardAsync(client, id);
            }
            catch
            {
                if (!_running) break;
            }
        }
    }

    private static async Task<TcpClient> ConnectBackendAsync()
    {
        // 1. Try primary target IP
        TcpClient client = new TcpClient();
        client.NoDelay = true;
        client.LingerState = new LingerOption(false, 0);
        try
        {
            var task = client.ConnectAsync(_targetIp, _targetPort);
            if (await Task.WhenAny(task, Task.Delay(2000)) == task)
            {
                await task;
                return client;
            }
        }
        catch {}
        try { client.Close(); } catch {}

        // 2. Fallback to 127.0.0.1
        client = new TcpClient();
        client.NoDelay = true;
        client.LingerState = new LingerOption(false, 0);
        try
        {
            var task = client.ConnectAsync("127.0.0.1", _targetPort);
            if (await Task.WhenAny(task, Task.Delay(2000)) == task)
            {
                await task;
                return client;
            }
        }
        catch {}
        try { client.Close(); } catch {}

        return null;
    }

    private static async Task ForwardAsync(TcpClient client, long id)
    {
        string remoteEp = "";
        try { remoteEp = client.Client.RemoteEndPoint.ToString(); } catch {}

        using (client)
        {
            client.NoDelay = true;
            client.LingerState = new LingerOption(false, 0);

            TcpClient target = await ConnectBackendAsync();
            if (target == null)
            {
                Console.WriteLine(string.Format("[Conn #{0} Error] Failed to connect backend for {1}", id, remoteEp));
                return;
            }

            Console.WriteLine(string.Format("[Conn #{0}] Connected: {1}", id, remoteEp));

            using (target)
            {
                target.NoDelay = true;
                target.LingerState = new LingerOption(false, 0);

                using (NetworkStream cs = client.GetStream())
                using (NetworkStream ts = target.GetStream())
                using (CancellationTokenSource cts = new CancellationTokenSource())
                {
                    Task t1 = RelayAsync(cs, ts, cts.Token);
                    Task t2 = RelayAsync(ts, cs, cts.Token);

                    Task first = await Task.WhenAny(t1, t2);
                    if (first == t1)
                    {
                        await Task.WhenAny(t2, Task.Delay(500));
                    }
                    cts.Cancel();
                    try { client.Close(); } catch {}
                    try { target.Close(); } catch {}
                }
            }

            Console.WriteLine(string.Format("[Conn #{0}] Closed: {1}", id, remoteEp));
        }
    }

    private static async Task RelayAsync(NetworkStream from, NetworkStream to, CancellationToken ct)
    {
        byte[] buf = new byte[65536];
        try
        {
            int read;
            while (!ct.IsCancellationRequested && (read = await from.ReadAsync(buf, 0, buf.Length, ct)) > 0)
            {
                await to.WriteAsync(buf, 0, read, ct);
                await to.FlushAsync(ct);
            }
        }
        catch {}
    }
}
