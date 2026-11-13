$script:PraxoCoreDll = $null
$script:PraxoAdapterExports = @(); foreach ($adapter in @('Otel', 'Retriever', 'Delegation')) { . (Join-Path $PSScriptRoot "adapters/$adapter.ps1") }
function Get-PraxoCoreDllPath {
    if ($env:PRAXO_CORE_DLL) {
        return $env:PRAXO_CORE_DLL
    }
    $candidates = @(
        (Join-Path $PSScriptRoot 'Praxo.Core.dll'),
        (Join-Path $PSScriptRoot '../../../language/csharp/Praxo.Core/bin/Release/net8.0/Praxo.Core.dll'),
        (Join-Path $PSScriptRoot '../../../language/csharp/Praxo.Core/bin/Debug/net8.0/Praxo.Core.dll')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }
    throw 'Praxo.Core.dll not found. Build language/csharp/Praxo.Core or set PRAXO_CORE_DLL.'
}

function Import-PraxoCoreAssembly {
    if ($script:PraxoCoreDll) {
        return
    }
    $path = Get-PraxoCoreDllPath
    Add-Type -Path $path
    $script:PraxoCoreDll = $path
}

function Get-PraxoCoreInfo {
    Import-PraxoCoreAssembly
    [pscustomobject]@{
        Name = 'PraxoCore'
        Version = (Get-Content (Join-Path $PSScriptRoot '../VERSION') -Raw).Trim()
        SpecVersion = (Get-Content (Join-Path $PSScriptRoot '../../../spec/SPEC_VERSION') -Raw).Trim()
        Assembly = $script:PraxoCoreDll
        Runtime = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
    }
}

function New-PraxoStaticModel {
    param([Parameter(Mandatory = $true)][string]$Content)
    Import-PraxoCoreAssembly
    [Praxo.Core.StaticModel]::new($Content)
}

function New-PraxoSession {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [object[]]$Messages = @()
    )
    Import-PraxoCoreAssembly
    $session = [Praxo.Core.Session]::new($Id)
    foreach ($message in $Messages) {
        $session.Messages.Add($message)
    }
    $session
}

function New-PraxoAgentOptions {
    param([Parameter(Mandatory = $true)]$Model)
    Import-PraxoCoreAssembly
    [Praxo.Core.AgentOptions]::new($Model)
}

function New-PraxoAgent {
    param([Parameter(Mandatory = $true)]$Options)
    Import-PraxoCoreAssembly
    [Praxo.Core.Agent]::new($Options)
}

function Invoke-PraxoAgent {
    param(
        [Parameter(Mandatory = $true)]$Agent,
        [Parameter(Mandatory = $true)]$Session,
        [Parameter(Mandatory = $true)][string]$Prompt
    )
    $Agent.Run($Session, $Prompt)
}

function Invoke-PraxoAgentStream {
    param(
        [Parameter(Mandatory = $true)]$Agent,
        [Parameter(Mandatory = $true)]$Session,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][scriptblock]$OnDelta
    )
    $action = [System.Management.Automation.LanguagePrimitives]::ConvertTo(
        $OnDelta,
        [System.Action[string]]
    )
    $Agent.RunStream($Session, $Prompt, $action)
}

function New-PraxoToolRegistry {
    Import-PraxoCoreAssembly
    [Praxo.Core.ToolRegistry]::new()
}

function New-PraxoFuncTool {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Description = '',
        [Parameter(Mandatory = $true)][scriptblock]$Invoke
    )
    Import-PraxoCoreAssembly
    $function = [System.Management.Automation.LanguagePrimitives]::ConvertTo(
        $Invoke,
        [System.Func[System.Text.Json.Nodes.JsonObject, System.Text.Json.Nodes.JsonNode]]
    )
    [Praxo.Core.FuncTool]::new($Name, $Description, $function)
}

function Register-PraxoTool {
    param(
        [Parameter(Mandatory = $true)]$Registry,
        [Parameter(Mandatory = $true)]$Tool
    )
    $Registry.Register($Tool)
    $Tool
}

function ConvertFrom-PraxoJson {
    param([Parameter(Mandatory = $true)][string]$Text)
    Import-PraxoCoreAssembly
    Write-Output -NoEnumerate ([Praxo.Core.Json]::Parse($Text))
}

