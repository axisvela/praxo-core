# E2B Workspace Adapter (Evaluation)

This module adapts E2B sandboxes to the workspace evaluation contract. It is
not a published adapter and is not part of `pkg/...`.

It uses the E2B platform REST API for create/attach/pause/resume/delete and the
envd Connect/JSON endpoints for commands and files.

## Configuration

```go
provider, err := e2b.New(e2b.Config{
    APIKey: os.Getenv("E2B_API_KEY"),
})
```

Defaults:

- platform URL: `https://api.e2b.app`
- envd URL: `https://sandbox.e2b.app`
- template: `base`
- envd port: `49983`

## Test

```bash
cd adapters/workspace/e2b
GOWORK=off go test ./...
```

The default test runs the shared workspace conformance suite against an
in-process fake platform and envd server. It does not call E2B.

## Live Verification

Live verification requires an `E2B_API_KEY` and is intentionally not part of
default CI. The live test skips when the key is absent.

```bash
cd adapters/workspace/e2b
E2B_API_KEY=... GOWORK=off go test -run TestLiveConformance -v ./...
```

Optional: `E2B_TEMPLATE`, `E2B_PLATFORM_URL`, `E2B_ENVD_URL`. Record the tested
API version, region, template, and observed capability gaps.

## Limits

- No snapshot API mapping.
- `Glob` and `Grep` walk files through envd calls rather than a server-side
  search primitive.
- `Run` returns one command result; streaming command output is not exposed.
- No control plane, warm pool, image catalog, quota, billing, or multi-tenant
  isolation.
