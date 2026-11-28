# Workspace And Policy

Sandbox, policy, and governed workspace recipes.

## Sandbox and Policy {#sandbox-and-policy}

Authorize before execution and keep high-risk commands behind
`sandbox.Sandbox`.

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

Pass the same command to authorization and execution. `sandbox.Sandbox` is an
interface: this example gates host execution but does not provide OS-level
isolation. Keep the allowlist static and do not build it from model output. See
the
[sandbox example](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/sandbox).

## Governed Workspace Demo {#governed-workspace-demo}

The governed workspace demo is a deterministic, no-API-key path through
read-only tools, write approval, denial, and policy rejection with an event
trace. It uses a scripted model and does not claim real model behavior.

```bash
GOWORK=off go run ./language/go/examples/governed-workspace -mode read
GOWORK=off go run ./language/go/examples/governed-workspace -mode write
GOWORK=off go run ./language/go/examples/governed-workspace -mode deny
GOWORK=off go run ./language/go/examples/governed-workspace -mode escape
```

See the
[governed workspace demo](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/governed-workspace).

## Reference Workspace Agent {#reference-workspace-agent}

The reference app combines the OpenAI-compatible adapter, confined VFS tools,
policy, memory, events, and a context budget.

```bash
GOWORK=off go run ./language/go/examples/reference -workspace ./workspace
```

The example policy allows only `model.generate` and `fs.*` tool calls, and the
VFS backend confines paths to the workspace. See the
[reference app](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/reference).
