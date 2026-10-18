package agent

import (
	"context"
	"errors"
	"testing"

	"github.com/axisvela/praxo-core/pkg/model"
	"github.com/axisvela/praxo-core/pkg/tool"
)

type stubModel struct {
	response model.Response
	err      error
	calls    int
}

func (s *stubModel) Generate(context.Context, model.Request) (model.Response, error) {
	s.calls++
	return s.response, s.err
}

type fakeSelector struct {
	names []string
	err   error
	query string
	tools []model.ToolSpec
}

func (f *fakeSelector) Select(_ context.Context, query string, tools []model.ToolSpec) ([]string, error) {
	f.query = query
	f.tools = tools
	return f.names, f.err
}

func TestNewWiresParityMiddleware(t *testing.T) {
	redactor := NewPIIRedactor(DefaultPIIRules()...)
	ag, err := New(Options{
		Model:            &stubModel{},
		StructuredOutput: &StructuredOutput{Name: "answer", Schema: answerSchema()},
		ToolSelector:     &fakeSelector{names: []string{"echo"}},
		PIIRedactor:      &redactor,
		ModelCallLimit:   2,
		ToolCallLimit:    3,
		FallbackModel:    &stubModel{},
		ToolRetry:        &tool.RetryPolicy{Attempts: 2},
	})
	if err != nil {
		t.Fatal(err)
	}
	names := make(map[string]bool)
	for _, mw := range ag.Middleware {
		names[mw.Name] = true
	}
	for _, want := range []string{"structured-output", "tool-selection", "pii", "call-limit"} {
		if !names[want] {
			t.Fatalf("missing middleware %q in %+v", want, names)
		}
	}
	if len(ag.ModelMiddleware) != 1 || ag.ToolRetry == nil {
		t.Fatalf("model middleware=%d tool retry=%v", len(ag.ModelMiddleware), ag.ToolRetry)
	}
}

type retryOnceTool struct {
	attempts int
}

func (r *retryOnceTool) Name() string        { return "flaky" }
func (r *retryOnceTool) Description() string { return "fails once" }
func (r *retryOnceTool) Invoke(context.Context, map[string]any) (any, error) {
	r.attempts++
	if r.attempts == 1 {
		return nil, errors.New("transient")
	}
	return "ok", nil
}

type toolOnceModel struct {
	calls int
}

func (m *toolOnceModel) Generate(context.Context, model.Request) (model.Response, error) {
	m.calls++
	if m.calls == 1 {
		return model.Response{Message: model.Message{ToolCalls: []model.ToolCall{{ID: "c1", Name: "flaky"}}}}, nil
	}
	return model.Response{Message: model.Message{Content: "done"}}, nil
}

func TestAgentToolRetry(t *testing.T) {
	registry := tool.NewRegistry()
	flaky := &retryOnceTool{}
	registry.Register(flaky)
	ag, err := New(Options{
		Model:     &toolOnceModel{},
		Tools:     registry,
		ToolRetry: &tool.RetryPolicy{Attempts: 2},
	})
	if err != nil {
		t.Fatal(err)
	}
	result, err := ag.Run(context.Background(), Session{ID: "s"}, "go")
	if err != nil {
		t.Fatal(err)
	}
	if result.Output != "done" || flaky.attempts != 2 {
		t.Fatalf("output=%q attempts=%d", result.Output, flaky.attempts)
	}
}
