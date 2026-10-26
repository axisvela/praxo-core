# Release Requirements

Core, SDKs, optional adapters, and the shared specification have independent
version lines. A release must document its scope and compatibility impact.

## Required Evidence

- Update the applicable version file, changelog, and user-facing release notes.
- Pass build, tests, API checks, and security checks for the affected artifact.
- SDKs pass their declared conformance vectors and parity checks.
- Review dependency licenses and generate applicable SBOMs and checksums.
- Verify release tags; signed tags are preferred and exceptions are documented.
- Verify installation from the artifact users will actually consume.

## Tag Names

| Artifact | Tag |
| --- | --- |
| Go core | `vX.Y.Z` |
| Shared specification | `spec/vX.Y.Z` |
| Language SDK | `<language>/vX.Y.Z` |
| Optional Go adapter | `adapters/<name>/vX.Y.Z` |

Existing tags are immutable. SDK releases declare their supported contract
version. The root release workflow handles only `v*` core tags; a source tag for
an SDK or adapter does not by itself publish a package-registry artifact.

## Consumer Guidance

Use [release notes](../releases/index.md) to review changes, then follow the
artifact's documented installation method. Check [compatibility](compatibility.md)
and [SDK support](../sdks/support.md) before upgrading. Product release versions
are independent from framework versions.
