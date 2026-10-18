package agentcontext

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/axisvela/praxo-core/pkg/model"
)

// ErrContextBudget is returned when the system prompt alone exceeds the
// configured context budget and compaction cannot make the request fit.
var ErrContextBudget = errors.New("agent: context budget exceeded")

const compactMarkerPrefix = "[context compacted:"

// ContextBudget bounds the estimated prompt size sent to the model. MaxTokens
// is an estimate (roughly four characters per token); zero disables compaction.
// KeepRecent is the number of trailing non-system messages retained; zero
// applies a default of four.
type ContextBudget struct {
	MaxTokens  int
	KeepRecent int
}

// Compact returns a prompt that fits the budget, reporting false when the
// system prompt alone cannot fit. It never mutates the input slice or messages.
func (b ContextBudget) Compact(messages []model.Message) ([]model.Message, bool) {
	if b.MaxTokens <= 0 {
		return messages, true
	}
	if EstimateTokens(messages) <= b.MaxTokens {
		return messages, true
	}

	system := make([]model.Message, 0, len(messages))
	rest := make([]model.Message, 0, len(messages))
	for _, m := range messages {
		if m.Role == model.RoleSystem {
			if strings.HasPrefix(m.Content, compactMarkerPrefix) {
				continue
			}
			system = append(system, cloneMessage(m))
			continue
		}
		rest = append(rest, cloneMessage(m))
	}

	if EstimateTokens(system) > b.MaxTokens {
		if len(system) == 0 {
			return nil, false
		}
		system = []model.Message{system[0]}
		system[0].Content = truncateToTokens(system[0].Content, b.MaxTokens-4)
		if EstimateTokens(system) > b.MaxTokens {
			return nil, false
		}
	}

	keep := b.KeepRecent
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

	marker := model.Message{Role: model.RoleSystem, Content: fmt.Sprintf("%s %d older messages omitted]", compactMarkerPrefix, start)}
	kept := rest[start:]
	out := buildCompacted(system, marker, start > 0, kept)
	for EstimateTokens(out) > b.MaxTokens && len(kept) > 1 {
		if kept[1].Role == model.RoleTool {
			break
		}
		kept = kept[1:]
		out = buildCompacted(system, marker, start > 0, kept)
	}
	if EstimateTokens(out) > b.MaxTokens {
		return nil, false
	}
	return out, true
}

func buildCompacted(system []model.Message, marker model.Message, includeMarker bool, kept []model.Message) []model.Message {
	out := make([]model.Message, 0, len(system)+len(kept)+1)
	out = append(out, system...)
	if includeMarker {
		out = append(out, marker)
	}
	out = append(out, kept...)
	return out
}

func cloneMessage(m model.Message) model.Message {
	c := m
	if m.ContentBlocks != nil {
		c.ContentBlocks = append([]model.ContentBlock(nil), m.ContentBlocks...)
	}
	if m.ToolCalls != nil {
		c.ToolCalls = make([]model.ToolCall, len(m.ToolCalls))
		for i, tc := range m.ToolCalls {
			c.ToolCalls[i] = tc
			if tc.Arguments != nil {
				c.ToolCalls[i].Arguments = make(map[string]any, len(tc.Arguments))
				for k, v := range tc.Arguments {
					c.ToolCalls[i].Arguments[k] = v
				}
			}
		}
	}
	return c
}

// EstimateTokens returns a rough token estimate (about four characters per
// token).
func EstimateTokens(messages []model.Message) int {
	total := 0
	for _, m := range messages {
		total += 4 + len(m.Content)/4 + len(m.ToolID)/4
		for _, b := range m.ContentBlocks {
			total += 4 + len(b.Text)/4 + len(b.ImageURL)/4 + len(b.Data)/4
		}
		for _, tc := range m.ToolCalls {
			total += 4 + len(tc.Name)/4
			raw, err := json.Marshal(tc.Arguments)
			if err == nil {
				total += len(raw) / 4
			}
		}
	}
	return total
}

func truncateToTokens(s string, tokens int) string {
	if tokens <= 0 {
		return ""
	}
	max := tokens * 4
	if len(s) <= max {
		return s
	}
	if max <= 16 {
		return s[:max]
	}
	return s[:max-16] + "\n[truncated]"
}
