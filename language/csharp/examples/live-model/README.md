# C# Live Model

This example uses published NuGet `Praxo.Core==0.11.1` to connect the C# Core to
an OpenAI-compatible endpoint and registers one low-risk `get_time` tool.

## Run

```bash
cd language/csharp/examples/live-model
dotnet run
```

If the apphost or `dotnet run` does not return in your environment, run the
built DLL directly:

```bash
dotnet bin/Debug/net8.0/Praxo.LiveModel.dll
```

Environment:

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "qwen3.5:4b"
# $env:PRAXO_API_KEY = "..."   # only for hosted endpoints
```

On POSIX use the equivalent `export` commands.

The example authorizes only `get_time`; every other tool call is denied by
policy. It is an integration starting point, not a production security profile.
Identity, durable approvals, isolation, and effect reconciliation remain the
application's responsibility.
