# Independent Go Consumer

Build a new application using published Core `2.8.0`, without checking out
PRAXO-CORE. This starter uses a deterministic model and an in-memory tool so
installation and authorization behavior can be checked without credentials,
a model service, or AxisVela products.

## Is This a Fit?

| Task | Fit and boundary |
| --- | --- |
| Embed a model/tool loop in an existing Go application | Good fit; your application owns the model adapter and tools |
| Authorize tool calls and test a denial path | Good fit; your application supplies policy and authentic identity |
| Add human approval or checkpoint recovery | Supported seams; persistent approvals and external effect reconciliation remain integration work |
| Run durable graph workflows or guarantee exactly-once effects | Not supplied by Core alone; use a dedicated runtime or execution service |
| Obtain a hosted sandbox or robot safety controller | Not supplied; Core exposes integration boundaries, not those services |

Review [when not to use Core](when-not-to-use.md) before choosing it.

## Create the Application

Use Go `1.26.11`, the tested CI/release toolchain. Installation needs registry
access or a populated module cache. Set `GOWORK=off` for all commands in this
guide so a parent workspace cannot substitute local dependencies. In PowerShell
use `$env:GOWORK = "off"`; in a POSIX shell use `export GOWORK=off`.

In a new application directory, run:

```sh
go mod init example.com/praxo-starter
go get github.com/axisvela/praxo-core/v2@v2.8.0
```

## Application Source

Use the following as `main.go`. On the documentation site this code is rendered
directly from the [tested starter source](https://github.com/axisvela/praxo-core/blob/main/language/go/examples/consumer-go/main.go),
not a separately maintained copy. GitHub readers can follow that source link.

<!-- go-consumer-source: main.go -->

## Acceptance Tests

Use the following as `main_test.go`, also rendered from the
[tested source](https://github.com/axisvela/praxo-core/blob/main/language/go/examples/consumer-go/main_test.go).
The dependency check rejects replacements and verifies the exact Core version.

<!-- go-consumer-source: main_test.go -->

## Verify

After adding both files, resolve their dependencies and verify the application:

```sh
go mod tidy
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

The fake model requests the tool regardless of policy. The explicit
`AllowedTools` list limits the tool name; the policy additionally restricts its
target argument. A rejected private target must never increment the effect
counter. An empty allowlist is not a deny-all configuration in the current API.

## Governed Acceptance

### Published-Package Upgrades

From a source checkout, `python scripts/test_go_upgrade.py -v` creates one fresh
consumer, installs the historical version pinned by `tests/consumer/go.mod`,
then upgrades that same application to the Go version in the package map.
It rejects module replacements, checks both exact dependency versions, and
requires unchanged application source. The historical phase checks basic
allow/deny behavior; the upgraded phase runs all five governed negative checks,
build, vet and the expected program output. It does not claim those stronger
checks passed on the historical security baseline.

CI runs this check on Linux, Windows and macOS. A run proves only its named
published-version pair and fixture, not an unpublished release candidate,
arbitrary version upgrades, user adoption or production retention.

### Negative Checks

The published-package tests also include five negative checks:

```sh
go test -mod=readonly -run Governed -v ./...
```

| Check | Required outcome |
| --- | --- |
| Missing mandatory policy | application guard rejects before a run; zero tool effects |
| Empty tool scope | application guard rejects; zero tool effects |
| Middleware changes final arguments | final operation is reauthorized; denial prevents the effect |
| Approval edit changes arguments | edited operation is reauthorized; denial prevents the effect |
| Policy service error | run fails closed; zero tool effects |

The tests are in the
[tested source](https://github.com/axisvela/praxo-core/blob/main/language/go/examples/consumer-go/governed_test.go).
The guard is application-level: Core keeps its ordinary nil-policy embeddable
behavior. These checks do not prove authentic identity, durable approvals,
effect reconciliation, or a general security profile.

These checks prove this published-package fixture only, not live-model quality,
identity authenticity, process isolation, durable effects, or production safety.
To connect a real model, continue with the [endpoint quickstart](quickstart.md#run-with-ollama)
and the [adoption guide](adoption.md). Keep denial tests when replacing the fake.
