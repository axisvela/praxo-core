@{
    RootModule        = 'praxo-core-ps.psm1'
    ModuleVersion     = '0.9.1'
    GUID              = '8f04a4d6-1f3c-4f6e-9d69-7b2f11d3a902'
    Author            = 'AxisVela'
    CompanyName       = 'AxisVela'
    Copyright         = '(c) AxisVela. MIT License.'
    Description       = @'
PRAXO-CORE (praxocore) for PowerShell is an embeddable, policy-governed agent execution
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
  - consumer: published Core runtime with a deterministic model and allow/deny policy checks.
  - live-model: OpenAI-compatible adapter wired through PRAXO_BASE_URL with a get_time tool.
  - structured-output: JSON Schema validation with a deterministic valid/invalid check.
  - mcp: transport-neutral MCP client boundary over a caller-owned transport.
  - representative-chain: deterministic MCP, policy, delegation, OTel/Harmovela, and edited-denial chain.
  - advanced-delegation: application-level governance negative checks for delegated child agents.
  - service: transport-neutral request handler with health, principal, and run cases.
  - provider-fallback: fallback model after a primary failure, with a deterministic check.
  - event-sink: lifecycle and tool events through sink composition and filtering.
  - streaming: delta reconstruction with a deterministic check.
  - checkpoint: application-owned checkpoint storage with allowlisted payload encoding.
  - session-checkpoint: multi-turn history save, reload, and continue.
  - retry: retry transient failures with bounded attempts and a deterministic check.
  - identity-policy: bind a trusted principal to policy and reject effects before execution.
  - hitl: approve a write, then edit it to a denied value and verify reauthorization stops the effect.
  Examples source: https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples

Scenario tutorials:
  - Windows diagnostics: read-only service and disk checks, native PowerShell commands, scoped tools, and a structured report.
    https://github.com/axisvela/praxo-core/tree/main/language/powershell/Tutorial/windows-diagnostics
  - FinOps review: bounded cloud cost review that selects the highest-cost underused resource and drafts a review-only action; no cloud API or termination.
    https://github.com/axisvela/praxo-core/tree/main/language/powershell/Tutorial/finops-review

Reference applications:
  - No accepted end-to-end reference application yet.
    Candidate goals: https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio

Community:
  https://github.com/axisvela/praxo-core/discussions
  https://x.com/axisvela
  https://www.linkedin.com/company/axisvela/

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
            Tags       = @('praxo-core', 'praxocore', 'powershell', 'dotnet', 'ai-agents', 'agent-framework', 'llm', 'tool-calling', 'human-in-the-loop', 'checkpoints', 'mcp', 'opentelemetry')
            LicenseUri = 'https://github.com/axisvela/praxo-core/blob/main/LICENSE'
            ProjectUri = 'https://github.com/axisvela/praxo-core'
            ReleaseNotes = @'
0.9.1
- Add explicit example, scenario-tutorial, and reference-application lists to the Gallery description.
'@
        }
    }
}
