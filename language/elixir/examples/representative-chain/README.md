# Elixir Representative Chain

This deterministic example exercises the same application seams as the Go,
Python, and TypeScript representative chains without a live provider:

```text
scripted model -> MCP record tool -> final-argument authorization
               -> governed child delegation -> OTel / Harmovela events
               -> edited denial with zero effects
```

It uses an in-memory MCP transport, deterministic parent/child models, the OTel
and Harmovela sinks with in-memory transports, and an explicit parent/child
policy composition.

## Run

Build the source tree once if `language/elixir/build/ebin` is missing:

```powershell
New-Item -ItemType Directory -Force language/elixir/build/ebin | Out-Null
D:\dev\Elixir\bin\elixirc.bat -o language/elixir/build/ebin language/elixir/lib/praxo/*.ex language/elixir/lib/praxo/adapters/*.ex
```

Then, from the repository root:

```powershell
$env:PATH = "D:\dev\Erlang OTP\bin;" + $env:PATH
D:\dev\Elixir\bin\elixir.bat -pa language/elixir/build/ebin language/elixir/examples/representative-chain/chain.exs
```

Expected output:

```text
output: DONE
effects: parent=1 child=1
child calls: 2
otel spans: 7
harmovela events: 7
denied effects: 0
```

## What It Proves

- the parent requests the MCP `record` tool and the final arguments are
  authorized;
- the parent delegates to a child with `record` as its only tool scope and a
  composed parent/child policy;
- OTel and Harmovela sinks receive the parent and child lifecycle and tool
  events;
- a middleware edit to `target=blocked` is reauthorized, the MCP tool is not
  called, and the effect count stays zero.

## Boundaries

The MCP server, OTel collector, and Harmovela receiver are in-memory transport
seams backed by `Praxo.Mcp.Transport`, `Praxo.OtelSink`, and
`Praxo.HarmovelaSink` injection points. This is not a live-model, remote MCP, or
remote Harmovela run and does not prove provider behavior, identity, isolation,
exactly-once execution, or production readiness. The Go
`language/go/examples/representative-chain` is the real-model counterpart.
