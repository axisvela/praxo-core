# 注册表发布状态

最后核对：2026-11-04。

本页汇总各语言实现当前发布到哪里。源码标签、包注册表版本、一致性测试和生产验证是
不同层面的声明。注册表版本不代表完整 Go 功能对齐或生产就绪。

## 已发布且当前

| 语言 | 注册表 | 版本 | 地址 | 状态 |
| --- | --- | --- | --- | --- |
| Go | Go module proxy / pkg.go.dev | `v2.5.2` | https://pkg.go.dev/github.com/axisvela/praxo-core/v2 | 已发布 |
| Python | PyPI | `0.3.0` | https://pypi.org/project/praxo-core/0.3.0/ | 已发布 |
| TypeScript | npm | `0.2.0` | https://www.npmjs.com/package/@axisvela/praxo-core/v/0.2.0 | 已发布 |
| Java | Maven Central | `0.4.0` | https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.4.0/ | 已发布 |
| Rust | crates.io | `0.3.0` | https://crates.io/crates/praxo-core/0.3.0 | 已发布 |
| C# | NuGet | `0.3.0` | https://www.nuget.org/packages/Praxo.Core/0.3.0 | 已发布 |
| Elixir | Hex / HexDocs | `0.4.0` | https://hex.pm/packages/praxo_core/0.4.0 · https://praxo-core.hexdocs.pm/0.4.0/ | 已发布 |
| Erlang | Hex | `0.4.0` | https://hex.pm/packages/praxo_core_erlang/0.4.0 | 已发布 |
| Ruby | RubyGems | `0.4.1` | https://rubygems.org/gems/praxo-core/versions/0.4.1 | 已发布；Ruby 源码仓库为 `axisvela/praxo-core-ruby` |
| Lua | LuaRocks | `0.4.0-1` | https://luarocks.org/modules/hanhhuiwen/praxo-core | 已发布 |
| PHP | Packagist | `0.4.0` | https://packagist.org/packages/axisvela/praxo-core | 已发布 |
| Dart | pub.dev | `0.1.1` | https://pub.dev/packages/praxo_core/versions/0.1.1 | 已发布 |
| D | DUB | `0.1.0` | https://code.dlang.org/packages/praxo-core | 已发布 |
| Swift | Swift Package Index | `0.2.0` | https://swiftpackageindex.com/axisvela/praxo-core-swift | PackageList 已合并 |
| MATLAB | MATLAB File Exchange | `0.2.1` | https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core | 已发布 |
| PowerShell Core | PowerShell Gallery | `0.2.0` | https://www.powershellgallery.com/packages/praxo-core-ps/0.2.0 | 已发布 |
| PowerShell Bridge | PowerShell Gallery | `0.1.0` | https://www.powershellgallery.com/packages/praxo-core-ps-br/0.1.0 | 已发布 |
| R | r-universe | `0.5.0` | https://axisvela.r-universe.dev/praxocore | 仅 r-universe；未发布 CRAN |
| Nim | nim-lang/packages（Nimble） | `0.1.1` | https://github.com/nim-lang/packages | 已列入；安装 smoke 待完成 |

## 已上传或等待索引

| 语言 | 注册表 | 版本 | 地址 | 状态 |
| --- | --- | --- | --- | --- |
| Julia | Julia General Registry | `0.2.0` | https://github.com/JuliaRegistries/General/pull/174826 | 注册 PR 待合并 |
| Perl | CPAN | `0.1.1` | https://metacpan.org/dist/Praxo-Core | 已上传；MetaCPAN 索引待完成 |
| V | VPM | `0.1.2` | https://github.com/axisvela/praxo-core-v | mirror 已发布；VPM 未索引 |

## 仅源码或未发布到注册表

| 语言 | 源码标签 | 注册表状态 |
| --- | --- | --- |
| C | `c/v0.6.0` | 未发布注册表 |
| C++ | `cpp/v0.4.0` | 未发布注册表 |
| Fortran | `fortran/v0.6.0` | fpm registry 上游暂停 |
| COBOL | `cobol/v0.4.0` | 无主流注册表 |
| Haskell | `haskell/v0.2.0` | Hackage 上传受 Uploaders 组限制 |
| OCaml | `ocaml/v0.2.0` | opam 打包待完成 |
| Objective-C | `objc/v0.1.1` | CocoaPods 发布待完成 |
| Delphi / Free Pascal | `delphi/v0.2.1` | OPM 打包待完成 |
| Zig | `zig/v0.2.0` | 无中央注册表 |
| Tcl / Lisp / Prolog | `tcl/v0.1.0`、`lisp/v0.1.0`、`prolog/v0.1.1` | 桥接包；注册表发布待完成 |

成熟度、支持级别和 consumer smoke 的区别见[支持政策](support.md)。包注册表可用性
不是生产就绪证据。
