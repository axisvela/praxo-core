# Harmovela 事件 Sink

这是原生 Harmovela event sink 的共享映射。它是可选适配器契约，不是新的 Core Wire
状态机，也不代表投递保证。

## 端点

`POST {baseURL}/events`，`content-type: application/json`。

`baseURL` 通常以 `/aep/api` 结尾；Go 适配器本地示例使用
`http://127.0.0.1:8790/aep/api`。

## Envelope

```json
{
  "spec_version": "0.2",
  "id": "run-123-1700000000000000000",
  "type": "tool.call",
  "source": "praxo-core",
  "created_at": "2026-11-10T07:00:00.000000000Z",
  "payload": {
    "session_id": "s1",
    "run_id": "run-123",
    "name": "echo"
  }
}
```

- `spec_version` 默认 `0.2`。
- `id` 由 run id（否则 session id）加纳秒时间戳组成。它是标识符，不是 exactly-once 证明。
- `type` 原样保留 Core 事件类型。
- `source` 默认 `praxo-core`。
- `created_at` 为 UTC RFC 3339，含纳秒。
- `payload` 为事件 data，并在存在时加入 `session_id`、`run_id`。

## Sink 行为

- 2xx 为成功；其他状态返回包含状态码与有界响应体的错误。
- Sink 不添加认证；应放在可信网络边界或产品自有认证网关之后。
- 事件 data 可能含敏感内容；调用方应先过滤。
- 远端端点应使用 HTTPS。
- Sink 不提供重试、缓冲、确认、排序或 exactly-once；这些属于集成职责。

## 基线状态

原生 sink 覆盖 Go、Python、TypeScript、Java、Rust、C#、R、Elixir、Ruby、PHP、
Lua、Nim、Perl 与 Erlang。各实现测试使用注入 transport 或 loopback fixture；未声明
真实 Harmovela 服务。

## 测试

使用注入 transport 或 loopback HTTP fixture。必须断言：请求路径、envelope 字段、
payload 合并、2xx 成功、非 2xx 错误。不能把真实 Harmovela 服务作为唯一测试。
