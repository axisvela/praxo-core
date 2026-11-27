# Registry Publication Status

Public audit: 2026-11-27. The versioned registry URLs below record published
availability, not acceptance of package descriptions or consumer installation.
Go `v2.11.3` is the reference release dated 2026-11-27 in the release docs;
the [Go proxy metadata](https://proxy.golang.org/github.com/axisvela/praxo-core/v2/@v/v2.11.3.info)
records publication on 2026-11-27 UTC. These are different dates, not a
2026-11-20 release. Unchanged pending rows retain their earlier evidence.

This page summarizes where each language implementation is published. Source
tags, package-registry versions, conformance, and production verification are
separate claims. A registry version does not imply full Go feature parity or
production readiness.

Registry pages are release snapshots. Their descriptions, keywords, and READMEs
may lag the source repository and the documentation site. See
[Registry Pages and Package Introductions](registry-pages.md) for the page
checklist and the current pilot-page audit.

Each language source directory also has a registry-facing `REGISTRY.md`,
`llms.txt`, and `llms.md`; the central list is
[language/REGISTRY-INDEX.md](https://github.com/axisvela/praxo-core/blob/main/language/REGISTRY-INDEX.md). These are source
entries, not evidence that a registry page has been refreshed.

## Tutorials, candidate scenarios, and reference applications

- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/): delivery standards and the reference-application portfolio.
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/): candidate business goals and their existing related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/): cross-language tutorials, examples, and application paths.
- [Reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio): planned and existing full host integrations.
- Per-language `REGISTRY.md` entries link their `Tutorial/` and `application/` source directories.

## Published Versions

This is the **Language Release Index** for registry versions. For independent
source tags and capability declarations, use the [implementation directory](index.md).
GitHub Latest represents the Go Reference Core only, not the last language package published.

| Language | Registry | Version | Address | Status |
| --- | --- | --- | --- | --- |
| Go | Go module proxy / pkg.go.dev | `v2.11.3` | https://pkg.go.dev/github.com/axisvela/praxo-core/v2@v2.11.3 | published; rendered README installs and calls current `v2.11.3` |
| Python | PyPI | `0.11.0` | https://pypi.org/project/praxo-core/0.11.0/ | published; README defect recorded in page audit |
| TypeScript | npm | `0.10.1` | https://www.npmjs.com/package/@axisvela/praxo-core/v/0.10.1 | published; latest; README updated; rendered-page re-audit pending |
| Java | Maven Central | `0.12.3` | https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.12.3/ | published; SDK version corrected; SCM tag `java/v0.12.3` |
| Rust | crates.io | `0.11.1` | https://crates.io/crates/praxo-core/0.11.1 | published; README includes scenario tutorials, reference-application status, and community links |
| C# | NuGet | `0.11.1` | https://www.nuget.org/packages/Praxo.Core/0.11.1 | published; README updated; rendered-page re-audit pending |
| C | xmake | `0.13.0` | https://packages.xmake.io/packages/praxo-core | published on xmake; source `c/v0.14.0`; vcpkg and Conan pending |
| C++ | xmake | `0.9.0` | https://packages.xmake.io/packages/praxo-core-cpp | published on xmake; source `cpp/v0.10.0`; vcpkg and Conan pending |
| Elixir | Hex / HexDocs | `0.11.1` | https://hex.pm/packages/praxo_core/0.11.1; https://praxo-core.hexdocs.pm/0.11.1/ | published; README reordered with tutorials, reference-application status, and community |
| Erlang | Hex | `0.10.1` | https://hex.pm/packages/praxo_core_erlang/0.10.1 | published; README includes scenario tutorials, reference-application status, and community |
| Ruby | RubyGems | `0.10.2` | https://rubygems.org/gems/praxo-core/versions/0.10.2 | published; split source repo `axisvela/praxo-core-ruby` tagged `v0.10.2` |
| Lua | LuaRocks | `0.9.1-1` | https://luarocks.org/modules/hanhhuiwen/praxo-core/0.9.1-1 | published; split repository `v0.9.1` tagged |
| PHP | Packagist | `0.10.1` | https://packagist.org/packages/axisvela/praxo-core#v0.10.1 | published |
| Dart | pub.dev | `0.8.2` | https://pub.dev/packages/praxo_core/versions/0.8.2 | published; public API has dartdoc coverage |
| D | DUB | `0.8.0` | https://code.dlang.org/packages/praxo-core/versions/0.8.0 | published; matches source `d/v0.8.0` |
| Swift | Swift Package Index | `0.7.2` | https://swiftpackageindex.com/axisvela/praxo-core-swift | SPI indexes split `0.7.2`; split repository tagged `0.9.0` with streaming scope; SPI re-index pending |
| MATLAB | MATLAB File Exchange | `0.9.1` | https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core | published; source `matlab/v0.9.0`; citation still `0.2.1`; MATLAB compatibility unverified |
| PowerShell Core | PowerShell Gallery | `0.9.1` | https://www.powershellgallery.com/packages/praxo-core-ps/0.9.1 | published; release workflow 45922472866 |
| PowerShell Bridge | PowerShell Gallery | `0.1.0` | https://www.powershellgallery.com/packages/praxo-core-ps-br/0.1.0 | published |
| Perl | CPAN | `0.8.1` | https://metacpan.org/dist/Praxo-Core | published; README.pod includes examples, tutorials, reference-application status, and community |
| Haskell | Hackage | `0.9.0` | https://hackage.haskell.org/package/praxo-core-0.9.0 | published; README defect recorded in page audit |
| R | r-universe | `0.12.0` | https://axisvela.r-universe.dev/praxocore | actual build HEAD `9b417e3`; checks have warnings, not all clean; CRAN not published |
| Nim | nim-lang/packages (Nimble) | `0.1.1` | https://github.com/axisvela/praxo-core-nim | split repo `v0.8.0` tagged; nim-lang/packages PR #3600 merged 2026-11-05; nimpkgs re-crawl pending |

