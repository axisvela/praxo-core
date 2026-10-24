# CubeSandbox Workspace Adapter (Evaluation)

This module adapts CubeSandbox to the workspace evaluation contract using the
official CubeSandbox Go SDK (`github.com/tencentcloud/CubeSandbox/sdk/go`). It is
an evaluation adapter, not part of `pkg/...`.

CubeSandbox is Apache-2.0 except for listed third-party components.

## Configuration

```go
provider := cubesandbox.New(cubesandbox.Config{
    APIURL:     os.Getenv("CUBE_API_URL"),
    APIKey:     os.Getenv("CUBE_API_KEY"),
    TemplateID: os.Getenv("CUBE_TEMPLATE_ID"),
})
```

Optional: `MCPTemplateID`, `ProxyNodeIP`, `ProxyPortHTTP`, `ProxyScheme`,
`SandboxDomain`, `Timeout`, `RequestTimeout`.

## Test

```bash
cd adapters/workspace/cubesandbox
GOWORK=off go test ./...
```

The default test runs the shared workspace conformance suite against an
in-process fake SDK client. It does not call CubeSandbox.

## Live Verification

```bash
cd adapters/workspace/cubesandbox
CUBE_API_URL=... CUBE_TEMPLATE_ID=... CUBE_API_KEY=... \
  GOWORK=off go test -run TestLiveConformance -v ./...
```

The live test skips when `CUBE_API_URL` or `CUBE_TEMPLATE_ID` is absent.

## Limits

- The adapter maps `Spec.Image` to a CubeSandbox template ID; it does not build
  templates.
- `Glob` and `Grep` are client-side walks.
- No control plane, warm pool, quota, billing, or multi-tenant isolation.
