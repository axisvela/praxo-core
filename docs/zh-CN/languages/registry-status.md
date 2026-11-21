# 注册表发布状态

最后核对：2026-11-21（仅本修订更新的行）。Ruby `0.9.2`、Lua `0.8.1-1`、
Perl `0.7.1` 与 PowerShell `0.8.1` 已从对应源码标签发布。Java `0.11.0` 已从源码标签
`java/v0.11.0` 发布到 Maven Central。TypeScript npm `0.9.0` 已发布并为 `latest`；
consumer 示例锁文件已改为 registry integrity，此前 `npm ci` 报 EINTEGRITY。
Go `v2.10.0` 为当前参考版本。其他行保留原有核对日期；本页不声称每个 registry
页面都已重新审计。

本页汇总各语言实现当前发布到哪里。源码标签、包注册表版本、一致性测试和生产验证是
不同层面的声明。注册表版本不代表完整 Go 功能对齐或生产就绪。

注册表页面是发布快照，其介绍、关键词与 README 可能落后于源码仓库和文档站。页面检查
清单与当前试点页面审计见[Registry 页面与包介绍](registry-pages.md)。

每个语言源码目录还提供 `REGISTRY.md`、`llms.txt` 与 `llms.md`；总索引见
[语言 Registry 与编程 Agent 入口](https://github.com/axisvela/praxo-core/blob/main/language/REGISTRY-INDEX.md)。这些是源码入口，
不是 Registry 页面已刷新的证据。

## 已发布且当前

本页也是注册表版本的**语言发布索引**。独立源码 tag 与声明能力见[语言实现目录](index.md)。
GitHub Latest 仅代表 Go 参考 Core，不代表最近发布的语言包。

| 语言 | 注册表 | 版本 | 地址 | 状态 |
| --- | --- | --- | --- | --- |
| Go | Go module proxy / pkg.go.dev | `v2.10.0` | https://pkg.go.dev/github.com/axisvela/praxo-core/v2 | 已发布；发布 `v2.10.0`（2026-11-20） |
| Python | PyPI | `0.10.0` | https://pypi.org/project/praxo-core/0.10.0/ | 已发布 |
| TypeScript | npm | `0.9.0` | https://www.npmjs.com/package/@axisvela/praxo-core/v/0.9.0 | 已发布；latest |
| Java | Maven Central | `0.11.0` | https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.11.0/ | 已发布 |
| Rust | crates.io | `0.10.0` | https://crates.io/crates/praxo-core/0.10.0 | 已发布 |
| C# | NuGet | `0.10.0` | https://www.nuget.org/packages/Praxo.Core/0.10.0 | 已发布 |
| Elixir | Hex / HexDocs | `0.10.0` | https://hex.pm/packages/praxo_core/0.10.0；https://praxo-core.hexdocs.pm/0.10.0/ | 已发布 |
| Erlang | Hex | `0.9.0` | https://hex.pm/packages/praxo_core_erlang/0.9.0 | 已发布 |
| Ruby | RubyGems | `0.9.2` | https://rubygems.org/gems/praxo-core/versions/0.9.2 | 已发布；Ruby 源码仓库为 `axisvela/praxo-core-ruby` |
| Lua | LuaRocks | `0.8.1-1` | https://luarocks.org/modules/hanhhuiwen/praxo-core | 已发布 |
| PHP | Packagist | `0.8.1` | https://packagist.org/packages/axisvela/praxo-core | 已发布 |
| Dart | pub.dev | `0.7.0` | https://pub.dev/packages/praxo_core/versions/0.7.0 | 已发布 |
| D | DUB | `0.6.1` | https://code.dlang.org/packages/praxo-core | 已从 split 标签 `v0.6.1` 发布；源码标签 `d/v0.7.0` 更新 |
| Swift | Swift Package Index | `0.7.0` | https://swiftpackageindex.com/axisvela/praxo-core-swift | split 标签 `0.7.2` 已推送；SPI 刷新待完成 |
| MATLAB | MATLAB File Exchange | `0.5.0` | https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core | 已发布；0.8.0 上传待完成 |
| PowerShell Core | PowerShell Gallery | `0.8.1` | https://www.powershellgallery.com/packages/praxo-core-ps/0.8.1 | 已发布；记录于 registry metadata；页面未重新审计 |
| PowerShell Bridge | PowerShell Gallery | `0.1.0` | https://www.powershellgallery.com/packages/praxo-core-ps-br/0.1.0 | 已发布 |
| Perl | CPAN | `0.7.1` | https://metacpan.org/dist/Praxo-Core | 已发布；MetaCPAN 索引可能滞后 |
| Haskell | Hackage | `0.8.0` | https://hackage.haskell.org/package/praxo-core-0.8.0 | 已发布 |
| R | r-universe | `0.11.0` | https://axisvela.r-universe.dev/praxocore | 已从 `d59cb301` 在 r-universe 发布；未发布 CRAN；提交需先通过 `R CMD check --as-cran` |
| Nim | nim-lang/packages（Nimble） | `0.1.1` | https://github.com/axisvela/praxo-core-nim | split 仓库 `v0.6.0` 已打 tag；nim-lang/packages PR #3600 已于 2026-11-05 合并；nimpkgs 待重新抓取 |

## 已上传或等待索引

| 语言 | 注册表 | 版本 | 地址 | 状态 |
| --- | --- | --- | --- | --- |
| Julia | Julia General Registry | `0.7.0` | https://github.com/JuliaRegistries/General/pull/176393 | mirror `0.7.0` 已打 tag；注册待完成 |
| Octave | Octave Packages | `0.7.0` | https://github.com/axisvela/praxo-core/releases/tag/octave%2Fv0.7.0 | 0.7.0 release tarball 已发布；包索引 PR 待完成 |
| V | VPM | `0.6.0` | https://github.com/axisvela/praxo-core-v | split 仓库 `0.6.0` 已打 tag；VPM 未索引 |
| Delphi / Free Pascal | OPM / GitHub release | `0.2.1` | https://github.com/axisvela/praxo-core/releases/tag/delphi%2Fv0.7.0 | 0.7.0 OPM 资产已发布；OPM 收录待完成 |

## 仅源码或未发布到注册表

| 语言 | 源码标签 | 注册表状态 |
| --- | --- | --- |
| C | `c/v0.13.0` | 未发布注册表；xmake-repo PR #11309、vcpkg PR #55192、Conan Center PR #31502 仍开放，未合并 |
| C++ | `cpp/v0.9.0` | 未发布注册表；xmake-repo PR #11310、vcpkg PR #55192、Conan Center PR #31503 仍开放，未合并 |
| Fortran | `fortran/v0.11.0` | fpm registry 上游暂停 |
| COBOL | `cobol/v0.8.0` | 无主流注册表 |
| OCaml | `ocaml/v0.9.0` | opam `0.3.0`；PR #31222 因 opam-ci 失败已关闭，需要重新提交 |
| Objective-C | `objc/v0.7.0` | CocoaPods 发布暂缓；需要 macOS/Xcode 与 Trunk token |
| Zig | `zig/v0.8.0` | 无中央注册表 |
| Tcl / Lisp / Prolog | `tcl/v0.1.0`、`lisp/v0.1.0`、`prolog/v0.1.1` | 桥接包；注册表发布待完成 |

成熟度、支持级别和 consumer smoke 的区别见[支持政策](support.md)。包注册表可用性
不是生产就绪证据。