function ConvertTo-PraxoJson {
    param([Parameter(Mandatory = $true)]$Node)
    Import-PraxoCoreAssembly
    [Praxo.Core.Json]::Stringify($Node)
}

function Test-PraxoJsonSchema {
    param(
        [Parameter(Mandatory = $true)]$Schema,
        [AllowNull()]$Data
    )
    Import-PraxoCoreAssembly
    [Praxo.Core.JsonSchema]::Validate($Schema, $Data)
}

function Get-PraxoToolCall {
    param([Parameter(Mandatory = $true)][string]$Content)
    Import-PraxoCoreAssembly
    [Praxo.Core.ToolCallParser]::Parse($Content)
}

function Remove-PraxoToolCallMarkup {
    param([Parameter(Mandatory = $true)][string]$Content)
    Import-PraxoCoreAssembly
    [Praxo.Core.ToolCallParser]::StripMarkup($Content)
}

function Get-PraxoPluginManifest {
    param([Parameter(Mandatory = $true)][string]$Raw)
    Import-PraxoCoreAssembly
    [Praxo.Core.Plugin]::ParseManifest($Raw)
}

function New-PraxoMemoryRecord {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Content,
        [string]$Frame = '',
        [string]$CreatedAt = ''
    )
    Import-PraxoCoreAssembly
    $record = [Praxo.Core.MemoryRecord]::new()
    $record.Id = $Id
    $record.Content = $Content
    $record.Frame = $Frame
    if ($CreatedAt) {
        $record.CreatedAt = $CreatedAt
    }
    $record
}

function New-PraxoMemoryStore {
    Import-PraxoCoreAssembly
    [Praxo.Core.InMemoryMemoryStore]::new()
}

function Add-PraxoMemoryRecord {
    param(
        [Parameter(Mandatory = $true)]$Store,
        [Parameter(Mandatory = $true)][string]$SessionId,
        [Parameter(Mandatory = $true)]$Record
    )
    $Store.Put($SessionId, $Record)
}

function Find-PraxoMemory {
    param(
        [Parameter(Mandatory = $true)]$Store,
        [Parameter(Mandatory = $true)][string]$SessionId,
        [string]$Query = '',
        [int]$Limit = 10
    )
    $Store.Search($SessionId, $Query, $Limit)
}

function New-PraxoPathGrant {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [ValidateSet('read', 'write', 'readwrite')][string]$Access = 'read'
    )
    Import-PraxoCoreAssembly
    $grant = [Praxo.Core.PathGrant]::new()
    $grant.Root = $Root
    $grant.Access = $Access
    $grant
}

function New-PraxoPathChecker {
    param([Parameter(Mandatory = $true)][object[]]$Grants)
    Import-PraxoCoreAssembly
    $list = [System.Collections.Generic.List[Praxo.Core.PathGrant]]::new()
    foreach ($grant in $Grants) { $list.Add($grant) }
    [Praxo.Core.PathChecker]::new($list)
}

function Test-PraxoPath {
    param(
        [Parameter(Mandatory = $true)]$Checker,
        [Parameter(Mandatory = $true)][string]$Target,
        [ValidateSet('read', 'write', 'readwrite')][string]$Access = 'read'
    )
    $Checker.Check($Target, $Access)
}

function New-PraxoCheckpointAllowlist {
    Import-PraxoCoreAssembly
    [Praxo.Core.CheckpointAllowlist]::new()
}

function Register-PraxoCheckpointType {
    param(
        [Parameter(Mandatory = $true)]$Allowlist,
        [Parameter(Mandatory = $true)][string]$TypeName
    )
    $Allowlist.Register($TypeName)
}

function ConvertTo-PraxoCheckpoint {
    param(
        [Parameter(Mandatory = $true)]$Allowlist,
        [Parameter(Mandatory = $true)][string]$TypeName,
        [AllowNull()]$Value
    )
    $Allowlist.Marshal($TypeName, $Value)
}

