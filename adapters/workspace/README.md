# Workspace Session Contract (Evaluation)

This module is an evaluation spike for a provider-neutral workspace/session
contract. It is not part of `pkg/...` and must not be promoted until at least
two provider adapters fit without provider-specific fields.

## Packages

- `contract`: candidate `Provider`, `Session`, optional `Pauser` and
  `Snapshotter` interfaces.
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

## Status

The shared contract, fake, and conformance checks exist. E2B and Daytona
adapters are the next evaluation step. Provider SDKs must stay in their own
adapter modules, and live provider tests must be opt-in.
