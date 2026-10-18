// Package agent implements the governed agent loop.
package agent

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/axisvela/praxo-core/pkg/event"
	"github.com/axisvela/praxo-core/pkg/memory"
	"github.com/axisvela/praxo-core/pkg/model"
	"github.com/axisvela/praxo-core/pkg/policy"
	"github.com/axisvela/praxo-core/pkg/tool"
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
	// MaxParallelTools bounds concurrent tool invocations within one step.
	// Values <= 1 run tools sequentially.
	MaxParallelTools int
	Retry            RetryPolicy
	Hooks            Hooks
	// OnDelta receives streamed text fragments when Model implements
	// model.StreamingModel. It may be nil.
	OnDelta func(delta string)
}

// Result is one completed run.
type Result struct {
	RunID  string      `json:"runId"`
	Output string      `json:"output"`
	Steps  int         `json:"steps"`
	Usage  model.Usage `json:"usage"`
}

// Run executes the loop until the model returns a final answer.
func (a *Agent) Run(ctx context.Context, session Session, prompt string) (result *Result, err error) {
	if a.Model == nil {
		return nil, errors.New("agent: model is required")
	}
	maxSteps := a.MaxSteps
	if maxSteps <= 0 {
		maxSteps = 8
	}

	runID := fmt.Sprintf("run-%d", time.Now().UnixNano())
	defer func() {
		if err == nil {
			return
		}
		_ = a.emit(ctx, event.Event{
			Type: "run.failed", SessionID: session.ID, RunID: runID,
			Data: map[string]any{"error": err.Error()},
		})
		if a.Hooks.OnRunError != nil {
			a.Hooks.OnRunError(ctx, runID, err)
		}
	}()

	if a.Hooks.OnRunStart != nil {
		if err := a.Hooks.OnRunStart(ctx, runID, session); err != nil {
			return nil, err
		}
	}

	messages := append([]model.Message{}, session.Messages...)
	messages = append(messages, model.Message{Role: model.RoleUser, Content: prompt})

	if err := a.emit(ctx, event.Event{Type: "run.started", SessionID: session.ID, RunID: runID}); err != nil {
		return nil, err
	}

	var usage model.Usage
	for step := 1; step <= maxSteps; step++ {
		if a.Hooks.OnStep != nil {
			if err := a.Hooks.OnStep(ctx, runID, step, messages); err != nil {
				return nil, err
			}
		}

		if err := a.authorize(ctx, policy.Action{Kind: "model.generate", SessionID: session.ID}); err != nil {
			return nil, err
		}

		var specs []model.ToolSpec
		if a.Tools != nil {
			specs = a.Tools.Specs()
		}
		req := model.Request{Messages: messages, Tools: specs}
		if a.Hooks.OnModelCall != nil {
			if err := a.Hooks.OnModelCall(ctx, runID, req); err != nil {
				return nil, err
			}
		}

		var resp model.Response
		if err := a.Retry.Do(ctx, func() error {
			var callErr error
			resp, callErr = a.generate(ctx, req)
			return callErr
		}); err != nil {
			return nil, err
		}

		if a.Hooks.OnModelResult != nil {
			if err := a.Hooks.OnModelResult(ctx, runID, resp); err != nil {
				return nil, err
			}
		}
		usage.InputTokens += resp.Usage.InputTokens
		usage.OutputTokens += resp.Usage.OutputTokens
		usage.CachedTokens += resp.Usage.CachedTokens

		messages = append(messages, resp.Message)
		if len(resp.Message.ToolCalls) == 0 {
			result = &Result{RunID: runID, Output: resp.Message.Content, Steps: step, Usage: usage}
			if err := a.remember(ctx, session.ID, result); err != nil {
				return nil, err
			}
			if err := a.emit(ctx, event.Event{Type: "run.completed", SessionID: session.ID, RunID: runID}); err != nil {
				return nil, err
			}
			if a.Hooks.OnRunComplete != nil {
				if err := a.Hooks.OnRunComplete(ctx, result); err != nil {
					return nil, err
				}
			}
			return result, nil
		}

		prepared := make([]preparedTool, 0, len(resp.Message.ToolCalls))
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
			if a.Hooks.OnToolCall != nil {
				if err := a.Hooks.OnToolCall(ctx, runID, call); err != nil {
					return nil, err
				}
			}
			if err := a.emit(ctx, event.Event{
				Type: "tool.call", SessionID: session.ID, RunID: runID,
				Data: map[string]any{"name": call.Name, "arguments": call.Arguments},
			}); err != nil {
				return nil, err
			}
			prepared = append(prepared, preparedTool{call: call, tool: t})
		}

		outcomes := runTools(ctx, prepared, a.MaxParallelTools)
		for i, outcome := range outcomes {
			call := prepared[i].call
			if a.Hooks.OnToolResult != nil {
				if err := a.Hooks.OnToolResult(ctx, runID, call, outcome.value, outcome.err); err != nil {
					return nil, err
				}
			}
			if outcome.err != nil {
				return nil, outcome.err
			}
			raw, err := json.Marshal(outcome.value)
			if err != nil {
				return nil, err
			}
			messages = append(messages, model.Message{Role: model.RoleTool, ToolID: call.ID, Content: string(raw)})
		}
	}

	return nil, ErrMaxSteps
}

type preparedTool struct {
	call model.ToolCall
	tool tool.Tool
}

type toolOutcome struct {
	value any
	err   error
}

func runTools(ctx context.Context, prepared []preparedTool, parallel int) []toolOutcome {
	out := make([]toolOutcome, len(prepared))
	if parallel <= 1 || len(prepared) <= 1 {
		for i := range prepared {
			out[i].value, out[i].err = invokeTool(ctx, prepared[i].tool, prepared[i].call)
		}
		return out
	}

	sem := make(chan struct{}, parallel)
	var wg sync.WaitGroup
	for i := range prepared {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()
			out[i].value, out[i].err = invokeTool(ctx, prepared[i].tool, prepared[i].call)
		}(i)
	}
	wg.Wait()
	return out
}

func invokeTool(ctx context.Context, t tool.Tool, call model.ToolCall) (value any, err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("agent: tool %s panicked: %v", call.Name, r)
		}
	}()
	return t.Invoke(ctx, call.Arguments)
}

func (a *Agent) generate(ctx context.Context, req model.Request) (model.Response, error) {
	if a.OnDelta != nil {
		if streaming, ok := a.Model.(model.StreamingModel); ok {
			return streaming.GenerateStream(ctx, req, a.OnDelta)
		}
	}
	return a.Model.Generate(ctx, req)
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
