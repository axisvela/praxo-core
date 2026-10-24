# Daytona Workspace Adapter (Evaluation)

This module adapts Daytona sandboxes to the workspace evaluation contract using
the official Daytona Go SDK. It is not a published adapter and is not part of
`pkg/...`.

The SDK is `github.com/daytona/clients/sdk-go v0.226.1`. The Daytona clients
repository is Apache-2.0 outside its `cli/` directory; this adapter does not use
`cli/`.

## Configuration

```go
provider, err := daytona.New(daytona.Config{
    APIKey: os.Getenv("DAYTONA_API_KEY"),
    APIURL: os.Getenv("DAYTONA_API_URL"),
    Target: os.Getenv("DAYTONA_TARGET"),
})
```

## Test

```bash
cd adapters/workspace/daytona
GOWORK=off go test ./...
```

The default test runs the shared workspace conformance suite against an
in-process fake SDK client. It does not call Daytona.

## Live Verification

Live verification requires a `DAYTONA_API_KEY` and is intentionally not part of
default CI. Record the SDK version, target region, image or snapshot, and
observed capability gaps.

## Limits

- The SDK exposes one combined command output string, so `sandbox.Result.Stdout`
  carries it and `Stderr` is empty.
- `Attach` uses `Client.Get`; it does not add a new lifecycle primitive.
- No snapshot adapter surface.
- No control plane, warm pool, image catalog, quota, billing, or multi-tenant
  isolation.
