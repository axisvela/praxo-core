# PRAXO-CORE for PowerShell

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its
PowerShell Core: a shared-runtime wrapper over the C# Core for existing
PowerShell automation that needs a model/tool loop, explicit policy and tool
scope, events, memory, checkpoints, and human-in-the-loop decisions.

It is not an HTTP user agent, crawler, hosted agent service, or a separate
PowerShell agent-loop implementation. Requires PowerShell 7.4+ on .NET 8.

## Features

- Native PowerShell cmdlets over the C# Core agent loop, tools, sessions, and
  options.
- Policy hooks, explicit tool scope, final-argument reauthorization, and HITL
  approve, edit, reject, and respond decisions.
- Typed events, memory, checkpoints, context budgets, middleware, JSON Schema,
  and plugin manifests.
- MCP, OpenTelemetry, retriever, and delegation helpers.
- A deterministic consumer starter with allow/deny checks.

## Limits

- Core is an execution framework, not a hosted model, identity provider,
  workflow engine, or production sandbox.
- Checkpoints are recovery hints, not transactions. Core does not provide
  durable execution, exactly-once effects, or an effect ledger.
- Provider credentials, authentication, retries, and durable state remain
  application-owned.
- The module shares the C# Core; it is not a separate agent-loop runtime.
- Go remains the reference implementation; full Go feature parity is not
  claimed.

## Package

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.9.0`
- Package: `praxo-core-ps`
- Tier: core
- License: MIT

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/powershell/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/powershell/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/powershell/llms.md)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples): runnable language-specific examples.
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [PowerShell Gallery](https://www.powershellgallery.com/packages/praxo-core-ps/0.8.1)
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761) · [LinkedIn](https://www.linkedin.com/company/axisvela/) · [Facebook](https://www.facebook.com/profile.php?id=61596905732406) · [YouTube](https://www.youtube.com/@axisvela) · [Discord](https://discord.com/channels/1575163993767809064/1575164343148875977) · [GitHub Discussions](https://github.com/axisvela/praxo-core/discussions) · [GitHub Issues](https://github.com/axisvela/praxo-core/issues) · [Documentation](https://axisvela.github.io/praxo-core/) · [Architect](https://axisvela.architect.pub)

## Get started

Install the published package:

```powershell
Install-Module praxo-core-ps
```

Then run the smallest deterministic example:

- [Consumer starter](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/consumer): explicit tool scope and a deny check.
- [Live model](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/live-model): connect an OpenAI-compatible endpoint and register `get_time`.

See the [PowerShell documentation](https://axisvela.github.io/praxo-core/languages/powershell/) for the full API and the
[language matrix](https://axisvela.github.io/praxo-core/languages/matrix/) for
current scope.

## Examples

Runnable examples live under [`language/powershell/examples`](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples).

| Goal | Example |
| --- | --- |
| Install and deny one unsafe call | [consumer](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/consumer) |
| Connect a real model | [live-model](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/live-model) |
| Connect MCP tools | [mcp](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/mcp) |
| Run the representative end-to-end chain | [representative-chain](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/representative-chain) |
| Test delegated-child governance | [advanced-delegation](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/advanced-delegation) |
| Validate structured output | [structured-output](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/structured-output) |
| Stream a response | [streaming](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/streaming) |
| Add identity and policy | [identity-policy](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/identity-policy) |
| Approve a tool call | [hitl](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/hitl) |
| Persist checkpoints | [checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/checkpoint) |
| Resume a multi-turn session | [session-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/session-checkpoint) |
| Run behind HTTP | [service](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/service) |
| Retry transient failures | [retry](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/retry) |
| Add provider fallback | [provider-fallback](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/provider-fallback) |
| Observe agent events | [event-sink](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/event-sink) |

## Install

```powershell
Install-Module praxo-core-ps
```

For a source checkout:

```powershell
dotnet build language/csharp/Praxo.Core/Praxo.Core.csproj -c Release
Import-Module ./language/powershell/praxo-core-ps/praxo-core-ps.psd1
```

## Quickstart

```powershell
$model = New-PraxoStaticModel -Content 'hello'
$options = New-PraxoAgentOptions -Model $model
$agent = New-PraxoAgent -Options $options
$session = New-PraxoSession -Id 'demo'
(Invoke-PraxoAgent -Agent $agent -Session $session -Prompt 'hello').Output
```

The module loads `Praxo.Core.dll` from its own directory. Set `PRAXO_CORE_DLL`
to override the assembly path.

## Human-in-the-loop Approval

Add a tool name to `InterruptOn`, then attach either an interrupt handler or a
boolean approval. Decisions use `New-PraxoInterruptDecision` with `approve`,
`edit`, `reject`, or `respond`; edited arguments are authorized again before
`tool.call`.

```powershell
$options = New-PraxoAgentOptions -Model $model
$options.Policy = $policy
Add-PraxoInterruptTool -Options $options -Name 'write_note'
$options.OnInterruptDecision = New-PraxoInterruptHandler -Handler {
    param($interrupt)
    New-PraxoInterruptDecision -Action 'approve'
}
```

`New-PraxoInterruptApproval` wraps a boolean approval. See the
[`hitl` example](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/hitl)
for approve and edited-denial scenarios.

## Scope

The PowerShell module exposes the C# Core agent loop, tools, policy, events,
memory, context, middleware, checkpoints, JSON Schema, plugin manifests, and
human-in-the-loop decisions. The implementation is shared with the C# Core; the
PowerShell layer provides typed constructors and command wrappers.

It also wraps the C# OpenTelemetry sink (`New-PraxoOtelSinkOptions`,
`New-PraxoOtelSink`, `Send-PraxoOtelEvent`), retriever seam
(`New-PraxoDocument`, `New-PraxoFuncRetriever`, `Invoke-PraxoRetrieve`), and
synchronous subagent delegation (`New-PraxoFuncSubagentRunner`,
`New-PraxoSubagentRequest`, `New-PraxoSubagentManager`, `Invoke-PraxoSubagent`).
Event data stays excluded from OpenTelemetry spans unless listed in
`AllowedDataKeys`.

## Testing

```bash
dotnet build language/csharp/Praxo.Core/Praxo.Core.csproj -c Release
dotnet run --project language/csharp/Praxo.Conformance -c Release
dotnet run --project language/csharp/Praxo.Tests -c Release
pwsh -NoProfile -File language/powershell/tests/run.ps1
pwsh -NoProfile -File language/powershell/api-snapshot.ps1 -Check
```

## Layout

- `praxo-core-ps/` PowerShell module.
- `tests/run.ps1` wrapper smoke tests.
- `api-snapshot.ps1` and `api/` public API snapshot.

## Legacy bridge

The bridge package is `praxo-core-ps-br`; see
[`bindings/powershell`](../../bindings/powershell/README.md).