## Uploaded or awaiting indexing

| Language | Registry | Version | Address | Status |
| --- | --- | --- | --- | --- |
| Julia | Julia General Registry | not registered | https://github.com/JuliaRegistries/General/pull/176393 | PR updated to `0.9.0`, pending review; mirror tagged `0.9.0`; mirror tag is not General availability |
| Octave | Octave Packages | `0.9.0` | https://github.com/axisvela/praxo-core/releases/tag/octave%2Fv0.9.0 | 0.9.0 release tarball published; package index PR pending |
| V | VPM | unverified | https://github.com/axisvela/praxo-core-v | registry availability unverified; split repo `0.8.0` tagged; VPM submission pending |
| Delphi / Free Pascal | OPM / GitHub release | `0.9.0` | https://github.com/axisvela/praxo-core/releases/tag/delphi%2Fv0.9.0 | 0.9.0 OPM assets published; OPM listing pending |

## Source-only or not published to a registry

| Language | Source tag | Registry state |
| --- | --- | --- |
| Fortran | `fortran/v0.12.0` | fpm registry upstream paused |
| COBOL | `cobol/v0.9.0` | no mainstream registry |
| OCaml | `ocaml/v0.11.1` | not published to opam; replacement submission pending; split source aligned to `0.11.1` and validated locally; see [publication status](https://github.com/axisvela/praxo-core/blob/main/language/ocaml/PUBLISHING.md) |
| Objective-C | `objc/v0.8.0` | CocoaPods publication deferred; requires macOS/Xcode and a Trunk token |
| Zig | `zig/v0.9.0` | no central registry |
| Tcl / Lisp / Prolog | `tcl/v0.1.0`, `lisp/v0.1.0`, `prolog/v0.1.1` | bridge packages; registry publication pending |

Use the [support policy](support.md) for maturity, support level, and consumer
smoke distinctions. Package-registry availability is not evidence of production
readiness.
