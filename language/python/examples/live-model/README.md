# Python Live Model

This example uses published PyPI `praxo-core==0.8.1` to connect the Python Core
to an OpenAI-compatible endpoint and registers one low-risk `get_time` tool.

## Run

```bash
cd language/python/examples/live-model
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python live_starter.py
```

On Windows PowerShell:

```powershell
python -m venv .venv
.venv\Scripts\python -m pip install -r requirements.txt
.venv\Scripts\python live_starter.py
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
