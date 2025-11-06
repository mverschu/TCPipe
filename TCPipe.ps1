param(
    [int]$ListenPort,
    [string]$RemoteHost,
    [int]$RemotePort
)

# Create listener
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
    } catch {
        # ignore errors
    }
}

while ($true) {
    $client = $listener.AcceptTcpClient()
    Write-Host "Client connected: $($client.Client.RemoteEndPoint)"

    try {
        $remote = [System.Net.Sockets.TcpClient]::new($RemoteHost, $RemotePort)
        $clientStream = $client.GetStream()
        $remoteStream = $remote.GetStream()

        # Bidirectional forwarding using Tasks
        $t1 = [System.Threading.Tasks.Task]::Run({ Copy-Stream $clientStream $remoteStream })
        $t2 = [System.Threading.Tasks.Task]::Run({ Copy-Stream $remoteStream $clientStream })

        # Wait until both directions complete
        [System.Threading.Tasks.Task]::WaitAll($t1, $t2)

        $client.Close()
        $remote.Close()
        Write-Host "Connection closed."
    } catch {
        Write-Host "Error: $_"
        try { $client.Close() } catch {}
    }
}
