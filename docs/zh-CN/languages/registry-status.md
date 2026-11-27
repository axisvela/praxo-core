# 注册表发布状态

公开审计：2026-11-27。以下版本化 URL 记录发布可用性，不代表包介绍验收或消费者安装验证。
Go `v2.11.2` 的发布文档日期为 2026-11-27；
[Go proxy 元数据](https://proxy.golang.org/github.com/axisvela/praxo-core/v2/@v/v2.11.2.info)
记录 2026-11-27 UTC 发布，两者并不矛盾，不应写为 2026-11-20。
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
| Go | Go module proxy / pkg.go.dev | `v2.11.2` | https://pkg.go.dev/github.com/axisvela/praxo-core/v2@v2.11.2 | 已发布；README 安装并称 `v2.11.2` 为当前版本 |
| Python | PyPI | `0.11.0` | https://pypi.org/project/praxo-core/0.11.0/ | 已发布；README 缺陷见页面审计 |
| TypeScript | npm | `0.10.0` | https://www.npmjs.com/package/@axisvela/praxo-core/v/0.10.0 | 已发布；latest；README 缺陷见页面审计 |
| Java | Maven Central | `0.12.2` | https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.12.2/ | 已发布；SDK 版本已修正；SCM tag 为 `java/v0.12.2` |
| Rust | crates.io | `0.11.1` | https://crates.io/crates/praxo-core/0.11.1 | 已发布；README 包含场景教程、参考应用状态和社区链接 |
| C# | NuGet | `0.11.0` | https://www.nuget.org/packages/Praxo.Core/0.11.0 | 已发布；README 缺陷见页面审计 |
| C | xmake | `0.13.0` | https://packages.xmake.io/packages/praxo-core | xmake 已发布；源码 `c/v0.14.0`；vcpkg 与 Conan 待完成 |
| C++ | xmake | `0.9.0` | https://packages.xmake.io/packages/praxo-core-cpp | xmake 已发布；源码 `cpp/v0.10.0`；vcpkg 与 Conan 待完成 |
| Elixir | Hex / HexDocs | `0.11.1` | https://hex.pm/packages/praxo_core/0.11.1; https://praxo-core.hexdocs.pm/0.11.1/ | 已发布；README 已重排并包含教程、参考应用状态和社区信息 |
| Erlang | Hex | `0.10.1` | https://hex.pm/packages/praxo_core_erlang/0.10.1 | 已发布；README 包含场景教程、参考应用状态和社区信息 |
| Ruby | RubyGems | `0.10.0` | https://rubygems.org/gems/praxo-core/versions/0.10.0 | 已发布；split 源码仓库 `axisvela/praxo-core-ruby` 已打 tag `v0.10.0` |
| Lua | LuaRocks | `0.9.1-1` | https://luarocks.org/modules/hanhhuiwen/praxo-core/0.9.1-1 | 已发布；split 仓库 `v0.9.1` 已打 tag |
| PHP | Packagist | `0.10.0` | https://packagist.org/packages/axisvela/praxo-core#v0.10.0 | 已发布 |
| Dart | pub.dev | `0.8.2` | https://pub.dev/packages/praxo_core/versions/0.8.2 | 已发布；公共 API 已有 dartdoc 注释覆盖 |
| D | DUB | `0.8.0` | https://code.dlang.org/packages/praxo-core/versions/0.8.0 | 已发布；与源码 `d/v0.8.0` 一致 |
| Swift | Swift Package Index | `0.7.2` | https://swiftpackageindex.com/axisvela/praxo-core-swift | SPI 索引 split `0.7.2`；split 仓库已打 tag `0.9.0`（流式范围）；SPI 重新索引待完成 |
| MATLAB | MATLAB File Exchange | `0.9.1` | https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core | 已发布；源码 `matlab/v0.9.0`；引用仍为 `0.2.1`；MATLAB 兼容性未验证 |
| PowerShell Core | PowerShell Gallery | `0.9.1` | https://www.powershellgallery.com/packages/praxo-core-ps/0.9.1 | 已发布；发布工作流 45922472866 |
| PowerShell Bridge | PowerShell Gallery | `0.1.0` | https://www.powershellgallery.com/packages/praxo-core-ps-br/0.1.0 | 已发布 |
| Perl | CPAN | `0.8.1` | https://metacpan.org/dist/Praxo-Core | 已发布；README.pod 包含示例、教程、参考应用状态和社区信息 |
| Haskell | Hackage | `0.9.0` | https://hackage.haskell.org/package/praxo-core-0.9.0 | 已发布；README 缺陷见页面审计 |
| R | r-universe | `0.12.0` | https://axisvela.r-universe.dev/praxocore | 实际构建 HEAD `9b417e3`；检查有 warnings，非全部通过且无警告；未发布 CRAN |
| Nim | nim-lang/packages（Nimble） | `0.1.1` | https://github.com/axisvela/praxo-core-nim | split 仓库 `v0.8.0` 已打 tag；nim-lang/packages PR #3600 已于 2026-11-05 合并；nimpkgs 待重新抓取 |

## 已上传或等待索引

| 语言 | 注册表 | 版本 | 地址 | 状态 |
| --- | --- | --- | --- | --- |
| Julia | Julia General Registry | 未注册 | https://github.com/JuliaRegistries/General/pull/176393 | PR 已更新为 `0.9.0`，待审核；mirror 已打 `0.9.0`；mirror tag 不等于 General 可用 |
| Octave | Octave Packages | `0.9.0` | https://github.com/axisvela/praxo-core/releases/tag/octave%2Fv0.9.0 | 0.9.0 release tarball 已发布；包索引 PR 待完成 |
| V | VPM | 未验证 | https://github.com/axisvela/praxo-core-v | registry 可用性未验证；split 仓库 `0.8.0` 已打 tag；VPM 提交待完成 |
| Delphi / Free Pascal | OPM / GitHub release | `0.9.0` | https://github.com/axisvela/praxo-core/releases/tag/delphi%2Fv0.9.0 | 0.9.0 OPM 资产已发布；OPM 收录待完成 |

## 仅源码或未发布到注册表

| 语言 | 源码标签 | 注册表状态 |
| --- | --- | --- |
| Fortran | `fortran/v0.12.0` | fpm registry 上游暂停 |
| COBOL | `cobol/v0.9.0` | 无主流注册表 |
| OCaml | `ocaml/v0.11.1` | 未发布到 opam；替代提交待审核；split 源码已对齐到 `0.11.1` 并在本地验证；见[发布状态](https://github.com/axisvela/praxo-core/blob/main/language/ocaml/PUBLISHING.md) |
| Objective-C | `objc/v0.8.0` | CocoaPods 发布暂缓；需要 macOS/Xcode 与 Trunk token |
| Zig | `zig/v0.9.0` | 无中央注册表 |
| Tcl / Lisp / Prolog | `tcl/v0.1.0`、`lisp/v0.1.0`、`prolog/v0.1.1` | 桥接包；注册表发布待完成 |

成熟度、支持级别和 consumer smoke 的区别见[支持政策](support.md)。包注册表可用性
不是生产就绪证据。
