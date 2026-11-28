# CI Workflows

CI 按路径拆分，语言专属改动不再运行完整矩阵。`ci.yml` 继续作为核心/共享检查和
定时全矩阵入口。

## Workflow 地图

| Workflow | 范围 | 触发路径 |
| --- | --- | --- |
| `ci.yml` | Go/核心、共享检查、Bridge、质量、安全、全矩阵 | 每次 main push；按路径过滤的 PR；定时；手动 |
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
| `ci-additional.yml` | Dart、Perl、D、Delphi 示例矩阵 | 示例及 SDK 源码依赖 |
| `ci-additional2.yml` | PowerShell 与 MATLAB/Octave 示例矩阵 | 示例及共享运行时依赖 |
| `ci-additional3.yml` | Swift、Julia、Haskell、OCaml、Nim、V、Zig、Objective-C 示例矩阵 | 示例及 SDK 源码依赖 |
| `ci-examples.yml` | Go 示例、SDK 示例、Go 消费者与配方 | `language/go/examples/**` 和选定语言示例路径 |
| `docs.yml` | 文档构建、Registry 检查、消费者 pin | `docs/**`、元数据、选定脚本和 workflow |
| `ci-applications.yml` | 参考应用 | 应用及其 SDK 依赖 |
| `ci-tutorials.yml` | 教程目录和可运行教程 | 目录输入、教程及 SDK 依赖 |
| `ci-labs.yml` | Behavior/Compatibility Lab | 所选 SDK、共享依赖、定时和手动 |
| `ci-bridge.yml` | Go Bridge 和共享运行时绑定 | Bridge 和 Go/核心依赖 |

`spec/`、`.github/actions/` 以及没有明确文档作用域的脚本修改仍会触发完整测试矩阵。
已知文档、Registry/Discovery 和 Mirror 脚本列在 `scripts/ci_changes.py` 的 `DOCS_SCRIPTS`
中，只运行文档或 Mirror 校验。Discovery JSON、SDK Markdown 和生成的 README、REGISTRY、llms
文件只运行文档、Mirror 或目录检查，包括嵌套教程 README。规范 `spec/` 下的 Markdown
仍是共享契约输入，但纯文档实现状态页 `spec/languages.md` 除外。
源码目录中嵌入提示词等 Markdown 保留运行时检查，除非匹配约定的
文档文件名或文档目录。包和构建清单仍运行对应运行时检查，因为它们可能修改实际依赖。
修改测试 workflow 自身文件
或手动触发时，该 workflow 全量运行；其他 workflow 的修改不会触发全局全量运行。
定时运行仍为全量运行。

根 README 和普通文档改动由 `docs.yml` 处理。教程目录文档只运行目录检查，不运行所有教程。
PR 触发器保留路径过滤。每次 main push 都启动 `ci.yml` 和 `docs.yml`，因为发布门禁要求
同一提交的这两个 workflow 均有成功的 main push 结果；手动运行不能替代。
纯文档以及由独立 workflow 负责的 SDK/应用修改只运行 `ci.yml` 中真实的变更分类和路由检查，
不会选择其运行时组合测试。独立 SDK 检查仍按依赖运行。Mirror PR 检查与串行写入隔离。

Job 在矩阵展开前过滤。SDK 修改运行对应 SDK 的测试、消费者、示例、教程、应用以及
依赖该共享运行时的示例。仅应用修改不会运行 SDK 或消费者 Job。Go/核心修改保留
Go、Bridge、Adapter、安全与质量检查。普通 push/PR 使用独立 workflow；`ci.yml` 中重复的
组合测试只在全量请求时运行，独有检查保持按依赖运行。Lab 参数取所选语言的交集，
工具链安装和构建也按语言过滤。组合 SDK 示例保留全部检查，但只执行所选 SDK 的步骤。
跨 SDK 服务集成需要全量请求。

`LANGUAGE_SCRIPTS` 将 PHP 包构建与测试脚本限定到 PHP。Ubuntu `php-package` 检查提供
PHP 和 Composer 并执行 `scripts/test_php_package.py`。文档使用明确的元数据测试列表，
不再因 README 修改发现并运行所有运行时脚本测试。全量组合检查中的 `script-tests`
保留完整脚本测试套件，包括没有独立检查的脚本测试。
同一 workflow 和事件/ref 下，后续 push 或 PR 会取消过期测试；不会取消手动或定时运行。

## 新增或修改语言 Workflow

1. 在 `.github/workflows/` 下新增 workflow。
2. 包含该语言的一致性、消费者和示例 Job，在命令或工作目录中明确引用 `language/<language>`。
3. 运行 `python scripts/sync_ci_routing.py` 生成触发路径和 Job 过滤。
4. 运行 `python scripts/sync_ci_routing.py --check` 和
   `python -m unittest discover -s scripts -p test_ci_changes.py -v`，以及
   `python -m unittest discover -s scripts -p test_ci_execution.py -v`（需要 PyYAML）。
5. 检查 `scripts/ci_changes.py` 中的间接依赖。生成器读取明确的语言路径、消费者 Job 名称
   以及脚本作用域和 Lab 语言选择；隐藏在其他脚本中的依赖需要明确路由和测试。
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
