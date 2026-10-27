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
python -m unittest discover -s scripts -p "test_*.py" -v
```

## Documentation

Public documentation under `docs/` is organized by user task: getting started,
guides, SDKs, integrations, reference, security, project information, releases,
and contributing. Keep the same paths under `docs/zh-CN/` for translations.
Missing translations fall back to English.

Independent language implementations live under `language/`, runtime wrappers under
`bindings/`, and shared-runtime samples under `examples/`. See the
[source migration guide](docs/project/repository-layout.md) before updating
source-based consumer scripts. The Go root module and public imports stay unchanged.

Each language has an entry under `docs/languages/`. Pages with `sdk_readme` metadata
render the source README during the site build so examples, installation
instructions, and limitations have one source. Update that README rather than
copying its content. Distinguish source tags from package-registry availability.

Keep historical releases in `releases/index.md` rather than adding every version
to the sidebar. When moving a published page, update repository links and the
redirect map in `scripts/docs_hooks.py`, then run the strict build and tests.

Only user-facing guidance and public contribution requirements belong here.
Internal execution plans, staffing, effort estimates, product split decisions,
and release-operator instructions belong in `PRAXOVELA-EE/docs/praxo-core/`,
not in a hidden or navigation-excluded directory in this public repository.

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
changes in `CHANGELOG.md` and `docs/project/compatibility.md`.

## Commit Style

Use clear prefixes such as `feat:`, `fix:`, `docs:`, `test:`, and `refactor:`.
Keep commits small enough to review.

## License

By contributing, you agree that your contribution is licensed under the MIT
License and that AxisVela may relicense contributed code as described in
`docs/project/provenance.md`.

## Security

Do not report vulnerabilities in public issues. See [SECURITY.md](SECURITY.md).

## Community

Follow the [Code of Conduct](CODE_OF_CONDUCT.md). Use GitHub Discussions for
questions and design proposals.
