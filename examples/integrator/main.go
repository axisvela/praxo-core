// Command integrator is a self-contained external-integrator example: it wires
// an agent with a model, tool registry, memory, policy, events, and a context
// budget without importing any product package.
package main

import (
	"context"
	"fmt"
	"log"
	"strings"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/memory"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

type scriptedModel struct {
	calls int
}

func (m *scriptedModel) Generate(_ context.Context, _ model.Request) (model.Response, error) {
	m.calls++
	if m.calls == 1 {
		return model.Response{Message: model.Message{
			Role: model.RoleAssistant,
			ToolCalls: []model.ToolCall{{
				ID:        "call-1",
				Name:      "lookup",
				Arguments: map[string]any{"key": "status"},
			}},
		}}, nil
	}
	return model.Response{Message: model.Message{
		Role:    model.RoleAssistant,
		Content: "status is green",
	}}, nil
}

type lookupTool struct{}

func (lookupTool) Name() string        { return "lookup" }
func (lookupTool) Description() string { return "Look up a key" }

func (lookupTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	return map[string]any{"key": args["key"], "value": "green"}, nil
}

func main() {
	tools := tool.NewRegistry()
	tools.Register(lookupTool{})

	ag, err := agent.New(agent.Options{
		Model:        &scriptedModel{},
		SystemPrompt: "You are an external integrator example.",
		Tools:        tools,
		Memory:       memory.NewMemoryStore(),
		Recall:       true,
		MaxSteps:     4,
		Context:      &agent.ContextBudget{MaxTokens: 4000, KeepRecent: 6},
		Policy: policy.FuncHook(func(context.Context, policy.Action) (policy.Decision, error) {
			return policy.Decision{Allowed: true}, nil
		}),
		Events: event.FuncSink(func(_ context.Context, e event.Event) error {
			fmt.Println("event:", e.Type)
			return nil
		}),
	})
	if err != nil {
		log.Fatal(err)
	}

	result, err := ag.Run(context.Background(), agent.Session{
		ID:          "demo",
		TenantID:    "demo",
		WorkspaceID: "demo",
	}, "check status")
	if err != nil {
		log.Fatal(err)
	}
	if !strings.Contains(result.Output, "green") {
		log.Fatalf("unexpected output: %q", result.Output)
	}
	fmt.Println("output:", result.Output)
}
