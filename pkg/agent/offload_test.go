package agent

import (
	"context"
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/pkg/model"
	"github.com/axisvela/praxo-core/pkg/tool"
)

type bigTool struct{}

func (bigTool) Name() string        { return "big" }
func (bigTool) Description() string { return "returns a large result" }
func (bigTool) Invoke(context.Context, map[string]any) (any, error) {
	return strings.Repeat("x", 4096), nil
}

type toolThenFinalModel struct {
	calls int
	req   model.Request
}

func (m *toolThenFinalModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	m.req = req
	m.calls++
	if m.calls == 1 {
		return model.Response{Message: model.Message{
			Role:      model.RoleAssistant,
			ToolCalls: []model.ToolCall{{ID: "call-1", Name: "big"}},
		}}, nil
	}
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "done"}}, nil
}

func TestAgentOffloadsLargeToolResult(t *testing.T) {
	reg := tool.NewRegistry()
	reg.Register(bigTool{})
	var offloaded []byte
	var hookBytes int
	tm := &toolThenFinalModel{}
	ag := &Agent{
		Model: tm,
		Tools: reg,
		Offloader: OffloadFunc(func(_ context.Context, _ string, _ string, data []byte) (string, error) {
			offloaded = append([]byte(nil), data...)
			return "[offloaded]", nil
		}),
		OffloadThresholdBytes: 10,
		Hooks: Hooks{OnOffload: func(_ context.Context, _, _ string, _, _ int) error {
			hookBytes = len(offloaded)
			return nil
		}},
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "go"); err != nil {
		t.Fatal(err)
	}
	if len(offloaded) < 4096 {
		t.Fatalf("offloader received %d bytes", len(offloaded))
	}
	if hookBytes == 0 {
		t.Fatal("OnOffload not called")
	}
	found := false
	for _, msg := range tm.req.Messages {
		if msg.Role == model.RoleTool && msg.Content == "[offloaded]" {
			found = true
		}
	}
	if !found {
		t.Fatalf("placeholder missing from request: %+v", tm.req.Messages)
	}
}

func TestAgentOffloadRejectsEmptyPlaceholder(t *testing.T) {
	reg := tool.NewRegistry()
	reg.Register(bigTool{})
	ag := &Agent{
		Model:                 &toolThenFinalModel{},
		Tools:                 reg,
		Offloader:             OffloadFunc(func(context.Context, string, string, []byte) (string, error) { return "", nil }),
		OffloadThresholdBytes: 10,
	}
	_, err := ag.Run(context.Background(), Session{ID: "s1"}, "go")
	if err == nil || !strings.Contains(err.Error(), "empty placeholder") {
		t.Fatalf("err = %v, want empty placeholder error", err)
	}
}
