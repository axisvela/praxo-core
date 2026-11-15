# PowerShell Live Model

This example is a thin PowerShell wrapper over the C# PRAXO-CORE runtime. It
uses the C# `OpenAiCompatibleModel` and registers one low-risk `get_time` tool
with a small JSON Schema. The agent loop, policy enforcement, and provider
adapter are inherited from the C# Core.

## Run

From the repository root:

```powershell
dotnet build language/csharp/Praxo.Core/Praxo.Core.csproj -c Release
pwsh -NoProfile -File language/powershell/examples/live-model/live_model.ps1
```

Environment:

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "qwen3.5:4b"
# $env:PRAXO_API_KEY = "..."   # only for hosted endpoints
# $env:PRAXO_PROMPT = "What time is it? Use get_time with zone set to utc."
```

The run prints `result.Output` from the model. On failure it prints troubleshooting
for `PRAXO_BASE_URL`, `PRAXO_MODEL`, and `PRAXO_API_KEY` and exits nonzero.

Set `PRAXO_CORE_DLL` if `Praxo.Core.dll` is built somewhere other than the
default Release or Debug output directory.

The example authorizes only `get_time`; every other tool call is denied by
policy. It is an integration starting point, not a production security profile.
Identity, durable approvals, isolation, and effect reconciliation remain the
application's responsibility.
