# 16 语言覆盖矩阵

示例目录覆盖十六种语言实现的九个集成主题。每个主题都有确定性检查，不需要真实模型端点。

| 主题 | 语言数 | 入口 |
| --- | --- | --- |
| Checkpoint Allowlist | 30 | `language/<language>/examples/checkpoint` |
| Event Sink | 30 | `language/<language>/examples/event-sink` |
| Retry | 30 | `language/<language>/examples/retry` |
| Provider Fallback | 30 | `language/<language>/examples/provider-fallback` |
| Streaming | 30 | `language/<language>/examples/streaming` |
| Structured Output | 30 | `language/<language>/examples/structured-output` |
| Identity / Policy | 30 | `language/<language>/examples/identity-policy` |
| HTTP Service | 30 | `language/<language>/examples/service` |
| MCP | 16 | `language/<language>/examples/mcp` |

Go 的参考配方与示例保留在 `examples/`。

## 语言与验证方式

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

Structured Output 示例也已覆盖 Dart、Perl、Julia、Swift、Haskell、OCaml、D、Nim、Zig、V、Delphi、PowerShell、MATLAB 和 Objective-C，入口位于 `language/<language>/examples/structured-output`。

## 额外 SDK 语言：Streaming

Streaming 累加示例也已覆盖 Dart、Perl、Julia、Swift、Haskell、OCaml、D、Nim、Zig、V、Delphi、PowerShell、MATLAB 和 Objective-C，入口位于 `language/<language>/examples/streaming`。这些是 transport-neutral 分片累加示例。

## 额外 SDK 语言：Identity / Policy

Identity / Policy 示例也已覆盖 Dart、Perl、Julia、Swift、Haskell、OCaml、D、Nim、Zig、V、Delphi、PowerShell、MATLAB 和 Objective-C，入口位于 `language/<language>/examples/identity-policy`。

## 额外 SDK 语言：HTTP Service

transport-neutral HTTP handler 示例也已覆盖 Dart、Perl、Julia、Swift、Haskell、OCaml、D、Nim、Zig、V、Delphi、PowerShell、MATLAB 和 Objective-C，入口位于 `language/<language>/examples/service`。
