package main

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/memory"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

var errWorkspaceContext = errors.New("workspace: invalid context trust boundary")

const workspaceContextFormat = "workspace-context/v1"

type workspaceContext struct {
	Memory         []memory.Record
	Skills         []agent.Skill
	ApprovedSkills map[string][32]byte
	Summarizer     model.Model
}

type workspaceSource struct {
	Format       string   `json:"format"`
	Source       string   `json:"source"`
	ID           string   `json:"id"`
	Trust        string   `json:"trust"`
	Content      string   `json:"content"`
	Parents      []string `json:"parents,omitempty"`
	OriginalRole string   `json:"originalRole,omitempty"`
}

func runWithWorkspaceContext(ctx context.Context, opts agent.Options, session agent.Session, prompt string, sources workspaceContext) (*agent.Result, error) {
	if strings.TrimSpace(opts.SystemPrompt) == "" || opts.Recall || opts.Skills != nil || len(opts.MemoryFiles) > 0 || opts.Compactor != nil || opts.Offloader != nil {
		return nil, fmt.Errorf("%w: explicit instructions and managed sources are required", errWorkspaceContext)
	}
	if sources.Summarizer != nil && workspaceControlMissing(sources.Summarizer) {
		return nil, fmt.Errorf("%w: nil summarizer", errWorkspaceContext)
	}
	if opts.FallbackModel != nil && workspaceControlMissing(opts.FallbackModel) {
		return nil, fmt.Errorf("%w: nil fallback", errWorkspaceContext)
	}
	var messages []model.Message
	seen := make(map[string]bool)
	add := func(source workspaceSource) error {
		key := source.Source + "/" + source.ID
		if seen[key] {
			return fmt.Errorf("%w: duplicate source", errWorkspaceContext)
		}
		message, err := workspaceData(source)
		if err != nil {
			return err
		}
		seen[key] = true
		messages = append(messages, message)
		return nil
	}
	for i, message := range session.Messages {
		if message.Role != model.RoleUser && message.Role != model.RoleAssistant || len(message.ContentBlocks) > 0 || len(message.ToolCalls) > 0 || message.ToolID != "" {
			return nil, fmt.Errorf("%w: restore text history explicitly", errWorkspaceContext)
		}
		source, matched, err := parseWorkspaceSource(message.Content)
		if err != nil {
			return nil, err
		}
		if !matched {
			source = workspaceSource{Source: "history", ID: fmt.Sprintf("history-%d", i), Content: message.Content, OriginalRole: string(message.Role)}
		}
		if err := add(source); err != nil {
			return nil, err
		}
	}
	for _, record := range sources.Memory {
		if err := add(workspaceSource{Source: "memory", ID: record.ID, Content: record.Content}); err != nil {
			return nil, err
		}
	}
	skillNames := make(map[string]bool)
	for _, skill := range sources.Skills {
		if strings.TrimSpace(skill.Name) == "" || skillNames[skill.Name] {
			return nil, fmt.Errorf("%w: invalid skill identity", errWorkspaceContext)
		}
		skillNames[skill.Name] = true
		if approved, ok := sources.ApprovedSkills[skill.Name]; ok {
			if approved != workspaceSkillDigest(skill) {
				return nil, fmt.Errorf("%w: approved skill content changed", errWorkspaceContext)
			}
			opts.SystemPrompt += "\n\nApproved skill: " + skill.Name + "\n" + skill.Description + "\n" + skill.Content
			continue
		}
		if err := add(workspaceSource{Source: "skill", ID: skill.Name, Content: skill.Description + "\n" + skill.Content}); err != nil {
			return nil, err
		}
	}
	session.Messages = messages
	boundary := workspaceContextCompactor{system: opts.SystemPrompt, summarizer: sources.Summarizer}
	opts.Compactor = boundary
	if opts.Context != nil {
		budget := *opts.Context
		opts.Context = &budget
	}
	opts.ModelMiddleware = append(append([]agent.ModelMiddleware(nil), opts.ModelMiddleware...), func(next func(context.Context, model.Request) (model.Response, error)) func(context.Context, model.Request) (model.Response, error) {
		return func(ctx context.Context, req model.Request) (model.Response, error) {
			messages, err := boundary.normalize(req.Messages)
			if err != nil {
				return model.Response{}, err
			}
			if opts.Context != nil && opts.Context.MaxTokens > 0 && agent.EstimateTokens(messages) > opts.Context.MaxTokens {
				return model.Response{}, agent.ErrContextBudget
			}
			req.Messages = messages
			return next(ctx, req)
		}
	})
	return runGovernedWorkspace(ctx, opts, session, prompt)
}

func workspaceSkillDigest(skill agent.Skill) [32]byte {
	raw, _ := json.Marshal(skill)
	return sha256.Sum256(raw)
}

func workspaceData(source workspaceSource) (model.Message, error) {
	source.Format = workspaceContextFormat
	source.Trust = "untrusted"
	raw, err := json.Marshal(source)
	if err != nil {
		return model.Message{}, err
	}
	if _, _, err := parseWorkspaceSource(string(raw)); err != nil {
		return model.Message{}, err
	}
	return model.Message{Role: model.RoleUser, Content: string(raw)}, nil
}

func parseWorkspaceSource(content string) (workspaceSource, bool, error) {
	var source workspaceSource
	if json.Unmarshal([]byte(content), &source) != nil || source.Format != workspaceContextFormat {
		return source, false, nil
	}
	validKind := source.Source == "memory" || source.Source == "skill" || source.Source == "history" || source.Source == "tool" || source.Source == "summary"
	if !validKind || strings.TrimSpace(source.ID) == "" || source.Trust != "untrusted" || (source.Source == "summary" && len(source.Parents) == 0) {
		return source, true, errWorkspaceContext
	}
	parents := make(map[string]bool)
	for _, parent := range source.Parents {
		if strings.TrimSpace(parent) == "" || parents[parent] || parent == source.Source+"/"+source.ID {
			return source, true, errWorkspaceContext
		}
		parents[parent] = true
	}
	return source, true, nil
}

func restoreWorkspaceMessages(raw []byte) ([]model.Message, error) {
	var messages []model.Message
	if err := json.Unmarshal(raw, &messages); err != nil {
		return nil, err
	}
	out := make([]model.Message, 0, len(messages))
	for i, message := range messages {
		if len(message.ContentBlocks) > 0 || len(message.ToolCalls) > 0 || message.ToolID != "" || message.Role == model.RoleTool {
			return nil, fmt.Errorf("%w: only text history restore is supported", errWorkspaceContext)
		}
		source, matched, err := parseWorkspaceSource(message.Content)
		if err != nil {
			return nil, err
		}
		if !matched {
			source = workspaceSource{Source: "history", ID: fmt.Sprintf("restored-%d", i), Content: message.Content, OriginalRole: string(message.Role)}
		}
		data, err := workspaceData(source)
		if err != nil {
			return nil, err
		}
		out = append(out, data)
	}
	return out, nil
}
