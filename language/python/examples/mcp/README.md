# MCP Stdio Client

This example uses published PyPI `praxo-core==0.6.0` to connect to a minimal
stdio MCP server, list its tools, register them in a Core registry, and call one
tool.

## Run

```bash
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python client.py
```

Expected output:

```text
tools=add,echo; sum=5
```

## Test

The server is local and deterministic; no external MCP service is required.

```bash
.venv/bin/python -m unittest test_client.py -v
```

MCP tool output remains untrusted. Policy still authorizes every tool call when
these tools are registered with an Agent. This client example does not provide
remote authentication, schema promotion, or a hosted MCP service.
