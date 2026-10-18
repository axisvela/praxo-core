package agent

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/pkg/model"
)

type summaryModel struct {
	summary string
	err     error
	calls   int
}

func (m *summaryModel) Generate(context.Context, model.Request) (model.Response, error) {
	m.calls++
	if m.err != nil {
		return model.Response{}, m.err
	}
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: m.summary}}, nil
}

func TestModelSummarizerCompactsOldContext(t *testing.T) {
	msgs := []model.Message{
		{Role: model.RoleSystem, Content: "system"},
		{Role: model.RoleUser, Content: strings.Repeat("u", 800)},
		{Role: model.RoleAssistant, Content: strings.Repeat("a", 800)},
		{Role: model.RoleUser, Content: strings.Repeat("v", 800)},
		{Role: model.RoleAssistant, Content: strings.Repeat("b", 800)},
	}
	m := &summaryModel{summary: "earlier work: decided X"}
	out, err := (ModelSummarizer{Model: m, MaxSummaryTokens: 64}).Compact(context.Background(), msgs, ContextBudget{MaxTokens: 250, KeepRecent: 2})
	if err != nil {
		t.Fatal(err)
	}
	if m.calls != 1 {
		t.Fatalf("summary calls = %d, want 1", m.calls)
	}
	found := false
	for _, msg := range out {
		if msg.Role == model.RoleSystem && strings.HasPrefix(msg.Content, summaryMarkerPrefix) {
			found = true
		}
	}
	if !found {
		t.Fatalf("summary marker missing: %+v", out)
	}
	if estimateTokens(out) > 250 {
		t.Fatalf("summary output over budget: %d", estimateTokens(out))
	}
}

func TestModelSummarizerFallsBackOnError(t *testing.T) {
	msgs := []model.Message{{Role: model.RoleSystem, Content: "system"}}
	for i := 0; i < 8; i++ {
		msgs = append(msgs, model.Message{Role: model.RoleUser, Content: strings.Repeat("x", 400)})
	}
	out, err := (ModelSummarizer{Model: &summaryModel{err: errors.New("boom")}}).Compact(context.Background(), msgs, ContextBudget{MaxTokens: 250, KeepRecent: 2})
	if err != nil {
		t.Fatal(err)
	}
	if estimateTokens(out) > 250 {
		t.Fatalf("fallback output over budget: %d", estimateTokens(out))
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
		if strings.HasPrefix(msg.Content, summaryMarkerPrefix) {
			found = true
		}
	}
	if !found {
		t.Fatal("compacted request missing summary marker")
	}
}
