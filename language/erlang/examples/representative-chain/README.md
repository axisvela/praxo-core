# Erlang Representative Chain

This deterministic example exercises the same application seams as the Go,
Python, and TypeScript representative chains without a live provider:

```text
scripted model -> MCP record tool -> final-argument authorization
               -> governed child delegation -> OTel / Harmovela events
               -> edited denial with zero effects
```

It uses the Erlang MCP client with an injected in-memory transport, deterministic
parent/child models, the OTel and Harmovela adapters with injected in-memory
transports, and an explicit parent/child policy composition.

## Run

From the repository root:

```powershell
$env:PATH = "D:\dev\Erlang OTP\bin;D:\dev\rebar3;" + $env:PATH
& "D:\dev\Erlang OTP\bin\erlc.exe" -I language/erlang/src -o language/erlang/build/ebin (Get-ChildItem language/erlang/src/*.erl, language/erlang/src/adapters/*.erl | ForEach-Object { $_.FullName })
& "D:\dev\Erlang OTP\bin\escript.exe" language/erlang/examples/representative-chain/chain.escript
```

Alternatively compile the runtime from `language/erlang` with `rebar3 compile`
or `python language/erlang/run-tests.py`; the script also adds
`_build/default/lib/praxo_core/ebin` and `language/erlang/build/ebin` to the
code path.

Expected output:

```text
output: DONE
effects: parent=1 child=1
child calls: 2
otel spans: 7
harmovela events: 7
denied effects: 0
erlang representative chain passed
```

## What It Proves

- the parent requests the MCP `record` tool and the final arguments are
  authorized;
- the parent delegates to a child with `record` as its only tool scope and a
  composed parent/child policy;
- the OTel and Harmovela sinks receive the lifecycle and tool events through
  their injected transports;
- a middleware edit to `target=blocked` is reauthorized, the MCP tool is not
  called, and the effect count stays zero.

## Boundaries

The parent and child models are deterministic. The MCP, OTel, and Harmovela
transports are in-memory fixtures; no network is used. This is not a live-model
run and does not prove provider behavior, remote MCP or Harmovela operation,
identity, isolation, exactly-once execution, or production readiness. The Go
`examples/representative-chain` is the real-model counterpart.
