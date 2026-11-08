# Registry Pages and Package Introductions

**Status:** public guidance, 2026-11-05. A package-registry page is a snapshot
created at publication. Source READMEs, manifests, and the documentation site
can be newer. Do not infer current behavior from a stale registry page, and do
not assume this repository's changes update an already-published page.

This matters for adoption: a coding agent or developer may see PyPI, npm, Maven
Central, pkg.go.dev, crates.io, NuGet, RubyGems, Packagist, Hex, pub.dev, or
another registry page before the documentation site.

## What Each Registry Renders

| Registry family | Page source | When it changes |
| --- | --- | --- |
| Go module proxy / pkg.go.dev | Tagged module README and package docs | A new module tag |
| PyPI | Published summary, keywords, classifiers, project URLs, README | A new package release |
| npm | Published description, keywords, README, repository and homepage | A new package release |
| Maven Central | POM name, description, URL, license, SCM; Javadoc/sources | A new deployment |
| crates.io, NuGet, RubyGems, Packagist, Hex, pub.dev, LuaRocks, DUB, PowerShell Gallery, r-universe, and others | Registry-specific metadata and README rendering | A new registry publication |

Registry-specific addresses and current versions are maintained in
[Registry Publication Status](registry-status.md). That page records publication
state, not a promise that every page introduction is current.

## Page Checklist

- Exact package name, version, install command, and supported runtime version.
- One-sentence positioning: embeddable, governed agent runtime with policy,
  human-in-the-loop approval, checkpoints, and tool calling.
- Task-specific keywords where the registry supports them, for example
  `agent-runtime`, `tool-authorization`, `policy-enforcement`,
  `human-in-the-loop`, `checkpoint`, `embeddable`.
- Links to the canonical documentation site, the language consumer starter, the
  security model, and [When Not to Use](../getting-started/when-not-to-use.md).
- A license and source/repository link.
- No unsupported claim of exactly-once execution, complete sandbox isolation,
  production security certification, or real-time/physical safety.
- Version metadata consistent with the source tag and the registry.

## Current Pilot Page Audit

Checked 2026-11-08 for the four pilot packages; the Go proxy was re-checked
2026-11-07.

| Language | Page | Published version | Current page state | Next action |
| --- | --- | --- | --- | --- |
| Go | [pkg.go.dev](https://pkg.go.dev/github.com/axisvela/praxo-core/v2) | `v2.6.0` | Proxy latest is `v2.6.0`; the new tag carries the consumer starters and current selection guidance. Rendered-page content was not re-audited | Verify the rendered `v2.6.0` page and mark the row current |
| Python | [PyPI](https://pypi.org/project/praxo-core/) | `0.3.2` | Rendered `0.3.2` description includes absolute registry/coding-agent links; verified 2026-11-08 | No further action |
| TypeScript | [npm](https://www.npmjs.com/package/@axisvela/praxo-core) | `0.2.1` | `0.2.1` is published; `0.2.2` with absolute links is staged and requires maintainer approval | Approve `0.2.2`, then verify the rendered page |
| Java | [Maven Central](https://central.sonatype.com/artifact/com.axisvela/praxo-core) | `0.4.1` | POM is `0.4.1` with sources/javadoc returning 200; Central does not render the README; verified 2026-11-08 | No further action |

The source metadata updates in this repository do not change the already
published `0.3.2`, `0.2.1`, and `0.4.1` language pages. The Go page follows the
`v2.6.0` tag. Do not claim that a published page is updated until its registry
shows the new version and text.

Other registries are listed in [Registry Publication Status](registry-status.md).
They were not all re-audited in this update; use the same checklist at release
time instead of inferring page quality from source files alone.

## Per-Language Registry and Coding-Agent Entries

Every `language/<language>/` directory now ships:

- `REGISTRY.md`: registry-facing introduction with package, version, install,
  registry page, documentation, and explicit boundaries.
- `llms.txt`: compact machine-readable entry for that language.
- `llms.md`: Markdown version of the same entry.
- A `README.md` link block so a rendered registry page exposes the entries.

The central index is [language/REGISTRY-INDEX.md](https://github.com/axisvela/praxo-core/blob/main/language/REGISTRY-INDEX.md).
The generated files are checked by `scripts/sync_language_registry_docs.py --check`
and `scripts/test_language_registry_docs.py`.

Package inclusion is registry-specific. Explicit allowlists now include the
files for npm, Python sdist, Cargo, NuGet, RubyGems, Hex, CPAN, and Hackage.
Registries that package the repository tree or use release workflows include
them through their existing process; Maven Central continues to render POM
metadata rather than the README. A source file or source tag is not proof that a
registry page has been updated.

The generated entries distinguish `source_version` from `published_version`. A
source release can be prepared before its registry page updates; consumers must
install the published version until the new tag is published, and a prepared
source tag is not registry availability evidence.

## For Coding Agents

1. Read the registry page for the exact package, version, and install command.
2. Prefer the canonical documentation site for behavior, boundaries, and
   verification commands.
3. Verify the published version before relying on a feature.
4. If the page is stale, report it and use the
   [coding-agent integration contract](../getting-started/coding-agents.md)
   rather than adapting unsupported behavior from the page.

## For Maintainers

- Update source description, keywords, README, and canonical links before the
  release, not after.
- Publish a new version to update a registry page; do not move or reuse tags.
- After publication, verify the rendered description, keywords, README, install
  command, license, and version, then update
  [Registry Publication Status](registry-status.md) with the checked date.
- Keep registry-specific procedures in the internal release runbooks.

## Published Artifact Acceptance

A source README update is not completion. At the next official release, verify
the actual package and rendered page for each affected registry:

| Evidence | Acceptance |
| --- | --- |
| Identity | Exact package/version, immutable source tag and artifact digest agree |
| Packaged introduction | Inspect the downloaded wheel/sdist, npm tarball, Maven POM/sources or tagged Go module, not main |
| Rendered page | Verify positioning, consumer starter links, limitations, installation and runtime requirements at the versioned public URL |
| Consumer installation | Install that version in a clean consumer and execute its documented deterministic smoke/allow-deny checks |
| Boundaries | Explain what Core implements, what tests verify, and what the consumer must supply; policy is configurable, sandbox interfaces are not isolation, checkpoints are not external transactions |

Record the checked version, URL, date, artifact hash and observed result before
marking the page current in [Registry Publication Status](registry-status.md).
If rendering/indexing is delayed, mark it pending rather than inferring success
from a publish job. A registry that does not render README content (for example
Maven Central) must still have accurate metadata and canonical documentation links.

## MATLAB Compatibility Metadata

Checked 2026-11-06: [File Exchange](https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core)
shows version `0.2.1`, "Compatible with any release" and Windows/macOS/Linux
labels; its installation menu also says R2026b or later. These labels are not
independent MATLAB test evidence. The implementation is tested under GNU Octave
11.3.0; MATLAB execution and installed-artifact validation remain unverified.
The submission owner must narrow editable compatibility metadata or add the
prominent [runtime limitation](matlab/index.md) to the Overview.
This source change does not edit the live submission.
