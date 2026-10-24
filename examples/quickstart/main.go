package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/axisvela/praxo-core/v2/adapters/openaicompat"
	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

type timeTool struct{}

func (timeTool) Name() string { return "get_time" }

func (timeTool) Description() string { return "Return the current local time in RFC3339 format." }

func (timeTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "get_time",
		Description: "Return the current local time in RFC3339 format.",
		Parameters: map[string]any{
			"type":       "object",
			"properties": map[string]any{},
		},
	}
}

func (timeTool) Invoke(context.Context, map[string]any) (any, error) {
	return time.Now().Format(time.RFC3339), nil
}

func main() {
	baseURL := envOr("PRAXO_BASE_URL", "http://localhost:11434/v1")
	modelName := envOr("PRAXO_MODEL", "llama3.2")
	prompt := envOr("PRAXO_PROMPT", "What time is it? Use the get_time tool.")

	tools := tool.NewRegistry()
	tools.Register(timeTool{})

	streamed := false
	ag, err := agent.New(agent.Options{
		Model: openaicompat.Adapter{
			BaseURL: baseURL,
			APIKey:  os.Getenv("PRAXO_API_KEY"),
			Model:   modelName,
			HTTP:    &http.Client{Timeout: 120 * time.Second},
		},
		SystemPrompt: "You are a concise assistant. Use tools when they help.",
		Tools:        tools,
		MaxSteps:     4,
		Events: event.FuncSink(func(_ context.Context, ev event.Event) error {
			fmt.Fprintln(os.Stderr, "event:", ev.Type)
			return nil
		}),
		OnDelta: func(delta string) {
			streamed = true
			fmt.Print(delta)
		},
		Policy: policy.FuncHook(func(context.Context, policy.Action) (policy.Decision, error) {
			return policy.Decision{Allowed: true}, nil
		}),
	})
	if err != nil {
		log.Fatal(err)
	}
	result, err := ag.Run(context.Background(), agent.Session{
		ID:          "quickstart",
		TenantID:    "local",
		WorkspaceID: "default",
	}, prompt)
	if err != nil {
		log.Fatalf("quickstart: %v\n\nConfigure PRAXO_BASE_URL (current %s), PRAXO_MODEL (current %s), and PRAXO_API_KEY as needed.", err, baseURL, modelName)
	}
	if streamed {
		fmt.Println()
		return
	}
	fmt.Println(result.Output)
}

func envOr(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
