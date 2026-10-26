# 多语言路线图

**状态：**执行计划，2026-10-25。本文排列[多语言 SDK 设计](17-multilingual-sdk.md)
定义的工作。日期和投入为估算，可在不改变规范的前提下调整。

## 排序原则

1. **契约先于代码。** 在 wire 产物和 Go 一致性 runner 就绪前，不启动 SDK 实现。
2. **由 Go 证明向量。** 参考实现无法通过的向量不构成契约。
3. **一次一种语言。** Python 达到一致性后才让 TypeScript 满负荷；TypeScript
   之后再 Java。这样可限制契约漂移。
4. **核心先于适配器。** 核心契约全绿前，不发布提供商、MCP、OTel 或插件适配器。
5. **不新增 Go API。** 多语言工作不得放宽已冻结的 `pkg/...` 表面。

## 阶段总览

| 阶段 | 产出 | 门禁 |
| --- | --- | --- |
| 0 | 规范 spec、一致性清单、Go 向量 runner、CI 门禁 | Go 向量全绿 |
| 1 | Python SDK 核心达到一致并发布到 PyPI | 11 组向量 + parity |
| 2 | TypeScript SDK 核心达到一致并发布到 npm | 11 组向量 + parity |
| 3 | Java SDK 核心达到一致并发布到 Maven Central | 11 组向量 + parity |
| 4 | 按需求交付可选适配器与插件宿主 | 明确使用方 + 证据 |

内部工期、人力和风险跟踪位于本仓库之外。

## 当前状态（2026-10-25）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| P0-1 spec 骨架与一致性清单 | 完成 | `spec/SPEC_VERSION`、`spec/parity.md` |
| P0-2 事件 wire 产物 | 完成 | `spec/wire/events.json` |
| P0-3 错误 wire 产物 | 完成 | `spec/wire/errors.json` |
| P0-4 插件 wire 产物 | 完成 | `spec/wire/plugin.json` |
| P0-5 JSON Schema wire 产物 | 完成 | `spec/wire/jsonschema.json` |
| P0-6 行为向量 | 完成 | 十一组全绿：agent loop、toolcall、jsonschema、plugin、memory、event、stream、checkpoint、policy、context、middleware |
| P0-7 Go 向量 runner | 完成 | `internal/spec` |
| P0-8 `spec-conformance` CI 任务 | 完成 | `.github/workflows/ci.yml` |
| P0-9 一致性 linter | 完成 | `internal/spec` 中的 `TestParityInventory` 与 `TestParitySymbols` |

本地检查：`GOWORK=off go test -count=1 ./internal/spec/... -v`。

阶段 0 的契约抽取退出门禁已满足。

### 阶段 1 进度（2026-10-25）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| P1-1 核心模块 | 完成 | `python/praxo/{model,tool,event,policy,memory,checkpoint,agent}.py` |
| P1-2 异步循环、取消、流式 | 完成 | `Agent`、`AgentOptions.on_delta`、流式测试 |
| P1-3 上下文预算、压缩、卸载、`AGENTS.md` | 完成 | `python/praxo/context.py`、上下文测试 |
| P1-4 中间件子集 | 完成 | `python/praxo/middleware/`、中间件测试 |
| P1-5 OpenAI 兼容适配器 | 完成 | `python/praxo/adapters/openaicompat.py`、假 SSE 测试 |
| P1-6 Python 一致性 runner | 完成 | `python/conformance/run.py`、CI 任务 `python-conformance` |
| P1-7 SDK 文档 | 完成 | `python/README.md`、`python/API.md`、`python/api/0.2.0.txt` |
| P1-8 PyPI 发布 | 就绪 | wheel/sdist 构建与干净 venv 安装通过；发布待凭据 |

本地检查：

```bash
cd python
python conformance/run.py
python -m unittest discover -s tests -v
```

阶段 1 的代码与文档门禁已满足；PyPI 发布仍待发布凭据。

发布状态：`spec/v0.2.0` 标记十一组契约，`python/v0.2.0` 标记 Python SDK，
`typescript/v0.1.0` 标记 TypeScript 核心，`java/v0.2.1` 标记 Java 核心，
`rust/v0.1.0` 标记 Rust 核心，`shell/v0.1.0` 与 `powershell/v0.1.0` 标记桥接
包装，`c/v0.1.0` 标记 C 一致性核心，`csharp/v0.1.0` 标记 C# 核心，
`php/v0.1.0` 标记 PHP 核心，`perl/v0.1.0` 标记 Perl 核心，
`cpp/v0.1.0` 标记 C++ 核心，`ruby/v0.1.0` 标记 Ruby 核心，
`lua/v0.1.0` 标记 Lua 核心，`dart/v0.1.0` 标记 Dart 核心，
`zig/v0.2.0` 标记 Zig 核心，`d/v0.1.0` 标记 D 核心，
`swift/v0.2.0`、`julia/v0.2.0` 和 `r/v0.2.0` 分别标记对应核心 SDK。
`zig/v0.1.0` 继续保留为 wire 标签。Swift、Julia 和 R 的 `0.1.0` 标签继续
保留给已固定 wire 子集的使用方。

