# PRAXO Bridge for Prolog

SWI-Prolog is a Bridge with source tag `prolog/v0.1.0` over the maintained Go
runtime. The wrapper forwards arguments and stdin to `praxo-bridge`, preserves
stdout and stderr, and propagates the bridge exit code. It does not implement an
agent loop, provider adapter, or plugin host.

## Use

Build the bridge once and point `PRAXO_BRIDGE_BIN` at it:

```bash
go build -o build/praxo-bridge ./cmd/praxo-bridge
PRAXO_BRIDGE_BIN="$PWD/build/praxo-bridge" \
  swipl -q -s bindings/prolog/praxo_bridge.pl -- version
```

Without `PRAXO_BRIDGE_BIN`, the wrapper falls back to `go run` and therefore
requires Go on `PATH`. JSON is supplied on stdin and diagnostics stay on stderr.

Example:

```bash
printf '%s' '{"content":"plain text"}' |
  PRAXO_BRIDGE_BIN="$PWD/build/praxo-bridge" \
  swipl -q -s bindings/prolog/praxo_bridge.pl -- toolcall parse
```

## Test

```bash
python bindings/prolog/test_bridge.py
```

The test builds the Go bridge, then checks version reporting, Unicode tool-call
forwarding, markup stripping, schema validation, and contract-error exit code.
Set `SWIPL` to select a specific interpreter.

## Limits

- Requires SWI-Prolog and either a prebuilt bridge or Go.
- No native Prolog agent loop, provider configuration, streaming API, plugin
  host, or filesystem sandbox.
- The bridge process boundary, not the Prolog wrapper, enforces contract errors.
- The wrapper buffers stdin before invoking the bridge and is not a streaming
  transport.
- The source tag does not establish package-registry publication or production
  readiness.

See the [bridge contract](../../spec/bridge.md),
[parity inventory](../../spec/parity/prolog.md), and
[implementation support](../../docs/languages/support.md).
