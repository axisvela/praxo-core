# Workspace Session Contract (Evaluation)

This module is an evaluation spike for a provider-neutral workspace/session
contract. It is not part of `pkg/...` and must not be promoted until at least
two provider adapters fit without provider-specific fields.

## Packages

- `contract`: candidate `Provider`, `Session`, optional `Pauser` and
  `Snapshotter` interfaces.
- `profile`: evaluation-only runtime profiles for state, local, and sandbox
  composition. Tools are selected from explicit capabilities, not from backend
  type assertions.
- `fake`: in-memory provider and session for offline tests. It does not execute
  host commands and is not an isolation boundary.
- `conformance`: reusable checks for adapters and fakes.

## Test

```bash
cd adapters/workspace
GOWORK=off go test ./...
GOWORK=off go vet ./...
GOWORK=off go build ./...
```

## Adapters

- `e2b`: E2B platform REST and envd adapter, with an in-process fake server test.
- `daytona`: Daytona Go SDK adapter, with an in-process fake client test.
- `opensandbox`: OpenSandbox Go SDK adapter, with an in-process fake client test.
- `cubesandbox`: CubeSandbox Go SDK adapter, with an in-process fake client test.

## Status

The shared contract, fake, conformance checks, and offline E2B, Daytona,
OpenSandbox, and CubeSandbox adapters exist. None has been run against a live
provider in this environment. CubeSandbox is E2B-compatible, so the E2B adapter
may still be evaluated as a compatibility profile before keeping a separate
implementation. Provider SDKs stay in their own adapter modules, and live tests
must be opt-in.
