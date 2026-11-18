# 31 语言覆盖矩阵

示例目录覆盖三十一种语言实现的十三个集成主题。每个主题都有确定性检查，不需要真实模型端点。

| 主题 | 语言数 | 入口 |
| --- | --- | --- |
| Consumer Starter | 31 | `language/<language>/examples/consumer` |
| Live Model | 31 | `language/<language>/examples/live-model` |
| Checkpoint Allowlist | 31 | `language/<language>/examples/checkpoint` |
| Event Sink | 31 | `language/<language>/examples/event-sink` |
| Retry | 31 | `language/<language>/examples/retry` |
| Provider Fallback | 31 | `language/<language>/examples/provider-fallback` |
| Streaming | 31 | `language/<language>/examples/streaming` |
| Structured Output | 31 | `language/<language>/examples/structured-output` |
| Identity / Policy | 31 | `language/<language>/examples/identity-policy` |
| HTTP Service | 31 | `language/<language>/examples/service` |
| MCP | 31 | `language/<language>/examples/mcp` |
| HITL | 31 | `language/<language>/examples/hitl` |
| Session Checkpoint | 31 | `language/<language>/examples/session-checkpoint` |

Go 的参考配方与示例保留在 `examples/`。

GNU Octave 复用 `language/matlab/examples/` 下的共享 MATLAB 示例；`matlab-octave-core` 是共享实现，没有独立的示例根目录。

运行 `python scripts/check_example_coverage.py --report` 可查看当前每语言矩阵。覆盖要求包含 `README.md` 和至少一个源码文件；只有 README 的目录不算已实现。

这只是源码存在检查，不是运行或语义对齐验证。示例深度与运行证据分开：

| 深度 | 要求 |
| --- | --- |
| 机制检查 | 孤立的 schema、handler 或 callback 断言，可能不调用 Core |
| Core 集成 | 通过实际 Core/model/tool/policy 接缝验证所声明行为 |
| 应用教程 | 包含安装、输入到输出任务、错误处理与后续路径 |

有记录的运行是独立证据维度，需 revision、工具链、命令、输出和限制。机制检查即使
实测通过，也不会变成应用教程。目录尚未按上述深度完整审计，不由计数推断等价深度。

## 覆盖情况

全部 31 种声明语言都提供 HITL 与 Session Checkpoint 示例。Go 使用仓库根目录示例，
Octave 复用 MATLAB 示例。对于 transport-seam 或共享运行时示例，语言 README 会说明
所需的调用方 transport 或继承的运行时。

## 语言与验证方式

下表列出十六种主要 Core 语言；其余十五种额外 SDK 语言在各主题章节中列出。

| 语言 | 示例根目录 | 本地 / CI 证据 |
| --- | --- | --- |
| Go | `examples/` 与 `examples/recipes/` | Go 测试与配方 |
| Python | `language/python/examples/` | 已发布 PyPI 包；CI |
| TypeScript | `language/typescript/examples/` | 已发布 npm 包；CI |
| Java | `language/java/examples/` | 已发布 Maven 包；CI |
| Rust | `language/rust/examples/` | 已发布 crates.io 包；CI |
| C# | `language/csharp/examples/` | 已发布 NuGet 包；CI |
| Ruby | `language/ruby/examples/` | 源码 SDK；本地与 CI |
| PHP | `language/php/examples/` | 源码 SDK；本地与 CI |
| C | `language/c/examples/` | 源码库；本地与 CI |
| C++ | `language/cpp/examples/` | 源码库；CI CMake target |
| Fortran | `language/fortran/examples/` | 源码模块；本地与 CI |
| Elixir | `language/elixir/examples/` | 源码模块；本地与 CI |
| Erlang | `language/erlang/examples/` | 源码模块；本地与 CI |
| Lua | `language/lua/examples/` | 源码模块；本地与 CI |
| R | `language/r/examples/` | 源码模块；本地与 CI |
| COBOL | `language/cobol/examples/` | 源码模块；本地与 CI |

## 运行方式

每个示例目录的 README 提供准确命令。常见形式：

```bash
# 已发布包
cd language/python/examples/checkpoint && python -m unittest ...
cd language/typescript/examples/checkpoint && npm test
cd language/csharp/examples/checkpoint && dotnet run -- --test
cd language/java/examples/checkpoint && mvn -q compile exec:java
cd language/rust/examples/checkpoint && cargo run

# 源码 SDK
ruby -I language/ruby/lib language/ruby/examples/checkpoint/checkpoint.rb
php language/php/examples/checkpoint/checkpoint.php
python language/fortran/examples/checkpoint/run.py
python language/cobol/examples/checkpoint/build.py
```

