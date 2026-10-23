package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/axisvela/praxo-core/v2/adapters/openaicompat"
	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/memory"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
	"github.com/axisvela/praxo-core/v2/pkg/vfs/localfs"
	"github.com/axisvela/praxo-core/v2/pkg/vfs/vfstools"
)

func main() {
	workspace := flag.String("workspace", "workspace", "local workspace directory")
	prompt := flag.String("prompt", "List the workspace, read any text files, and summarize them.", "request to send")
	baseURL := flag.String("base-url", envOr("PRAXO_BASE_URL", "http://localhost:11434/v1"), "OpenAI-compatible base URL")
	modelName := flag.String("model", envOr("PRAXO_MODEL", "llama3.2"), "model name")
	flag.Parse()

	backend, err := localfs.New(*workspace)
	if err != nil {
		log.Fatal(err)
	}

	registry := tool.NewRegistry()
	for _, item := range vfstools.Tools(backend) {
		registry.Register(item)
	}

	ag, err := agent.New(agent.Options{
		Model: openaicompat.Adapter{
			BaseURL: *baseURL,
			APIKey:  os.Getenv("PRAXO_API_KEY"),
			Model:   *modelName,
		},
		SystemPrompt: "You are a workspace assistant. Use the fs.* tools to inspect and edit files. Keep all changes inside the workspace.",
		Tools:        registry,
		Memory:       memory.NewMemoryStore(),
		Recall:       true,
		MaxSteps:     8,
		Context:      &agent.ContextBudget{MaxTokens: 4000, KeepRecent: 8},
		Events: event.FuncSink(func(_ context.Context, ev event.Event) error {
			fmt.Fprintln(os.Stderr, "event:", ev.Type)
			return nil
		}),
		Policy: policy.FuncHook(workspacePolicy),
	})
	if err != nil {
		log.Fatal(err)
	}

	result, err := ag.Run(context.Background(), agent.Session{
		ID:          fmt.Sprintf("reference-%d", time.Now().Unix()),
		TenantID:    "local",
		WorkspaceID: *workspace,
	}, *prompt)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(result.Output)
}

func envOr(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func workspacePolicy(_ context.Context, action policy.Action) (policy.Decision, error) {
	if action.Kind == "model.generate" || strings.HasPrefix(action.ToolName, "fs.") {
		return policy.Decision{Allowed: true, Reason: "workspace policy"}, nil
	}
	return policy.Decision{Allowed: false, Reason: "action is not allowed"}, nil
}
