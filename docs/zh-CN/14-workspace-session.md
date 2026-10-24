# Workspace 与 Session 契约（评估）

**状态：** 评估草案，2026-10-24。本页不是 API 承诺。它记录问题、候选形态、
提供商问题，以及把契约提升到 `pkg/` 的验收标准。

## 为什么评估

PRAXO-CORE 目前有两个独立接缝：

| 接缝 | 契约 | 当前用途 |
| --- | --- | --- |
| 虚拟文件系统 | `vfs.Backend` | 读、写、列目录、glob、grep、删除 |
| 命令执行 | `vfs.Executor` | VFS backend 上的可选 shell 执行 |
| 沙箱 | `sandbox.Sandbox` | 一次 `Run(ctx, Spec, command)` 调用 |
| 解释器 | `sandbox.Interpreter` | 可选的进程内脚本求值 |

这对无状态执行和本地工作区已经足够。E2B、OpenSandbox、CubeSandbox 等远程
沙箱服务增加了生命周期：

```text
create or attach -> execute -> upload/download -> pause/resume -> close
```

Deep Agents 把它建模为可插拔 backend 协议，并让 sandbox backend 增加执行能力。
PRAXO-CORE 应学习这种形态，但不复制 LangGraph state、图运行时或提供商 SDK。

缺口不是“接入更多 sandbox”，而是能对至少两个实现验证的、提供商中立的 session
契约。

## 需求

1. **有状态生命周期。** 创建或 attach、执行多次命令、传输文件并关闭。
   Pause、resume、snapshot 是可选能力，不是必需方法。
2. **组合优先。** Session 应暴露现有 `sandbox.Sandbox` 和 `vfs.Backend` 行为，
   而不是重新定义它们。
3. **不泄漏提供商。** 公共契约不包含 E2B、OpenSandbox 或 CubeSandbox 的类型、
   凭据、端点或控制平面字段。
4. **认证与租户由调用方拥有。** 产品通过适配器配置传入凭据和租户上下文，
   核心契约不保存它们。
5. **Context 与超时。** 每个操作接收 `context.Context`；超时和取消可观察，
   且不泄漏 session。
6. **错误映射。** 缺失 session、不支持的能力、策略失败和提供商错误可区分。
7. **无控制平面。** 池化、镜像目录、快照、网络策略、配额、计费、多租户隔离、
   审计和 SLA 由产品拥有。
8. **一致性。** 共享检查套件必须能对 fake 和至少两个真实提供商运行，之后才能
   提升到核心。

## 候选形态

以下是设计草图，不是导出 API。

```go
package workspace

type Spec struct {
    Image     string
    WorkDir   string
    Env       map[string]string
    Timeout   time.Duration
    Metadata  map[string]string
}

type Session interface {
    ID() string
    sandbox.Sandbox
    vfs.Backend
    Upload(ctx context.Context, path string, data []byte) error
    Download(ctx context.Context, path string) ([]byte, error)
    Close(ctx context.Context) error
}

type Provider interface {
    Create(ctx context.Context, spec Spec) (Session, error)
    Attach(ctx context.Context, id string) (Session, error)
}

type Pauser interface {
    Pause(ctx context.Context) error
    Resume(ctx context.Context) error
}
```

需要评估的替代方案：

- **嵌入 vs 组合。** 嵌入 `sandbox.Sandbox` 和 `vfs.Backend` 更方便，但要求
  每个 session 同时支持两者。返回 `Files()` 和 `Sandbox()` 访问器更灵活，
  但使用体验较差。
- **可选能力。** Pause/resume 应是独立接口，而不是运行时失败的方法。快照和
  端口访问同理。
- **Session 标识。** 决定 `ID()` 是提供商本地、全局唯一还是不透明。产品不得
  解析它。
- **Attach 语义。** Attach 可能不支持、可能要求相同调用方身份，或用于恢复
  暂停的 session。这些是不同能力。
- **文件传输。** 对于 VFS 操作昂贵或异步的提供商，upload/download 可能是
  必需能力。不要假设它们成本很低。
