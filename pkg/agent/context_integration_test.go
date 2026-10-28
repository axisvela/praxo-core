package agent

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

type summaryModel struct {
	summary string
	calls   int
	err     error
}

func (m *summaryModel) Generate(context.Context, model.Request) (model.Response, error) {
	m.calls++
	if m.err != nil {
		return model.Response{}, m.err
	}
	return model.Response{Message: model.Message{Content: m.summary}}, nil
}

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

func TestAgentContextBudgetCompactsRequest(t *testing.T) {
	m := &requestModel{}
	ag := &Agent{Model: m, Context: &ContextBudget{MaxTokens: 250, KeepRecent: 2}}
	session := Session{ID: "s1"}
	for i := 0; i < 10; i++ {
		session.Messages = append(session.Messages, model.Message{Role: model.RoleUser, Content: strings.Repeat("u", 400)})
	}
	var compacted bool
	ag.Hooks.OnCompaction = func(_ context.Context, _ string, before, after int) error {
		compacted = true
		if after >= before {
			t.Fatalf("after = %d, before = %d", after, before)
		}
		return nil
	}
	if _, err := ag.Run(context.Background(), session, "do it"); err != nil {
		t.Fatal(err)
	}
	if !compacted {
		t.Fatal("OnCompaction was not called")
	}
	marker := false
	for _, msg := range m.req.Messages {
		if msg.Role == model.RoleSystem && strings.HasPrefix(msg.Content, "[context compacted:") {
			marker = true
		}
	}
	if !marker {
		t.Fatal("compacted request is missing the marker")
	}
}

func TestAgentContextBudgetFailsClosed(t *testing.T) {
	ag := &Agent{
		Model:        &requestModel{},
		Context:      &ContextBudget{MaxTokens: 3},
		SystemPrompt: strings.Repeat("x", 1000),
	}
	_, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it")
	if !errors.Is(err, ErrContextBudget) {
		t.Fatalf("err = %v, want ErrContextBudget", err)
	}
}

func TestAgentContextBudgetAppliesSameLengthCompaction(t *testing.T) {
	m := &requestModel{}
	budget := &ContextBudget{MaxTokens: 30, KeepRecent: 1}
	ag := &Agent{Model: m, Context: budget}
	session := Session{ID: "session", Messages: []model.Message{{Role: model.RoleUser, Content: strings.Repeat("s", 1000)}}}
	want, ok := budget.Compact(append(append([]model.Message(nil), session.Messages...), model.Message{Role: model.RoleUser, Content: "now"}))
	if !ok || len(want) != 2 {
		t.Fatalf("expected same-length compaction: %v %v", want, ok)
	}
	var compactions int
	ag.Hooks.OnCompaction = func(_ context.Context, _ string, before, after int) error {
		compactions++
		if before != 2 || after != 2 {
			t.Fatalf("before=%d after=%d", before, after)
		}
		return nil
	}
	if _, err := ag.Run(context.Background(), session, "now"); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(m.req.Messages, want) || EstimateTokens(m.req.Messages) > budget.MaxTokens || compactions != 1 {
		t.Fatalf("messages=%v want=%v compactions=%d", m.req.Messages, want, compactions)
	}
}

func TestAgentUsesCompactor(t *testing.T) {
	m := &requestModel{}
	sm := &summaryModel{summary: "summarized"}
	ag := &Agent{
		Model:     m,
		Context:   &ContextBudget{MaxTokens: 250, KeepRecent: 2},
		Compactor: ModelSummarizer{Model: sm, MaxSummaryTokens: 32},
	}
	session := Session{ID: "s1"}
	for i := 0; i < 10; i++ {
		session.Messages = append(session.Messages, model.Message{Role: model.RoleUser, Content: strings.Repeat("u", 400)})
	}
	if _, err := ag.Run(context.Background(), session, "do it"); err != nil {
		t.Fatal(err)
	}
	if sm.calls != 1 {
		t.Fatalf("summary calls = %d, want 1", sm.calls)
	}
	found := false
	for _, msg := range m.req.Messages {
		if strings.HasPrefix(msg.Content, "[context summary:") {
			found = true
		}
	}
	if !found {
		t.Fatal("compacted request missing summary marker")
	}
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
	if EstimateTokens(runModel.req.Messages) > 50 {
		t.Fatalf("final request over budget: %d", EstimateTokens(runModel.req.Messages))
	}
	hasSummary := false
	for _, msg := range runModel.req.Messages {
		if strings.HasPrefix(msg.Content, "[context summary:") {
			hasSummary = true
		}
	}
	if !hasSummary {
		t.Fatal("final request missing summary marker")
	}
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
		OffloadThresholdBytes: 100,
		Hooks: Hooks{
			OnOffload: func(_ context.Context, _ string, _ string, originalBytes, offloadedBytes int) error {
				hookBytes = originalBytes
				return nil
			},
		},
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "go"); err != nil {
		t.Fatal(err)
	}
	if len(offloaded) < 4000 || hookBytes < 4000 {
		t.Fatalf("offloaded=%d hookBytes=%d", len(offloaded), hookBytes)
	}
}

func TestAgentOffloadRejectsEmptyPlaceholder(t *testing.T) {
	reg := tool.NewRegistry()
	reg.Register(bigTool{})
	ag := &Agent{
		Model:                 &toolThenFinalModel{},
		Tools:                 reg,
		Offloader:             OffloadFunc(func(context.Context, string, string, []byte) (string, error) { return "", nil }),
		OffloadThresholdBytes: 100,
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "go"); err == nil {
		t.Fatal("expected empty placeholder error")
	}
}

func TestNewInjectsAgentsMD(t *testing.T) {
	p := filepath.Join(t.TempDir(), "AGENTS.md")
	if err := os.WriteFile(p, []byte("project rule"), 0o600); err != nil {
		t.Fatal(err)
	}
	m := &requestModel{}
	ag, err := New(Options{Model: m, SystemPrompt: "base", MemoryFiles: []string{p}})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "hi"); err != nil {
		t.Fatal(err)
	}
	if len(m.req.Messages) == 0 || m.req.Messages[0].Role != model.RoleSystem {
		t.Fatalf("system message missing: %+v", m.req.Messages)
	}
	if !strings.Contains(m.req.Messages[0].Content, "base") ||
		!strings.Contains(m.req.Messages[0].Content, "project rule") {
		t.Fatalf("system prompt = %q", m.req.Messages[0].Content)
	}
}
