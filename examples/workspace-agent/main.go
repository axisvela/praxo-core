package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/axisvela/praxo-core/v2/adapters/openaicompat"
	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
	"github.com/axisvela/praxo-core/v2/pkg/vfs/localfs"
	"github.com/axisvela/praxo-core/v2/pkg/vfs/vfstools"
)

func main() {
	workspace := flag.String("workspace", "workspace", "local workspace directory")
	prompt := flag.String("prompt", "List the workspace, read the text files, and summarize them.", "request to send")
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
		SystemPrompt: "You are a read-only workspace assistant. Use fs.list, fs.read, fs.glob, and fs.grep. Never modify files.",
		Tools:        registry,
		MaxSteps:     8,
		AllowedTools: []string{"fs.list", "fs.read", "fs.glob", "fs.grep"},
		Events: event.FuncSink(func(_ context.Context, ev event.Event) error {
			fmt.Fprintln(os.Stderr, "event:", ev.Type)
			return nil
		}),
		Policy: policy.FuncHook(readOnlyPolicy),
	})
	if err != nil {
		log.Fatal(err)
	}

	result, err := ag.Run(context.Background(), agent.Session{
		ID:          "workspace-agent",
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

func readOnlyPolicy(_ context.Context, action policy.Action) (policy.Decision, error) {
	if action.Kind == "model.generate" {
		return policy.Decision{Allowed: true, Reason: "model generation"}, nil
	}
	if action.Kind != "tool.invoke" {
		return policy.Decision{Allowed: false, Reason: "unsupported action"}, nil
	}
	switch action.ToolName {
	case "fs.list", "fs.read", "fs.glob", "fs.grep":
		if escapes(action.Arguments["path"]) || escapes(action.Arguments["pattern"]) {
			return policy.Decision{Allowed: false, Reason: "path escapes the workspace"}, nil
		}
		return policy.Decision{Allowed: true, Reason: "read-only workspace tool"}, nil
	default:
		return policy.Decision{Allowed: false, Reason: "tool is not allowed"}, nil
	}
}

func escapes(value any) bool {
	path, _ := value.(string)
	if path == "" {
		return false
	}
	clean := strings.TrimPrefix(strings.ReplaceAll(path, "\\", "/"), "./")
	return strings.HasPrefix(path, "/") || clean == ".." || strings.HasPrefix(clean, "../")
}
