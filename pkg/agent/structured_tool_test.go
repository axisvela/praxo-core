package agent

import (
	"context"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

type structuredToolModel struct {
	calls int
}

func (m *structuredToolModel) Generate(context.Context, model.Request) (model.Response, error) {
	m.calls++
	return model.Response{Message: model.Message{ToolCalls: []model.ToolCall{{
		ID:        "answer-1",
		Name:      "answer",
		Arguments: map[string]any{"answer": "ok"},
	}}}}, nil
}

func TestStructuredOutputToolStrategyCompletesRun(t *testing.T) {
	ag, err := New(Options{
		Model: &structuredToolModel{},
		StructuredOutput: &StructuredOutput{
			Name:     "answer",
			Schema:   answerSchema(),
			Strategy: StructuredOutputTool,
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	result, err := ag.Run(context.Background(), Session{ID: "s"}, "answer")
	if err != nil {
		t.Fatal(err)
	}
	if result.Output != `{"answer":"ok"}` {
		t.Fatalf("output = %q", result.Output)
	}
	if result.Steps != 1 {
		t.Fatalf("steps = %d", result.Steps)
	}
}
