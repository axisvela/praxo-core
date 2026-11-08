# PRAXO-CORE for PowerShell

PowerShell Core package `praxo-core-ps`, a shared-runtime wrapper over the C#
PRAXO-CORE framework. Requires PowerShell 7.4+ on .NET 8.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.2.0`
- Package: `praxo-core-ps`
- Tier: core
- License: MIT

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](REGISTRY.md)
- Machine-readable entry: [llms.txt](llms.txt) and [llms.md](llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](../../docs/getting-started/coding-agents.md)
- Registry: [PowerShell Gallery](https://www.powershellgallery.com/packages/praxo-core-ps/0.2.0)

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

## Scope

The PowerShell module exposes the C# Core agent loop, tools, policy, events,
memory, context, middleware, checkpoints, JSON Schema, plugin manifests, and
human-in-the-loop decisions. The implementation is shared with the C# Core; the
PowerShell layer provides typed constructors and command wrappers.

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
