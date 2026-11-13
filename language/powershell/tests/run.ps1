$ErrorActionPreference = 'Stop'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "assertion failed: $Message"
    }
}

Import-Module (Join-Path $PSScriptRoot '../praxo-core-ps/praxo-core-ps.psd1') -Force

$info = Get-PraxoCoreInfo
Assert-True ($info.Version -eq '0.5.2') 'core version'
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

$mcpRejected = $false
try {
    New-PraxoMcpHttpTransport -Endpoint 'http://example.com/mcp' | Out-Null
} catch {
    $mcpRejected = $true
}
Assert-True $mcpRejected 'mcp remote plain HTTP rejected'

$script:otelCalls = [System.Collections.Generic.List[object]]::new()
$otelTransport = {
    param($request)
    $script:otelCalls.Add($request)
    $response = [Praxo.Core.OtelHttpResponse]::new()
    $response.StatusCode = 200
    $response.Body = ''
    $response
}
$otelOptions = New-PraxoOtelSinkOptions -Endpoint 'http://otel.test/v1/traces' `
    -ServiceName 'praxo-test' -AllowedDataKeys @('name')
$otelSink = New-PraxoOtelSink -Options $otelOptions -Transport $otelTransport
$otelEvent = [Praxo.Core.Event]::new('tool.call', 's1')
$otelEvent.RunId = 'run-123'
$otelEvent.At = '2026-11-10T07:00:00Z'
$otelData = [System.Text.Json.Nodes.JsonObject]::new()
$otelData['name'] = 'echo'
$otelData['secret'] = 'hidden'
$otelEvent.Data = $otelData
Send-PraxoOtelEvent -Sink $otelSink -Event $otelEvent
Assert-True ($script:otelCalls.Count -eq 1) 'otel single request'
$otelRequest = $script:otelCalls[0]
Assert-True ($otelRequest.Method -eq 'POST') 'otel method'
Assert-True ($otelRequest.Url -eq 'http://otel.test/v1/traces') 'otel url'
Assert-True ($otelRequest.Headers['content-type'] -eq 'application/json') 'otel content type'
$otelPayload = ConvertFrom-PraxoJson $otelRequest.Body
$otelResourceSpan = $otelPayload['resourceSpans'][0]
$otelResourceAttributes = $otelResourceSpan['resource']['attributes']
Assert-True ($otelResourceAttributes[0]['key'].ToString() -eq 'service.name') 'otel service key'
Assert-True ($otelResourceAttributes[0]['value']['stringValue'].ToString() -eq 'praxo-test') 'otel service name'
$otelSpan = $otelResourceSpan['scopeSpans'][0]['spans'][0]
Assert-True ($otelSpan['name'].ToString() -eq 'praxo.tool.call') 'otel span name'
Assert-True ($otelSpan['traceId'].ToString().Length -eq 32) 'otel trace id'
Assert-True ($otelSpan['spanId'].ToString().Length -eq 16) 'otel span id'
$otelSpanAttributes = @{}
foreach ($attribute in $otelSpan['attributes']) {
    $otelSpanAttributes[$attribute['key'].ToString()] =
        $attribute['value']['stringValue'].ToString()
}
Assert-True ($otelSpanAttributes['praxo.event.type'] -eq 'tool.call') 'otel event type'
Assert-True ($otelSpanAttributes['praxo.session.id'] -eq 's1') 'otel session'
Assert-True ($otelSpanAttributes['praxo.run.id'] -eq 'run-123') 'otel run'
Assert-True ($otelSpanAttributes['praxo.event.data.name'] -eq 'echo') 'otel allowed data'
Assert-True (-not $otelSpanAttributes.ContainsKey('praxo.event.data.secret')) 'otel data excluded'

$otelFailingSink = New-PraxoOtelSink -Options $otelOptions -Transport {
    param($request)
    $response = [Praxo.Core.OtelHttpResponse]::new()
    $response.StatusCode = 503
    $response.Body = 'down'
    $response
}
$otelThrown = $false
try {
    Send-PraxoOtelEvent -Sink $otelFailingSink -Event $otelEvent
} catch {
    $otelThrown = $true
    Assert-True ($_.Exception.Message -match '503') 'otel error status'
}
Assert-True $otelThrown 'otel non-2xx fails'

$document = New-PraxoDocument -Id 'doc-1' -Content 'hello:3' `
    -Metadata @{ source = 'test' } -Score 0.5
