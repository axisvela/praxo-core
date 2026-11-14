# CI Workflows

CI 按路径拆分，语言专属改动不再运行完整矩阵。`ci.yml` 继续作为核心/共享检查和
定时全矩阵入口。

## Workflow 地图

| Workflow | 范围 | 触发路径 |
| --- | --- | --- |
| `ci.yml` | Go/核心、共享检查、Bridge、Behavior/Compatibility Lab、质量、安全、全矩阵 | 未被忽略的语言/示例/Adapter 路径；定时；手动 |
| `ci-python.yml` | Python 一致性和消费者 | `language/python/**` |
| `ci-typescript.yml` | TypeScript 一致性、消费者、JavaScript 示例 | `language/typescript/**` |
| `ci-java.yml` | Java 一致性、消费者、Kotlin/Scala/Groovy/Clojure 示例 | `language/java/**` |
| `ci-rust.yml` | Rust 一致性 | `language/rust/**` |
| `ci-dotnet.yml` | C# 一致性和 PowerShell Core | `language/csharp/**`、`language/powershell/**` |
| `ci-extended.yml` | Ruby、PHP、Elixir、Erlang、Lua | 对应 `language/<language>/**` |
| `ci-native.yml` | C、C++、Fortran、COBOL、OpenCL 示例 | 对应路径和 `language/opencl/examples/**` |
| `ci-optional.yml` | Haskell、Swift、Dart、Julia、R | 对应 `language/<language>/**` |
| `ci-optional2.yml` | MATLAB、Octave、OCaml、Objective-C、Nim、V、D、Zig、Perl | 对应 `language/<language>/**` |
| `ci-adapters.yml` | Adapter 模块和 Adapter module-security | `adapters/**` |
| `ci-additional.yml` | Dart、Perl、D、Delphi 示例矩阵 | 对应 `language/<language>/examples/**` 路径 |
| `ci-additional2.yml` | PowerShell 与 MATLAB/Octave 示例矩阵 | 对应 `language/<language>/examples/**` 路径 |
| `ci-examples.yml` | Go 示例、SDK 示例、Go 消费者与配方 | `examples/**` 和选定语言示例路径 |
| `docs.yml` | 文档构建、Registry 检查、消费者 pin | `docs/**`、元数据、选定脚本和 workflow |

`spec/`、`scripts/`、`.github/` 下的共享修改仍会触发完整 `ci.yml` 矩阵。这是有意设计：
这些文件可能影响所有语言契约。

纯文档改动由 `docs.yml` 处理；`ci.yml` 忽略 `docs/**`、Markdown 文件、
`mkdocs.yml` 和 `requirements-docs.txt`。

## 新增或修改语言 Workflow

1. 在 `.github/workflows/` 下新增 workflow。
2. 触发路径包含 `language/<language>/**` 和该 workflow 文件本身。
3. 包含该语言的一致性、消费者和示例 job。
4. 在 `ci.yml` 的 `paths-ignore` 中加入 `language/<language>/**`。
5. 共享 `spec/` 和兼容性覆盖继续留在 `ci.yml`，不要在每种语言 workflow 中重复全矩阵。
6. 将分支保护的 required checks 更新为新的 `<workflow> / <job>` 名称。

## Required Checks

Required checks 名称格式为 `<workflow> / <job>`，例如：

- `ci-python / python-conformance`
- `ci-java / java-conformance`
- `ci-dotnet / csharp-conformance`
- `ci-adapters / adapters`

拆分 workflow 时必须在同一变更窗口更新分支保护，否则 PR 会一直等待已不存在的检查名。

## 本地等价命令

使用仓库 `AGENTS.md` 中对应语言的命令。路径拆分不降低验收标准，只是避免运行无关 job。
