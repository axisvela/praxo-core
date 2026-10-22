# Contributing to PRAXO-CORE

PRAXO-CORE is an MIT-licensed framework. Contributions that keep the public API
small, tested, and product-neutral are welcome.

## Development

Requirements: Go 1.26 or newer.

```bash
GOWORK=off go test ./...
GOWORK=off go vet ./...
GOWORK=off go build ./...
GOWORK=off go test -race ./...
```

The NOETIVELA SDK example is a separate module:

```bash
cd examples/ecosystem-sdk
GOWORK=off go test ./...
GOWORK=off go vet ./...
GOWORK=off go build ./...
```

The MCP adapter is also a separate module:

```bash
cd adapters/mcp
GOWORK=off go test ./...
GOWORK=off go vet ./...
GOWORK=off go build ./...
```

Documentation:

```bash
pip install -r requirements-docs.txt
mkdocs build --strict
```

## Pull Requests

- Keep changes focused and explain the reason in the PR summary.
- Add tests for exported interfaces and loop behavior.
- Update documentation when behavior or public API changes.
- Do not add product credentials, tenant data, secrets, or AGPL-only imports.
- Do not copy third-party code without compatible licensing and notices.
- Run the commands above before requesting review.

## API Changes

Exported interfaces, struct fields, JSON tags, error sentinels, and wire
formats are part of the compatibility contract. Document intentional API
changes in `CHANGELOG.md` and `docs/05-compatibility.md`.

## Commit Style

Use clear prefixes such as `feat:`, `fix:`, `docs:`, `test:`, and `refactor:`.
Keep commits small enough to review.

## License

By contributing, you agree that your contribution is licensed under the MIT
License and that AxisVela may relicense contributed code as described in
`docs/04-license-and-provenance.md`.

## Security

Do not report vulnerabilities in public issues. See [SECURITY.md](SECURITY.md).

## Community

Follow the [Code of Conduct](CODE_OF_CONDUCT.md). Use GitHub Discussions for
questions and design proposals.
