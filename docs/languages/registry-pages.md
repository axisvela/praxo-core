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

Checked 2026-11-05 for the four pilot packages.

| Language | Page | Published version | Current page state | Next action |
| --- | --- | --- | --- | --- |
| Go | [pkg.go.dev](https://pkg.go.dev/github.com/axisvela/praxo-core/v2) | `v2.5.2` | Proxy latest is `v2.5.2`; pkg.go.dev renders the tagged source README | Publish a new tag to show the consumer starters and current selection guidance |
| Python | [PyPI](https://pypi.org/project/praxo-core/) | `0.3.0` | Summary and keywords are generic; published README predates the consumer/governance additions | Source metadata updated; publish a new release to update the page |
| TypeScript | [npm](https://www.npmjs.com/package/@axisvela/praxo-core) | `0.2.0` | Description and keywords are generic; published README predates the consumer/governance additions | Source metadata updated; publish a new release to update the page |
| Java | [Maven Central](https://central.sonatype.com/artifact/com.axisvela/praxo-core) | `0.4.0` | POM description is generic; Central does not render the source README | Source POM updated; deploy a new release to update the page |

The source metadata updates in this repository do not change the already
published `0.3.0`, `0.2.0`, `0.4.0`, or `v2.5.2` pages. Do not claim that a
published page is updated until its registry shows the new version and text.

Other registries are listed in [Registry Publication Status](registry-status.md).
They were not all re-audited in this update; use the same checklist at release
time instead of inferring page quality from source files alone.

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