## 范围说明

- 发布包示例证明安装与 API 使用；源码示例证明仓库集成。
- Ruby/PHP/C/C++/Fortran/Elixir/Erlang/Lua/R/COBOL 的 HTTP Service 示例是
  transport-neutral 请求处理器；Python/TypeScript/C#/Rust/Java 包含可执行 HTTP 服务。
- Streaming 示例在 SDK 提供 delta 时使用 delta，在仅提供 agent 生命周期时使用
  stream parts。
- 这些示例不提供生产级身份、持久存储、沙箱或 exactly-once 交付；这些仍由应用负责。

另见[示例目录](examples.md)。

## 额外 SDK 语言：Retry

Retry 主题也已覆盖 Dart、Perl、Julia、Swift、Haskell、OCaml、D、Nim、Zig、V、
Delphi、PowerShell、MATLAB 和 Objective-C，入口位于
`language/<language>/examples/retry`。这些是确定性源码示例；CI 覆盖取决于工具链。

## 额外 SDK 语言：Checkpoint

Checkpoint Allowlist 示例也已覆盖 Dart、Perl、Julia、Swift、Haskell、OCaml、D、Nim、Zig、V、Delphi、PowerShell、MATLAB 和 Objective-C，入口位于 `language/<language>/examples/checkpoint`。

## 额外 SDK 语言：Event Sink

Event Sink 示例也已覆盖 Dart、Perl、Julia、Swift、Haskell、OCaml、D、Nim、Zig、V、Delphi、PowerShell、MATLAB 和 Objective-C，入口位于 `language/<language>/examples/event-sink`。

## 额外 SDK 语言：Provider Fallback

Provider Fallback 示例也已覆盖 Dart、Perl、Julia、Swift、Haskell、OCaml、D、Nim、Zig、V、Delphi、PowerShell、MATLAB 和 Objective-C，入口位于 `language/<language>/examples/provider-fallback`。

## 额外 SDK 语言：Structured Output

Structured Output 示例也已覆盖 Dart、Perl、Julia、Swift、Haskell、OCaml、D、Nim、Zig、V、Delphi、PowerShell、MATLAB 和 Objective-C，入口位于 `language/<language>/examples/structured-output`。[结构化输出教程](../guides/structured-output-tutorial.md)列出了每种已声明语言的运行命令。

## 额外 SDK 语言：Streaming

Streaming 累加示例也已覆盖 Dart、Perl、Julia、Swift、Haskell、OCaml、D、Nim、Zig、V、Delphi、PowerShell、MATLAB 和 Objective-C，入口位于 `language/<language>/examples/streaming`。这些是 transport-neutral 分片累加示例。

## 额外 SDK 语言：Identity / Policy

Identity / Policy 示例也已覆盖 Dart、Perl、Julia、Swift、Haskell、OCaml、D、Nim、Zig、V、Delphi、PowerShell、MATLAB 和 Objective-C，入口位于 `language/<language>/examples/identity-policy`。

## 额外 SDK 语言：HTTP Service

transport-neutral HTTP handler 示例也已覆盖 Dart、Perl、Julia、Swift、Haskell、OCaml、D、Nim、Zig、V、Delphi、PowerShell、MATLAB 和 Objective-C，入口位于 `language/<language>/examples/service`。

## 额外 SDK 语言：MCP

MCP transport 示例也已覆盖 Dart、Perl、Julia、Swift、Haskell、OCaml、D、Nim、Zig、V、
Delphi、PowerShell、MATLAB 和 Objective-C，入口位于
`language/<language>/examples/mcp`。MATLAB/Octave 与 PowerShell Core 未内置 MCP
客户端，因此这两个示例是 transport-neutral 的。

## 高级示例

应用级委派和确定性 representative-chain 示例已覆盖各 Core SDK 语言，包括原生、共享
运行时和 adapter 实现。部分 SDK 将相同检查放在原生测试套件中，而非
`examples/advanced-delegation` 目录。Go 还提供长时操作、受治理 Workspace 和 Plugin 参考示例。Sample
语言指向宿主 Core 的 chain/delegation 示例；Shell、Lisp、Tcl 和 Prolog 明确记录 Bridge
契约没有本地委派接口。记录运行见[验证证据](../project/verification-evidence.md)，模式说明见
[高级示例](../guides/advanced-examples.md)，并运行
`python scripts/check_example_coverage.py --report-advanced` 查看当前逐语言报告。
