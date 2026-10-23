# Recipes

常用集成的可复制起点。完整可运行示例位于
[`examples/`](https://github.com/axisvela/praxo-core/tree/main/examples)。

## OpenAI 兼容模型

适用于 Ollama、vLLM 和托管的 OpenAI 兼容 API。适配器只使用标准库。

```go
adapter := openaicompat.Adapter{
    BaseURL: "http://localhost:11434/v1",
    Model:   "llama3.2",
}

ag, err := agent.New(agent.Options{
    Model:    adapter,
    MaxSteps: 4,
})
```

该适配器也实现 `model.StreamingModel`。设置 `agent.Options.OnDelta` 可接收流式
文本；工具调用增量会聚合到最终响应中。支持的端点可设置 `IncludeUsage: true`
获取流式 token 用量。

参见 [快速开始](quickstart.md) 和
[OpenAI 兼容适配器](https://github.com/axisvela/praxo-core/tree/main/adapters/openaicompat)。

## MCP 工具

使用可选的 MCP 模块，通过 `tool.Gateway` 暴露 MCP 工具。

```go
client := mcpsdk.NewClient(&mcpsdk.Implementation{Name: "agent", Version: "v0.1.0"}, nil)
session, err := client.Connect(ctx, &mcpsdk.CommandTransport{
    Command: exec.Command("my-mcp-server"),
}, nil)
if err != nil {
    return err
}
defer session.Close()

tools, err := mcpadapter.NewTools(ctx, session)
if err != nil {
    return err
}
for _, item := range tools {
    registry.Register(item)
}
```

MCP 认证绑定在客户端会话上。`NewTools` 通过 `tool.SpecProvider` 保留每个
server 的输入 schema；底层 `NewGateway`/`tool.NewGatewayTools` 路径只携带名称
和描述。若直接使用 `NewGateway`，服务器工具变化后调用 `Refresh`。应将每个
MCP server 视为不可信代码：与其他工具使用相同的策略、sandbox 和凭据边界，
不要传递环境中的隐式密钥。

同一模块也暴露 resources 和 prompts：

```go
resources, err := mcpadapter.ListResources(ctx, session)
contents, err := mcpadapter.ReadResource(ctx, session, "embedded:info")
prompts, err := mcpadapter.ListPrompts(ctx, session)
messages, err := mcpadapter.GetPrompt(ctx, session, "greet", map[string]string{
    "name": "Ada",
})
```

参见
[MCP 适配器](https://github.com/axisvela/praxo-core/tree/main/adapters/mcp)。

## Anthropic Messages

使用原生适配器连接 Anthropic 模型，支持工具调用、usage 和 SSE 流式输出。

```go
adapter := anthropic.Adapter{
    APIKey:    os.Getenv("ANTHROPIC_API_KEY"),
    Model:     "claude-sonnet-4-5",
    MaxTokens: 1024,
}

ag, err := agent.New(agent.Options{
    Model:    adapter,
    MaxSteps: 4,
})
```

参见
[Anthropic 适配器](https://github.com/axisvela/praxo-core/tree/main/adapters/anthropic)。

## Gemini generateContent

使用原生适配器连接 Gemini 模型，支持 function call、usage 和 SSE 流式输出。

```go
adapter := gemini.Adapter{
    APIKey:    os.Getenv("GEMINI_API_KEY"),
    Model:     "gemini-2.5-pro",
    MaxTokens: 1024,
}

ag, err := agent.New(agent.Options{
    Model:    adapter,
    MaxSteps: 4,
})
```

参见
[Gemini 适配器](https://github.com/axisvela/praxo-core/tree/main/adapters/gemini)。

## OpenTelemetry 事件

使用可选的 OpenTelemetry 模块将生命周期事件转换为 span。

```go
provider := sdktrace.NewTracerProvider(
    sdktrace.WithBatcher(exporter),
)
defer provider.Shutdown(ctx)

ag, err := agent.New(agent.Options{
    Model:  modelAdapter,
    Events: otelsink.New(provider),
})
```

每个事件会成为 `praxo.<event.type>` span，并带有会话、运行和时间戳属性。
适配器 v0.2.0 默认排除事件数据，可通过 `AllowedDataKeys` 选择经过审查的字段。
已发布的 v0.1.0 会导出全部事件数据，需在调用 `Emit` 前自行过滤。参见
[OpenTelemetry Sink](https://github.com/axisvela/praxo-core/tree/main/adapters/otel)。

## NOETIVELA

NOETIVELA 是 AxisVela 的推理基础设施。将其受治理 Chat API 包装为
`model.Model` 适配器。

```go
adapter := noetivelaadapter.Adapter{
    Client: sdk.New("http://localhost:1826"),
    Policy: "legal-confidential-v2",
    ContractFunc: func(model.Request) *sdk.Contract {
        return &sdk.Contract{
            Task:     "status_lookup",
            Modality: []string{"text"},
        }
    },
}
```

该 SDK 暴露文本内容，不暴露工具调用。需要工具调用时，应使用保留 tool-call
字段的自定义 HTTP 适配器。参见
[NOETIVELA SDK 示例](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/noetivela)。

## Mnemovela

Mnemovela 是 Agent Cognition Runtime。其 JSON-RPC 传输可支撑 `memory.Store`。

```go
transport := jsonrpc.New("http://localhost:8080")
store := mnemovelaadapter.Store{
    Client: mnemovela.New(transport),
    Branch: "main",
}

ag, err := agent.New(agent.Options{
    Model:  modelAdapter,
    Memory: store,
    Recall: true,
})
```

参见
[Mnemovela SDK 示例](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/mnemovela)。

## GNOSIVELA

GNOSIVELA grounding 映射到 `retriever.Retriever`。

```go
adapter := gnosivelaadapter.Retriever{
    Client:    gnosivela.New("http://localhost:8080"),
    Principal: "user:demo",
    Purpose:   "status_lookup",
    Budget:    1200,
}

documents, err := adapter.Retrieve(ctx, "current status", 8)
```

GNOSIVELA 尚未为该模块路径发布 `v3` semver 标签；示例模块固定 `master` 的
pseudo-version。参见
[GNOSIVELA SDK 示例](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/gnosivela)。

## AEGIVELA 策略

将 AEGIVELA 策略评估映射到 `policy.Hook`。

```go
hook := aegivelaadapter.Hook{
    Client: pepsdk.NewClient("https://aegivela.internal:1886", http.DefaultClient),
    Route: pepsdk.Route{
        Audience:  "agent",
        Action:    "tool:invoke",
        Scope:     []string{"tool:invoke"},
        Kind:      "tool",
        Reference: "lookup",
    },
    Input: pepsdk.AuthorizationInput{
        Mode:              pepsdk.ModeSystemAPI,
        WorkloadAssertion: "...",
    },
}
```

Hook 仅在结果精确为 `allow` 时放行，其他结果一律拒绝。`WorkloadAssertion`
应在运行时从密钥管理系统读取，不要硬编码；`Route` 值应保持静态。参见
[AEGIVELA SDK 示例](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/aegivela)。

## LIMENORA 网关

将工具名映射为受治理的出站请求，并通过 LIMENORA 网络网关发送。

```go
gateway := limenoraadapter.Gateway{
    Client: proxyEgress,
    Tools: map[string]limenoraadapter.Route{
        "lookup": {
            URL:         "https://api.example.com/status",
            Method:      "POST",
            Description: "Look up status",
        },
    },
    Ctx: sdk.AuthzContext{
        TenantID:    "acme",
        WorkspaceID: "default",
        ActorID:     "agent-1",
    },
}
```

Route 应保持静态并加入允许列表。不要从模型输出推导 `URL`、`Method` 或请求头；
出站策略由 LIMENORA 执行。参见
[LIMENORA SDK 示例](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/limenora)。

## Harmovela 事件

通过 `event.Sink` 将生命周期事件发布到 Harmovela HTTP API。

```go
sink := harmovela.Sink{
    BaseURL: "http://127.0.0.1:8790/aep/api",
    Source:  "praxo-core",
}

ag, err := agent.New(agent.Options{
    Model:  modelAdapter,
    Events: sink,
})
```

Sink 会发送 `spec_version`、`id`、`type`、`source`、`created_at`，以及包含
session、run 和事件数据的 payload。发送前应清除或省略密钥、凭据和 PII，或改用
强制脱敏的事件 Sink。参见
[Harmovela 适配器](https://github.com/axisvela/praxo-core/tree/main/adapters/harmovela)。

## A2A 服务端

将 PRAXO-CORE Agent 暴露为 A2A 服务端 Executor。

```go
executor := a2aadapter.Executor{Agent: ag}
handler := a2asrv.NewHandler(executor)

mux := http.NewServeMux()
mux.Handle("/invoke", a2asrv.NewJSONRPCHandler(handler))
```

默认将 A2A `ContextID` 映射为会话 ID；可通过 `Executor.Session` 自定义映射。
[Google ADK Go 订单取消示例](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-adk-order-cancellation)
使用外部 A2A consumer 通过 agent card 发现此服务端，并经 JSON-RPC 调用。它以
确定性 fixture 覆盖批准、业务拒绝、远端失败、超时、可选 bearer 认证、双进程
loopback 运行、并发 consumer、loopback TLS 终止和跨来源 card 拒绝；不代表已验证
部署远端 peer、外部 gRPC、部署 TLS/身份或部署吞吐/SLO。`enterprise-autonomy`
仓库还提供
[直连](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-agent-iam/direct)
和 [LIMENORA 前置](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-agent-iam/limenora)
的 Agent IAM 合同示例，组合 NOMIVELA、EIDOVELA、AEGIVELA、Google ADK 与
PRAXO-CORE。参见
[A2A 适配器](https://github.com/axisvela/praxo-core/tree/main/adapters/a2a)。

## RHEOVELA 工作流

将 Agent 会话映射为 RHEOVELA 工作流实例。RHEOVELA 拥有图与子图执行；
PRAXO-CORE 提供 Agent 节点/会话边界。

```go
runner := rheovelaadapter.Runner{
    Client:    rheovela.NewClient("http://127.0.0.1:8080"),
    Workflow:  "agent",
    ProjectID: "proj",
    Actor:     "agent-1",
}

instance, err := runner.Start(ctx, session)
err = runner.Step(ctx, instance.InstanceID, "advance", "review")
audit, err := runner.Audit(ctx, instance.InstanceID)
```

参见
[RHEOVELA SDK 示例](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/rheovela)。

## Sandbox 与策略

执行前先授权，并将高风险命令放在 `sandbox.Sandbox` 之后。

```go
func commandArgs(value any) ([]string, bool) {
    switch v := value.(type) {
    case []string:
        return v, true
    case []any:
        out := make([]string, len(v))
        for i, item := range v {
            text, ok := item.(string)
            if !ok {
                return nil, false
            }
            out[i] = text
        }
        return out, true
    default:
        return nil, false
    }
}

command := []string{"go", "version"}

hook := policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
    requested, ok := commandArgs(action.Arguments["command"])
    if action.ToolName != "exec" || !ok || len(requested) != 2 ||
        requested[0] != "go" || requested[1] != "version" {
        return policy.Decision{Allowed: false, Reason: "command is not allowlisted"}, nil
    }
    return policy.Decision{Allowed: true}, nil
})

decision, err := hook.Authorize(ctx, policy.Action{
    Kind:      "sandbox",
    ToolName:  "exec",
    Arguments: map[string]any{"command": command},
})
if err != nil {
    return err
}
if !decision.Allowed {
    return fmt.Errorf("sandbox: %s", decision.Reason)
}
result, err := runner.Run(ctx, sandbox.Spec{Timeout: 5 * time.Second}, command)
```

授权与执行必须使用同一条命令。`sandbox.Sandbox` 是接口：该示例对宿主命令执行做
策略门控，但不提供 OS 级隔离。允许列表应保持静态，不要从模型输出构建。参见
[sandbox 示例](https://github.com/axisvela/praxo-core/tree/main/examples/sandbox)。

## Reference Workspace Agent

reference app 组合了 OpenAI 兼容适配器、受限 VFS 工具、策略、记忆、事件和
上下文预算。

```bash
GOWORK=off go run ./examples/reference -workspace ./workspace
```

示例策略只允许 `model.generate` 和 `fs.*` 工具调用，VFS 后端将路径限制在
workspace 内。参见
[reference app](https://github.com/axisvela/praxo-core/tree/main/examples/reference)。
