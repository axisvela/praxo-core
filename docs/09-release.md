# Release Process

## Disciplines

- Versions are clean semver: `major.minor.patch`. No `-rc`, `-beta`, or other
  suffixes.
- `PRAXOVELA` and `PRAXOVELA-open` share the exact `vX.Y.Z` tag.
  `PRAXOVELA-EE` may release independently on the same clean semver scheme.
- `VERSION` and `CHANGELOG.md` are updated before tagging.
- A release tag is signed by the operator.

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

1. Update `PRAXOVELA` module pins to `vX.Y.Z`.
2. Run `go mod tidy` and `go mod vendor` in `packages/axon-core`.
3. Run the full `PRAXOVELA` and `PRAXOVELA-open` suites.
4. Update the extraction docs in `PRAXOVELA-EE`.

## Checklist

- [ ] `VERSION` and `CHANGELOG.md` updated
- [ ] API snapshot and diff reviewed
- [ ] release-check, race, fuzz, staticcheck, govulncheck green
- [ ] security checklist complete
- [ ] SBOM and checksums generated
- [ ] signed tag created and verified
- [ ] GitHub release published
- [ ] PRAXOVELA and PRAXOVELA-open pinned and tested
