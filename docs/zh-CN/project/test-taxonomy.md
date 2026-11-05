# 测试与证据分层

**状态：** 公开证据指引，2026-11-05。测试通过并不说明它证明了什么；必须先知道证据层级。
引用测试为 Core 能力、集成证据或采用证据前，请先阅读本页。

## 层级

| 层级 | 证据 | 能证明 | 不能证明 |
| --- | --- | --- | --- |
| L1 Core 契约与行为 | `pkg/...` 测试、`spec/vectors/`、API 快照 | Go 参考实现具备声明的本地行为或契约 | 已发布包、其他 SDK 或生产行为 |
| L2 SDK 一致性 | `language/...` 测试、parity 与 conformance runner | 某个 SDK 声明范围与其向量一致 | 完整 Go 对齐、真实 provider 或采用 |
| L3 已发布包消费者 | `examples/consumer-go`、`consumer-python`、`consumer-typescript`、`consumer-java` | Registry 产物可安装、构建并走通允许/拒绝等公开 API 路径 | Core 内部、生产安全或有人采用 |
| L4 应用配方 | 身份绑定、治理验收胶水、长时操作 fixture 与 verifier/fencing 演示 | 参考应用模式及声明的失败边界 | Core 拥有外部服务、存储、验证器或策略决策 |
| L5 采用实验 | Agent Adoption Lab 记录 | 固定条件下编程工具如何发现、选择、集成与保留 | 框架本身正确性 |
| L6 生产与运行 | 部署、平台、硬件与独立评审记录 | 被测部署或环境 | 其他环境或未来 revision |

`已验证` 始终限定于 revision、产物和日期；后续提交不会扩展它。

## `examples/consumer-go` 映射

| 文件 | 层级 | 实际触及的 Core 接缝 | 配方/应用行为 |
| --- | --- | --- | --- |
| `main_test.go` | L3，并通过公开 API 触及 L1 行为 | 工具循环、Policy 允许/拒绝、发布包导入 | 确定性 fixture 与输出 |
| `governed_test.go` | L3/L4 | 最终参数重授权、审批编辑重授权、Policy 错误传播 | 缺少 Policy/范围守卫属于应用检查；Core 保留 nil-policy 嵌入 |
| `identity_test.go` | L4 | Policy Hook 接收工具参数与 context | principal、角色、租户、过期均是应用逻辑；模型角色声明被该逻辑忽略 |

长时操作套件已移到
[`examples/recipes/long-running-go`](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/long-running-go)，
避免 starter 混合 L3 包检查与 L4 配方。它是有价值的参考集成，也明确了应用必须自己承担
什么；它不是 Core 提供持久操作、HTTP 认证、效果验证、lease 或 fencing 的证据。只有其
Run 取消断言触及 Core 接缝。

Core 层的对应行为在 `pkg/agent` 测试（策略拒绝、最终参数授权、允许工具、取消）和
`spec/vectors` 中单独验证。

## 是否应把配方能力内化进 Core？

不要仅因配方测试通过就内化。只有全部满足才考虑：

1. 有明确消费者，且不止一个应用需要。
2. 语义稳定，属于本地 Agent 执行，而不是外部服务、存储、身份系统或传输。
3. 适合公开 API，不为单一产品扩大 API。
4. 已理解负向测试与兼容性影响。
5. 若是共享行为，需要 `spec/` 契约、向量、parity 和 SDK 影响评审。

持久 operation 存储、HTTP 认证、独立效果验证、fencing store 与 lease 过期目前都不满足。
它们继续属于应用、集成或产品责任。未来若要共享异步 operation 生命周期，应作为带 conformance
向量的 Spec profile 提案，而不是默认新增 Core API。

## 引用测试

写明层级、revision、命令与结果，例如：

- “L1：SHA ... 的 `pkg/agent` 测试”
- “L3：SHA ... 的 Go 2.5.2 发布包消费者测试”
- “L4：SHA ... 的长时操作配方；不是 Core 能力声明”
- “L5：not run；无采用数据”

不得把配方 fixture 当成 Core 功能证据，也不得把消费者安装当成采用证据。