### 阶段 2 进度（2026-10-25）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| P2-1 包与构建 | 完成 | `typescript/`、`package.json`、`tsconfig.json` |
| P2-2 异步循环、流式、取消 | 完成 | 异步循环、`onDelta`、`AbortSignal` |
| P2-3 schema 校验 | 完成 | 无依赖子集校验器；未采用 Zod（D9） |
| P2-4 核心循环、中间件、记忆、检查点、策略、事件 | 完成 | `typescript/src`、`node --test` |
| P2-5 OpenAI 兼容适配器 | 完成 | `typescript/src/adapters/openaicompat.ts`、假 HTTP/SSE 测试 |
| P2-6 一致性 runner 与 parity | 完成 | `typescript/src/conformance/`、CI 任务 `typescript-conformance` |
| P2-7 npm 发布 | 就绪 | `npm pack` 与 `npm publish --dry-run` 已验证；发布待凭据 |

TypeScript SDK 已通过全部十一组向量与 parity 检查。阶段 2 的代码与文档门禁
已满足；npm 发布仍待发布凭据。VFS 与插件宿主属于可选后续工作。

### 阶段 3 进度（2026-10-25）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| P3-1 Java 模块与包 | 完成 | `java/`、`pom.xml`、record 类型 |
| P3-2 虚拟线程执行与取消 | 完成 | 虚拟线程执行器、`CancellationToken`、并发自测 |
| P3-3 JSON 编解码 | 完成 | 无依赖 `util/Json.java`；未采用 Jackson（D10） |
| P3-4 核心循环、中间件、记忆、检查点、策略、事件 | 完成 | `java/src`、`javac` + `jrun` 一致性运行 |
| P3-5 OpenAI 兼容适配器 | 完成 | `java/.../adapters`、本地 HTTP/SSE 自测 |
| P3-6 一致性 runner | 完成 | `java/.../conformance/Run.java`、CI 任务 `java-conformance` |
| P3-API API 快照与 parity | 完成 | `java/api/0.2.0.txt`、`Parity.check()` |
| P3-7 Maven Central 发布 | 计划中 | CI 执行 Maven 构建；发布待完成 |

Java SDK 已通过全部十一组向量、API 快照/parity 检查及适配器/并发自测。
阶段 3 尚未完成：Maven Central 发布。

### Rust 与 C SDK（2026-10-25）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| Rust 核心 | 完成 | `rust/`、11 组向量、`cargo test` |
| Rust OpenAI 适配器 | 计划中 | 未实现 |
| Rust API 快照/parity | 计划中 | 未实现 |
| C 核心 | 完成 | `c/`、11 组向量、`ctest`、`c/v0.1.0` |
| C API 快照/parity | 部分完成 | wire 级 parity 与 linter；惯用 Agent API 待补 |

Rust SDK 已通过全部十一组向量及 7 个单元测试。C 是 wire 级一致性核心；
两者都使用共享向量与 wire 契约。

### C# 与 VB.NET（2026-10-26）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| C# 核心 | 完成 | `csharp/`、11 组向量、API 快照、`dotnet` 测试 |
| C# OpenAI 适配器 | 完成 | `OpenAiCompatibleModel`，支持同步与流式 |
| C# API 快照/parity | 完成 | `csharp/api-snapshot.txt`、`spec/parity/csharp.md` |
| VB.NET 示例 | 完成 | `csharp/samples/VbSample` |

C# SDK 已通过全部十一组向量、无依赖核心测试和 API 快照检查。VB.NET 示例
直接复用同一程序集。

### PHP（2026-10-26）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| PHP 核心 | 完成 | `php/`、11 组向量、API 快照、测试 |
| PHP API 快照/parity | 完成 | `php/api/0.1.0.txt`、`spec/parity/php.md` |
| PHP 提供商适配器 | 计划中 | `0.1.0` 未包含 |

PHP SDK 已通过全部十一组向量、无依赖测试和 API 快照检查。它是同步的、
仅依赖标准库的包。

