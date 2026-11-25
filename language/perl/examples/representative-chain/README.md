# Perl Representative Chain

This deterministic example exercises the same application seams as the Go
representative chain without a live provider:

```text
scripted model -> MCP record tool -> final-argument authorization
               -> governed child delegation -> OTel / Harmovela events
               -> edited denial with zero effects
```

It uses an in-memory MCP transport, deterministic parent/child models, OTel and
Harmovela sinks with in-memory transports, and an explicit parent/child policy
composition.

## Run

From the repository root:

```bash
perl language/perl/examples/representative-chain/chain.pl
```

The script adds `language/perl/lib` relative to its own location, so it also
works from this directory.

Expected output:

```text
output: DONE
effects: parent=1 child=1
child calls: 2
otel spans: 10
harmovela events: 10
denied effects: 0
```

## What It Proves

- the parent requests the MCP `record` tool and the final arguments are
  authorized;
- the parent delegates to a child with `record` as its only tool scope and a
  composed parent/child policy;
- OTel and Harmovela sinks receive lifecycle and tool events;
- an approval edit to `target=blocked` is reauthorized, the MCP tool is not
  called, and the effect count stays zero.

## Boundaries

The parent and child models are deterministic. This is not a live-model run and
does not prove provider behavior, remote MCP or Harmovela operation, identity,
isolation, exactly-once execution, or production readiness. The Go
`language/go/examples/representative-chain` is the real-model counterpart.
