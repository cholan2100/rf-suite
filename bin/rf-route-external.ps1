# ==============================================================================
# RF SaaS External Network Router
# Native async I/O completion port TCP proxy
# Routes external physical LAN IP (192.168.0.100:8000) -> 127.0.0.1:8000
# ==============================================================================
param(
    [string]$ListenIP = "192.168.0.100",
    [int]$ListenPort = 8000,
    [string]$TargetIP = "",
    [int]$TargetPort = 8000
)

# Auto-detect target IP if not explicitly provided
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

$source = @"
using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Threading.Tasks;

public class RfSaaSProxy
{
    private TcpListener _listener;
    private bool _running;

    public void Start(string listenIp, int listenPort, string targetIp, int targetPort)
    {
        _listener = new TcpListener(IPAddress.Parse(listenIp), listenPort);
        _listener.Start();
        _running = true;
        Task.Run((Func<Task>)delegate { return AcceptLoopAsync(targetIp, targetPort); });
    }

    private async Task AcceptLoopAsync(string targetIp, int targetPort)
    {
        while (_running)
        {
            try
            {
                TcpClient client = await _listener.AcceptTcpClientAsync();
                Task task = ForwardAsync(client, targetIp, targetPort);
            }
            catch
            {
                if (!_running) break;
            }
        }
    }

    private async Task ForwardAsync(TcpClient client, string targetIp, int targetPort)
    {
        using (client)
        using (TcpClient target = new TcpClient())
        {
            try
            {
                await target.ConnectAsync(targetIp, targetPort);
                using (NetworkStream cs = client.GetStream())
                using (NetworkStream ts = target.GetStream())
                {
                    Task t1 = Task.Run((Func<Task>)delegate { return RelayAsync(cs, ts, target); });
                    Task t2 = Task.Run((Func<Task>)delegate { return RelayAsync(ts, cs, client); });
                    await Task.WhenAll(t1, t2);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("[Proxy Debug] " + ex.Message);
            }
        }
    }

    private async Task RelayAsync(NetworkStream from, NetworkStream to, TcpClient toClient)
    {
        byte[] buf = new byte[16384];
        try
        {
            int read;
            while ((read = await from.ReadAsync(buf, 0, buf.Length)) > 0)
            {
                await to.WriteAsync(buf, 0, read);
                await to.FlushAsync();
            }
            try
            {
                toClient.Client.Shutdown(SocketShutdown.Send);
            }
            catch { }
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

$proxy = New-Object RfSaaSProxy
$proxy.Start($ListenIP, $ListenPort, $TargetIP, $TargetPort)

Write-Host "[RF SaaS Router] Actively routing $ListenIP`:$ListenPort -> $TargetIP`:$TargetPort" -ForegroundColor Green
Write-Host "[RF SaaS Router] External Health Check: http://$ListenIP`:$ListenPort/health" -ForegroundColor Cyan
Write-Host "[RF SaaS Router] External API Docs:    http://$ListenIP`:$ListenPort/docs" -ForegroundColor Cyan

while ($true) {
    Start-Sleep -Seconds 1
}