### D 核心（2026-10-26）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| D core | 完成 | `d/`、11 组向量、`d/v0.1.0` |
| D 测试 | 完成 | `./build/tests` |
| D API 快照 | 完成 | `d/api/0.1.0.txt` |

D SDK 仅使用标准库，并通过全部十一组向量和 API 快照检查。

### Zig 核心（2026-10-26）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| Zig core | 完成 | `zig/`、11 组向量、`zig/v0.2.0` |
| Zig 测试 | 完成 | `zig test src/toolcall.zig`、`jsonschema.zig`、`plugin.zig`、`pii_test.zig` |
| Zig API 快照 | 完成 | `zig/api/0.2.0.txt` |

Zig SDK 仅使用标准库，并通过全部十一组向量和 API 快照检查。
`zig/v0.1.0` 继续保留为 wire 标签。

### Kotlin 与 Scala 示例（2026-10-26）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| Kotlin 示例 | 完成 | `kotlin/sample.kt`、`kotlin-sample` CI |
| Scala 示例 | 完成 | `scala/sample.scala`、`scala-sample` CI |
| 独立 JVM 核心 | 不计划 | Java 仍是源实现 |

两个示例都使用编译后的 Java SDK。没有独立的 Kotlin 或 Scala 标签。

### Dart 核心（2026-10-26）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| Dart core | 完成 | `dart/`、11 组向量、`dart/v0.1.0` |
| Dart 测试 | 完成 | `dart run tests/run.dart` |
| Dart API 快照 | 完成 | `dart/api/0.1.0.txt` |

Dart SDK 仅使用标准库，并通过全部十一组向量、核心测试和 API 快照检查。

### JavaScript 示例（2026-10-26）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| JavaScript 示例 | 完成 | `javascript/sample.mjs` |
| JavaScript 入口 | 完成 | `javascript/README.md`、`docs/sdks.md` |
| 独立 JavaScript 核心 | 不计划 | TypeScript 仍是源实现 |

示例在 Node 中导入构建后的 TypeScript 包，并在 CI 中运行。没有独立的
JavaScript 标签。

### Lua 核心（2026-10-26）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| Lua core | 完成 | `lua/`、11 组向量、`lua/v0.1.0` |
| Lua 测试 | 完成 | `lua lua/tests/run.lua` |
| Lua API 快照 | 完成 | `lua/api/0.1.0.txt` |

Lua SDK 仅使用标准库，并通过全部十一组向量、核心测试和 API 快照检查。

### Ruby 核心（2026-10-26）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| Ruby core | 完成 | `ruby/`、11 组向量、`ruby/v0.1.0` |
| Ruby 测试 | 完成 | `ruby ruby/tests/run.rb` |
| Ruby API 快照 | 完成 | `ruby/api/0.1.0.txt` |

Ruby SDK 仅使用标准库，并通过全部十一组向量、核心测试和 API 快照检查。

### C++ 核心（2026-10-26）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| C++ core | 完成 | `cpp/`、11 组向量、`cpp/v0.1.0` |
| C++ 测试 | 完成 | `ctest --test-dir cpp/build` |
| C++ API 快照 | 完成 | `cpp/api/0.1.0.txt` |

C++20 SDK 仅使用标准库，并通过全部十一组向量、核心测试和 API 快照检查。

### Perl 核心（2026-10-26）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| Perl core | 完成 | `perl/`、11 组向量、`perl/v0.1.0` |
| Perl 测试 | 完成 | `perl perl/tests/run.pl` |
| Perl API 快照 | 完成 | `perl/api/0.1.0.txt` |

Perl SDK 仅使用核心模块，并通过全部十一组向量、27 个测试和 API 快照检查。

### Swift 核心（2026-10-26）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| Swift core | 完成 | `swift/`、11 组向量、`swift/v0.2.0` |
| Swift XCTest | 完成 | macOS 上的 `swift test` |
| Swift API 快照 | 完成 | `swift/api/0.2.0.txt` |

Swift 核心通过全部十一组向量、XCTest 和 API 快照检查。

### Julia 核心（2026-10-26）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| Julia core | 完成 | `julia/`、11 组向量、`julia/v0.2.0` |
| Julia 测试 | 完成 | `julia --project=julia julia/test/runtests.jl` |
| Julia API 快照 | 完成 | `julia/api/0.2.0.txt` |

Julia 包使用 JSON.jl 并通过全部十一组向量和 API 快照检查。

