# Registry Publication Status

Last checked: 2026-11-12 (Python 0.5.0, TypeScript 0.4.1, Java 0.6.0, Rust
0.5.0, C# 0.5.0, Elixir 0.8.0, Erlang 0.7.1, Ruby 0.7.0, Dart 0.2.0, Perl 0.4.0,
Haskell 0.5.0, PowerShell 0.5.3, and R 0.7.1 published; Go `v2.7.0` remains
current; other rows from the 2026-11-04/05 audit).

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

## Published and current

This is the **Language Release Index** for registry versions. For independent
source tags and capability declarations, use the [implementation directory](index.md).
GitHub Latest represents the Go Reference Core only, not the last language package published.

| Language | Registry | Version | Address | Status |
| --- | --- | --- | --- | --- |
| Go | Go module proxy / pkg.go.dev | `v2.7.0` | https://pkg.go.dev/github.com/axisvela/praxo-core/v2 | published; page audited 2026-11-09 |
| Python | PyPI | `0.5.0` | https://pypi.org/project/praxo-core/0.5.0/ | published |
| TypeScript | npm | `0.4.1` | https://www.npmjs.com/package/@axisvela/praxo-core/v/0.4.1 | published; latest |
| Java | Maven Central | `0.6.0` | https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.6.0/ | published |
| Rust | crates.io | `0.5.0` | https://crates.io/crates/praxo-core/0.5.0 | published |
| C# | NuGet | `0.5.0` | https://www.nuget.org/packages/Praxo.Core/0.5.0 | published |
| Elixir | Hex / HexDocs | `0.6.0` | https://hex.pm/packages/praxo_core/0.6.0 · https://praxo-core.hexdocs.pm/0.6.0/ | published |
| Erlang | Hex | `0.7.1` | https://hex.pm/packages/praxo_core_erlang/0.7.1 | published |
| Ruby | RubyGems | `0.7.0` | https://rubygems.org/gems/praxo-core/versions/0.7.0 | published; Ruby source repo is `axisvela/praxo-core-ruby` |
| Lua | LuaRocks | `0.6.0-1` | https://luarocks.org/modules/hanhhuiwen/praxo-core | published |
| PHP | Packagist | `0.4.1` | https://packagist.org/packages/axisvela/praxo-core | published; source tag `php/v0.5.0` is newer |
| Dart | pub.dev | `0.2.0` | https://pub.dev/packages/praxo_core/versions/0.2.0 | published |
| D | DUB | `0.1.0` | https://code.dlang.org/packages/praxo-core | published |
| Swift | Swift Package Index | `0.2.0` | https://swiftpackageindex.com/axisvela/praxo-core-swift | package list merged |
| MATLAB | MATLAB File Exchange | `0.3.0` | https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core | published |
| PowerShell Core | PowerShell Gallery | `0.5.3` | https://www.powershellgallery.com/packages/praxo-core-ps/0.5.3 | published |
| PowerShell Bridge | PowerShell Gallery | `0.1.0` | https://www.powershellgallery.com/packages/praxo-core-ps-br/0.1.0 | published |
| Perl | CPAN | `0.4.0` | https://metacpan.org/dist/Praxo-Core | published and indexed on MetaCPAN |
| Haskell | Hackage | `0.5.0` | https://hackage.haskell.org/package/praxo-core-0.5.0 | published |
| R | r-universe | `0.7.1` | https://axisvela.r-universe.dev/praxocore | r-universe only; CRAN not published |
| Nim | nim-lang/packages (Nimble) | `0.1.1` | https://github.com/axisvela/praxo-core-nim | split repo published; nim-lang/packages PR #3600 merged 2026-11-05; install smoke not recorded; nimpkgs re-crawl pending |

## Uploaded or awaiting indexing

| Language | Registry | Version | Address | Status |
| --- | --- | --- | --- | --- |
| Julia | Julia General Registry | `0.2.0` | https://github.com/JuliaRegistries/General/pull/174826 | registration PR open |
| Octave | Octave Packages | `0.2.1` | https://github.com/gnu-octave/packages/pull/875 | registration PR open |
| OCaml | opam | `0.3.0` | https://github.com/ocaml/opam-repository/pull/31106 | registration PR open; package CI passed; opam-ci pending |
| V | VPM | `0.1.2` | https://github.com/axisvela/praxo-core-v | mirror published; VPM not indexed |
| Delphi / Free Pascal | OPM / GitHub release | `0.2.1` | https://github.com/axisvela/praxo-core/releases/tag/delphi%2Fv0.2.1 | OPM assets published; maintainer submission pending |

## Source-only or not published to a registry

| Language | Source tag | Registry state |
| --- | --- | --- |
| C | `c/v0.7.0` | no registry publication |
| C++ | `cpp/v0.5.0` | no registry publication |
| Fortran | `fortran/v0.7.0` | fpm registry upstream paused |
| COBOL | `cobol/v0.4.0` | no mainstream registry |
| Objective-C | `objc/v0.4.0` | CocoaPods publication deferred; requires macOS/Xcode and a Trunk token |
| Zig | `zig/v0.5.0` | no central registry |
| Tcl / Lisp / Prolog | `tcl/v0.1.0`, `lisp/v0.1.0`, `prolog/v0.1.1` | bridge packages; registry publication pending |

Use the [support policy](support.md) for maturity, support level, and consumer
smoke distinctions. Package-registry availability is not evidence of production
readiness.
