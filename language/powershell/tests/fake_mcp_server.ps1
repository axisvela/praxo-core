$ErrorActionPreference = 'Stop'

while ($null -ne ($line = [Console]::In.ReadLine())) {
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }
    $message = $line | ConvertFrom-Json
    $method = $message.method
    if ($method -eq 'notifications/initialized') {
        continue
    }
    if ($method -eq 'initialize') {
        $response = @{
            jsonrpc = '2.0'
            id      = $message.id
            result  = @{
                protocolVersion = '2024-11-05'
                capabilities    = @{}
                serverInfo      = @{ name = 'fake'; version = '1' }
            }
        }
    }
    elseif ($method -eq 'tools/list') {
        $response = @{
            jsonrpc = '2.0'
            id      = $message.id
            result  = @{
                tools = @(@{
                    name        = 'echo'
                    description = 'Echo input'
                    inputSchema = @{
                        type       = 'object'
                        properties = @{ text = @{ type = 'string' } }
                        required   = @('text')
                    }
                })
            }
        }
    }
    elseif ($method -eq 'tools/call') {
        $text = [string]$message.params.arguments.text
        $response = @{
            jsonrpc = '2.0'
            id      = $message.id
            result  = @{
                content = @(@{ type = 'text'; text = "echo:$text" })
            }
        }
    }
    else {
        $response = @{
            jsonrpc = '2.0'
            id      = $message.id
            error   = @{ code = -32601; message = 'method not found' }
        }
    }
    [Console]::Out.WriteLine(($response | ConvertTo-Json -Compress -Depth 20))
    [Console]::Out.Flush()
}
