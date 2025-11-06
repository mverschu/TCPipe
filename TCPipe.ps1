param(
    [int]$ListenPort,
    [string]$RemoteHost,
    [int]$RemotePort
)

# Start the listener
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $ListenPort)
$listener.Start()
Write-Host "Listening on 0.0.0.0:$ListenPort -> $RemoteHost:$RemotePort"

function Accept-Loops {
    param($listenerRef, $remoteHostOuter, $remotePortOuter)

    while ($true) {
        $client = $listenerRef.AcceptTcpClient()
        Write-Host "Client connected: $($client.Client.RemoteEndPoint)"

        # Start a job per connection and pass the client and remote info as arguments
        Start-Job -ScriptBlock {
            param($clientParam, $remoteHostParam, $remotePortParam)

            # Define the copy stream routine inside the job so it's available
            function Copy-Stream-InJob {
                param($FromStream, $ToStream)
                $buffer = New-Object byte[] 8192
                try {
                    while (($bytesRead = $FromStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                        $ToStream.Write($buffer, 0, $bytesRead)
                        $ToStream.Flush()
                    }
                } catch {
                    # ignore typical disconnect errors
                }
            }

            try {
                # Use the job-local parameter names (important!)
                Write-Host "Job connecting to remote $remoteHostParam`:$remotePortParam"
                $remote = [System.Net.Sockets.TcpClient]::new($remoteHostParam, $remotePortParam)

                $clientStream = $clientParam.GetStream()
                $remoteStream = $remote.GetStream()

                # Run two thread jobs inside this job to forward both directions
                $t1 = [System.Threading.Tasks.Task]::Run({
                    Copy-Stream-InJob -FromStream $clientStream -ToStream $remoteStream
                })
                $t2 = [System.Threading.Tasks.Task]::Run({
                    Copy-Stream-InJob -FromStream $remoteStream -ToStream $clientStream
                })

                # Wait until both directions complete
                [System.Threading.Tasks.Task]::WaitAll($t1, $t2)

                $clientParam.Close()
                $remote.Close()
                Write-Host "Job finished for $($clientParam.Client.RemoteEndPoint)"
            } catch {
                Write-Host "Job error: $_"
                try { $clientParam.Close() } catch {}
            }
        } -ArgumentList $client, $remoteHostOuter, $remotePortOuter | Out-Null
    }
}

# Run accept loop on the main thread (keeps the script alive)
Accept-Loops -listenerRef $listener -remoteHostOuter $RemoteHost -remotePortOuter $RemotePort