Assert-True ($document.Id -eq 'doc-1') 'retriever document id'
Assert-True ($document.Metadata['source'] -eq 'test') 'retriever document metadata'
$retriever = New-PraxoFuncRetriever -Retrieve {
    param($query, $limit)
    @(New-PraxoDocument -Id 'doc-1' -Content "${query}:${limit}" `
        -Metadata @{ source = 'test' } -Score 0.5)
}
$documents = Invoke-PraxoRetrieve -Retriever $retriever -Query 'hello' -Limit 3
Assert-True ($documents.Count -eq 1) 'retriever count'
Assert-True ($documents[0].Id -eq 'doc-1') 'retriever id'
Assert-True ($documents[0].Content -eq 'hello:3') 'retriever content'
Assert-True ($documents[0].Metadata['source'] -eq 'test') 'retriever metadata'
Assert-True ($documents[0].Score -eq 0.5) 'retriever score'

$subagentRunner = New-PraxoFuncSubagentRunner -Run {
    param($request)
    $result = [Praxo.Core.Delegation.SubagentResult]::new()
    $result.TaskId = 'task-1'
    $result.AgentId = $request.AgentId
    $result.Output = 'done'
    $result
}
$subagentManager = New-PraxoSubagentManager -Runner $subagentRunner
$subagentRequest = New-PraxoSubagentRequest -ParentSessionId 'parent' `
    -AgentId 'child' -Prompt 'do work' -Mode 'fork' `
    -Context @{ key = 'value' } `
    -History @([Praxo.Core.Message]::Text('user', 'go'))
Assert-True ($subagentRequest.Context['key'] -eq 'value') 'delegation context'
Assert-True ($subagentRequest.History.Count -eq 1) 'delegation history'
$subagentTask = Invoke-PraxoSubagent -Manager $subagentManager -Request $subagentRequest
Assert-True ($subagentTask.Status -eq [Praxo.Core.Delegation.SubagentStatus]::Completed) 'delegation completed'
Assert-True ($subagentTask.Output -eq 'done') 'delegation output'
Assert-True ($subagentTask.ParentSessionId -eq 'parent') 'delegation parent'
Assert-True ($subagentTask.AgentId -eq 'child') 'delegation agent'
Assert-True ($subagentTask.Mode -eq [Praxo.Core.Delegation.SubagentMode]::Fork) 'delegation mode'

$subagentFailingRunner = New-PraxoFuncSubagentRunner -Run {
    param($request)
    throw 'boom'
}
$subagentFailingManager = New-PraxoSubagentManager -Runner $subagentFailingRunner
$subagentFailed = Invoke-PraxoSubagent -Manager $subagentFailingManager `
    -Request $subagentRequest
Assert-True ($subagentFailed.Status -eq [Praxo.Core.Delegation.SubagentStatus]::Failed) 'delegation failed'
Assert-True ($subagentFailed.Error -match 'boom') 'delegation failure detail'

$invalidRequest = [Praxo.Core.Delegation.SubagentRequest]::new()
$invalidRequest.AgentId = 'child'
$invalidThrown = $false
try {
    Invoke-PraxoSubagent -Manager $subagentManager -Request $invalidRequest
} catch {
    $invalidThrown = $true
}
Assert-True $invalidThrown 'delegation rejects missing parent session'

Write-Output 'PowerShell core tests passed'
