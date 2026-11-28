# 产品集成

可选的 AxisVela 产品与协议集成配方。

## NOETIVELA {#workspace-session-contract-evaluation}

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

该 Core 暴露文本内容，不暴露工具调用。需要工具调用时，应使用保留 tool-call
字段的自定义 HTTP 适配器。参见
[NOETIVELA SDK 示例](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/ecosystem-sdk/noetivela)。

## Mnemovela {#noetivela}

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

仅提供 `memory.Store` 不会注入记录；必须显式设置 `Recall: true`。其他 Core SDK
目前不做自动召回。召回内容按不可信历史数据处理，不是 system 指令；其来源和帧标签
不能提升自身指令权限。参见
[Mnemovela Core 示例](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/ecosystem-sdk/mnemovela)。

## GNOSIVELA {#mnemovela}

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
[GNOSIVELA Core 示例](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/ecosystem-sdk/gnosivela)。

## AEGIVELA 策略 {#gnosivela}

将 AEGIVELA 策略评估映射到 `policy.Hook`。

```go
hook := aegivelaadapter.Hook{
    Client: pepsdk.NewClient("https://aegivela.example.com", http.DefaultClient),
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
[AEGIVELA Core 示例](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/ecosystem-sdk/aegivela)。

## LIMENORA 网关 {#aegivela-policy}

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
[LIMENORA Core 示例](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/ecosystem-sdk/limenora)。

## Harmovela 事件 {#limenora-gateway}

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

## A2A 服务端 {#harmovela-events}

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

另见[本地 IAM 运行记录](https://github.com/axisvela/enterprise-autonomy/blob/f6297d0/examples/a2a-agent-iam-local/RUN-RECORD.md#v2-verification-update)：
已验证真实本地 IAM 服务参与的 Google ADK 直连 PRAXO-CORE A2A 调用
（`system_api`），以及独立的 AEGIVELA `serviceAgentApi` v2 `allow` 决策
（policy `v1`，后端修复提交 `3ceb44c`）。后续重新生成 protobuf 描述符（`c14b781`）后，
identity 初始化 panic 已解除；后端无缓存全量测试、vet 和 build 均通过。
未配置测试数据库时，数据库相关测试仍可能跳过。
这不代表完整 v2 A2A、实例租约校验或真实 LIMENORA 反向入口已验证；
未修改框架公开 API 或适配器版本。

## RHEOVELA 工作流 {#a2a-server}

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
[RHEOVELA Core 示例](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/ecosystem-sdk/rheovela)。
