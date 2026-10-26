# 插件编写

本指南涵盖框架侧的运行时插件契约。签名信任、物化、SBOM/证据和更新策略归
产品（PRAXOVELA）所有。

可运行的最小 process plugin 与 host 位于
[`examples/plugin`](https://github.com/axisvela/praxo-core/tree/main/examples/plugin)。

## Manifest v1

插件附带严格的 JSON manifest。未知字段和尾随数据会被拒绝。

```json
{
  "schemaVersion": 1,
  "id": "com.example.search",
  "version": "1.0.0",
  "kind": "tool.provider.v1",
  "entrypoint": { "type": "process", "command": "./bin/search" },
  "protocol": "jsonrpc-2",
  "capabilities": ["tool.invoke"],
  "permissions": {
    "filesystem": [{ "path": "/workspace", "mode": "read" }],
    "network": [{ "host": "api.example.com", "port": 443 }],
    "env": ["SEARCH_API_KEY"]
  },
  "limits": { "memoryMB": 256, "cpuMillis": 2000, "timeoutMs": 30000, "maxInflight": 8 },
  "isolation": "process",
  "health": { "method": "health", "intervalMs": 15000 },
  "signature": { "algorithm": "ed25519", "keyId": "example-release-1" },
  "sbom": "sbom.spdx.json"
}
```

- `kind` 为 `tool.provider.v1`、`model.provider.v1`、`policy.provider.v1`、
  `memory.provider.v1` 或 `sandbox.provider.v1`。
- `entrypoint.type` 和 `isolation` 为 `process`、`wasm` 或 `container`，
  且必须匹配。
- `process` 需要 `entrypoint.command`；`wasm` 需要 `entrypoint.module`；
  `container` 需要 `entrypoint.image`。
- `permissions` 默认拒绝。文件系统模式为 `read`、`write` 或 `readwrite`。
- 在签名信任配置下，`signature` 和 `sbom` 是必需的。未签名配置是明确的
  本地开发选择。

使用以下代码解析和校验：

```go
m, err := plugin.ParseManifest(raw)
if err != nil { /* reject */ }
if err := m.ValidateTrust(plugin.TrustSigned); err != nil { /* reject */ }
```

## 进程宿主

进程宿主通过子进程的 stdio 使用 JSON-Lines。每个请求是每行一个 JSON 对象：

```json
{
  "id": "req-1",
  "version": 1,
  "plugin_id": "com.example.search",
  "service": "tool.provider",
  "method": "invoke",
  "token": "<per-process token>",
  "payload": "<opaque contract bytes>"
}
```

插件回复：

```json
{
  "id": "req-1",
  "version": 1,
  "ok": true,
  "payload": "<opaque contract bytes>"
}
```

规则：

- 在每个请求上校验 `token`。宿主默认通过 `PRAXOVELA_PLUGIN_TOKEN` 环境变量
  提供它（可通过 `process.Config.TokenEnvVar` 覆盖）；它绝不通过 argv 传递。
- 在启动期间响应 `health`。
- 收到 `cancel` 时放弃进行中的工作；在 `shutdown` 后干净退出。
- 将失败映射为 `CAPABILITY_DENIED`、`NOT_ACTIVE`、`NOT_FOUND`、
  `INVALID_REQUEST`、`TIMEOUT` 或 `INTERNAL`。
- 不要将协议帧写入 stderr；stderr 会被捕获并有界。

宿主侧配置（`process.Config`）包括 `PluginID`、`Provider`、`Sink`、
`RequireEvidence`、`Path`、`Args`、`Dir`、`Env`、`Token`、`TokenEnvVar`、
超时、帧大小限制、`Limits` 和 `RequireLimits`。生产调用方应设置
`RequireLimits` 和 `RequireEvidence`。

## WASM 宿主

WASM guest 必须导出：

- `memory`
- `alloc(len i32) i32`
- `prax_request(ptr i32, len i32)`

并导入 `env.prax_respond(ptr i32, len i32)`。每次 `prax_request` 必须恰好
交付一个响应帧。宿主使用 `MaxMemoryPages` 限制线性内存，并在调用上下文结束
时终止 guest。v1 中不强制 CPU fuel。

## 一致性测试套件

实现 `tck.HostFactory` / `tck.HostHarness`：

```go
type HostHarness interface {
    Start(context.Context) error
    Stop(context.Context) error
    Invoke(ctx context.Context, service, method string, payload []byte) ([]byte, error)
    PluginID() string
    Contract() plugin.Contract
    Methods() tck.HostMethods
}
```

`HostMethods` 命名测试夹具方法：

- `Echo`：原样返回载荷。
- `Block`：等待上下文完成。
- `Denied`：返回 `CAPABILITY_DENIED`。
- `Timeout`：限制阻塞调用的时间。

然后运行：

```go
if err := tck.CheckLifecycle(plugin.NewLifecycle()); err != nil { /* fail */ }
if err := tck.CheckRegistry(registry); err != nil { /* fail */ }
if err := tck.CheckHost(factory); err != nil { /* fail */ }
```

`CheckHost` 覆盖分帧、超时、取消、能力拒绝和非活跃门禁。每个检查都会从
工厂获取一个全新的宿主。

## 信任边界

核心宿主启动已经验证的载荷。产品必须在构造宿主之前验证描述符签名、SBOM、
身份、ABI 和兼容性。`pkg/plugin` 从不解析需求，也从不调用信任存储。
