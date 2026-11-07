package context_budget_recipe

import (
	"context"
	"errors"
	"strings"
	"testing"

	agentcontext "github.com/axisvela/praxo-core/v2/pkg/agent/context"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

type summaryModel struct {
	err error
}

func (m summaryModel) Generate(context.Context, model.Request) (model.Response, error) {
	if m.err != nil {
		return model.Response{}, m.err
	}
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "summary"}}, nil
}

func TestBudgetUnderLimitIsUnchanged(t *testing.T) {
	messages := []model.Message{
		{Role: model.RoleSystem, Content: "system"},
		{Role: model.RoleUser, Content: "short"},
	}
	budget := agentcontext.ContextBudget{MaxTokens: 100}
	compacted, ok := budget.Compact(messages)
	if !ok {
		t.Fatal("small prompt did not fit")
	}
	if len(compacted) != len(messages) {
		t.Fatalf("len = %d, want %d", len(compacted), len(messages))
	}
}

func TestBudgetDropsOldMessagesAndKeepsSystem(t *testing.T) {
	messages := []model.Message{{Role: model.RoleSystem, Content: "system"}}
	for i := 0; i < 6; i++ {
		messages = append(messages, model.Message{
			Role:    model.RoleUser,
			Content: strings.Repeat("old ", 100),
		})
	}
	messages = append(messages,
		model.Message{Role: model.RoleUser, Content: "recent-1"},
		model.Message{Role: model.RoleAssistant, Content: "recent-2"},
	)
	budget := agentcontext.ContextBudget{MaxTokens: 60, KeepRecent: 2}
	compacted, ok := budget.Compact(messages)
	if !ok {
		t.Fatal("compactable prompt did not fit")
	}
	if len(compacted) >= len(messages) {
		t.Fatalf("len = %d, want fewer than %d", len(compacted), len(messages))
	}
	if compacted[0].Role != model.RoleSystem || compacted[0].Content != "system" {
		t.Fatalf("system prompt lost: %#v", compacted[0])
	}
	foundMarker := false
	for _, message := range compacted {
		if strings.HasPrefix(message.Content, "[context compacted:") {
			foundMarker = true
		}
	}
	if !foundMarker {
		t.Fatal("missing compaction marker")
	}
	if compacted[len(compacted)-2].Content != "recent-1" || compacted[len(compacted)-1].Content != "recent-2" {
		t.Fatalf("recent messages lost: %#v", compacted)
	}
	if got := agentcontext.EstimateTokens(compacted); got > budget.MaxTokens {
		t.Fatalf("tokens = %d, want <= %d", got, budget.MaxTokens)
	}
	if len(messages) != 9 {
		t.Fatal("input slice was mutated")
	}
}

func TestBudgetFailsWhenSystemCannotFit(t *testing.T) {
	messages := []model.Message{
		{Role: model.RoleSystem, Content: strings.Repeat("x", 400)},
		{Role: model.RoleUser, Content: "hi"},
	}
	budget := agentcontext.ContextBudget{MaxTokens: 10}
	if _, ok := budget.Compact(messages); ok {
		t.Fatal("oversized system prompt was accepted")
	}
}

func TestModelSummarizerCreatesSummary(t *testing.T) {
	messages := []model.Message{{Role: model.RoleSystem, Content: "system"}}
	for i := 0; i < 6; i++ {
		messages = append(messages, model.Message{
			Role:    model.RoleUser,
			Content: strings.Repeat("old ", 100),
		})
	}
	messages = append(messages,
		model.Message{Role: model.RoleUser, Content: "recent-1"},
		model.Message{Role: model.RoleAssistant, Content: "recent-2"},
	)
	budget := agentcontext.ContextBudget{MaxTokens: 30, KeepRecent: 2}
	summarizer := agentcontext.ModelSummarizer{Model: summaryModel{}, MaxSummaryTokens: 8}
	compacted, err := summarizer.Compact(context.Background(), messages, budget)
	if err != nil {
		t.Fatal(err)
	}
	foundSummary := false
	for _, message := range compacted {
		if strings.HasPrefix(message.Content, "[context summary: summary]") {
			foundSummary = true
		}
	}
	if !foundSummary {
		t.Fatalf("summary marker missing: %#v", compacted)
	}
	if got := agentcontext.EstimateTokens(compacted); got > budget.MaxTokens {
		t.Fatalf("tokens = %d, want <= %d", got, budget.MaxTokens)
	}
}

func TestModelSummarizerFallsBackOnError(t *testing.T) {
	messages := []model.Message{{Role: model.RoleSystem, Content: "system"}}
	for i := 0; i < 6; i++ {
		messages = append(messages, model.Message{
			Role:    model.RoleUser,
			Content: strings.Repeat("old ", 100),
		})
	}
	messages = append(messages,
		model.Message{Role: model.RoleUser, Content: "recent-1"},
		model.Message{Role: model.RoleAssistant, Content: "recent-2"},
	)
	budget := agentcontext.ContextBudget{MaxTokens: 30, KeepRecent: 2}
	summarizer := agentcontext.ModelSummarizer{Model: summaryModel{err: errors.New("summary model unavailable")}}
	compacted, err := summarizer.Compact(context.Background(), messages, budget)
	if err != nil {
		t.Fatal(err)
	}
	if got := agentcontext.EstimateTokens(compacted); got > budget.MaxTokens {
		t.Fatalf("fallback tokens = %d, want <= %d", got, budget.MaxTokens)
	}
}
