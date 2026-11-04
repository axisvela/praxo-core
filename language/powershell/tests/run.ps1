$ErrorActionPreference = 'Stop'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "assertion failed: $Message"
    }
}

Import-Module (Join-Path $PSScriptRoot '../praxo-core-ps/praxo-core-ps.psd1') -Force

$info = Get-PraxoCoreInfo
Assert-True ($info.Version -eq '0.2.0') 'core version'
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
Assert-True ($decoded['value'].ToString() -eq 'x') 'checkpoint roundtrip'

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

Write-Output 'PowerShell core tests passed'