function ConvertFrom-PraxoCheckpoint {
    param(
        [Parameter(Mandatory = $true)]$Allowlist,
        [Parameter(Mandatory = $true)][string]$Data
    )
    Write-Output -NoEnumerate ($Allowlist.Unmarshal($Data))
}

function New-PraxoContextBudget {
    param(
        [Parameter(Mandatory = $true)][int]$MaxTokens,
        [int]$KeepRecent = 0
    )
    Import-PraxoCoreAssembly
    [Praxo.Core.ContextBudget]::new($MaxTokens, $KeepRecent)
}

function Get-PraxoTokenEstimate {
    param([Parameter(Mandatory = $true)][object[]]$Messages)
    Import-PraxoCoreAssembly
    $list = [System.Collections.Generic.List[Praxo.Core.Message]]::new()
    foreach ($message in $Messages) { $list.Add($message) }
    [Praxo.Core.ContextEstimator]::EstimateTokens($list)
}

function Invoke-PraxoContextCompact {
    param(
        [Parameter(Mandatory = $true)]$Budget,
        [Parameter(Mandatory = $true)][object[]]$Messages
    )
    $list = [System.Collections.Generic.List[Praxo.Core.Message]]::new()
    foreach ($message in $Messages) { $list.Add($message) }
    $result = $Budget.Compact($list)
    [pscustomobject]@{
        Messages = $result.Item1
        Ok = $result.Item2
    }
}

function New-PraxoPiiRedactor {
    Import-PraxoCoreAssembly
    [Praxo.Core.PiiRedactor]::Defaults()
}

function Invoke-PraxoPiiRedaction {
    param(
        [Parameter(Mandatory = $true)]$Redactor,
        [Parameter(Mandatory = $true)][string]$Text
    )
    $Redactor.Redact($Text)
}

function Get-PraxoStreamKinds {
    Import-PraxoCoreAssembly
    [Praxo.Core.StreamKinds]::All
}

function New-PraxoHarmovelaSinkOptions {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [string]$Source = 'praxo-core',
        [string]$SpecVersion = '0.2',
        [int]$TimeoutSeconds = 30
    )
    Import-PraxoCoreAssembly
    $options = [Praxo.Core.HarmovelaSinkOptions]::new()
    $options.BaseUrl = $BaseUrl
    $options.Source = $Source
    $options.SpecVersion = $SpecVersion
    $options.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)
    $options
}

function New-PraxoHarmovelaSink {
    param(
        [Parameter(Mandatory = $true)]$Options,
        [scriptblock]$Transport
    )
    Import-PraxoCoreAssembly
    if ($Transport) {
        $delegate = [System.Management.Automation.LanguagePrimitives]::ConvertTo(
            $Transport,
            [Praxo.Core.HarmovelaTransport]
        )
        [Praxo.Core.HarmovelaSink]::new($Options, $delegate)
    } else {
        [Praxo.Core.HarmovelaSink]::new($Options)
    }
}

function Send-PraxoHarmovelaEvent {
    param(
        [Parameter(Mandatory = $true)]$Sink,
        [Parameter(Mandatory = $true)]$Event
    )
    $Sink.Emit($Event)
}

function New-PraxoMcpServerOptions {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @(),
        [hashtable]$Environment = @{},
        [string]$WorkingDirectory
    )
    Import-PraxoCoreAssembly
    $options = [Praxo.Core.McpServerOptions]::new()
    $options.Command = $Command
    foreach ($argument in $Arguments) {
        $options.Args.Add($argument)
    }
    if ($Environment.Count -gt 0) {
        $options.Env = @{}
        foreach ($key in $Environment.Keys) {
            $options.Env[$key] = [string]$Environment[$key]
        }
    }
    if ($WorkingDirectory) {
        $options.WorkingDirectory = $WorkingDirectory
    }
    $options
}

function New-PraxoMcpStdioTransport {
    param([Parameter(Mandatory = $true)]$Options)
    Import-PraxoCoreAssembly
    [Praxo.Core.McpStdioTransport]::new($Options)
}

