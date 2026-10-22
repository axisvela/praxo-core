package main

import (
	"context"
	"fmt"
	"log"
	"strings"

	"github.com/axisvela/praxo-core/v2/examples/ecosystem"
	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/memory"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

func main() {
	calls := 0
	noetivela := ecosystem.Noetivela{
		ContractFunc: func(_ model.Request) ecosystem.InferenceContract {
			return ecosystem.InferenceContract{
				Task:           "status_lookup",
				Modality:       []string{"text"},
				AllowedRegions: []string{"sg"},
				DataClass:      "internal",
			}
		},
		ChatFunc: func(_ context.Context, contract ecosystem.InferenceContract, _ []model.Message) (model.Response, error) {
			if contract.Task != "status_lookup" {
				return model.Response{}, fmt.Errorf("unexpected contract task %q", contract.Task)
			}
			calls++
			if calls == 1 {
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
		},
	}

	records := make([]memory.Record, 0, 4)
	memoryAdapter := ecosystem.Memory{
		PutFunc: func(_ context.Context, _ string, record memory.Record) error {
			records = append(records, record)
			return nil
		},
		SearchFunc: func(_ context.Context, _ string, _ string, _ int) ([]memory.Record, error) {
			return records, nil
		},
	}

	gateway := ecosystem.Gateway{
		ListToolsFunc: func() []tool.GatewayInfo {
			return []tool.GatewayInfo{{Name: "lookup", Description: "Look up a key"}}
		},
		ExecuteFunc: func(_ context.Context, name string, input map[string]any, _ string) (any, error) {
			if name != "lookup" {
				return nil, fmt.Errorf("unknown tool %q", name)
			}
			return map[string]any{"key": input["key"], "value": "green"}, nil
		},
	}
	tools := tool.NewRegistry()
	for _, gatewayTool := range tool.NewGatewayTools(gateway) {
		tools.Register(gatewayTool)
	}

	ag, err := agent.New(agent.Options{
		Model:        noetivela,
		SystemPrompt: "Use the lookup tool when status is requested.",
		Tools:        tools,
		Memory:       memoryAdapter,
		Recall:       true,
		MaxSteps:     4,
		Events: ecosystem.Events{EmitFunc: func(_ context.Context, ev event.Event) error {
			fmt.Println("event:", ev.Type)
			return nil
		}},
		Policy: ecosystem.Policy{AuthorizeFunc: func(_ context.Context, _ policy.Action) (policy.Decision, error) {
			return policy.Decision{Allowed: true}, nil
		}},
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
	if len(records) == 0 {
		log.Fatal("memory adapter did not receive a record")
	}
	fmt.Println("output:", result.Output)
}
