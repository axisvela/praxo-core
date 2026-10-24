# OpenSandbox Workspace Adapter (Evaluation)

This module adapts OpenSandbox to the workspace evaluation contract using the
OpenSandbox Go SDK (`github.com/alibaba/OpenSandbox/sdks/sandbox/go`). It is an
evaluation adapter, not part of `pkg/...`.

OpenSandbox is Apache-2.0.

## Configuration

```go
provider := opensandbox.New(opensandbox.Config{
    Domain:       os.Getenv("OPEN_SANDBOX_DOMAIN"),
    Protocol:     os.Getenv("OPEN_SANDBOX_PROTOCOL"),
    APIKey:       os.Getenv("OPEN_SANDBOX_API_KEY"),
    DefaultImage: os.Getenv("OPEN_SANDBOX_IMAGE"),
})
```

`OPEN_SANDBOX_DOMAIN` is the server address, for example `localhost:8080`.
`OPEN_SANDBOX_IMAGE` is the default container image for new sandboxes.

## Test

```bash
cd adapters/workspace/opensandbox
GOWORK=off go test ./...
```

The default test runs the shared workspace conformance suite against an
in-process fake SDK client. It does not call OpenSandbox.

## Live Verification

```bash
cd adapters/workspace/opensandbox
OPEN_SANDBOX_DOMAIN=... OPEN_SANDBOX_IMAGE=... OPEN_SANDBOX_API_KEY=... \
  GOWORK=off go test -run TestLiveConformance -v ./...
```

The live test skips when `OPEN_SANDBOX_DOMAIN` or `OPEN_SANDBOX_IMAGE` is absent.

## Limits

- The adapter maps `Spec.Image` to the sandbox image; it does not build images.
- `Glob` and `Grep` are client-side walks.
- No control plane, pool, quota, billing, or multi-tenant isolation.
