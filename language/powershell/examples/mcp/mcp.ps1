$ErrorActionPreference = 'Stop'

function Invoke-McpTransport {
    param([string]$Method, [hashtable]$Params)
    switch ($Method) {
        'initialize' {
            return @{
                protocolVersion = '2024-11-05'
                serverInfo      = @{ name = 'example-mcp' }
            }
        }
        'tools/list' {
            return @{
                tools = @(
                    @{ name = 'echo'; description = 'Echo'; inputSchema = @{ type = 'object' } },
                    @{ name = 'add'; description = 'Add'; inputSchema = @{ type = 'object' } }
                )
            }
        }
        'tools/call' {
            return @{ structuredContent = @{ sum = 5 } }
        }
        default {
            return @{}
        }
    }
}

$init = Invoke-McpTransport -Method 'initialize' -Params @{}
if ($init.protocolVersion -ne '2024-11-05' -or $init.serverInfo.name -ne 'example-mcp') {
    throw 'initialize failed'
}
$tools = (Invoke-McpTransport -Method 'tools/list' -Params @{}).tools
if ($tools.Count -ne 2 -or $tools[0].name -ne 'echo' -or $tools[1].name -ne 'add') {
    throw 'tools/list failed'
}
$result = Invoke-McpTransport -Method 'tools/call' -Params @{ name = 'add' }
if ($result.structuredContent.sum -ne 5) {
    throw 'tools/call failed'
}
Write-Output 'PowerShell MCP example passed'
