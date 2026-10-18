// Package agent implements the governed agent loop.
package agent

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/axisvela/praxo-core/v3/pkg/event"
	"github.com/axisvela/praxo-core/v3/pkg/memory"
	"github.com/axisvela/praxo-core/v3/pkg/model"
	"github.com/axisvela/praxo-core/v3/pkg/policy"
	"github.com/axisvela/praxo-core/v3/pkg/tool"
)

// ErrMaxSteps is returned when the agent exceeds its step budget.
var ErrMaxSteps = errors.New("agent: max steps exceeded")

// Session is the execution scope.
type Session struct {
	ID          string          `json:"id"`
	TenantID    string          `json:"tenantId"`
	WorkspaceID string          `json:"workspaceId"`
	Messages    []model.Message `json:"messages,omitempty"`
}

// Agent is a governed model/tool loop.
type Agent struct {
	Model    model.Model
	Tools    *tool.Registry
	Memory   memory.Store
	Events   event.Sink
	Policy   policy.Hook
	MaxSteps int
}

// Result is one completed run.
type Result struct {
	RunID  string      `json:"runId"`
	Output string      `json:"output"`
	Steps  int         `json:"steps"`
	Usage  model.Usage `json:"usage"`
}

// Run executes the loop until the model returns a final answer.
func (a *Agent) Run(ctx context.Context, session Session, prompt string) (*Result, error) {
	if a.Model == nil {
		return nil, errors.New("agent: model is required")
	}
	if a.MaxSteps <= 0 {
		a.MaxSteps = 8
	}

	runID := fmt.Sprintf("run-%d", time.Now().UnixNano())
	messages := append([]model.Message{}, session.Messages...)
	messages = append(messages, model.Message{Role: model.RoleUser, Content: prompt})

	if err := a.emit(ctx, event.Event{Type: "run.started", SessionID: session.ID, RunID: runID}); err != nil {
		return nil, err
	}

	var usage model.Usage
	for step := 1; step <= a.MaxSteps; step++ {
		if err := a.authorize(ctx, policy.Action{Kind: "model.generate", SessionID: session.ID}); err != nil {
			return nil, err
		}

		var specs []model.ToolSpec
		if a.Tools != nil {
			specs = a.Tools.Specs()
		}
		resp, err := a.Model.Generate(ctx, model.Request{Messages: messages, Tools: specs})
		if err != nil {
			return nil, err
		}
		usage.InputTokens += resp.Usage.InputTokens
		usage.OutputTokens += resp.Usage.OutputTokens
		usage.CachedTokens += resp.Usage.CachedTokens

		messages = append(messages, resp.Message)
		if len(resp.Message.ToolCalls) == 0 {
			result := &Result{RunID: runID, Output: resp.Message.Content, Steps: step, Usage: usage}
			if err := a.remember(ctx, session.ID, result); err != nil {
				return nil, err
			}
			if err := a.emit(ctx, event.Event{Type: "run.completed", SessionID: session.ID, RunID: runID}); err != nil {
				return nil, err
			}
			return result, nil
		}

		for _, call := range resp.Message.ToolCalls {
			if err := a.authorize(ctx, policy.Action{
				Kind: "tool.invoke", SessionID: session.ID, ToolName: call.Name, Arguments: call.Arguments,
			}); err != nil {
				return nil, err
			}
			if a.Tools == nil {
				return nil, errors.New("agent: model requested a tool but no registry is configured")
			}
			t, err := a.Tools.Get(call.Name)
			if err != nil {
				return nil, err
			}
			if err := a.emit(ctx, event.Event{
				Type: "tool.call", SessionID: session.ID, RunID: runID,
				Data: map[string]any{"name": call.Name, "arguments": call.Arguments},
			}); err != nil {
				return nil, err
			}
			value, err := t.Invoke(ctx, call.Arguments)
			if err != nil {
				return nil, err
			}
			raw, err := json.Marshal(value)
			if err != nil {
				return nil, err
			}
			messages = append(messages, model.Message{Role: model.RoleTool, ToolID: call.ID, Content: string(raw)})
		}
	}

	if err := a.emit(ctx, event.Event{Type: "run.failed", SessionID: session.ID, RunID: runID}); err != nil {
		return nil, err
	}
	return nil, ErrMaxSteps
}

func (a *Agent) authorize(ctx context.Context, action policy.Action) error {
	if a.Policy == nil {
		return nil
	}
	decision, err := a.Policy.Authorize(ctx, action)
	if err != nil {
		return err
	}
	if !decision.Allowed {
		return fmt.Errorf("agent: %s denied: %s", action.Kind, decision.Reason)
	}
	return nil
}

func (a *Agent) emit(ctx context.Context, e event.Event) error {
	if a.Events == nil {
		return nil
	}
	if e.At.IsZero() {
		e.At = time.Now().UTC()
	}
	return a.Events.Emit(ctx, e)
}

func (a *Agent) remember(ctx context.Context, sessionID string, result *Result) error {
	if a.Memory == nil {
		return nil
	}
	return a.Memory.Put(ctx, sessionID, memory.Record{
		ID:        result.RunID,
		Frame:     memory.FrameEvent,
		Content:   result.Output,
		CreatedAt: time.Now().UTC(),
		Metadata:  map[string]any{"steps": result.Steps},
	})
}
