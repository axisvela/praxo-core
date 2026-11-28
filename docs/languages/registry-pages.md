# Registry Pages and Package Introductions

**Status:** public audit, 2026-11-27. A package-registry page is a snapshot
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

- Product description first, then get started/install, examples, scenario tutorials,
  reference applications, capability evidence, limits, and community. Distinguish
  a bounded teaching slice or application source from accepted end-to-end behavior.
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

## Product Discovery

PRAXO-CORE (also written **praxocore**) is an embeddable, MIT-licensed
multi-language AI agent framework. Both spellings identify the same framework;
the alias does not rename imports, modules, package coordinates, or repositories.
R's existing package name `praxocore` is unchanged.

`language/discovery.json` configures the product aliases, shared and
language/ecosystem-specific GitHub topics, publication-source split keys, and
repository-name overrides (including `praxo-core-Julia`). The registry generator
embeds this discovery metadata in `language/registry-metadata.json`. The shared
MATLAB/Octave implementation is not a standalone package or mirror.

The English and Chinese site homepages also expose `SoftwareSourceCode` JSON-LD
with the product name, aliases, canonical repository, MIT license, description,
and shared discovery terms. This identifies source software, not a hosted
service, rated product, or independently certified security system.

Local checks and a **proposal only**, with no network calls or remote mutation:

```bash
python -m scripts.discovery.sync_language_registry_docs --check
python -m scripts.discovery.repository_discovery --check
python -m scripts.discovery.repository_discovery
python -m unittest discover -s scripts -t . -p test_discovery.py -v
```

The proposal covers the canonical repository, 22 discovery mirrors, and nine
publication-source splits. Topics follow GitHub's 20-topic limit and syntax.
The canonical proposal retains the existing descriptive topics and adds both
product spellings; language proposals combine shared product terms with their
own language and ecosystem terms. Review differences against live topics before
any separately authorized update. The proposal is not wired to mirror sync and
does not publish packages, tags, branches, or topics.

Discovery files and natural-language aliases help readers and search/coding
tools identify the framework. They do not guarantee SEO ranking, generative
engine citations, crawler indexing, package discovery, or adoption. Capability
claims still come from [adapter status](adapter-status.md), each implementation's
README, and [verification evidence](../project/evaluation/verification-evidence.md).

### Metadata Coverage

| Ecosystem | Source discovery fields | Constraints and remaining gaps |
| --- | --- | --- |
| PyPI / npm | Description, keywords, README, canonical URLs | Rich task and ecosystem terms; package IDs and versions are unchanged |
| crates.io | Description, five focused keywords, Cargo categories, README | Five keywords maximum, 20 characters each; alias is also in the description |
| NuGet / PowerShell Gallery | Description and package/module tags, README | C#/.NET and PowerShell-specific terms; PowerShell wraps the C# runtime |
| pub.dev | Description and five topics, README | Five topics maximum; do not invent Flutter-specific support |
| CPAN / opam | CPAN `META_MERGE` keywords and POD; generated opam tags and source README | OCaml publication remains pending; staged metadata is not an opam listing |
| Maven Central | POM description and canonical links | No standard POM keywords field; description contains ordered discovery links and limits |
| RubyGems / Hex / DUB / Nimble / V / r-universe / Octave | Native description/summary and README | Do not invent unsupported keyword fields; RubyGems metadata URI fields are not tags |
| LuaRocks | Current rockspec summary/detailed introduction and README | Historical rockspecs are not rewritten; live labels require a separate registry audit |
| Swift / Julia / C / C++ / Fortran / COBOL / Delphi / Objective-C / Zig / MATLAB | Source README, registry and coding-agent entries, repository topic proposal | No universal keyword field; external package indexes and File Exchange metadata need their own audit |
| PHP / Packagist | Generated README, registry and coding-agent entries, repository topic proposal | Composer metadata and the complete runtime payload were published in `0.10.2`; rendered-page re-audit pending |

These are source changes, not claims that an already-published artifact or
rendered registry page has been refreshed. A future authorized release must
inspect packaged bytes, rendered introductions, keywords/topics, and consumer
installation before recording page acceptance. Split publication repositories
also require their own reviewed source update; mirror branch sync does not
update those layouts or topics.

