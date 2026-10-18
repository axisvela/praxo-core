package middleware

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

// ModelToolSelector asks a model to choose tool names for a query.
type ModelToolSelector struct {
	Model model.Model
	// Prompt overrides the default selector instruction.
	Prompt string
	// MaxTools bounds the returned selection. Zero means no bound.
	MaxTools int
}

const defaultToolSelectorPrompt = `Select the tools needed to answer the user query.
Return only JSON in the form {"tools":["tool_name"]}.
Prefer the smallest sufficient set. Return {"tools":[]} when no tool is needed.`

// Select implements ToolSelector.
func (s ModelToolSelector) Select(ctx context.Context, query string, tools []model.ToolSpec) ([]string, error) {
	if s.Model == nil {
		return nil, fmt.Errorf("agent: tool selector model is required")
	}
	if len(tools) == 0 {
		return nil, nil
	}
	prompt := s.Prompt
	if strings.TrimSpace(prompt) == "" {
		prompt = defaultToolSelectorPrompt
	}
	var catalog strings.Builder
	for _, spec := range tools {
		fmt.Fprintf(&catalog, "\n- %s: %s", spec.Name, spec.Description)
	}
	req := model.Request{Messages: []model.Message{
		{Role: model.RoleSystem, Content: prompt},
		{Role: model.RoleUser, Content: "Query: " + query + "\nAvailable tools:" + catalog.String()},
	}}
	resp, err := s.Model.Generate(ctx, req)
	if err != nil {
		return nil, err
	}
	raw, err := extractJSON(resp.Message.Content)
	if err != nil {
		return nil, fmt.Errorf("agent: tool selector response: %w", err)
	}
	var selection struct {
		Tools []string `json:"tools"`
	}
	if err := json.Unmarshal(raw, &selection); err != nil {
		return nil, fmt.Errorf("agent: tool selector response: %w", err)
	}
	known := make(map[string]struct{}, len(tools))
	for _, spec := range tools {
		known[spec.Name] = struct{}{}
	}
	seen := make(map[string]struct{}, len(selection.Tools))
	out := make([]string, 0, len(selection.Tools))
	for _, name := range selection.Tools {
		if _, ok := known[name]; !ok {
			continue
		}
		if _, ok := seen[name]; ok {
			continue
		}
		seen[name] = struct{}{}
		out = append(out, name)
		if s.MaxTools > 0 && len(out) >= s.MaxTools {
			break
		}
	}
	return out, nil
}
