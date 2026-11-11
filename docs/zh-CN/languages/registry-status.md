# 注册表发布状态

最后核对：2026-11-10（Go `v2.7.0` 已发布并重新审计渲染页面；
Rust 0.4.0、C# 0.4.0、Elixir 0.5.1、Python 0.4.1、TypeScript 0.2.2、Java 0.4.1 已发布；Java 0.5.0 源码已准备，R 0.6.1 已发布；
Go module proxy 与 crates.io 于 2026-11-10 重新核对；其他行来自 2026-11-04/05 审计）。

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
| Go | Go module proxy / pkg.go.dev | `v2.7.0` | https://pkg.go.dev/github.com/axisvela/praxo-core/v2 | 已发布；页面已于 2026-11-10 审计 |
| Python | PyPI | `0.4.1` | https://pypi.org/project/praxo-core/0.4.1/ | 已发布 |
| TypeScript | npm | `0.2.2` | https://www.npmjs.com/package/@axisvela/praxo-core/v/0.2.2 | 已发布；latest |
| Java | Maven Central | `0.4.1` | https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.4.1/ | 已发布 |
| Rust | crates.io | `0.4.0` | https://crates.io/crates/praxo-core/0.4.0 | 已发布 |
| C# | NuGet | `0.4.0` | https://www.nuget.org/packages/Praxo.Core/0.4.0 | 已发布 |
| Elixir | Hex / HexDocs | `0.5.1` | https://hex.pm/packages/praxo_core/0.5.1 · https://praxo-core.hexdocs.pm/0.5.1/ | 已发布 |
| Erlang | Hex | `0.4.0` | https://hex.pm/packages/praxo_core_erlang/0.4.0 | 已发布 |
| Ruby | RubyGems | `0.4.1` | https://rubygems.org/gems/praxo-core/versions/0.4.1 | 已发布；Ruby 源码仓库为 `axisvela/praxo-core-ruby` |
| Lua | LuaRocks | `0.4.1-1` | https://luarocks.org/modules/hanhhuiwen/praxo-core | 已发布 |
| PHP | Packagist | `0.4.1` | https://packagist.org/packages/axisvela/praxo-core | 已发布 |
| Dart | pub.dev | `0.1.1` | https://pub.dev/packages/praxo_core/versions/0.1.1 | 已发布 |
| D | DUB | `0.1.0` | https://code.dlang.org/packages/praxo-core | 已发布 |
| Swift | Swift Package Index | `0.2.0` | https://swiftpackageindex.com/axisvela/praxo-core-swift | PackageList 已合并 |
| MATLAB | MATLAB File Exchange | `0.2.1` | https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core | 已发布 |
| PowerShell Core | PowerShell Gallery | `0.2.0` | https://www.powershellgallery.com/packages/praxo-core-ps/0.2.0 | 已发布 |
| PowerShell Bridge | PowerShell Gallery | `0.1.0` | https://www.powershellgallery.com/packages/praxo-core-ps-br/0.1.0 | 已发布 |
| R | r-universe | `0.6.1` | https://axisvela.r-universe.dev/praxocore | 仅 r-universe；未发布 CRAN |
| Nim | nim-lang/packages（Nimble） | `0.1.1` | https://github.com/axisvela/praxo-core-nim | split repo 已发布；nim-lang/packages PR #3600 已于 2026-11-05 合并；安装 smoke 未记录；nimpkgs 待重新抓取 |

## 已上传或等待索引

| 语言 | 注册表 | 版本 | 地址 | 状态 |
| --- | --- | --- | --- | --- |
| Julia | Julia General Registry | `0.2.0` | https://github.com/JuliaRegistries/General/pull/174826 | 注册 PR 待合并 |
| Octave | Octave Packages | `0.2.1` | https://github.com/gnu-octave/packages/pull/875 | 注册 PR 待合并 |
| Perl | CPAN | `0.1.1` | https://metacpan.org/dist/Praxo-Core | 已在 MetaCPAN 索引（0.1.1）；安装 smoke 未记录 |
| OCaml | opam | `0.3.0` | https://github.com/ocaml/opam-repository/pull/31106 | 注册 PR 待合并；包 CI 已通过；opam-ci 待完成 |
| V | VPM | `0.1.2` | https://github.com/axisvela/praxo-core-v | mirror 已发布；VPM 未索引 |

## 仅源码或未发布到注册表

| 语言 | 源码标签 | 注册表状态 |
| --- | --- | --- |
| C | `c/v0.6.0` | 未发布注册表 |
| C++ | `cpp/v0.4.0` | 未发布注册表 |
| Fortran | `fortran/v0.6.0` | fpm registry 上游暂停 |
| COBOL | `cobol/v0.4.0` | 无主流注册表 |
| Haskell | `haskell/v0.2.0` | sdist 已发布；API 和手工上传均需 Hackage trustees 将账号加入 Uploaders |
| Objective-C | `objc/v0.1.1` | CocoaPods 发布待完成 |
| Delphi / Free Pascal | `delphi/v0.2.1` | OPM 资产已发布；维护者提交待完成 |
| Zig | `zig/v0.2.0` | 无中央注册表 |
| Tcl / Lisp / Prolog | `tcl/v0.1.0`、`lisp/v0.1.0`、`prolog/v0.1.1` | 桥接包；注册表发布待完成 |

成熟度、支持级别和 consumer smoke 的区别见[支持政策](support.md)。包注册表可用性
不是生产就绪证据。
