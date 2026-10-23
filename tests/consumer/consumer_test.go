package consumer_test

import (
	"context"
	"encoding/json"
	"os"
	"os/exec"
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/adapters/anthropic"
	"github.com/axisvela/praxo-core/adapters/gemini"
	mcpadapter "github.com/axisvela/praxo-core/adapters/mcp"
	oteladapter "github.com/axisvela/praxo-core/adapters/otel"
	"github.com/axisvela/praxo-core/v2/adapters/openaicompat"
	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

var (
	_ model.StreamingModel = openaicompat.Adapter{}
	_ model.StreamingModel = anthropic.Adapter{}
	_ model.StreamingModel = gemini.Adapter{}
	_ tool.Gateway         = (*mcpadapter.Gateway)(nil)
	_ event.Sink           = oteladapter.Sink{}
)

type finalModel struct{}

func (finalModel) Generate(context.Context, model.Request) (model.Response, error) {
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "consumer ok"}}, nil
}

func TestPublishedAgent(t *testing.T) {
	ag, err := agent.New(agent.Options{Model: finalModel{}, MaxSteps: 2})
	if err != nil {
		t.Fatal(err)
	}
	result, err := ag.Run(context.Background(), agent.Session{ID: "consumer"}, "hello")
	if err != nil {
		t.Fatal(err)
	}
	if result.Output != "consumer ok" {
		t.Fatalf("output = %q", result.Output)
	}
}

func TestPublishedDependencyGraph(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	cmd := exec.CommandContext(ctx, "go", "list", "-m", "-json", "all")
	cmd.Env = append(os.Environ(), "GOWORK=off")
	output, err := cmd.Output()
	if err != nil {
		t.Fatal(err)
	}
	expected := map[string]string{
		"github.com/axisvela/praxo-core/v2":                 "v2.1.0",
		"github.com/axisvela/praxo-core/adapters/anthropic": "v0.1.0",
		"github.com/axisvela/praxo-core/adapters/gemini":    "v0.1.0",
		"github.com/axisvela/praxo-core/adapters/mcp":       "v0.2.0",
		"github.com/axisvela/praxo-core/adapters/otel":      "v0.1.0",
	}
	decoder := json.NewDecoder(strings.NewReader(string(output)))
	for decoder.More() {
		var module struct {
			Path    string
			Version string
			Replace json.RawMessage
		}
		if err := decoder.Decode(&module); err != nil {
			t.Fatal(err)
		}
		if len(module.Replace) != 0 {
			t.Fatalf("unexpected replacement: %s", module.Path)
		}
		if version, ok := expected[module.Path]; ok {
			if module.Version != version {
				t.Fatalf("%s: got %s, want %s", module.Path, module.Version, version)
			}
			delete(expected, module.Path)
		}
	}
	if len(expected) != 0 {
		t.Fatalf("missing modules: %v", expected)
	}
}
