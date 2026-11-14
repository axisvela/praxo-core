package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/axisvela/praxo-core/v2/adapters/openaicompat"
	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

type timeTool struct{}

func (timeTool) Name() string { return "get_time" }

func (timeTool) Description() string {
	return "Return the current time in RFC3339 format for the requested zone."
}

func (timeTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "get_time",
		Description: "Return the current time in RFC3339 format for the requested zone.",
		Parameters: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"zone": map[string]any{
					"type":        "string",
					"enum":        []string{"utc", "local"},
					"description": "utc or local; defaults to utc",
				},
			},
		},
	}
}

func (timeTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	if zone, _ := args["zone"].(string); zone == "local" {
		return time.Now().Format(time.RFC3339), nil
	}
	return time.Now().UTC().Format(time.RFC3339), nil
}

func main() {
	if err := run(context.Background(), os.Stdout); err != nil {
		log.Fatal(err)
	}
}

func run(ctx context.Context, out io.Writer) error {
	baseURL := envOr("PRAXO_BASE_URL", "http://localhost:11434/v1")
	modelName := envOr("PRAXO_MODEL", "llama3.2")
	prompt := envOr("PRAXO_PROMPT", "What time is it? Use get_time with zone set to utc and reply with the time.")

	tools := tool.NewRegistry()
	tools.Register(timeTool{})

	agentInstance, err := agent.New(agent.Options{
		Model: openaicompat.Adapter{
			BaseURL: baseURL,
			APIKey:  os.Getenv("PRAXO_API_KEY"),
			Model:   modelName,
			HTTP:    &http.Client{Timeout: 120 * time.Second},
		},
		SystemPrompt: "You are a concise assistant. Use the provided tools when they help.",
		Tools:        tools,
		MaxSteps:     4,
		AllowedTools: []string{"get_time"},
		Policy: policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
			switch action.Kind {
			case "model.generate":
				return policy.Decision{Allowed: true}, nil
			case "tool.invoke":
				return policy.Decision{
					Allowed: action.ToolName == "get_time",
					Reason:  "only get_time is permitted",
				}, nil
			default:
				return policy.Decision{Reason: "unsupported action"}, nil
			}
		}),
	})
	if err != nil {
		return err
	}

	result, err := agentInstance.Run(ctx, agent.Session{
		ID:          "live-model",
		TenantID:    "local",
		WorkspaceID: "default",
	}, prompt)
	if err != nil {
		return fmt.Errorf("live model run failed: %w\n\nCheck PRAXO_BASE_URL (%s), PRAXO_MODEL (%s), and PRAXO_API_KEY", err, baseURL, modelName)
	}
	fmt.Fprintln(out, result.Output)
	return nil
}

func envOr(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