### R 核心（2026-10-26）

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| R core | 完成 | `r/`、11 组向量、`r/v0.2.0` |
| R 测试 | 完成 | `Rscript r/tests/run_tests.R` |
| R API 快照 | 完成 | `r/api/0.2.0.txt` |

R 包使用基础 R 的 JSON 解析器并通过全部十一组向量和 API 快照检查。

长尾语言分层见
[语言扩展计划](19-language-expansion.md)。

## 阶段 0 - 契约抽取

**目标：**在不改变 Go 行为的前提下，让“同一份契约”可被机器检查。

### 交付物

| ID | 交付物 | 证据 |
| --- | --- | --- |
| P0-1 | `spec/SPEC_VERSION`、`spec/README.md`、`spec/parity.md` | 完成审查的清单，无未分类包 |
| P0-2 | `spec/wire/events.json` | 事件类型、stream kind、负载键与 `docs/event-schema.md` 及 `pkg/agent/stream` 一致 |
| P0-3 | `spec/wire/errors.json` | 每个导出 sentinel 映射到稳定错误码 |
| P0-4 | `spec/wire/plugin.json` | Manifest v1、生命周期状态、进程/WASM 信封 |
| P0-5 | `spec/wire/jsonschema.json` | 支持与忽略的关键字与 `pkg/tool/jsonschema` 一致 |
| P0-6 | `spec/vectors/*.json`，覆盖 agent loop、toolcall、jsonschema、memory、checkpoint、policy、stream、plugin | 每组向量在 Go runner 上通过 |
| P0-7 | Go 向量 runner，位于 `pkg/conformance/vectors` 或 `spec/runner/go` | `GOWORK=off go test ./...` 覆盖 runner |
| P0-8 | CI 任务 `spec-conformance` | 向量失败阻断合并 |
| P0-9 | 一致性 linter | 当 `spec/parity.md` 引用缺失的 SDK 符号或遗漏 Go 符号时失败 |

### 退出条件

- `spec/parity.md` 覆盖所有导出 `pkg/...` 包。
- P0-6 全部向量组在 Go 上通过。
- CI 拒绝缺少 `SPEC_VERSION` 决策的 wire 变更。
- 除增量测试/runner 代码外，不改变 Go 行为。

### 说明

- Go runner 放在普通 Go 包中，复用现有工具链，不新增模块。
- 向量以 JSON 存储，使用稳定的 `id`、`group`、`input`、`expect` 形状，使非 Go
  runner 无需代码生成即可消费。
- 不要从向量生成符合语言习惯的 API。向量验证行为，不定义源码接口。

## 阶段 1 - Python SDK

**目标：**Python 开发者无需接触 Go 即可构建 quickstart Agent，并使用流式、工具、
记忆、检查点、策略和事件。

### 交付物

| ID | 交付物 | 证据 |
| --- | --- | --- |
| P1-1 | `python/praxo/{model,tool,event,policy,memory,checkpoint,agent}` | 可导入、类型模型、异步 API |
| P1-2 | 支持取消与流式的异步 Agent 循环 | 与 `examples/quickstart` 行为一致 |
| P1-3 | 上下文预算、压缩、卸载、`AGENTS.md` 加载 | 行为向量 |
| P1-4 | 中间件子集：结构化输出、PII、回退、调用限额、工具选择 | 每个中间件一个测试 |
| P1-5 | `praxo.model.openaicompat` 适配器 | 针对假服务器的确定性 SSE 测试 |
| P1-6 | 覆盖全部 `spec/vectors` 的一致性 runner | CI 任务 `python-conformance` |
| P1-7 | `python/README.md`、API 参考、迁移指南 | 文档构建通过 |
| P1-8 | PyPI 发布 `praxo-core` | wheel 安装测试 |

### 退出条件

- P1 全部向量组全绿。
- `python/` 的一致性 linter 全绿。
- 每个导出符号都有 docstring。
- 取消、工具保序和失败关闭有专门测试。
- 依赖不超出已批准的宽松许可清单。

## 阶段 2 - TypeScript SDK

**目标：**在 Node 及 API 允许的边缘环境实现核心 Agent 循环和工具的一致性。

### 交付物

| ID | 交付物 | 证据 |
| --- | --- | --- |
| P2-1 | 带子路径导出的 `typescript/src` | `exports` 映射与设计文档一致 |
| P2-2 | 异步迭代流式与 `AbortSignal` 取消 | stream 向量 |
| P2-3 | 基于 Zod 的工具输入校验 | schema 向量 |
| P2-4 | 核心 Agent 循环、中间件、记忆、检查点、策略、事件 | 行为向量 |
| P2-5 | OpenAI 兼容适配器 | 确定性 fetch/SSE 测试 |
| P2-6 | 一致性 runner | CI 任务 `typescript-conformance` |
| P2-7 | npm 发布 `@axisvela/praxo-core` | tarball 安装测试 |

