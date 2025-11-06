function Start-TcpProxy {
    param(
        [int]$ListenPort,
        [string]$RemoteHost,
        [int]$RemotePort
    )
    
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $ListenPort)
    $listener.Start()
    
    Write-Host "Listening on 0.0.0.0:$ListenPort -> $RemoteHost:$RemotePort"
    
    while ($true) {
        $client = $listener.AcceptTcpClient()
        Write-Host "Client connected: $($client.Client.RemoteEndPoint)"
        
        Start-Job -ScriptBlock {
            param($Client, $RemoteHost, $RemotePort)
            
            try {
                $remote = [System.Net.Sockets.TcpClient]::new($RemoteHost, $RemotePort)
                $clientStream = $Client.GetStream()
                $remoteStream = $remote.GetStream()
                
                # Bidirectional forwarding
                $clientToRemoteJob = Start-Job -ScriptBlock {
                    param($FromStream, $ToStream)
                    $buffer = New-Object byte[] 8192
                    try {
                        while (($bytesRead = $FromStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                            $ToStream.Write($buffer, 0, $bytesRead)
                            $ToStream.Flush()
                        }
                    } catch { }
                } -ArgumentList $clientStream, $remoteStream
                
                $remoteToClientJob = Start-Job -ScriptBlock {
                    param($FromStream, $ToStream)
                    $buffer = New-Object byte[] 8192
                    try {
                        while (($bytesRead = $FromStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                            $ToStream.Write($buffer, 0, $bytesRead)
                            $ToStream.Flush()
                        }
                    } catch { }
                } -ArgumentList $remoteStream, $clientStream
                
                # Wait for both forwarding jobs to complete
                $clientToRemoteJob | Wait-Job | Out-Null
                $remoteToClientJob | Wait-Job | Out-Null
                
                # Clean up
                $clientToRemoteJob | Remove-Job -Force
                $remoteToClientJob | Remove-Job -Force
                
                $Client.Close()
                $remote.Close()
            }
            catch {
                Write-Error "Error: $($_.Exception.Message)"
                try { $Client.Close() } catch { }
            }
        } -ArgumentList $client, $RemoteHost, $RemotePort
    }
}

# Usage:
# Start-TcpProxy -ListenPort 8080 -RemoteHost "example.com" -RemotePort 80
