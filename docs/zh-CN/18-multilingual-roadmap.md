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

| 阶段 | 产出 | 周期 | 依赖 |
| --- | --- | --- | --- |
| 0 | 规范 spec、一致性清单、Go 向量 runner、CI 门禁 | 3-4 周 | 无 |
| 1 | Python SDK 核心达到一致并发布到 PyPI | 10-12 周 | 阶段 0 |
| 2 | TypeScript SDK 核心达到一致并发布到 npm | 10-12 周 | 阶段 1 核心全绿 |
| 3 | Java SDK 核心达到一致并发布到 Maven Central | 12-14 周 | 阶段 2 核心全绿 |
| 4 | 按需求交付可选适配器与插件宿主 | 持续 | 阶段 3 |

两到三名工程师并行推进后续阶段时，预计 **8-11 个月**达到三语言核心一致性。每语言
单人串行则为 **12-18 个月**。

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
`typescript/v0.1.0` 标记 TypeScript 核心，`java/v0.2.1` 标记 Java 核心。
`0.1.0` 标签继续保留给已固定早期契约的使用方。

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
| C 核心 | 计划中 | 未实现 |
| C API 快照/parity | 计划中 | 未实现 |

Rust SDK 已通过全部十一组向量及 7 个单元测试。C 是下一个实现；两者都使用
共享向量与 wire 契约。

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

## 工作分解

| Epic | 阶段 | 承担角色 |
| --- | --- | --- |
| 契约抽取与向量 runner | 0 | Go 维护者 |
| 一致性 linter 与 CI | 0 | 构建/基础设施 |
| Python 核心 | 1 | Python 维护者 |
| Python 适配器与打包 | 1 | Python 维护者 |
| TypeScript 核心 | 2 | TS 维护者 |
| TypeScript 打包 | 2 | TS 维护者 |
| Java 核心 | 3 | Java 维护者 |
| Java 打包 | 3 | Java 维护者 |
| 适配器与插件宿主 | 4 | 按适配器 |

## 风险清单

| 风险 | 影响 | 缓解 |
| --- | --- | --- |
| SDK 行为漂移 | 高 | 向量是发布阻断项；不接受仅文字一致性 |
| 某 SDK 自行规范化 wire | 高 | wire 夹具快照测试；记录混用大小写 |
| Go 特有语义泄漏到其他 API | 中 | 逐语言惯用法审查；不使用 goroutine/channel 形状的 API |
| 插件宿主分歧 | 中 | 先发布 wire 契约，宿主后做 |
| 打包与发布开销 | 中 | 每语言独立发布 workflow 与 tag |
| 路径/沙箱安全回归 | 高 | 每语言对抗性测试，不能只靠 Go 审查 |
| 范围蔓延到适配器 | 中 | P1 退出门禁阻断适配器工作 |
| 每语言单点依赖 | 高 | 每个 SDK 两名评审；spec 是共享产物 |

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

待定事项：

- Python SDK 只支持 `asyncio`，还是同时提供同步包装。
- Java 发布单一构件还是按领域拆分构件。
- `spec/vectors` 由 Go 测试生成，还是先手工编写。
- SDK 是否可在 P1 向量全绿前发布 P2 适配器。

## 指标

- 每个 SDK 的向量通过率：已发布版本目标 100%。
- 一致性覆盖率：已实现行数除以 `spec/parity.md` 总行数；P1 范围目标 100%。
- wire 夹具数量：单调增长。
- 使用方冒烟时间：每语言 CI 低于五分钟。
- 跨语言分歧缺陷：每个版本目标为零。

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
