# PRAXO Bridge for TCL

TCL is a Bridge over the maintained Go runtime. The wrapper forwards arguments
and stdin to `praxo-bridge`, preserves stdout and stderr, and propagates the
bridge exit code. It does not implement an agent loop, provider adapter, or
plugin host.

The declared Framework target for TCL remains open; this wrapper is an
intermediate delivery form. It supports `SPEC_VERSION` 0.2.0 through the
underlying bridge.

## Use

Build the bridge once and point `PRAXO_BRIDGE_BIN` at it:

```bash
go build -o build/praxo-bridge ./cmd/praxo-bridge
PRAXO_BRIDGE_BIN="$PWD/build/praxo-bridge" \
  tclsh bindings/tcl/praxo-bridge.tcl version
```

Without `PRAXO_BRIDGE_BIN`, the wrapper falls back to `go run` and therefore
requires Go on `PATH`. JSON is supplied on stdin and diagnostics stay on
stderr.

Example:

```bash
printf '%s' '{"content":"plain text"}' |
  PRAXO_BRIDGE_BIN="$PWD/build/praxo-bridge" \
  tclsh bindings/tcl/praxo-bridge.tcl toolcall parse
```

The wrapper does not interpolate JSON through a shell. Arguments are passed as
a TCL list and stdin is forwarded as data.

## Test

```bash
python bindings/tcl/test_bridge.py
```

The test builds the Go bridge, then checks version reporting, Unicode tool-call
forwarding, markup stripping, schema validation, and contract-error exit code.
Set `TCLSH` to select a specific interpreter.

## Limits

- Requires Tcl 8.6 and either a prebuilt bridge or Go.
- No native TCL agent loop, provider configuration, streaming API, plugin host,
  or filesystem sandbox.
- The bridge process boundary, not the TCL wrapper, enforces contract errors.
- Package-registry publication and production readiness are not claimed.

See the [bridge contract](../../spec/bridge.md),
[parity inventory](../../spec/parity/bridge-tcl.md), and
[implementation support](../../docs/languages/support.md).
