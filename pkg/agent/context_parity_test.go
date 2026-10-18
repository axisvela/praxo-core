package agent

import (
	"context"
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/pkg/model"
	"github.com/axisvela/praxo-core/pkg/tool"
)

type longRunModel struct {
	calls int
	req   model.Request
}

func (m *longRunModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	m.req = req
	m.calls++
	if m.calls <= 5 {
		return model.Response{Message: model.Message{
			Role:      model.RoleAssistant,
			ToolCalls: []model.ToolCall{{ID: "call-" + string(rune('0'+m.calls)), Name: "big"}},
		}}, nil
	}
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "finished"}}, nil
}

func TestLongRunContextParity(t *testing.T) {
	reg := tool.NewRegistry()
	reg.Register(bigTool{})
	runModel := &longRunModel{}
	summaries := &summaryModel{summary: "prior tool work compressed"}
	var offloads, compactions, offloadHooks int

	ag := &Agent{
		Model:                 runModel,
		Tools:                 reg,
		MaxSteps:              10,
		Context:               &ContextBudget{MaxTokens: 50, KeepRecent: 1},
		Compactor:             ModelSummarizer{Model: summaries, MaxSummaryTokens: 32},
		Offloader:             OffloadFunc(func(context.Context, string, string, []byte) (string, error) { offloads++; return "[offloaded]", nil }),
		OffloadThresholdBytes: 100,
		Hooks: Hooks{
			OnCompaction: func(context.Context, string, int, int) error { compactions++; return nil },
			OnOffload:    func(context.Context, string, string, int, int) error { offloadHooks++; return nil },
		},
	}
	result, err := ag.Run(context.Background(), Session{ID: "s1"}, "long task")
	if err != nil {
		t.Fatal(err)
	}
	if result.Output != "finished" {
		t.Fatalf("output = %q", result.Output)
	}
	if offloads == 0 || offloadHooks == 0 {
		t.Fatalf("offloads=%d hooks=%d", offloads, offloadHooks)
	}
	if summaries.calls == 0 {
		t.Fatal("summarizer was not called")
	}
	if compactions == 0 {
		t.Fatal("OnCompaction was not called")
	}
	if estimateTokens(runModel.req.Messages) > 50 {
		t.Fatalf("final request over budget: %d", estimateTokens(runModel.req.Messages))
	}
	hasSummary := false
	for _, msg := range runModel.req.Messages {
		if strings.HasPrefix(msg.Content, summaryMarkerPrefix) {
			hasSummary = true
		}
	}
	if !hasSummary {
		t.Fatal("final request missing summary marker")
	}
}
