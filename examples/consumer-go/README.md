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

Installation requires registry access or a populated module cache. Execution
does not require an API key, model server, or AxisVela products. To start outside
this checkout, follow the [consumer quickstart](../../docs/getting-started/consumer-go.md),
whose code is rendered from this module's tested source.