## Public Page Audit

GitHub Latest was corrected on 2026-11-26 to the existing
[Go `v2.9.0` Release](https://github.com/axisvela/praxo-core/releases/tag/v2.9.0).
The Go proxy has `v2.11.3`, and the GitHub Release is published as latest. This repairs
the language-release designation error, not the missing Core Release or package
README snapshots. `scripts/release/check_public_release.py` checks the live designation
and expected Core Release separately from local metadata checks.

Audit date: 2026-11-27. Published availability is not page acceptance. The
following immutable release snapshots retain known defects; source corrections
do not repair them. A new publication and a fresh audit are still required.

| Language | Published evidence | Version | Observed defect | Acceptance |
| --- | --- | --- | --- | --- |
| Go | [pkg.go.dev](https://pkg.go.dev/github.com/axisvela/praxo-core/v2@v2.11.3) | `v2.11.3` | README installs `@v2.11.3` and calls `v2.11.3` current | Rendered-page re-audit pending |
| Python | [PyPI](https://pypi.org/project/praxo-core/0.11.2/) | `0.11.2` | None recorded in source | Not accepted |
| TypeScript | [npm](https://www.npmjs.com/package/@axisvela/praxo-core/v/0.10.1) | `0.10.1` | None recorded in source | Rendered-page re-audit pending |
| Java | [Maven POM](https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.12.3/praxo-core-0.12.3.pom) | `0.12.3` | SCM tag is `java/v0.12.3` | Rendered-page re-audit pending |
| Rust | [crates.io](https://crates.io/crates/praxo-core/0.11.0) | `0.11.0` | Packaged README installs `0.9.2` | Not accepted |
| C# | [NuGet](https://www.nuget.org/packages/Praxo.Core/0.11.1) | `0.11.1` | None recorded in source | Rendered-page re-audit pending |
| Dart | [pub.dev](https://pub.dev/packages/praxo_core/versions/0.8.0) | `0.8.0` | Packaged README installs `0.7.0` | Not accepted |
| Haskell | [Hackage](https://hackage.haskell.org/package/praxo-core-0.9.0) | `0.9.0` | Packaged README installs `0.7.1` | Not accepted |

The Go release documentation date is 2026-11-27; the
[proxy publication timestamp](https://proxy.golang.org/github.com/axisvela/praxo-core/v2/@v/v2.11.3.info)
is 2026-11-27 UTC. Neither supports the earlier claimed 2026-11-16 page acceptance
or 2026-11-20 release date. No remote correction is claimed here.

Other publication evidence is in [Registry Publication Status](registry-status.md).
Swift Package Index lists split package `0.7.2`, whose non-streaming scope must
not be confused with monorepo `swift/v0.9.0` streaming scope. R r-universe
`0.12.0` was built from actual HEAD `9b417e3`; its checks include warnings, not
an all-clean result. Registry availability alone accepts neither page quality
nor runtime compatibility.

## Per-Language Registry and Coding-Agent Entries

Every `language/<language>/` directory now ships:

- `REGISTRY.md`: registry-facing introduction with package, version, install,
  registry page, documentation, and explicit boundaries.
- `llms.txt`: compact machine-readable entry for that language.
- `llms.md`: Markdown version of the same entry.
- A `README.md` link block so a rendered registry page exposes the entries.

The central index is [language/REGISTRY-INDEX.md](https://github.com/axisvela/praxo-core/blob/main/language/REGISTRY-INDEX.md).
The generated files are checked by `scripts/discovery/sync_language_registry_docs.py --check`
and `scripts/discovery/test_language_registry_docs.py`.

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

Checked 2026-11-26: [File Exchange](https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core)
shows version `0.9.1` (source `matlab/v0.9.0`), but its citation still names
`0.2.1`. It shows "Compatible with any release" and Windows/macOS/Linux
labels; its installation menu also says R2026b or later. These labels are not
independent MATLAB test evidence. The implementation is tested under GNU Octave
11.3.0; MATLAB execution and installed-artifact validation remain unverified.
The submission owner must narrow editable compatibility metadata or add the
prominent [runtime limitation](matlab/index.md) to the Overview.
This source change does not edit the live submission.
