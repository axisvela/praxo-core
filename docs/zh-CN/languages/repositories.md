# 各语言独立仓库

PRAXO-CORE 是多语言框架。Go 是参考实现；其他语言有独立发布包和独立仓库，
避免语言发现依赖在 Go 导向的 monorepo 中查找子目录。

规范源码、spec 与发布流程仍位于
[`axisvela/praxo-core`](https://github.com/axisvela/praxo-core)。独立仓库可能是
发布源，也可能是发现镜像；消费者实际安装的版本仍以 registry 为准。

## 已实现语言

| 语言 | 仓库 | 角色 |
| --- | --- | --- |
| Python | [axisvela/praxo-core-python](https://github.com/axisvela/praxo-core-python) | `language/python` 的发现镜像；包含 `spec/` |
| TypeScript | [axisvela/praxo-core-typescript](https://github.com/axisvela/praxo-core-typescript) | `language/typescript` 的发现镜像；包含 `spec/` |
| Java | [axisvela/praxo-core-java](https://github.com/axisvela/praxo-core-java) | `language/java` 的发现镜像；包含 `spec/` |
| Rust | [axisvela/praxo-core-rust](https://github.com/axisvela/praxo-core-rust) | `language/rust` 的发现镜像；包含 `spec/` |
| C# / .NET | [axisvela/praxo-core-csharp](https://github.com/axisvela/praxo-core-csharp) | `language/csharp` 的发现镜像；包含 `spec/` |
| R | [axisvela/praxo-core-r](https://github.com/axisvela/praxo-core-r) | `language/r` 的发现镜像；包含 `spec/` |
| Elixir | [axisvela/praxo-core-elixir](https://github.com/axisvela/praxo-core-elixir) | `language/elixir` 的发现镜像；包含 `spec/` |
| Ruby | [axisvela/praxo-core-ruby](https://github.com/axisvela/praxo-core-ruby) | RubyGems 发布源 |
| PHP | [axisvela/praxo-core-php](https://github.com/axisvela/praxo-core-php) | Packagist 发布源 |
| Lua | [axisvela/praxo-core-lua](https://github.com/axisvela/praxo-core-lua) | 独立 Lua 仓库 |
| Swift | [axisvela/praxo-core-swift](https://github.com/axisvela/praxo-core-swift) | Swift Package Index 源 |
| Julia | [axisvela/praxo-core-julia](https://github.com/axisvela/praxo-core-julia) | Julia General Registry 镜像 |
| V | [axisvela/praxo-core-v](https://github.com/axisvela/praxo-core-v) | V 独立仓库 |
| OCaml | [axisvela/praxo-core-ocaml](https://github.com/axisvela/praxo-core-ocaml) | OCaml 独立仓库 |
| Nim | [axisvela/praxo-core-nim](https://github.com/axisvela/praxo-core-nim) | Nim 独立仓库 |
| D | [axisvela/praxo-core-d](https://github.com/axisvela/praxo-core-d) | DUB 发布源 |
| Erlang | [axisvela/praxo-core-erlang](https://github.com/axisvela/praxo-core-erlang) | `language/erlang` 的发现镜像；包含 `spec/` |
| Perl | [axisvela/praxo-core-perl](https://github.com/axisvela/praxo-core-perl) | `language/perl` 的发现镜像；包含 `spec/` |
| Haskell | [axisvela/praxo-core-haskell](https://github.com/axisvela/praxo-core-haskell) | `language/haskell` 的发现镜像；包含 `spec/` |
| Dart | [axisvela/praxo-core-dart](https://github.com/axisvela/praxo-core-dart) | `language/dart` 的发现镜像；包含 `spec/` |
| Zig | [axisvela/praxo-core-zig](https://github.com/axisvela/praxo-core-zig) | `language/zig` 的发现镜像；包含 `spec/` |
| C | [axisvela/praxo-core-c](https://github.com/axisvela/praxo-core-c) | `language/c` 的发现镜像；包含 `spec/` |
| C++ | [axisvela/praxo-core-cpp](https://github.com/axisvela/praxo-core-cpp) | `language/cpp` 的发现镜像；包含 `spec/` |
| Fortran | [axisvela/praxo-core-fortran](https://github.com/axisvela/praxo-core-fortran) | `language/fortran` 的发现镜像；包含 `spec/` |
| COBOL | [axisvela/praxo-core-cobol](https://github.com/axisvela/praxo-core-cobol) | `language/cobol` 的发现镜像；包含 `spec/` |
| PowerShell | [axisvela/praxo-core-powershell](https://github.com/axisvela/praxo-core-powershell) | `language/powershell` 的发现镜像；包含 `spec/` |
| MATLAB | [axisvela/praxo-core-matlab](https://github.com/axisvela/praxo-core-matlab) | `language/matlab` 的发现镜像，含共享 MATLAB/Octave core |
| GNU Octave | [axisvela/praxo-core-octave](https://github.com/axisvela/praxo-core-octave) | `language/octave` 的发现镜像，含共享 MATLAB/Octave core |
| Delphi / Free Pascal | [axisvela/praxo-core-delphi](https://github.com/axisvela/praxo-core-delphi) | `language/delphi` 的发现镜像；包含 `spec/` |
| Objective-C | [axisvela/praxo-core-objc](https://github.com/axisvela/praxo-core-objc) | `language/objc` 的发现镜像；包含 `spec/` |

Go 保持仓库根目录，因为其模块路径为 `github.com/axisvela/praxo-core/v2`。
`bindings/` 下的 bridge 与 `examples/` 下的语言示例仍留在 monorepo。

## 自动刷新

`.github/workflows/language-mirrors.yml` 在 `main` 上的 `language/`、`spec/`、
`LICENSE` 或同步脚本变更时重建 21 个发现镜像。它需要 `PRAXO_MIRROR_TOKEN` secret，
并具备镜像仓库的推送权限。手动 `workflow_dispatch` 选择 `mode=check` 可只报告漂移、
不推送。未配置 secret 时，同步 job 输出 warning 并跳过推送。

九个发布源仓库（Ruby、PHP、Lua、Swift、Julia、V、OCaml、Nim、D）刻意排除，因为它们
有自己的发布布局与流程；应通过其发布流程更新，不能用镜像布局覆盖。

## 为什么镜像包含 `spec/`

镜像保留规范的 `language/<language>` 目录与共享 `spec/` 向量，使测试和一致性
runner 可用；它不替代 monorepo 发布流程。镜像会从规范源码刷新；若镜像滞后，以
monorepo 与 registry 版本为准。不要从仓库存在推断 registry 可用性、一致性通过或
生产就绪。

## 新增或更新仓库

1. 规范源码继续位于 monorepo 的 `language/<language>`。
2. 镜像该目录，并加入 `spec/`、`LICENSE` 与语言专用 README。
3. 复用语言 README 的 registry、安装与范围说明，并链接回规范源码与文档。
4. 在镜像中运行该语言的 conformance 与测试后再公开。
5. 仓库启用后，更新本页与对应语言的 `REGISTRY.md` 或 `llms.txt`。
