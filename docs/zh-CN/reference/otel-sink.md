# OpenTelemetry 事件 Sink

这是原生 OpenTelemetry 事件 sink 的共享映射。它属于可选适配器契约，不是新的
Core wire 状态机、采样器、Collector 或投递保证。

## 边界

- 每个 Core Event 映射为一个 OTLP span，名称为 `praxo.<event.type>`。
- Sink 可以使用 OpenTelemetry SDK，也可以通过调用方提供的 transport 发送
  OTLP/HTTP JSON。Core 不依赖 OpenTelemetry SDK。
- Event data 默认不导出；调用方可以显式 allowlist 单个 key。
- Session 和 run 标识存在时会导出；应使用不透明标识，并限制遥测后端访问。

## OTLP/HTTP JSON

使用 `POST {endpoint}`，`content-type: application/json`。典型端点为
`http://127.0.0.1:4318/v1/traces`。

```json
{
  "resourceSpans": [
    {
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "praxo-core"}}
        ]
      },
      "scopeSpans": [
        {
          "scope": {"name": "praxo-core"},
          "spans": [
            {
              "traceId": "0123456789abcdef0123456789abcdef",
              "spanId": "0123456789abcdef",
              "name": "praxo.tool.call",
              "kind": 1,
              "startTimeUnixNano": "1794294000000000000",
              "endTimeUnixNano": "1794294000000000000",
              "attributes": [
                {"key": "praxo.event.type", "value": {"stringValue": "tool.call"}},
                {"key": "praxo.session.id", "value": {"stringValue": "s1"}},
                {"key": "praxo.run.id", "value": {"stringValue": "run-123"}},
                {"key": "praxo.event.at", "value": {"stringValue": "2026-11-10T07:00:00Z"}}
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

- 标识符使用十六进制字符串：`traceId` 16 字节，`spanId` 8 字节。
- `startTimeUnixNano` 和 `endTimeUnixNano` 是 Unix 纳秒。一个 span 表示一个
  event，不表示完整 run 的持续时间。
- 空 session/run 标识和零时间戳会被省略。
- 允许的 data key 会变成 `praxo.event.data.<key>` 字符串属性。选择 key 不会
  自动脱敏。

## Transport Seam

没有 OpenTelemetry SDK 的实现可以接受调用方提供的 transport，参数包含 HTTP
method、URL、headers 和 body。Transport 返回状态码和有界响应 body。2xx 为成功；
其他状态返回包含状态码和有界 body 的错误。

## 基线状态

权威的逐语言列表见 [adapter status](../languages/adapter-status.md)。
Go 通过 `adapters/otel` 和 `trace.Tracer` 映射事件。Python、TypeScript、Java、
Rust、R、C#、Ruby、PHP、Elixir、Lua、C、C++、Fortran、Haskell、OCaml、Swift、
Dart、Perl、D、Delphi/Free Pascal、Objective-C、Nim、V、Zig、Julia、
MATLAB/Octave、Erlang 和 COBOL 提供基于调用方 OTLP/HTTP transport 的
transport-seam sink。其他实现尚无 in-tree OTel sink。当前所有实现只使用确定性
fixture 或内存 exporter 测试；不宣称 live Collector、采样策略或厂商后端。

## 测试

使用内存 exporter 或注入 transport。必需断言包括：span 名称、trace/span 标识
形状、起止时间、session/run 属性、默认 data 排除、显式 allowlist、2xx 成功和
非 2xx 错误。
