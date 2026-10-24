package consumer_test

import (
	"context"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

type protectedToolModel struct{}

func (protectedToolModel) Generate(context.Context, model.Request) (model.Response, error) {
	return model.Response{Message: model.Message{Role: model.RoleAssistant, ToolCalls: []model.ToolCall{{
		ID: "call-1", Name: "protected", Arguments: map[string]any{"path": "allowed"},
	}}}}, nil
}

type protectedTool struct{ calls int }

func (*protectedTool) Name() string        { return "protected" }
func (*protectedTool) Description() string { return "policy-controlled fixture" }
func (t *protectedTool) Invoke(context.Context, map[string]any) (any, error) {
	t.calls++
	return "executed", nil
}

func TestPublishedFinalToolAuthorization(t *testing.T) {
	for _, phase := range []string{"middleware", "hitl"} {
		t.Run(phase, func(t *testing.T) {
			impl := &protectedTool{}
			registry := tool.NewRegistry()
			registry.Register(impl)
			var checked []string
			ag, err := agent.New(agent.Options{
				Model: protectedToolModel{}, Tools: registry, MaxSteps: 2,
				AllowedTools: []string{"protected"},
				Policy: policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
					if action.Kind == "tool.invoke" {
						path := action.Arguments["path"].(string)
						checked = append(checked, path)
						return policy.Decision{Allowed: path == "allowed"}, nil
					}
					return policy.Decision{Allowed: true}, nil
				}),
				Middleware: []agent.Middleware{{BeforeTool: func(_ context.Context, call *agent.ToolCall) error {
					if phase == "middleware" {
						call.Call.Arguments["path"] = "blocked"
					}
					return nil
				}}},
				InterruptOn: map[string]bool{"protected": true},
				OnInterruptDecision: func(context.Context, agent.Interrupt) (agent.InterruptDecision, error) {
					if phase == "hitl" {
						return agent.InterruptDecision{Action: agent.InterruptEdit, Arguments: map[string]any{"path": "blocked"}}, nil
					}
					return agent.InterruptDecision{Action: agent.InterruptApprove}, nil
				},
			})
			if err != nil {
				t.Fatal(err)
			}
			if _, err := ag.Run(context.Background(), agent.Session{ID: "consumer-policy"}, "run"); err == nil {
				t.Fatal("changed arguments were not denied")
			}
			if impl.calls != 0 || len(checked) != 2 || checked[0] != "allowed" || checked[1] != "blocked" {
				t.Fatalf("tool calls=%d policy arguments=%v", impl.calls, checked)
			}
		})
	}
}
