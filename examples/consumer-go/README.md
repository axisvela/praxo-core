# Independent Go Consumer

This module installs published Core `2.6.0`, without local replacements or
optional adapters. It is the current-package starter, separate from the
historical `2.5.0` compatibility baseline in `tests/consumer`.

The files mix two evidence levels: L3 published-package consumer checks and L4
application recipes. The long-running, identity, and parts of the governed suite
validate the reference application pattern, not Core-owned capabilities. See the
[test and evidence taxonomy](../../docs/project/test-taxonomy.md) for the file
map and the criteria for promoting a recipe into Core.

Use Go 1.26.10, the CI/release toolchain. With this directory as the working
directory, set `GOWORK=off` (`$env:GOWORK = "off"` in PowerShell), then run:

```sh
go mod download
go test -mod=readonly ./...
go vet -mod=readonly ./...
go build -mod=readonly ./...
go run -mod=readonly .
```

Expected program output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The deterministic model requests a tool call. An explicit tool allowlist and
policy permit only the public target. The rejected private target never reaches
the tool's in-memory effect counter. This is an integration fixture, not a real
model, identity service, persistent effect ledger, or sandbox.

## Governed Acceptance

```sh
go test -mod=readonly -run Governed -v ./...
```

`governed_test.go` adds five negative checks against the published package:

| Check | Required outcome |
| --- | --- |
| Missing mandatory policy | application guard rejects before a run; zero tool effects |
| Empty tool scope | application guard rejects; zero tool effects |
| Middleware changes final arguments | final operation is reauthorized; denial prevents the effect |
| Approval edit changes arguments | edited operation is reauthorized; denial prevents the effect |
| Policy service error | run fails closed; zero tool effects |

These are application-level acceptance checks. Core keeps its ordinary
nil-policy embeddable behavior; the guard is in the starter. They do not prove
authentic identity, durable approvals, effect reconciliation, or a general
security profile.

## Identity and Policy Recipe

The verified-identity pattern is a separate L4 application recipe at
[`examples/recipes/identity-go`](../recipes/identity-go/README.md). It is not part
of this starter and is not a Core capability claim. See the
[identity and policy guide](../../docs/guides/identity-policy.md).

## Long-Running Operations

The long-running operation pattern is a separate L4 application recipe at
[`examples/recipes/long-running-go`](../recipes/long-running-go/README.md). It is
not part of this starter and is not a Core capability claim. See the
[long-running operations guide](../../docs/guides/long-running-operations.md).

Installation requires registry access or a populated module cache. Execution
does not require an API key, model server, or AxisVela products. To start outside
this checkout, follow the [consumer quickstart](../../docs/getting-started/consumer-go.md),
whose code is rendered from this module's tested source.
