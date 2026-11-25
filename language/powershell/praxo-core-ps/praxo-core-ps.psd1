@{
    RootModule        = 'praxo-core-ps.psm1'
    ModuleVersion     = '0.9.0'
    GUID              = '8f04a4d6-1f3c-4f6e-9d69-7b2f11d3a902'
    Author            = 'AxisVela'
    CompanyName       = 'AxisVela'
    Copyright         = '(c) AxisVela. MIT License.'
    Description       = @'
PRAXO-CORE for PowerShell is an embeddable, policy-governed agent execution
kernel for PowerShell 7.4+ on .NET 8. It wraps the C# PRAXO-CORE agent loop.

Features:
  - Native PowerShell cmdlets for the agent loop, tools, sessions, and options.
  - Policy hooks, explicit tool scope, final-argument reauthorization, and
    human-in-the-loop approve, edit, reject, and respond decisions.
  - Typed events, memory, checkpoints, context budgets, middleware, JSON Schema,
    and plugin manifests.
  - MCP, OpenTelemetry, retriever, and delegation helpers over the C# Core.
  - Deterministic consumer starter with allow/deny checks.

Install:
  Install-Module praxo-core-ps

Quickstart:
  $model = New-PraxoStaticModel -Content 'hello'
  $options = New-PraxoAgentOptions -Model $model
  $agent = New-PraxoAgent -Options $options
  $session = New-PraxoSession -Id 'demo'
  (Invoke-PraxoAgent -Agent $agent -Session $session -Prompt 'hello').Output

Starter (allow/deny):
  https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/consumer

Examples:
  https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples

Limits:
  - Not a hosted model, identity provider, workflow engine, or production
    sandbox.
  - Checkpoints are recovery hints, not transactions; no exactly-once effects.
  - Provider credentials, retries, and durable state remain application-owned.
  - The module shares the C# Core; it is not a separate agent-loop runtime.

Documentation:
  https://axisvela.github.io/praxo-core/languages/powershell/

Source and license (MIT):
  https://github.com/axisvela/praxo-core
'@
    PowerShellVersion = '7.4'
    FunctionsToExport = @(
        'Get-PraxoCoreInfo',
        'New-PraxoStaticModel',
        'New-PraxoSession',
        'New-PraxoAgentOptions',
        'New-PraxoInterruptDecision',
        'New-PraxoInterruptHandler',
        'New-PraxoInterruptApproval',
        'Add-PraxoInterruptTool',
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
        'Close-PraxoMcp',
        'New-PraxoOtelSinkOptions',
        'New-PraxoOtelSink',
        'Send-PraxoOtelEvent',
        'New-PraxoDocument',
        'New-PraxoFuncRetriever',
        'Invoke-PraxoRetrieve',
        'New-PraxoFuncSubagentRunner',
        'New-PraxoSubagentRequest',
        'New-PraxoSubagentManager',
        'Invoke-PraxoSubagent'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData = @{
        PraxoSpecVersion = '0.2.0'
        PSData = @{
            Tags       = @('praxo', 'agent', 'core', 'dotnet')
            LicenseUri = 'https://github.com/axisvela/praxo-core/blob/main/LICENSE'
            ProjectUri = 'https://github.com/axisvela/praxo-core'
            ReleaseNotes = @'
0.8.0
- Add a project introduction and starter, examples, and documentation links to the PowerShell Gallery page.
- Resolve the module version and SPEC_VERSION from the packaged manifest when source version files are not present.
'@
        }
    }
}
