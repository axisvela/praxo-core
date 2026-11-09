# Long-Running Operation Recipe (Go)

This module demonstrates the application-owned side of a remote long-running
operation: idempotent submission, status recovery, cancel request versus
confirmation, effect verification, fencing, and restart behavior. It consumes
published Core `2.6.0`; it does not add a Core API.

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
services. See the
[long-running operations guide](../../../docs/guides/long-running-operations.md).

From the repository root, `python scripts/test_go_longrunning.py -v` repeats the
flow in a fresh temporary application using the published package.
