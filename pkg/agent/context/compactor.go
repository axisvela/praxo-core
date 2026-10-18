package agentcontext

import (
	"context"
	"strings"

	"github.com/axisvela/praxo-core/pkg/model"
)

const summaryMarkerPrefix = "[context summary:"

// ContextCompactor replaces older context before the deterministic budget
// compactor runs. It may summarize, offload, or otherwise rewrite messages.
type ContextCompactor interface {
	Compact(ctx context.Context, messages []model.Message, budget ContextBudget) ([]model.Message, error)
}

// ModelSummarizer summarizes older messages with a model call. Failures fall
// back to deterministic compaction so a transient model error cannot abort a
// run solely because context maintenance failed.
type ModelSummarizer struct {
	Model            model.Model
	Prompt           string
	MaxSummaryTokens int
}

const defaultSummaryPrompt = "Summarize the conversation so far. Preserve decisions, open tasks, tool results, constraints, and user preferences. Be concise."

// Compact implements ContextCompactor.
func (s ModelSummarizer) Compact(ctx context.Context, messages []model.Message, budget ContextBudget) ([]model.Message, error) {
	if budget.MaxTokens <= 0 || EstimateTokens(messages) <= budget.MaxTokens {
		return messages, nil
	}
	if s.Model == nil {
		return fitBudget(messages, budget)
	}

	system := make([]model.Message, 0, len(messages))
	rest := make([]model.Message, 0, len(messages))
	for _, m := range messages {
		if m.Role == model.RoleSystem {
			if strings.HasPrefix(m.Content, compactMarkerPrefix) || strings.HasPrefix(m.Content, summaryMarkerPrefix) {
				continue
			}
			system = append(system, cloneMessage(m))
			continue
		}
		rest = append(rest, cloneMessage(m))
	}
	keep := budget.KeepRecent
	if keep <= 0 {
		keep = 4
	}
	start := len(rest) - keep
	if start < 0 {
		start = 0
	}
	for start > 0 && rest[start].Role == model.RoleTool {
		start--
	}
	if start == 0 {
		return fitBudget(messages, budget)
	}

	summary, err := s.summarize(ctx, rest[:start])
	if err != nil || strings.TrimSpace(summary) == "" {
		return fitBudget(messages, budget)
	}
	maxSummary := s.MaxSummaryTokens
	if maxSummary <= 0 {
		maxSummary = budget.MaxTokens / 4
	}
	summary = truncateToTokens(strings.TrimSpace(summary), maxSummary)
	out := make([]model.Message, 0, len(system)+1+len(rest[start:]))
	out = append(out, system...)
	out = append(out, model.Message{
		Role:    model.RoleSystem,
		Content: summaryMarkerPrefix + " " + summary + "]",
	})
	out = append(out, rest[start:]...)
	return fitBudget(out, budget)
}

func (s ModelSummarizer) summarize(ctx context.Context, messages []model.Message) (string, error) {
	prompt := s.Prompt
	if strings.TrimSpace(prompt) == "" {
		prompt = defaultSummaryPrompt
	}
	req := model.Request{Messages: make([]model.Message, 0, len(messages)+1)}
	req.Messages = append(req.Messages, model.Message{Role: model.RoleSystem, Content: prompt})
	req.Messages = append(req.Messages, messages...)
	resp, err := s.Model.Generate(ctx, req)
	if err != nil {
		return "", err
	}
	return resp.Message.Content, nil
}

func fitBudget(messages []model.Message, budget ContextBudget) ([]model.Message, error) {
	out, ok := budget.Compact(messages)
	if !ok {
		return nil, ErrContextBudget
	}
	return out, nil
}
