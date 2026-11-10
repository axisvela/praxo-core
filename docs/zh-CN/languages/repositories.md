# 各语言独立仓库

PRAXO-CORE 是多语言框架。Go 是参考实现；其他语言有独立发布包和独立仓库，
避免语言发现依赖在 Go 导向的 monorepo 中查找子目录。

规范源码、spec 与发布流程仍位于
[`axisvela/praxo-core`](https://github.com/axisvela/praxo-core)。独立仓库可能是
发布源，也可能是发现镜像；消费者实际安装的版本仍以 registry 为准。

## 已启用仓库

| 语言 | 仓库 | 角色 |
| --- | --- | --- |
| Python | [axisvela/praxo-core-python](https://github.com/axisvela/praxo-core-python) | `language/python` 的发现镜像；包含 `spec/` 以便运行一致性测试 |
| TypeScript | [axisvela/praxo-core-typescript](https://github.com/axisvela/praxo-core-typescript) | `language/typescript` 的发现镜像；包含 `spec/` 以便运行一致性测试 |
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

## 推进顺序

独立仓库按采用优先级增加，不以语言数量为目标。当前批次覆盖 agent-capable 实现：
Python、TypeScript、Java、Rust、C#、R 与 Elixir。扩展与可选实现由维护者或命名消费者推动。

镜像保留规范的 `language/<language>` 目录与共享 `spec/` 向量，使测试和一致性
runner 可用；它不替代 monorepo 发布流程。不要从仓库存在推断 registry 可用性、
一致性通过或生产就绪。

## 新增语言仓库

1. 规范源码继续位于 monorepo 的 `language/<language>`。
2. 镜像该目录，并加入 `spec/`、`LICENSE` 与语言专用 README。
3. 复用语言 README 的 registry、安装与范围说明，并链接回规范源码与文档。
4. 在镜像中运行该语言的 conformance 与测试后再公开。
5. 仓库启用后，更新本页与对应语言的 `REGISTRY.md` 或 `llms.txt`。
