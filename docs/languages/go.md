# Go Core

Go is the reference implementation. Install the current core release:

```bash
go get github.com/axisvela/praxo-core/v2@v2.5.2
```

The module declares Go 1.25; CI and releases use Go 1.26.10. Follow the
[quickstart](../getting-started/quickstart.md) for a runnable example using
Ollama or an OpenAI-compatible endpoint.

## Features and Boundaries

The reference includes the governed agent loop, policies, tools, memory,
events, checkpoints, middleware, delegation, and VFS contracts. Concrete
providers and product control planes are optional integrations, not required
dependencies. Review [primitives](../reference/primitives.md),
[security](../security/index.md), and [adapter scope](../integrations/index.md).

## API and Examples

- [Go API reference](https://pkg.go.dev/github.com/axisvela/praxo-core/v2)
- [Quickstart source](https://github.com/axisvela/praxo-core/tree/main/examples/quickstart)
- [Checkpoint example](https://github.com/axisvela/praxo-core/tree/main/examples/checkpoint)
- [Governed workspace example](https://github.com/axisvela/praxo-core/tree/main/examples/governed-workspace)
- [Compatibility](../project/compatibility.md)

## Verify From Source

Run from the repository root with `GOWORK=off`:

```bash
go test ./...
go vet ./...
go build ./...
```
