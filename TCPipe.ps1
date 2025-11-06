param(
    [int]$ListenPort,
    [string]$RemoteHost,
    [int]$RemotePort
)

# Create TCP listener
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $ListenPort)
$listener.Start()
Write-Host "Listening on 0.0.0.0:$ListenPort -> $RemoteHost:$RemotePort"

function Copy-Stream {
    param($FromStream, $ToStream)
    $buffer = New-Object byte[] 8192
    try {
        while (($bytesRead = $FromStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $ToStream.Write($buffer, 0, $bytesRead)
            $ToStream.Flush()
        }
    } catch { }
}

while ($true) {
    $client = $listener.AcceptTcpClient()
    Write-Host "Client connected: $($client.Client.RemoteEndPoint)"
    
    Start-Job -ScriptBlock {
        param($clientParam, $remoteHostParam, $remotePortParam)
        
        try {
            $remote = [System.Net.Sockets.TcpClient]::new($remoteHostParam, $remotePortParam)
            $clientStream = $clientParam.GetStream()
            $remoteStream = $remote.GetStream()

            # Start bidirectional forwarding
            $job1 = Start-Job -ScriptBlock { param($fs, $ts) Copy-Stream -FromStream $fs -ToStream $ts } -ArgumentList $clientStream, $remoteStream
            $job2 = Start-Job -ScriptBlock { param($fs, $ts) Copy-Stream -FromStream $fs -ToStream $ts } -ArgumentList $remoteStream, $clientStream

            # Wait for both jobs
            Wait-Job $job1, $job2 | Out-Null

            # Cleanup
            $clientParam.Close()
            $remote.Close()
        } catch {
            Write-Host "Error: $_"
            try { $clientParam.Close() } catch {}
        }
    } -ArgumentList $client, $RemoteHost, $RemotePort
}
