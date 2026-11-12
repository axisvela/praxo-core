$ErrorActionPreference = 'Stop'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "assertion failed: $Message"
    }
}

Import-Module (Join-Path $PSScriptRoot '../praxo-core-ps/praxo-core-ps.psd1') -Force

$info = Get-PraxoCoreInfo
Assert-True ($info.Version -eq '0.3.1') 'core version'
Assert-True ($info.SpecVersion -eq '0.2.0') 'spec version'

$call = Get-PraxoToolCall '{"name":"echo","input":{"text":"hi"}}'
Assert-True ($call.Name -eq 'echo') 'toolcall name'
Assert-True ($call.Input['text'].ToString() -eq 'hi') 'toolcall input'
Assert-True ((Remove-PraxoToolCallMarkup 'a<tool_call name="echo">{"x":1}</tool_call>b') -eq 'ab') 'toolcall strip'

$schema = ConvertFrom-PraxoJson '{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}'
$errors = Test-PraxoJsonSchema -Schema $schema -Data ([System.Text.Json.Nodes.JsonObject]::new())
Assert-True ($errors.Count -eq 1) 'schema error count'
Assert-True ($errors[0].Path -eq '$.name') 'schema path'

$manifest = Get-PraxoPluginManifest '{"schemaVersion":1,"id":"com.example.echo","version":"1.0.0","kind":"tool.provider.v1","entrypoint":{"type":"process","command":"echo"},"protocol":"jsonrpc-2","capabilities":[],"permissions":{},"limits":{},"health":{},"isolation":"process"}'
Assert-True ($manifest.Id -eq 'com.example.echo') 'plugin manifest'

$store = New-PraxoMemoryStore
$record = New-PraxoMemoryRecord -Id 'm1' -Content 'Alpha' -CreatedAt '2026-01-01T00:00:00Z'
Add-PraxoMemoryRecord -Store $store -SessionId 's1' -Record $record
$found = Find-PraxoMemory -Store $store -SessionId 's1' -Query 'alpha' -Limit 10
Assert-True ($found.Count -eq 1) 'memory search'

Assert-True ((Get-PraxoStreamKinds).Count -eq 6) 'stream kinds'

$allowlist = New-PraxoCheckpointAllowlist
Register-PraxoCheckpointType -Allowlist $allowlist -TypeName 'spec.payload'
$payload = ConvertFrom-PraxoJson '{"value":"x"}'
$encoded = ConvertTo-PraxoCheckpoint -Allowlist $allowlist -TypeName 'spec.payload' -Value $payload
$decoded = ConvertFrom-PraxoCheckpoint -Allowlist $allowlist -Data $encoded
Assert-True ($decoded.AsObject()['value'].ToString() -eq 'x') 'checkpoint roundtrip'

$root = Join-Path ([System.IO.Path]::GetTempPath()) 'praxo-powershell-policy'
$grant = New-PraxoPathGrant -Root $root -Access 'readwrite'
$checker = New-PraxoPathChecker -Grants @($grant)
$decision = Test-PraxoPath -Checker $checker -Target (Join-Path $root 'a.txt') -Access 'read'
Assert-True ($decision.Allowed) 'path policy'

$messages = @(
    [Praxo.Core.Message]::Text('system', 'sys'),
    [Praxo.Core.Message]::Text('user', 'hello')
)
Assert-True ((Get-PraxoTokenEstimate -Messages $messages) -gt 0) 'token estimate'
$budget = New-PraxoContextBudget -MaxTokens 20 -KeepRecent 1
$compacted = Invoke-PraxoContextCompact -Budget $budget -Messages $messages
Assert-True ($compacted.Ok) 'context compact ok'

$redactor = New-PraxoPiiRedactor
$redacted = Invoke-PraxoPiiRedaction -Redactor $redactor -Text 'mail me at a@example.com'
Assert-True ($redacted -match '\[REDACTED:email\]') 'pii redaction'

$model = New-PraxoStaticModel -Content 'hello'
$options = New-PraxoAgentOptions -Model $model
$agent = New-PraxoAgent -Options $options
$session = New-PraxoSession -Id 'demo'
$result = Invoke-PraxoAgent -Agent $agent -Session $session -Prompt 'hello'
Assert-True ($result.Output -eq 'hello') 'agent output'
Assert-True ($result.Steps -eq 1) 'agent steps'

