# Release Process

## Disciplines

- Versions are clean semver: `major.minor.patch`. No `-rc`, `-beta`, or other
  suffixes.
- Product repositories may release independently on the same clean semver
  scheme.
- `VERSION` and `CHANGELOG.md` are updated before tagging.
- A release tag is signed by the operator. If no signing key is available, use an annotated tag and record that fact in the release notes; signed tags are preferred.

## Pre-Release Gate

Run from the repository root on a supported platform:

```powershell
.\scripts\release-check.ps1 -Fuzz
```

Run the race job on Linux (the Windows race detector needs a working cgo
toolchain):

```bash
GOWORK=off go test -race ./...
```

The release also requires:

- CI green for Linux, Windows, and macOS
- green race/fuzz/staticcheck/govulncheck jobs
- API diff review (below)
- privacy checks pass for non-public email domains and internal hostnames
- security review completed per `docs/08-security.md`
- SBOM and checksums generated

## API Diff

Generate a snapshot for the previous release and the candidate version:

```powershell
.\scripts\api-snapshot.ps1 -Version 0.16.0
.\scripts\api-snapshot.ps1 -Version 1.0.0
.\scripts\api-diff.ps1 -From 0.16.0 -To 1.0.0
```

Commit the candidate snapshot under `api/<version>.txt`. Every added, removed,
or changed exported declaration must be intentional and reflected in
`CHANGELOG.md` and `docs/05-compatibility.md`.

## SBOM

```powershell
go install github.com/CycloneDX/cyclonedx-gomod/cmd/cyclonedx-gomod@latest
.\scripts\sbom.ps1
```

The result is `dist/sbom.json`. The release workflow runs the same command on
Linux.

## Source Archive and Checksums

```powershell
.\scripts\checksums.ps1 -Version 1.0.0
```

This writes `dist/praxo-core-1.0.0.tar.gz` and `dist/SHA256SUMS`.

## Optional Adapter Modules

Modules under `adapters/<name>` have their own `go.mod` and an independent
semantic-version line. They keep provider and protocol SDKs out of the core
module, so a core release does not require an adapter release and vice versa.

Tag an optional module as `adapters/<name>/vX.Y.Z`:

```bash
git tag -s adapters/mcp/v0.3.1 -m "praxo-core adapters/mcp v0.3.1"
git tag -v adapters/mcp/v0.3.1
git push origin adapters/mcp/v0.3.1
```

Existing module tags are immutable. Consumers install the tagged module with
the version segment from the tag:

```bash
go get github.com/axisvela/praxo-core/adapters/mcp@v0.3.1
```

The module tag must match the module's `go.mod` path. Update the module
`README.md` and `docs/adapters.md` in the same change, and run the module's
tests, vet, and build from its directory before tagging. The root `release.yml`
workflow runs only for `v*` tags; a tag such as `adapters/mcp/v0.3.1` does not
produce the core archive, SBOM, or GitHub release. Verify and publish optional
module releases separately.

Current optional modules:

- [`adapters/mcp`](https://github.com/axisvela/praxo-core/tree/main/adapters/mcp) - MCP tools, resources, and prompts
- [`adapters/otel`](https://github.com/axisvela/praxo-core/tree/main/adapters/otel) - OpenTelemetry event sink
- [`adapters/anthropic`](https://github.com/axisvela/praxo-core/tree/main/adapters/anthropic) - native Anthropic adapter
- [`adapters/gemini`](https://github.com/axisvela/praxo-core/tree/main/adapters/gemini) - native Gemini adapter

The same scheme applies to `adapters/harmovela`, `adapters/a2a`, and
`adapters/multiagent`. The OpenAI-compatible adapter stays in the core module
because it uses only the standard library.

## Tag Identity

- Release tags use the release signing identity:
  `AxisVela Release Signing <releases@axisvela.com>`.
- Existing tags keep their recorded identity; new tags must not use personal
  identities.
- Set the committer identity for the tag command only. Do not change repository
  config permanently. Select the release key explicitly with `-u`:

```powershell
$env:GIT_COMMITTER_NAME="AxisVela Release Signing"
$env:GIT_COMMITTER_EMAIL="releases@axisvela.com"
git tag -s -u <release-key-id> v2.5.1 -m "praxo-core v2.5.1"
```

## Multilingual Tags

- `spec/vX.Y.Z` tags the normative contract and must match
  `spec/SPEC_VERSION`.
- `python/vX.Y.Z` tags the Python SDK and must match `python/pyproject.toml`.
- `python/adapters/<name>/vX.Y.Z`, `typescript/...`, and `java/...` follow the
  same per-language scheme.
- These tags do not trigger `release.yml` (`v*` only). They produce no Go
  archive, SBOM, or GitHub release.
- Tag a spec or SDK release only after its conformance vectors and parity linter
  pass.

## Tag and Publish

```bash
git tag -s v1.0.0 -m "praxo-core v1.0.0"
git tag -v v1.0.0
git push origin v1.0.0
```

The `release.yml` workflow verifies that the tag matches `VERSION`, runs the
test gate, produces the SBOM, creates the source archive/checksums, and
publishes the GitHub release.

## Consumer Update

1. Update downstream module pins to `vX.Y.Z`.
2. Run `go mod tidy` and `go mod vendor` in each consumer module.
3. Run every downstream test suite.
4. Record release evidence in the internal release tracker.

## Checklist

- [ ] `VERSION` and `CHANGELOG.md` updated
- [ ] API snapshot and diff reviewed
- [ ] release-check, race, fuzz, staticcheck, govulncheck green
- [ ] security checklist complete
- [ ] SBOM and checksums generated
- [ ] signed tag created and verified
- [ ] GitHub release published
- [ ] downstream consumers pinned and tested
