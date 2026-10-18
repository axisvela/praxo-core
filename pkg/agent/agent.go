// Package agent implements the governed agent loop.
package agent

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
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

// ErrMaxTokens is returned when the agent exceeds its token budget.
var ErrMaxTokens = errors.New("agent: max tokens exceeded")

// ErrApprovalDenied is returned when an interrupt handler rejects a tool call.
var ErrApprovalDenied = errors.New("agent: tool call denied by approval")

// ErrInterruptUnhandled is returned when a tool requires approval but no
// handler is configured.
var ErrInterruptUnhandled = errors.New("agent: approval handler not configured")

// Session is the execution scope.
type Session struct {
	ID          string          `json:"id"`
	TenantID    string          `json:"tenantId"`
	WorkspaceID string          `json:"workspaceId"`
	Messages    []model.Message `json:"messages,omitempty"`
}

// Agent is a governed model/tool loop.
type Agent struct {
	Model           model.Model
	ModelMiddleware []ModelMiddleware
	SystemPrompt    string
	Tools           *tool.Registry
	Memory          memory.Store
	Skills          SkillProvider
	SkillsLimit     int
	Events          event.Sink
	Policy          policy.Hook
	ResponseFormat  *model.ResponseFormat
	InterruptOn     map[string]bool
	OnInterrupt     func(ctx context.Context, interrupt Interrupt) (bool, error)
	MaxSteps        int
	// MaxParallelTools bounds concurrent tool invocations within one step.
	// Values <= 1 run tools sequentially.
	MaxParallelTools int
	// MaxTokens stops the run once accumulated input+output tokens exceed it.
	MaxTokens int64
	// ToolChoice is forwarded to the model (auto, none, required).
	ToolChoice string
	// AllowedTools limits both advertised and invokable tools. Empty means all.
	AllowedTools []string
	// Recall injects matching memory records into the prompt.
	Recall      bool
	RecallLimit int
	Retry       RetryPolicy
	Hooks       Hooks
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
func (a *Agent) Run(ctx context.Context, session Session, prompt string) (*Result, error) {
	return a.RunWithContext(ctx, session, prompt, nil)
}

// RunWithContext is Run with per-run context values.
func (a *Agent) RunWithContext(ctx context.Context, session Session, prompt string, rc RunContext) (result *Result, err error) {
	ctx = WithRunContext(ctx, rc)
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

	var messages []model.Message
	if a.SystemPrompt != "" {
		messages = append(messages, model.Message{Role: model.RoleSystem, Content: a.SystemPrompt})
	}
	messages = append(messages, session.Messages...)
	if a.Recall && a.Memory != nil {
		limit := a.RecallLimit
		if limit <= 0 {
			limit = 5
		}
		records, err := a.Memory.Search(ctx, session.ID, prompt, limit)
		if err != nil {
			return nil, err
		}
		if a.Hooks.OnMemoryRead != nil {
			if err := a.Hooks.OnMemoryRead(ctx, runID, records); err != nil {
				return nil, err
			}
		}
		if len(records) > 0 {
			var b strings.Builder
			b.WriteString("Relevant memory:")
			for _, record := range records {
				fmt.Fprintf(&b, "\n- [%s] %s", record.Frame, record.Content)
			}
			messages = append(messages, model.Message{Role: model.RoleSystem, Content: b.String()})
		}
	}
	if a.Skills != nil {
		limit := a.SkillsLimit
		if limit <= 0 {
			limit = 5
		}
		skills, err := a.Skills.Skills(ctx, prompt)
		if err != nil {
			return nil, err
		}
		if len(skills) > limit {
			skills = skills[:limit]
		}
		if len(skills) > 0 {
			var b strings.Builder
			b.WriteString("Relevant skills:")
			for _, skill := range skills {
				fmt.Fprintf(&b, "\n## %s\n%s\n%s", skill.Name, skill.Description, skill.Content)
			}
			messages = append(messages, model.Message{Role: model.RoleSystem, Content: b.String()})
		}
	}
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

		req := model.Request{
			Messages:       messages,
			Tools:          a.toolSpecs(),
			ToolChoice:     a.ToolChoice,
			ResponseFormat: a.ResponseFormat,
		}
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
		if a.MaxTokens > 0 && usage.InputTokens+usage.OutputTokens > a.MaxTokens {
			return nil, ErrMaxTokens
		}

		messages = append(messages, resp.Message)
		if len(resp.Message.ToolCalls) == 0 {
			result = &Result{RunID: runID, Output: resp.Message.Content, Steps: step, Usage: usage}
			if err := a.remember(ctx, runID, session.ID, result); err != nil {
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
			if !a.toolAllowed(call.Name) {
				return nil, fmt.Errorf("agent: tool %s is not allowed", call.Name)
			}
			if err := a.authorize(ctx, policy.Action{
				Kind: "tool.invoke", SessionID: session.ID, ToolName: call.Name, Arguments: call.Arguments,
			}); err != nil {
				return nil, err
			}
			if a.InterruptOn[call.Name] {
				if a.OnInterrupt == nil {
					return nil, fmt.Errorf("%w: %s", ErrInterruptUnhandled, call.Name)
				}
				if err := a.emit(ctx, event.Event{
					Type: "tool.interrupt", SessionID: session.ID, RunID: runID,
					Data: map[string]any{"name": call.Name, "arguments": call.Arguments},
				}); err != nil {
					return nil, err
				}
				approved, err := a.OnInterrupt(ctx, Interrupt{RunID: runID, SessionID: session.ID, Call: call})
				if err != nil {
					return nil, err
				}
				if !approved {
					return nil, fmt.Errorf("%w: %s", ErrApprovalDenied, call.Name)
				}
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
	call := a.baseGenerate
	for i := len(a.ModelMiddleware) - 1; i >= 0; i-- {
		call = a.ModelMiddleware[i](call)
	}
	return call(ctx, req)
}

func (a *Agent) baseGenerate(ctx context.Context, req model.Request) (model.Response, error) {
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

func (a *Agent) toolSpecs() []model.ToolSpec {
	if a.Tools == nil {
		return nil
	}
	specs := a.Tools.Specs()
	if len(a.AllowedTools) == 0 {
		return specs
	}
	allowed := make(map[string]struct{}, len(a.AllowedTools))
	for _, name := range a.AllowedTools {
		allowed[name] = struct{}{}
	}
	filtered := specs[:0]
	for _, spec := range specs {
		if _, ok := allowed[spec.Name]; ok {
			filtered = append(filtered, spec)
		}
	}
	return filtered
}

func (a *Agent) toolAllowed(name string) bool {
	if len(a.AllowedTools) == 0 {
		return true
	}
	for _, allowed := range a.AllowedTools {
		if allowed == name {
			return true
		}
	}
	return false
}

func (a *Agent) remember(ctx context.Context, runID, sessionID string, result *Result) error {
	if a.Memory == nil {
		return nil
	}
	record := memory.Record{
		ID:        result.RunID,
		Frame:     memory.FrameEvent,
		Content:   result.Output,
		CreatedAt: time.Now().UTC(),
		Metadata:  map[string]any{"steps": result.Steps},
	}
	if a.Hooks.OnMemoryWrite != nil {
		if err := a.Hooks.OnMemoryWrite(ctx, runID, record); err != nil {
			return err
		}
	}
	return a.Memory.Put(ctx, sessionID, record)
}
