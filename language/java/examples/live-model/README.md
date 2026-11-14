# Java Live Model

This example uses published Maven Central `com.axisvela:praxo-core:0.9.0` to
connect the Java Core to an OpenAI-compatible endpoint and registers one
low-risk `get_time` tool.

## Run

```bash
cd language/java/examples/live-model
mvn -q compile exec:java
```

On Windows PowerShell, redirect stdin when a persistent shell owns the console:

```powershell
cmd /d /c "mvn -q compile exec:java < NUL"
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
