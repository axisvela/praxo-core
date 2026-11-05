package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"strings"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

type fixtureModel struct{ target string }

func (m fixtureModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	last := req.Messages[len(req.Messages)-1]
	if last.Role == model.RoleTool {
		return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "recorded"}}, nil
	}
	return model.Response{Message: model.Message{
		Role: model.RoleAssistant,
		ToolCalls: []model.ToolCall{{
			ID: "record-1", Name: "record", Arguments: map[string]any{"target": m.target},
		}},
	}}, nil
}

type recordTool struct{ calls int }

func (*recordTool) Name() string        { return "record" }
func (*recordTool) Description() string { return "Record a target in an in-memory counter." }

func (*recordTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name: "record", Description: "Record a target in an in-memory counter.",
		Parameters: map[string]any{
			"type": "object", "required": []string{"target"},
			"properties": map[string]any{"target": map[string]any{"type": "string"}},
		},
	}
}

func (t *recordTool) Invoke(context.Context, map[string]any) (any, error) {
	t.calls++
	return "recorded", nil
}

func runScenario(ctx context.Context, target string) (string, int, error) {
	impl := &recordTool{}
	tools := tool.NewRegistry()
	tools.Register(impl)
	ag, err := agent.New(agent.Options{
		Model: fixtureModel{target: target}, Tools: tools, MaxSteps: 3,
		AllowedTools: []string{"record"},
		Policy: policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
			switch action.Kind {
			case "model.generate":
				return policy.Decision{Allowed: true}, nil
			case "tool.invoke":
				return policy.Decision{
					Allowed: action.ToolName == "record" && action.Arguments["target"] == "public",
					Reason:  "only the public target is permitted",
				}, nil
			default:
				return policy.Decision{Reason: "unsupported action"}, nil
			}
		}),
	})
	if err != nil {
		return "", impl.calls, err
	}
	result, err := ag.Run(ctx, agent.Session{ID: "starter-" + target}, "Record the requested target.")
	if err != nil {
		return "", impl.calls, err
	}
	return result.Output, impl.calls, nil
}

func run(ctx context.Context, out io.Writer) error {
	output, calls, err := runScenario(ctx, "public")
	if err != nil || output != "recorded" || calls != 1 {
		return fmt.Errorf("allow verification failed: output=%q effects=%d error=%v", output, calls, err)
	}
	if _, err := fmt.Fprintln(out, "allow: recorded; effects=1"); err != nil {
		return err
	}
	_, calls, err = runScenario(ctx, "private")
	if err == nil || !strings.Contains(err.Error(), "tool.invoke denied") || calls != 0 {
		return fmt.Errorf("deny verification failed: effects=%d error=%v", calls, err)
	}
	_, err = fmt.Fprintln(out, "deny: policy rejected; effects=0")
	return err
}

func main() {
	if err := run(context.Background(), os.Stdout); err != nil {
		log.Fatal(err)
	}
}
