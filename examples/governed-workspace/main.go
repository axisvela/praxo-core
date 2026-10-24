package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
	"github.com/axisvela/praxo-core/v2/pkg/vfs/localfs"
	"github.com/axisvela/praxo-core/v2/pkg/vfs/vfstools"
)

const report = "Quarterly status: all checks green.\n"

func main() {
	mode := flag.String("mode", "read", "read, write, deny, or escape")
	workspace := flag.String("workspace", "", "workspace directory; a temporary directory is used when empty")
	flag.Parse()

	dir := *workspace
	cleanup := func() {}
	if dir == "" {
		var err error
		dir, err = os.MkdirTemp("", "praxo-governed-workspace-")
		if err != nil {
			log.Fatal(err)
		}
		cleanup = func() { _ = os.RemoveAll(dir) }
	}
	defer cleanup()

	if err := seed(dir); err != nil {
		log.Fatal(err)
	}
	output, trace, err := runDemo(context.Background(), *mode, dir)
	for _, item := range trace {
		fmt.Fprintln(os.Stderr, "trace:", item)
	}
	if err != nil {
		fmt.Println("expected:", err)
		return
	}
	fmt.Println(output)
}

func seed(dir string) error {
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	path := filepath.Join(dir, "report.txt")
	if _, err := os.Stat(path); err == nil {
		return nil
	}
	return os.WriteFile(path, []byte(report), 0o600)
}

func runDemo(ctx context.Context, mode, workspace string) (string, []string, error) {
	backend, err := localfs.New(workspace)
	if err != nil {
		return "", nil, err
	}
	registry := tool.NewRegistry()
	for _, item := range vfstools.Tools(backend) {
		registry.Register(item)
	}
	var trace []string
	opts := agent.Options{
		Model:        &scriptedModel{mode: mode},
		SystemPrompt: "You are a workspace assistant. Reads are allowed; writes require approval.",
		Tools:        registry,
		MaxSteps:     3,
		Events: event.FuncSink(func(_ context.Context, ev event.Event) error {
			entry := ev.Type
			if name, ok := ev.Data["name"].(string); ok && name != "" {
				entry += ":" + name
			}
			trace = append(trace, entry)
			return nil
		}),
		Policy: policy.FuncHook(workspacePolicy),
	}
	switch mode {
	case "read", "escape":
		opts.AllowedTools = []string{"fs.list", "fs.read", "fs.glob", "fs.grep"}
	case "write", "deny":
		opts.AllowedTools = []string{"fs.list", "fs.read", "fs.glob", "fs.grep", "fs.write", "fs.edit", "fs.delete"}
		opts.InterruptOn = map[string]bool{"fs.write": true, "fs.edit": true, "fs.delete": true}
		opts.OnInterruptDecision = func(context.Context, agent.Interrupt) (agent.InterruptDecision, error) {
			if mode == "write" {
				return agent.InterruptDecision{Action: agent.InterruptApprove}, nil
			}
			return agent.InterruptDecision{Action: agent.InterruptReject, Reason: "write approval denied by demo policy"}, nil
		}
	default:
		return "", trace, fmt.Errorf("unknown mode %q", mode)
	}
	ag, err := agent.New(opts)
	if err != nil {
		return "", trace, err
	}
	result, err := ag.Run(ctx, agent.Session{ID: "governed-workspace", TenantID: "local", WorkspaceID: workspace}, "inspect the workspace")
	if err != nil {
		return "", trace, err
	}
	return result.Output, trace, nil
}

func workspacePolicy(_ context.Context, action policy.Action) (policy.Decision, error) {
	if action.Kind == "model.generate" {
		return policy.Decision{Allowed: true, Reason: "model call"}, nil
	}
	if action.Kind != "tool.invoke" {
		return policy.Decision{Allowed: false, Reason: "unsupported action"}, nil
	}
	switch action.ToolName {
	case "fs.list", "fs.read", "fs.glob", "fs.grep":
		if escaped(action.Arguments["path"]) || escaped(action.Arguments["pattern"]) {
			return policy.Decision{Allowed: false, Reason: "path escapes the workspace"}, nil
		}
		return policy.Decision{Allowed: true, Reason: "read-only workspace tool"}, nil
	case "fs.write", "fs.edit", "fs.delete":
		if escaped(action.Arguments["path"]) {
			return policy.Decision{Allowed: false, Reason: "path escapes the workspace"}, nil
		}
		return policy.Decision{Allowed: true, Reason: "write requires approval"}, nil
	default:
		return policy.Decision{Allowed: false, Reason: "tool is not allowed"}, nil
	}
}

func escaped(value any) bool {
	path, _ := value.(string)
	if path == "" {
		return false
	}
	clean := filepath.ToSlash(filepath.Clean(filepath.FromSlash(path)))
	return filepath.IsAbs(path) || clean == ".." || strings.HasPrefix(clean, "../")
}

type scriptedModel struct {
	mode  string
	calls int
}

func (m *scriptedModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	m.calls++
	if m.calls == 1 {
		call := model.ToolCall{ID: "call-1"}
		switch m.mode {
		case "read":
			call.Name, call.Arguments = "fs.read", map[string]any{"path": "report.txt"}
		case "write", "deny":
			call.Name, call.Arguments = "fs.write", map[string]any{"path": "notes.md", "content": "approved by demo\n"}
		case "escape":
			call.Name, call.Arguments = "fs.read", map[string]any{"path": "../secret.txt"}
		}
		return model.Response{Message: model.Message{ToolCalls: []model.ToolCall{call}}}, nil
	}
	if m.mode == "read" {
		for i := len(req.Messages) - 1; i >= 0; i-- {
			if req.Messages[i].Role == model.RoleTool {
				content := req.Messages[i].Content
				var decoded string
				if json.Unmarshal([]byte(content), &decoded) == nil {
					content = decoded
				}
				return model.Response{Message: model.Message{Content: "read: " + strings.TrimSpace(content)}}, nil
			}
		}
	}
	return model.Response{Message: model.Message{Content: "approved: notes.md written"}}, nil
}
