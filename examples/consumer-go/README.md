# Independent Go Consumer

This module installs published Core `2.5.2`, without local replacements or
optional adapters. It is the current-package starter, separate from the
historical `2.5.0` compatibility baseline in `tests/consumer`.

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

```sh
go test -mod=readonly -run Identity -v ./...
```

`identity_test.go` shows how an application supplies a verified principal and
rejects missing, expired, tenant-mismatched, or insufficient roles. A model's
role claim is ignored. This is an application pattern, not an identity provider
or policy decision service. See the
[identity and policy guide](../../docs/guides/identity-policy.md).

Installation requires registry access or a populated module cache. Execution
does not require an API key, model server, or AxisVela products. To start outside
this checkout, follow the [consumer quickstart](../../docs/getting-started/consumer-go.md),
whose code is rendered from this module's tested source.