$script:harmovelaCalls = [System.Collections.Generic.List[object]]::new()
$harmovelaTransport = {
    param($request)
    $script:harmovelaCalls.Add($request)
    $response = [Praxo.Core.HarmovelaHttpResponse]::new()
    $response.StatusCode = 201
    $response.Body = ''
    $response
}
$harmovelaOptions = New-PraxoHarmovelaSinkOptions -BaseUrl 'http://harmovela.test/aep/api/'
$harmovelaSink = New-PraxoHarmovelaSink -Options $harmovelaOptions -Transport $harmovelaTransport
$harmovelaEvent = [Praxo.Core.Event]::new('tool.call', 's1')
$harmovelaEvent.RunId = 'run-123'
$harmovelaEvent.At = '2026-11-10T07:00:00Z'
$harmovelaEvent.Data = [System.Text.Json.Nodes.JsonObject]::new()
$harmovelaEvent.Data['name'] = 'echo'
Send-PraxoHarmovelaEvent -Sink $harmovelaSink -Event $harmovelaEvent
Assert-True ($script:harmovelaCalls.Count -eq 1) 'harmovela single request'
$request = $script:harmovelaCalls[0]
Assert-True ($request.Method -eq 'POST') 'harmovela method'
Assert-True ($request.Url -eq 'http://harmovela.test/aep/api/events') 'harmovela path'
Assert-True ($request.Headers['content-type'] -eq 'application/json') 'harmovela content type'
$envelope = ConvertFrom-PraxoJson $request.Body
Assert-True ($envelope['spec_version'].ToString() -eq '0.2') 'harmovela spec'
Assert-True ($envelope['id'].ToString() -eq 'run-123-1794294000000000000') 'harmovela id'
Assert-True ($envelope['type'].ToString() -eq 'tool.call') 'harmovela type'
Assert-True ($envelope['source'].ToString() -eq 'praxo-core') 'harmovela source'
Assert-True ($envelope['created_at'].ToString() -eq '2026-11-10T07:00:00.000000000Z') 'harmovela created_at'
Assert-True ($envelope['payload']['name'].ToString() -eq 'echo') 'harmovela payload data'
Assert-True ($envelope['payload']['session_id'].ToString() -eq 's1') 'harmovela payload session'
Assert-True ($envelope['payload']['run_id'].ToString() -eq 'run-123') 'harmovela payload run'

$script:harmovelaCalls.Clear()
$customOptions = New-PraxoHarmovelaSinkOptions -BaseUrl 'http://harmovela.test' -Source 'custom' -SpecVersion '0.3'
$customSink = New-PraxoHarmovelaSink -Options $customOptions -Transport $harmovelaTransport
$mergedEvent = [Praxo.Core.Event]::new('tool.call', 's1')
$mergedEvent.At = '2026-11-10T07:00:00Z'
$mergedData = [System.Text.Json.Nodes.JsonObject]::new()
$mergedData['name'] = 'echo'
$mergedData['session_id'] = 'event-side'
$mergedData['run_id'] = 'old'
$mergedEvent.Data = $mergedData
Send-PraxoHarmovelaEvent -Sink $customSink -Event $mergedEvent
$mergedEnvelope = ConvertFrom-PraxoJson $script:harmovelaCalls[0].Body
Assert-True ($mergedEnvelope['source'].ToString() -eq 'custom') 'harmovela custom source'
Assert-True ($mergedEnvelope['spec_version'].ToString() -eq '0.3') 'harmovela custom spec'
Assert-True ($mergedEnvelope['id'].ToString().StartsWith('s1-')) 'harmovela session id'
Assert-True ($mergedEnvelope['payload']['session_id'].ToString() -eq 's1') 'harmovela session override'
Assert-True ($mergedEnvelope['payload']['run_id'].ToString() -eq 'old') 'harmovela data run retained'

foreach ($status in @(200, 201, 204, 299)) {
    $acceptedTransport = {
        param($request)
        $response = [Praxo.Core.HarmovelaHttpResponse]::new()
        $response.StatusCode = $status
        $response
    }.GetNewClosure()
    $acceptedSink = New-PraxoHarmovelaSink -Options $harmovelaOptions -Transport $acceptedTransport
    Send-PraxoHarmovelaEvent -Sink $acceptedSink -Event $harmovelaEvent
}

$failingBody = 'service down ' * 100
$failingTransport = {
    param($request)
    $response = [Praxo.Core.HarmovelaHttpResponse]::new()
    $response.StatusCode = 503
    $response.Body = $failingBody
    $response
}.GetNewClosure()
$failingSink = New-PraxoHarmovelaSink -Options $harmovelaOptions -Transport $failingTransport
$thrown = $false
try {
    Send-PraxoHarmovelaEvent -Sink $failingSink -Event $harmovelaEvent
} catch {
    $thrown = $true
    $message = $_.Exception.Message
    Assert-True ($message -match '503') 'harmovela error status'
    Assert-True ($message -match 'service down') 'harmovela error body'
    Assert-True ($message.Length -le 600) 'harmovela bounded error'
}
Assert-True $thrown 'harmovela non-2xx fails'

$fakeMcpServer = Join-Path $PSScriptRoot 'fake_mcp_server.ps1'
$mcpOptions = New-PraxoMcpServerOptions `
    -Command (Get-Command pwsh).Source `
    -Arguments @('-NoProfile', '-File', $fakeMcpServer)
$mcpTransport = New-PraxoMcpStdioTransport -Options $mcpOptions
$mcpClient = Connect-PraxoMcp -Transport $mcpTransport -ProtocolVersion '2024-11-05'
$mcpTools = Get-PraxoMcpTools -Client $mcpClient
Assert-True ($mcpTools.Count -eq 1) 'mcp tool count'
Assert-True ($mcpTools[0].Name -eq 'echo') 'mcp tool name'
$mcpResult = Invoke-PraxoMcpTool -Client $mcpClient -Name 'echo' -Arguments @{ text = 'hi' }
Assert-True ($mcpResult.ToString() -eq 'echo:hi') 'mcp tool call'
Close-PraxoMcp -Client $mcpClient

$mcpRejected = $false
try {
    New-PraxoMcpHttpTransport -Endpoint 'http://example.com/mcp' | Out-Null
} catch {
    $mcpRejected = $true
}
Assert-True $mcpRejected 'mcp remote plain HTTP rejected'

Write-Output 'PowerShell core tests passed'
