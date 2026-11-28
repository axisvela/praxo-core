# 工作区与策略

Sandbox、策略与受治理工作区配方。

## Sandbox 与策略 {#sandbox-and-policy}

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
[sandbox 示例](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/sandbox)。

## Governed Workspace Demo {#governed-workspace-demo}

governed workspace demo 是无需 API key 的确定性路径，演示只读工具、写入审批、
拒绝、策略拒绝和事件 trace。它使用脚本化模型，不声称真实模型行为。

```bash
GOWORK=off go run ./language/go/examples/governed-workspace -mode read
GOWORK=off go run ./language/go/examples/governed-workspace -mode write
GOWORK=off go run ./language/go/examples/governed-workspace -mode deny
GOWORK=off go run ./language/go/examples/governed-workspace -mode escape
```

参见
[governed workspace demo](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/governed-workspace)。

## Reference Workspace Agent {#reference-workspace-agent}

reference app 组合了 OpenAI 兼容适配器、受限 VFS 工具、策略、记忆、事件和
上下文预算。

```bash
GOWORK=off go run ./language/go/examples/reference -workspace ./workspace
```

示例策略只允许 `model.generate` 和 `fs.*` 工具调用，VFS 后端将路径限制在
workspace 内。参见
[reference app](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/reference)。
