# MCP Client 边界

这是 Core 实现的最小 MCP client 边界。Go 参考实现使用 `adapters/mcp` 与官方 Go SDK；
其他实现可使用原生 JSON-RPC client 或许可证兼容的 MCP client 库。

## 传输

- stdio JSON-RPC 2.0，每行一个 JSON 对象。
- 请求带唯一 `id`；响应回显该 id。
- 通知不带 `id`。
- Client 负责子进程生命周期，成功、错误、取消时都必须关闭。

## 握手

1. 发送 `initialize`，包含 `protocolVersion`、`capabilities: {}`、`clientInfo: {name, version}`。
2. 要求成功结果和非空协商协议版本。
3. 发送 `notifications/initialized`。
4. 失败时执行已协商的 shutdown/exit 并终止子进程。

## 工具

- `tools/list` 接受可选 `cursor`。
- 按 `nextCursor` 分页直到缺失。
- 拒绝重复 cursor 与重复工具名。
- 保留 `inputSchema` 作为 model-facing 参数 schema。
- `tools/call` 发送 `{name, arguments}`。
- 有 structured content 时返回结构化内容；否则返回文本字符串或有序文本块列表。
- 工具失败是错误结果，不是空成功。

## 超时与取消

- 为 initialize、list、call 设置调用方可配置超时。
- 调用方取消在途请求时发送 `notifications/cancelled`。
- 不得把本地取消写成远端工作已停止的证明。

## 基线状态

原生 stdio client 目前覆盖 Go（`adapters/mcp`）、Python（`praxo.adapters.mcp`）与
TypeScript（`src/adapters/mcp.ts`）。Python/TypeScript 是确定性 fake-server 试点，
不是真实服务或远端 transport 证据。其他实现未声明。

## 安全与范围

- MCP 认证属于 client session 或 transport。
- 该边界不代表托管 MCP 服务、schema 晋级、沙箱隔离或生产认证。
- 工具输出是不可信内容；policy 与 tool authorization 仍然生效。
- 不得重写 tool-call markup 或绕过 Core policy 接缝。

## 测试

使用 stdio fake MCP server。必须断言：initialize 握手、分页、重复 cursor 拒绝、重复名称
拒绝、成功调用、错误调用、进程清理。真实 MCP 服务是集成证据，不能作为唯一测试。
