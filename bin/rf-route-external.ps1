# ==============================================================================
# RF SaaS External Network Router
# High-performance async I/O completion port TCP proxy
# Routes external physical LAN IP (192.168.0.100:8000) -> WSL Container (8000)
# ==============================================================================
param(
    [string]$ListenIP = "192.168.0.100",
    [int]$ListenPort = 8000,
    [string]$TargetIP = "",
    [int]$TargetPort = 8000
)

# 1. Resolve Target IP (WSL Debian IP or 127.0.0.1)
if (-not $TargetIP) {
    try {
        $wslRaw = (wsl -d Debian hostname -I 2>$null)
        if ($wslRaw) {
            $candidate = ($wslRaw.Trim() -split "\s+")[0]
            if ($candidate) {
                $TargetIP = $candidate
            }
        }
    } catch {}
    if (-not $TargetIP) {
        $TargetIP = "127.0.0.1"
    }
}

# 2. Start a background keep-alive job for WSL so Windows never sleeps the VM
try {
    Start-Job -Name "WSLKeepAlive" -ScriptBlock {
        wsl -d Debian sleep infinity
    } | Out-Null
} catch {}

$source = @"
using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;

public class RfSaaSProxyV3
{
    private TcpListener _listener;
    private bool _running;
    private string _targetIp;
    private int _targetPort;

    public void Start(string listenIp, int listenPort, string targetIp, int targetPort)
    {
        _targetIp = targetIp;
        _targetPort = targetPort;
        _listener = new TcpListener(IPAddress.Parse(listenIp), listenPort);
        _listener.Server.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
        _listener.Start();
        _running = true;
        Task.Run((Func<Task>)delegate { return AcceptLoopAsync(); });
    }

    private async Task AcceptLoopAsync()
    {
        while (_running)
        {
            try
            {
                TcpClient client = await _listener.AcceptTcpClientAsync();
                Task task = ForwardAsync(client);
            }
            catch
            {
                if (!_running) break;
            }
        }
    }

    private async Task<TcpClient> ConnectTargetAsync(string targetIp, int targetPort)
    {
        // Try primary target IP
        TcpClient client = new TcpClient();
        client.NoDelay = true;
        client.LingerState = new LingerOption(false, 0);
        try
        {
            var cTask = client.ConnectAsync(targetIp, targetPort);
            if (await Task.WhenAny(cTask, Task.Delay(2000)) == cTask)
            {
                await cTask;
                return client;
            }
        }
        catch { }
        try { client.Close(); } catch { }

        // Fallback to 127.0.0.1
        client = new TcpClient();
        client.NoDelay = true;
        client.LingerState = new LingerOption(false, 0);
        try
        {
            var fbTask = client.ConnectAsync("127.0.0.1", targetPort);
            if (await Task.WhenAny(fbTask, Task.Delay(2000)) == fbTask)
            {
                await fbTask;
                return client;
            }
        }
        catch { }
        try { client.Close(); } catch { }

        return null;
    }

    private async Task ForwardAsync(TcpClient client)
    {
        using (client)
        {
            client.NoDelay = true;
            client.LingerState = new LingerOption(false, 0);

            TcpClient target = await ConnectTargetAsync(_targetIp, _targetPort);
            if (target == null)
            {
                Console.WriteLine("[Proxy Debug] Connect failed to " + _targetIp + " and 127.0.0.1");
                return;
            }

            using (target)
            {
                using (NetworkStream cs = client.GetStream())
                using (NetworkStream ts = target.GetStream())
                using (CancellationTokenSource cts = new CancellationTokenSource())
                {
                    Task t1 = RelayAsync(cs, ts, cts.Token);
                    Task t2 = RelayAsync(ts, cs, cts.Token);

                    Task finished = await Task.WhenAny(t1, t2);
                    if (finished == t1)
                    {
                        await Task.WhenAny(t2, Task.Delay(500));
                    }
                    cts.Cancel();
                    try { client.Close(); } catch { }
                    try { target.Close(); } catch { }
                }
            }
        }
    }

    private async Task RelayAsync(NetworkStream from, NetworkStream to, CancellationToken ct)
    {
        byte[] buf = new byte[32768];
        try
        {
            int read;
            while (!ct.IsCancellationRequested && (read = await from.ReadAsync(buf, 0, buf.Length, ct)) > 0)
            {
                await to.WriteAsync(buf, 0, read, ct);
                await to.FlushAsync(ct);
            }
        }
        catch { }
    }

    public void Stop()
    {
        _running = false;
        try
        {
            if (_listener != null)
            {
                _listener.Stop();
            }
        }
        catch { }
    }
}
"@

Add-Type -TypeDefinition $source -Language CSharp

$proxy = New-Object RfSaaSProxyV3
$proxy.Start($ListenIP, $ListenPort, $TargetIP, $TargetPort)

Write-Host "[RF SaaS Router] Actively routing $ListenIP`:$ListenPort -> $TargetIP`:$TargetPort (with 127.0.0.1 fallback)" -ForegroundColor Green
Write-Host "[RF SaaS Router] External Health Check: http://$ListenIP`:$ListenPort/health" -ForegroundColor Cyan
Write-Host "[RF SaaS Router] External API Docs:    http://$ListenIP`:$ListenPort/docs" -ForegroundColor Cyan

while ($true) {
    Start-Sleep -Seconds 1
}
