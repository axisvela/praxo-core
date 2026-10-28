# Release Requirements

Core, SDKs, optional adapters, and the shared specification have independent
version lines. A release must document its scope and compatibility impact.

## Required Evidence

- Update the applicable version file, changelog, and user-facing release notes.
- Pass build, tests, API checks, and security checks for the affected artifact.
- SDKs pass their declared conformance vectors and parity checks.
- Review dependency licenses and generate applicable SBOMs and checksums.
- Publish a release manifest with the tag, commit SHA, version, spec version,
  Go toolchain, SBOM scope, and every attachment hash. Checksums cover the
  archive, SBOM, and manifest; the checksum file does not list itself.
- Verify release tags; signed tags are preferred and exceptions are documented.
- Verify installation from the artifact users will actually consume.

## Automated Checks

The core release workflow requires successful `ci` and `docs` push workflows
for the tagged commit's exact SHA on `main`, before a separate job receives
release-write permissions. Missing, unfinished, skipped, cancelled, or failed
runs block publication; an older successful attempt cannot mask a newer failed
attempt. Checks from another commit, branch, repository, or pull request do not
satisfy this requirement.

Documentation builds run for every push to `main`, including source-only changes,
so the same-commit requirement is attainable. Pull-request documentation builds
remain path-filtered. These checks observe GitHub Actions state at verification
time; they do not lock later reruns or replace compatibility, artifact-installation,
signature, and release-scope review. A green workflow is not by itself a reason
to create a new version tag.

Manual dispatch runs only the read-only prerequisite for the selected commit.
The publication job additionally requires a `v*` tag push and is skipped on
manual runs, allowing live gate validation without creating a tag or release.

## Artifact Evidence

`release-manifest.json` records the release version, tag, full commit SHA, spec
version, reported Go toolchain, SBOM scope, and the size and SHA-256 of each
attachment. `SHA256SUMS` covers the source archive, `sbom.json`, and the
manifest. The SBOM scope is currently the root Go module's dependencies only; it
is not a combined SBOM for every independent adapter, language SDK, or native
dependency. Record that distinction instead of presenting the root SBOM as a
complete archive inventory.

## Tag Names

| Artifact | Tag |
| --- | --- |
| Go core | `vX.Y.Z` |
| Shared specification | `spec/vX.Y.Z` |
| Language SDK | `<language>/vX.Y.Z` |
| Optional Go adapter | `adapters/<name>/vX.Y.Z` |

Tags and `VERSION` files use plain `X.Y.Z` versions. Do not add pre-release
suffixes such as `-rc.1`, `-beta`, or `-alpha`. Existing tags are immutable.
SDK releases declare their supported contract version. The root release workflow handles only `v*` core tags; a source tag for
an SDK or adapter does not by itself publish a package-registry artifact.

## Consumer Guidance

Use [release notes](../releases/index.md) to review changes, then follow the
artifact's documented installation method. Check [compatibility](compatibility.md)
and [SDK support](../languages/support.md) before upgrading. Product release versions
are independent from framework versions.