function New-PraxoMcpHttpOptions {
    param(
        [Parameter(Mandatory = $true)][string]$Endpoint,
        [hashtable]$Headers = @{},
        [string]$ProtocolVersion = '2025-03-26'
    )
    Import-PraxoCoreAssembly
    $options = [Praxo.Core.McpStreamableHttpOptions]::new()
    $options.Endpoint = $Endpoint
    $options.ProtocolVersion = $ProtocolVersion
    if ($Headers.Count -gt 0) {
        $options.Headers = @{}
        foreach ($key in $Headers.Keys) {
            $options.Headers[$key] = [string]$Headers[$key]
        }
    }
    $options
}

function New-PraxoMcpHttpTransport {
    param(
        [Parameter(Mandatory = $true)][string]$Endpoint,
        [hashtable]$Headers = @{},
        [string]$ProtocolVersion = '2025-03-26'
    )
    Import-PraxoCoreAssembly
    $options = New-PraxoMcpHttpOptions -Endpoint $Endpoint -Headers $Headers `
        -ProtocolVersion $ProtocolVersion
    [Praxo.Core.McpStreamableHttpTransport]::new($options)
}

function Connect-PraxoMcp {
    param(
        [Parameter(Mandatory = $true)]$Transport,
        [int]$TimeoutSeconds = 30,
        [string]$ClientName = 'praxo-core',
        [string]$ClientVersion = '0.6.0',
        [string]$ProtocolVersion = '2024-11-05'
    )
    Import-PraxoCoreAssembly
    $client = [Praxo.Core.McpClient]::new(
        $Transport,
        [TimeSpan]::FromSeconds($TimeoutSeconds),
        $ClientName,
        $ClientVersion,
        $ProtocolVersion
    )
    $client.Connect()
    $client
}

function Get-PraxoMcpTools {
    param([Parameter(Mandatory = $true)]$Client)
    $Client.ListTools()
}

function Invoke-PraxoMcpTool {
    param(
        [Parameter(Mandatory = $true)]$Client,
        [Parameter(Mandatory = $true)][string]$Name,
        [hashtable]$Arguments = @{}
    )
    $json = ConvertTo-Json -InputObject $Arguments -Compress -Depth 20
    $object = [System.Text.Json.Nodes.JsonNode]::Parse($json).AsObject()
    $Client.CallTool($Name, $object)
}

function Close-PraxoMcp {
    param([Parameter(Mandatory = $true)]$Client)
    $Client.Dispose()
}

Export-ModuleMember -Function (@(
    'Get-PraxoCoreInfo',
    'New-PraxoStaticModel',
    'New-PraxoSession',
    'New-PraxoAgentOptions',
    'New-PraxoAgent',
    'Invoke-PraxoAgent',
    'Invoke-PraxoAgentStream',
    'New-PraxoToolRegistry',
    'New-PraxoFuncTool',
    'Register-PraxoTool',
    'ConvertFrom-PraxoJson',
    'ConvertTo-PraxoJson',
    'Test-PraxoJsonSchema',
    'Get-PraxoToolCall',
    'Remove-PraxoToolCallMarkup',
    'Get-PraxoPluginManifest',
    'New-PraxoMemoryRecord',
    'New-PraxoMemoryStore',
    'Add-PraxoMemoryRecord',
    'Find-PraxoMemory',
    'New-PraxoPathGrant',
    'New-PraxoPathChecker',
    'Test-PraxoPath',
    'New-PraxoCheckpointAllowlist',
    'Register-PraxoCheckpointType',
    'ConvertTo-PraxoCheckpoint',
    'ConvertFrom-PraxoCheckpoint',
    'New-PraxoContextBudget',
    'Get-PraxoTokenEstimate',
    'Invoke-PraxoContextCompact',
    'New-PraxoPiiRedactor',
    'Invoke-PraxoPiiRedaction',
    'Get-PraxoStreamKinds',
    'New-PraxoHarmovelaSinkOptions',
    'New-PraxoHarmovelaSink',
    'Send-PraxoHarmovelaEvent',
    'New-PraxoMcpServerOptions',
    'New-PraxoMcpStdioTransport',
    'New-PraxoMcpHttpOptions',
    'New-PraxoMcpHttpTransport',
    'Connect-PraxoMcp',
    'Get-PraxoMcpTools',
    'Invoke-PraxoMcpTool',
    'Close-PraxoMcp'
) + $script:PraxoAdapterExports)
