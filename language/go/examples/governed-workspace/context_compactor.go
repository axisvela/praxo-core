package main

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"sort"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

type workspaceContextCompactor struct {
	system     string
	summarizer model.Model
}

func (b workspaceContextCompactor) normalize(messages []model.Message) ([]model.Message, error) {
	if len(messages) == 0 || messages[0].Role != model.RoleSystem || messages[0].Content != b.system || len(messages[0].ContentBlocks) > 0 || len(messages[0].ToolCalls) > 0 || messages[0].ToolID != "" {
		return nil, errWorkspaceContext
	}
	out := append([]model.Message(nil), messages...)
	for i, message := range messages {
		if message.Role != model.RoleSystem && message.Role != model.RoleUser && message.Role != model.RoleAssistant && message.Role != model.RoleTool {
			return nil, errWorkspaceContext
		}
		if message.Role == model.RoleSystem && i != 0 {
			return nil, errWorkspaceContext
		}
		if message.Role == model.RoleUser {
			if _, _, err := parseWorkspaceSource(message.Content); err != nil {
				return nil, err
			}
		}
		if message.Role != model.RoleTool {
			continue
		}
		if message.ToolID == "" {
			return nil, errWorkspaceContext
		}
		source, matched, err := parseWorkspaceSource(message.Content)
		if matched && err == nil && source.Source == "tool" && source.ID == message.ToolID && len(source.Parents) == 0 {
			continue
		}
		data, err := workspaceData(workspaceSource{Source: "tool", ID: message.ToolID, Content: message.Content})
		if err != nil {
			return nil, err
		}
		data.Role = model.RoleTool
		data.ToolID = message.ToolID
		out[i] = data
	}
	return out, nil
}

func (b workspaceContextCompactor) Compact(ctx context.Context, messages []model.Message, budget agent.ContextBudget) ([]model.Message, error) {
	normalized, err := b.normalize(messages)
	if err != nil {
		return nil, err
	}
	parents := make(map[string]bool)
	for i, message := range normalized {
		if message.Role == model.RoleSystem {
			continue
		}
		source, matched, err := parseWorkspaceSource(message.Content)
		if err != nil {
			return nil, err
		}
		if matched {
			parents[source.Source+"/"+source.ID] = true
			for _, parent := range source.Parents {
				parents[parent] = true
			}
		} else {
			parents[fmt.Sprintf("conversation/%d", i)] = true
		}
	}
	lineage := make([]string, 0, len(parents))
	for parent := range parents {
		lineage = append(lineage, parent)
	}
	sort.Strings(lineage)
	compacted, err := (agent.ModelSummarizer{Model: b.summarizer}).Compact(ctx, normalized, budget)
	if err != nil {
		return nil, err
	}
	if len(compacted) == 0 || compacted[0].Role != model.RoleSystem || compacted[0].Content != b.system {
		return nil, agent.ErrContextBudget
	}
	out := append([]model.Message(nil), compacted...)
	for i, message := range compacted {
		if i == 0 || message.Role != model.RoleSystem {
			continue
		}
		source := workspaceSource{Source: "summary", Content: message.Content, Parents: lineage}
		raw, _ := json.Marshal(source)
		source.ID = fmt.Sprintf("derived-%x", sha256.Sum256(raw))
		data, err := workspaceData(source)
		if err != nil {
			return nil, err
		}
		out[i] = data
	}
	if budget.MaxTokens > 0 && agent.EstimateTokens(out) > budget.MaxTokens {
		return nil, agent.ErrContextBudget
	}
	return out, nil
}
