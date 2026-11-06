package agent

import (
	"context"
	"errors"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

var errParallelTool = errors.New("tool failed")

type parallelFailTool struct {
	calls int
}

func (t *parallelFailTool) Name() string        { return "fail" }
func (t *parallelFailTool) Description() string { return "fails" }
func (t *parallelFailTool) Invoke(context.Context, map[string]any) (any, error) {
	t.calls++
	return nil, errParallelTool
}

type parallelOKTool struct {
	calls int
}

func (t *parallelOKTool) Name() string        { return "ok" }
func (t *parallelOKTool) Description() string { return "succeeds" }
func (t *parallelOKTool) Invoke(context.Context, map[string]any) (any, error) {
	t.calls++
	return "ok-result", nil
}

type parallelOutcomeModel struct {
	calls int
}

func (m *parallelOutcomeModel) Generate(context.Context, model.Request) (model.Response, error) {
	m.calls++
	if m.calls == 1 {
		return model.Response{Message: model.Message{ToolCalls: []model.ToolCall{
			{ID: "one", Name: "fail"},
			{ID: "two", Name: "ok"},
		}}}, nil
	}
	return model.Response{Message: model.Message{Content: "done"}}, nil
}

func TestParallelToolFailureStillReportsEveryOutcome(t *testing.T) {
	failTool := &parallelFailTool{}
	okTool := &parallelOKTool{}
	registry := tool.NewRegistry()
	registry.Register(failTool)
	registry.Register(okTool)

	var streamed, results []string
	var okValue any
	ag := &Agent{
		Model: &parallelOutcomeModel{}, Tools: registry, MaxParallelTools: 2,
		OnStream: func(part StreamPart) error {
			if part.Kind != StreamTasks {
				return nil
			}
			data, ok := part.Data.(map[string]any)
			if !ok || data["status"] != "end" {
				return nil
			}
			name, _ := data["name"].(string)
			streamed = append(streamed, name)
			return nil
		},
		Hooks: Hooks{OnToolResult: func(_ context.Context, _ string, call model.ToolCall, value any, _ error) error {
			results = append(results, call.Name)
			if call.Name == "ok" {
				okValue = value
			}
			return nil
		}},
	}

	_, err := ag.Run(context.Background(), Session{ID: "parallel-outcome"}, "go")
	if !errors.Is(err, errParallelTool) {
		t.Fatalf("err = %v, want the first tool error", err)
	}
	if failTool.calls != 1 || okTool.calls != 1 {
		t.Fatalf("calls: fail=%d ok=%d, want both executed once", failTool.calls, okTool.calls)
	}
	for _, name := range []string{"fail", "ok"} {
		if !contains(streamed, name) || !contains(results, name) {
			t.Fatalf("outcome %q not reported: streamed=%v results=%v", name, streamed, results)
		}
	}
	if len(streamed) != 2 || len(results) != 2 {
		t.Fatalf("unexpected duplicate notification: streamed=%v results=%v", streamed, results)
	}
	if okValue != "ok-result" {
		t.Fatalf("ok result = %v, want ok-result", okValue)
	}
}

func contains(values []string, want string) bool {
	for _, value := range values {
		if value == want {
			return true
		}
	}
	return false
}
