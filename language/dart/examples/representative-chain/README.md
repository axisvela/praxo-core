# Dart Representative Chain

This deterministic example exercises the same application seams as the Go
representative chain without a live provider:

```text
scripted model -> MCP-style record tool -> final-argument authorization
               -> governed child delegation -> OTel / Harmovela events
               -> edited denial with zero effects
```

The MCP handshake and tool listing use `McpClient` with an in-memory transport.
The record call uses the same synchronous in-memory server so the Core's
synchronous tool seam is exercised without blocking on a Future.

## Run

```bash
dart run language/dart/examples/representative-chain/chain.dart
```

Expected output:

```text
output: DONE
effects: parent=1 child=1
child calls: 2
otel spans: 10
harmovela events: 10
denied effects: 0
```

## Boundaries

The models and transports are deterministic. This does not prove live provider,
remote MCP/Harmovela, identity, isolation, exactly-once execution, or production
readiness.
