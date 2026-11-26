# 注册表发布状态

公开审计：2026-11-26。以下版本化 URL 记录发布可用性，不代表包介绍验收或消费者安装验证。
Go `v2.11.0` 的发布文档日期为 2026-11-26；
[Go proxy 元数据](https://proxy.golang.org/github.com/axisvela/praxo-core/v2/@v/v2.11.0.info)
记录 2026-11-25 UTC 发布，两者并不矛盾，不应写为 2026-11-20。
未更新的待处理行保留较早证据。

本页汇总各语言实现当前发布到哪里。源码标签、包注册表版本、一致性测试和生产验证是
不同层面的声明。注册表版本不代表完整 Go 功能对齐或生产就绪。

注册表页面是发布快照，其介绍、关键词与 README 可能落后于源码仓库和文档站。页面检查
清单与当前试点页面审计见[Registry 页面与包介绍](registry-pages.md)。

每个语言源码目录还提供 `REGISTRY.md`、`llms.txt` 与 `llms.md`；总索引见
[语言 Registry 与编程 Agent 入口](https://github.com/axisvela/praxo-core/blob/main/language/REGISTRY-INDEX.md)。这些是源码入口，
不是 Registry 页面已刷新的证据。

## 教程、候选场景与参考应用

- [教程计划](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)：交付标准与参考应用组合。
- [100 个候选 Agent 场景](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)：候选业务目标及已有相关切片。
- [统一教程目录](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)：跨语言教程、示例与应用路径。
- [参考应用组合](https://axisvela.github.io/praxo-core/zh-CN/project/roadmap/)：计划中与已有的完整宿主集成。
- 各语言的 `REGISTRY.md` 会链接对应 `Tutorial/` 和 `application/` 源码目录。

## 已发布版本

本页也是注册表版本的**语言发布索引**。独立源码 tag 与声明能力见[语言实现目录](index.md)。
GitHub Latest 仅代表 Go 参考 Core，不代表最近发布的语言包。

| 语言 | 注册表 | 版本 | 地址 | 状态 |
| --- | --- | --- | --- | --- |
| Go | Go module proxy / pkg.go.dev | `v2.11.0` | https://pkg.go.dev/github.com/axisvela/praxo-core/v2@v2.11.0 | 已发布；README 仍安装并称 `v2.10.0` 为当前版本 |
| Python | PyPI | `0.11.0` | https://pypi.org/project/praxo-core/0.11.0/ | 已发布；README 缺陷见页面审计 |
| TypeScript | npm | `0.10.0` | https://www.npmjs.com/package/@axisvela/praxo-core/v/0.10.0 | 已发布；latest；README 缺陷见页面审计 |
| Java | Maven Central | `0.12.0` | https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.12.0/ | 已发布；POM SCM tag 仍为 `java/v0.10.0` |
| Rust | crates.io | `0.11.0` | https://crates.io/crates/praxo-core/0.11.0 | 已发布；README 缺陷见页面审计 |
| C# | NuGet | `0.11.0` | https://www.nuget.org/packages/Praxo.Core/0.11.0 | 已发布；README 缺陷见页面审计 |
| Elixir | Hex / HexDocs | `0.11.0` | https://hex.pm/packages/praxo_core/0.11.0; https://praxo-core.hexdocs.pm/0.11.0/ | 已发布 |
| Erlang | Hex | `0.10.0` | https://hex.pm/packages/praxo_core_erlang/0.10.0 | 已发布 |
| Ruby | RubyGems | `0.10.0` | https://rubygems.org/gems/praxo-core/versions/0.10.0 | 已发布；Ruby 源码仓库为 `axisvela/praxo-core-ruby` |
| Lua | LuaRocks | `0.9.0-1` | https://luarocks.org/modules/hanhhuiwen/praxo-core/0.9.0-1 | 已发布 |
| PHP | Packagist | `0.10.0` | https://packagist.org/packages/axisvela/praxo-core#v0.10.0 | 已发布 |
| Dart | pub.dev | `0.8.0` | https://pub.dev/packages/praxo_core/versions/0.8.0 | 已发布；README 缺陷见页面审计 |
| D | DUB | `0.8.0` | https://code.dlang.org/packages/praxo-core/versions/0.8.0 | 已发布；与源码 `d/v0.8.0` 一致 |
| Swift | Swift Package Index | `0.7.2` | https://swiftpackageindex.com/axisvela/praxo-core-swift | split 包已索引；非流式范围，不等于主仓库 `swift/v0.9.0` 流式范围 |
| MATLAB | MATLAB File Exchange | `0.9.1` | https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core | 已发布；源码 `matlab/v0.9.0`；引用仍为 `0.2.1`；MATLAB 兼容性未验证 |
| PowerShell Core | PowerShell Gallery | `0.8.1` | https://www.powershellgallery.com/packages/praxo-core-ps/0.8.1 | 已发布；记录于 registry metadata；页面未重新审计 |
| PowerShell Bridge | PowerShell Gallery | `0.1.0` | https://www.powershellgallery.com/packages/praxo-core-ps-br/0.1.0 | 已发布 |
| Perl | CPAN | `0.8.0` | https://metacpan.org/dist/Praxo-Core | 已发布 |
| Haskell | Hackage | `0.9.0` | https://hackage.haskell.org/package/praxo-core-0.9.0 | 已发布；README 缺陷见页面审计 |
| R | r-universe | `0.12.0` | https://axisvela.r-universe.dev/praxocore | 实际构建 HEAD `9b417e3`；检查有 warnings，非全部通过且无警告；未发布 CRAN |
| Nim | nim-lang/packages（Nimble） | `0.1.1` | https://github.com/axisvela/praxo-core-nim | split 仓库 `v0.6.0` 已打 tag；nim-lang/packages PR #3600 已于 2026-11-05 合并；nimpkgs 待重新抓取 |

## 已上传或等待索引

| 语言 | 注册表 | 版本 | 地址 | 状态 |
| --- | --- | --- | --- | --- |
| Julia | Julia General Registry | 未注册 | https://github.com/JuliaRegistries/General/pull/176393 | PR 开放、未合并；mirror tag 不等于 General 可用 |
| Octave | Octave Packages | `0.7.0` | https://github.com/axisvela/praxo-core/releases/tag/octave%2Fv0.7.0 | 0.7.0 release tarball 已发布；包索引 PR 待完成 |
| V | VPM | 未验证 | https://github.com/axisvela/praxo-core-v | registry 可用性未验证；待完成，未验收 |
| Delphi / Free Pascal | OPM / GitHub release | `0.2.1` | https://github.com/axisvela/praxo-core/releases/tag/delphi%2Fv0.7.0 | 0.7.0 OPM 资产已发布；OPM 收录待完成 |

## 仅源码或未发布到注册表

| 语言 | 源码标签 | 注册表状态 |
| --- | --- | --- |
| C | `c/v0.14.0` | 未发布注册表；xmake-repo PR #11309、vcpkg PR #55192、Conan Center PR #31502 仍开放，未合并 |
| C++ | `cpp/v0.10.0` | 未发布注册表；xmake-repo PR #11310、vcpkg PR #55192、Conan Center PR #31503 仍开放，未合并 |
| Fortran | `fortran/v0.12.0` | fpm registry 上游暂停 |
| COBOL | `cobol/v0.9.0` | 无主流注册表 |
| OCaml | `ocaml/v0.11.1` | 未发布到 opam；替代提交待审核；split 源码已对齐到 `0.11.1` 并在本地验证；见[发布状态](https://github.com/axisvela/praxo-core/blob/main/language/ocaml/PUBLISHING.md) |
| Objective-C | `objc/v0.8.0` | CocoaPods 发布暂缓；需要 macOS/Xcode 与 Trunk token |
| Zig | `zig/v0.9.0` | 无中央注册表 |
| Tcl / Lisp / Prolog | `tcl/v0.1.0`、`lisp/v0.1.0`、`prolog/v0.1.1` | 桥接包；注册表发布待完成 |

成熟度、支持级别和 consumer smoke 的区别见[支持政策](support.md)。包注册表可用性
不是生产就绪证据。