### 退出条件

- P1 全部向量组全绿。
- `typescript/` 的一致性 linter 全绿。
- 类型严格；无正当理由不得导出 `any`。
- Node 20 与 Node 22 矩阵通过。
- 浏览器兼容性只记录，不作承诺。

## 阶段 3 - Java SDK

**目标：**以 Java 21 惯用法实现企业级一致性。

### 交付物

| ID | 交付物 | 证据 |
| --- | --- | --- |
| P3-1 | `java/praxo-core` 模块，包含 `io.axisvela.praxo.*` 包 | wire 类型使用 record/sealed interface |
| P3-2 | 虚拟线程执行模型与取消 | 并发测试 |
| P3-3 | 基于 Jackson 的 wire 编解码 | 往返向量 |
| P3-4 | 核心 Agent 循环、中间件、记忆、检查点、策略、事件 | 行为向量 |
| P3-5 | OpenAI 兼容适配器 | 假 HTTP 服务器测试 |
| P3-6 | 一致性 runner | CI 任务 `java-conformance` |
| P3-7 | Maven Central 发布 `io.axisvela:praxo-core` | 本地仓库安装测试 |

### 退出条件

- P1 全部向量组全绿。
- `java/` 的一致性 linter 全绿。
- Agent 循环中不使用基于反射的魔法。
- Java 21 与 Java 23 矩阵通过。
- 导出包 Javadoc 构建无警告。

## 阶段 4 - 适配器与插件宿主

每种语言的优先级：

1. Anthropic 与 Gemini 适配器
2. MCP 网关
3. OpenTelemetry sink
4. VFS 与受限本地后端
5. 基于共享 JSON-Lines 契约的进程插件宿主
6. WASM 插件宿主

每一项只在有明确使用方和自身一致性证据时发布。WASM 宿主最后做，因为各语言的运行时
绑定与资源限制差异很大。

## 决策记录

| ID | 决策 | 状态 |
| --- | --- | --- |
| D1 | Go 保留为仓库根目录的参考实现 | 已接受 |
| D2 | `spec/` 是规范，Go 用于验证 | 已接受 |
| D3 | wire 字段保持现有大小写，包括 `image_url` | 已接受 |
| D4 | 语言顺序为 Python、TypeScript、Java | 已接受 |
| D5 | 每个 SDK 独立版本化并声明 `SPEC_VERSION` | 已接受 |
| D6 | 无跨 SDK 运行时依赖或 FFI | 已接受 |
| D7 | WASM 插件宿主最后做 | 已接受 |
| D8 | TypeScript 浏览器支持只记录，不承诺 | 已接受 |
| D9 | TypeScript 使用无依赖 JSON Schema 子集校验器；不采用 Zod | 已接受 |
| D10 | Java 使用无依赖 JSON 工具；不采用 Jackson | 已接受 |

## SDK 完成定义

SDK 发布只有在以下条件全部满足时才完成：

1. 其一致性任务在已发布 `SPEC_VERSION` 上全绿。
2. 一致性 linter 对声明范围无缺口。
3. 干净安装后 quickstart 可运行。
4. 取消、流式和失败关闭行为有测试。
5. 安全敏感行为在该语言中有独立测试。
6. 文档列出支持的 `SPEC_VERSION` 和 Go 参考版本。
7. 发布为 MIT，且依赖许可已审查。

## 发布与标签策略

| 产物 | 标签形状 | 版本线 |
| --- | --- | --- |
| Go 核心 | `v2.x.y` | 现有 |
| Python | `python/v0.x.y` | P1 退出门禁前为 `0.x` |
| TypeScript | `typescript/v0.x.y` | P2 退出门禁前为 `0.x` |
| Java | `java/v0.x.y` | P3 退出门禁前为 `0.x` |
| 规范 | `spec/v0.x.y` | 首个稳定契约前为 `0.x` |

标签不得移动。规范可单独发布而不发布 SDK；SDK 发布必须注明其目标规范版本。

## 相关文档

- [多语言 SDK 设计](17-multilingual-sdk.md)
- [架构](01-architecture.md)
- [兼容与弃用策略](16-compatibility-policy.md)
- [发布流程](09-release.md)
- [路线图详情](06-roadmap.md)
