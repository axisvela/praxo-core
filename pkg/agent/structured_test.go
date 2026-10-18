package agent

import (
	"context"
	"errors"
	"testing"
)

func answerSchema() map[string]any {
	return map[string]any{
		"type":     "object",
		"required": []any{"answer"},
		"properties": map[string]any{
			"answer": map[string]any{"type": "string", "minLength": 1},
		},
	}
}

func TestStructuredOutputMiddlewareAcceptsValidOutput(t *testing.T) {
	cfg := StructuredOutput{Name: "answer", Schema: answerSchema()}
	result := &Result{Output: `{"answer":"ok"}`}
	if err := cfg.Middleware().AfterRun(context.Background(), result, nil); err != nil {
		t.Fatal(err)
	}
}

func TestStructuredOutputMiddlewareRepairsInvalidOutput(t *testing.T) {
	cfg := StructuredOutput{
		Name:       "answer",
		Schema:     answerSchema(),
		MaxRepairs: 1,
		Repair: func(context.Context, string, error) (string, error) {
			return `{"answer":"repaired"}`, nil
		},
	}
	result := &Result{Output: `{"wrong":true}`}
	if err := cfg.Middleware().AfterRun(context.Background(), result, nil); err != nil {
		t.Fatal(err)
	}
	if result.Output != `{"answer":"repaired"}` {
		t.Fatalf("output = %q", result.Output)
	}
}

func TestStructuredOutputMiddlewareExhaustsRepairs(t *testing.T) {
	cfg := StructuredOutput{
		Name:       "answer",
		Schema:     answerSchema(),
		MaxRepairs: 1,
		Repair: func(context.Context, string, error) (string, error) {
			return `{"still":"wrong"}`, nil
		},
	}
	err := cfg.Middleware().AfterRun(context.Background(), &Result{Output: `{"wrong":true}`}, nil)
	if !errors.Is(err, ErrStructuredOutput) {
		t.Fatalf("err = %v, want ErrStructuredOutput", err)
	}
}

func TestStructuredOutputProviderFormat(t *testing.T) {
	cfg := StructuredOutput{Name: "answer", Schema: answerSchema(), Strategy: StructuredOutputProvider}
	format := cfg.ResponseFormat()
	if format == nil || format.Name != "answer" || format.Schema == nil {
		t.Fatalf("format = %+v", format)
	}
}

func TestStructuredOutputToolFormat(t *testing.T) {
	cfg := StructuredOutput{Name: "answer", Schema: answerSchema(), Strategy: StructuredOutputTool}
	if cfg.ResponseFormat() != nil {
		t.Fatal("tool strategy must not set provider response format")
	}
	spec := cfg.ToolSpec()
	if spec.Name != "answer" || spec.Parameters == nil {
		t.Fatalf("spec = %+v", spec)
	}
}

func TestStructuredOutputSkipsRunError(t *testing.T) {
	cfg := StructuredOutput{Name: "answer", Schema: answerSchema()}
	if err := cfg.Middleware().AfterRun(context.Background(), &Result{Output: "bad"}, errors.New("run failed")); err != nil {
		t.Fatalf("err = %v", err)
	}
}

func TestStructuredOutputInvalidSchema(t *testing.T) {
	cfg := StructuredOutput{Name: "answer", Schema: map[string]any{"type": 1}}
	if err := cfg.Middleware().AfterRun(context.Background(), &Result{Output: `{}`}, nil); err == nil {
		t.Fatal("expected schema error")
	}
}