- **资源与网络策略。** 在两个提供商证明有稳定共同子集前，留在适配器配置中。

## 提供商评估

下表是检查清单，不是对当前提供商行为或许可证的断言。请根据上游文档和适配器
spike 填写。

| 问题 | E2B | OpenSandbox | CubeSandbox |
| --- | --- | --- | --- |
| Go SDK 或稳定 HTTP API | 待确认 | 待确认 | 待确认 |
| Create / attach / close | 待确认 | 待确认 | 待确认 |
| 重复命令执行 | 待确认 | 待确认 | 待确认 |
| Upload / download | 待确认 | 待确认 | 待确认 |
| Pause / resume | 待确认 | 待确认 | 待确认 |
| Snapshot 或模板 | 待确认 | 待确认 | 待确认 |
| 网络与端口策略 | 待确认 | 待确认 | 待确认 |
| 超时与取消 | 待确认 | 待确认 | 待确认 |
| 错误分类 | 待确认 | 待确认 | 待确认 |
| 认证与租户模型 | 待确认 | 待确认 | 待确认 |
| 许可证兼容性 | 待确认 | 待确认 | 待确认 |
| 控制平面功能 | 待确认 | 待确认 | 待确认 |

适配器 spike 必须记录测试版本、端点类型、许可证，以及哪些能力不可用。

## 原型计划

1. 在核心之外增加两个适配器模块，例如 `adapters/workspace/e2b` 和
   `adapters/workspace/opensandbox`。各自独立 `go.mod` 和 tag。
2. 使用调用方提供的凭据实现 create/attach、execute、upload/download 和 close。
   不把提供商 SDK 加入核心模块。
3. 增加一个实现相同契约的内存 fake，用于离线测试。
4. 对 fake 和两个适配器运行同一套 conformance 检查。实网提供商测试必须按需
   运行，不能进入默认 CI。
5. 记录每个不匹配的能力、每个提供商专用字段，以及无法清晰映射的错误。
6. 只有完成上述步骤后，才提议加法式 `pkg/` 契约。现有 `pkg/vfs` 和
   `pkg/sandbox` 声明保持不变。

## 提升标准

只有满足以下条件，workspace/session 契约才可进入 `pkg/`：

- 两个提供商实现它，且公共契约没有提供商专用字段；
- fake 和两个适配器通过同一套一致性检查；
- 取消和超时不会泄漏 session；
- 错误映射有文档和测试；
- 核心模块仍不依赖提供商 SDK；
- API 是加法式的，不改变 `vfs.Backend`、`vfs.Executor` 或 `sandbox.Sandbox`；
- 已编写兼容与迁移说明。

在此之前，契约只存在于适配器或评估模块中。当前 spike 位于
[`adapters/workspace`](https://github.com/axisvela/praxo-core/tree/main/adapters/workspace)，
包含候选契约、内存 fake 和一致性检查。

## 非目标

- Sandbox 控制平面、调度器、热池、镜像仓库或计费系统。
- 图运行时或持久工作流引擎。
- 把提供商专用字段放入 `pkg/...`。
- 声称 sandbox 接口提供 OS 级隔离。隔离由提供商或产品提供。

## 待解决问题

- `Session` 应嵌入 `vfs.Backend` 和 `sandbox.Sandbox`，还是通过访问器暴露？
- `Attach` 是核心生命周期操作，还是提供商能力？
- Pause/resume/snapshot 是否共享一个可选能力接口？
- 提供商侧 session ID 如何跨租户和区域隔离？
- 最小可移植错误分类是什么？
- 哪些文件传输语义可以安全标准化：覆盖、原子写、目录上传，还是都不？
- Workspace session 是否需要 lease 或 heartbeat，还是由产品拥有？

## 参考

- [Deep Agents backends](https://docs.langchain.com/oss/python/deepagents/backends)
- [Sandbox 安全边界](08-security.md)
- [Containment review](../containment-review.md)
- [事件 schema](event-schema.md)
