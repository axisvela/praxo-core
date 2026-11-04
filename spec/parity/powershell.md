# PowerShell Core Parity

- Tier: core
- SPEC_VERSION: 0.2.0

The PowerShell Core is a shared-runtime wrapper over the C# Core. The agent
loop, policy, middleware, checkpoints, and event contracts execute in the C#
Core assembly; PowerShell exposes typed constructors and command wrappers.

| Go symbol | PowerShell symbol | Status | Phase |
| --- | --- | --- | --- |
| `toolcall.ParseToolCall` | `Get-PraxoToolCall` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `Remove-PraxoToolCallMarkup` | parity | P1 |
| `tool/jsonschema.Schema` | `Test-PraxoJsonSchema` | parity | P1 |
| `plugin.ParseManifest` | `Get-PraxoPluginManifest` | parity | P1 |
| `memory.Store` | `New-PraxoMemoryStore`, `Add-PraxoMemoryRecord`, `Find-PraxoMemory` | parity | P1 |
| `event.Event` | C# `Praxo.Core.Event` | parity | P1 |
| `agent/stream.Part` | `Get-PraxoStreamKinds` | partial | P1 |
| `checkpoint.Allowlist` | `New-PraxoCheckpointAllowlist`, `ConvertTo-PraxoCheckpoint`, `ConvertFrom-PraxoCheckpoint` | parity | P1 |
| `policy.PathChecker` | `New-PraxoPathChecker`, `Test-PraxoPath` | parity | P1 |
| `agent/context.Budget` | `New-PraxoContextBudget`, `Invoke-PraxoContextCompact` | parity | P1 |
| `agent/middleware.Pii` | `New-PraxoPiiRedactor`, `Invoke-PraxoPiiRedaction` | parity | P1 |
| `agent.Agent` | `New-PraxoAgent`, `Invoke-PraxoAgent`, `Invoke-PraxoAgentStream` | parity | P1 |
