# Registry Publication Status

Last checked: 2026-11-18. Python `0.9.1`, Rust `0.9.2`, and Ruby `0.8.2`
were published and confirmed through their public registry APIs. TypeScript
npm `0.8.1` was approved and published after staging; `latest` is now `0.8.1`. C# `0.9.2` was pushed and subsequently appeared in the public
NuGet index. Elixir `0.9.2`, Erlang `0.8.2`, Haskell `0.7.1`, and PowerShell `0.7.2`
were published and confirmed; CPAN `0.6.2` upload succeeded but MetaCPAN
indexing was pending. Lua `0.7.2-1` and Dart `0.6.2` were published and confirmed.
Earlier rows retain their recorded check dates; Go `v2.10.0` was verified on
2026-11-16.

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
| Go | Go module proxy / pkg.go.dev | `v2.10.0` | https://pkg.go.dev/github.com/axisvela/praxo-core/v2 | published; page audited 2026-11-16 |
| Python | PyPI | `0.9.1` | https://pypi.org/project/praxo-core/0.9.1/ | published |
| TypeScript | npm | `0.8.1` | https://www.npmjs.com/package/@axisvela/praxo-core/v/0.8.1 | published; latest |
| Java | Maven Central | `0.11.0` | https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.10.0/ | published |
| Rust | crates.io | `0.9.2` | https://crates.io/crates/praxo-core/0.9.2 | published |
| C# | NuGet | `0.9.2` | https://www.nuget.org/packages/Praxo.Core/0.9.2 | published |
| Elixir | Hex / HexDocs | `0.9.2` | https://hex.pm/packages/praxo_core/0.9.2 路 https://praxo-core.hexdocs.pm/0.9.2/ | published |
| Erlang | Hex | `0.8.2` | https://hex.pm/packages/praxo_core_erlang/0.8.2 | published |
| Ruby | RubyGems | `0.8.2` | https://rubygems.org/gems/praxo-core/versions/0.8.2 | published; Ruby source repo is `axisvela/praxo-core-ruby` |
| Lua | LuaRocks | `0.7.2-1` | https://luarocks.org/modules/hanhhuiwen/praxo-core | published |
| PHP | Packagist | `0.8.1` | https://packagist.org/packages/axisvela/praxo-core | published |
| Dart | pub.dev | `0.6.2` | https://pub.dev/packages/praxo_core/versions/0.6.2 | published |
| D | DUB | `0.4.0` | https://code.dlang.org/packages/praxo-core | split repo `v0.6.0` tagged; DUB refresh pending |
| Swift | Swift Package Index | `0.7.0` | https://swiftpackageindex.com/axisvela/praxo-core-swift | published |
| MATLAB | MATLAB File Exchange | `0.5.0` | https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core | published; 0.7.0 upload pending |
| PowerShell Core | PowerShell Gallery | `0.7.2` | https://www.powershellgallery.com/packages/praxo-core-ps/0.7.2 | published; page content verified 2026-11-17 |
| PowerShell Bridge | PowerShell Gallery | `0.1.0` | https://www.powershellgallery.com/packages/praxo-core-ps-br/0.1.0 | published |
| Perl | CPAN | `0.6.1` | https://metacpan.org/dist/Praxo-Core | published and indexed on MetaCPAN 2026-11-17 |
| Haskell | Hackage | `0.7.1` | https://hackage.haskell.org/package/praxo-core-0.7.1 | published |
| R | r-universe | `0.10.1` | https://axisvela.r-universe.dev/praxocore | published on r-universe; CRAN not published |
| Nim | nim-lang/packages (Nimble) | `0.1.1` | https://github.com/axisvela/praxo-core-nim | split repo `v0.6.0` tagged; nim-lang/packages PR #3600 merged 2026-11-05; nimpkgs re-crawl pending |

## Uploaded or awaiting indexing

| Language | Registry | Version | Address | Status |
| --- | --- | --- | --- | --- |
| Julia | Julia General Registry | `0.7.0` | https://github.com/JuliaRegistries/General/pull/176393 | mirror `0.7.0` tagged; registration pending |
| Octave | Octave Packages | `0.7.0` | https://github.com/axisvela/praxo-core/releases/tag/octave%2Fv0.7.0 | 0.7.0 release tarball published; package index PR pending |
| OCaml | opam | `0.8.0` | https://github.com/ocaml/opam-repository/pull/31222 | split repo `0.8.0` tagged; registration PR open |
| V | VPM | `0.6.0` | https://github.com/axisvela/praxo-core-v | split repo `0.6.0` tagged; VPM not indexed |
| Delphi / Free Pascal | OPM / GitHub release | `0.2.1` | https://github.com/axisvela/praxo-core/releases/tag/delphi%2Fv0.7.0 | 0.7.0 OPM assets published; OPM listing pending |

## Source-only or not published to a registry

| Language | Source tag | Registry state |
| --- | --- | --- |
| C | `c/v0.12.0` | no registry publication |
| C++ | `cpp/v0.8.0` | no registry publication |
| Fortran | `fortran/v0.10.0` | fpm registry upstream paused |
| COBOL | `cobol/v0.7.0` | no mainstream registry |
| Objective-C | `objc/v0.6.0` | CocoaPods publication deferred; requires macOS/Xcode and a Trunk token |
| Zig | `zig/v0.7.0` | no central registry |
| Tcl / Lisp / Prolog | `tcl/v0.1.0`, `lisp/v0.1.0`, `prolog/v0.1.1` | bridge packages; registry publication pending |

Use the [support policy](support.md) for maturity, support level, and consumer
smoke distinctions. Package-registry availability is not evidence of production
readiness.
