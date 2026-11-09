# Long-Running Operation Recipe (Go)

This module demonstrates the application-owned side of a remote long-running
operation: idempotent submission, status recovery, cancel request versus
confirmation, effect verification, fencing, and restart behavior. It consumes
published Core `2.7.0`; it does not add a Core API.

**Evidence level: L4 application recipe.** These tests validate the reference
integration and its failure boundaries, not Core-owned durable operations,
HTTP authentication, verification, or leases. See the
[test and evidence taxonomy](../../../docs/project/test-taxonomy.md).

Run from this directory:

```sh
GOWORK=off go test -mod=readonly -run LongRunning -v ./...
```

The suite includes a file-backed store, a loopback HTTP service, a child-process
restart, a separate verifier process, fencing with lease expiry, renewal, and
revocation, and deterministic fault injection before and after the rename
boundary, including fail-closed corrupt state. They are fixtures, not production
services.

A standalone service binary is available at `cmd/longrunning-service` with
health/readiness and metrics endpoints, bearer auth, optional TLS, graceful
shutdown, environment-variable configuration, and a configurable file, SQLite, or
Postgres lease. SQLite is tested locally; the Postgres path needs a live server.
The command integration test builds and starts the binary on a real TCP port,
checks concurrent submissions and metrics, and crashes it before and after the
rename boundary to check restart recovery. A separate
`cmd/longrunning-verifier` serves `/verify` with its own token and signing secret.
Token/secret files are re-read on each request, so replacing the file rotates
credentials without restart; issuance remains external. `monitoring/` contains
an example Prometheus scrape config, 15-day retention argument, and alert rules;
they are config-validated but no live collector is included.
For a larger load/fault run, set `PRAXO_LOAD_SUBMISSIONS=100` and run
`TestStandaloneServiceLoadFault`; `python scripts/test_longrunning_service.py`
runs the module suite, load/fault test, and published-package recipe. See the
[long-running operations guide](../../../docs/guides/long-running-operations.md).

From the repository root, `python scripts/test_go_longrunning.py -v` repeats the
flow in a fresh temporary application using the published package.

## Durable Execution Start and Unknown Recovery

The [execution recovery supplement](recovery.md) adds a separate application-owned
journal for durable start intent, immutable request identity and no blind replay.
It includes before/after-rename failures and real child-process exit tests. It is
a teaching adaptation of authorized AKROVELA patterns, not Core-owned operation
state or proof of AKROVELA offline-admission acceptance.

Run `go test -mod=readonly -run LongRunningExecution -count=1 -v .` here.
The complete module suite above includes these tests; root Core tests do not
include this nested module. No new Core API or product integration is required.
