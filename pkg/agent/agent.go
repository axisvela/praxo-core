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
	Middleware      []Middleware
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
	// OnInterruptDecision, when set, takes precedence over OnInterrupt and
	// supports approve/edit/reject/respond decisions.
	OnInterruptDecision InterruptHandler
	MaxSteps            int
	// MaxParallelTools bounds concurrent tool invocations within one step.
	// Values <= 1 run tools sequentially.
	MaxParallelTools int
	// MaxTokens stops the run once accumulated input+output tokens exceed it.
	MaxTokens int64
	// Context bounds the estimated prompt size before each model call.
	Context *ContextBudget
	// Compactor optionally summarizes or offloads older context before the
	// deterministic budget pass.
	Compactor ContextCompactor
	// Offloader stores large tool results outside the prompt when the result
	// exceeds OffloadThresholdBytes.
	Offloader             Offloader
	OffloadThresholdBytes int
	// PromptCache returns provider cache hints for the current prompt.
	PromptCache func([]model.Message) *model.CacheHint
	// StructuredOutput optionally binds a JSON schema to this agent.
	StructuredOutput *StructuredOutput
	// ToolChoice is forwarded to the model (auto, none, required).
	ToolChoice string
	// AllowedTools limits both advertised and invokable tools. Empty means all.
	AllowedTools []string
	// Recall injects matching memory records into the prompt.
	Recall      bool
	RecallLimit int
	Retry       RetryPolicy
	// ToolRetry optionally wraps each resolved tool with retry semantics.
	ToolRetry *tool.RetryPolicy
	Hooks     Hooks
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
	if err := a.beforeRun(ctx, &RunState{RunID: runID, Session: &session, Prompt: &prompt}); err != nil {
		return nil, err
	}
	defer func() {
		if afterErr := a.afterRun(ctx, result, err); afterErr != nil && err == nil {
			err = afterErr
		}
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

		if a.Context != nil && a.Context.MaxTokens > 0 {
			before := len(messages)
			if a.Compactor != nil && estimateTokens(messages) > a.Context.MaxTokens {
				compacted, err := a.Compactor.Compact(ctx, messages, *a.Context)
				if err != nil {
					return nil, err
				}
				messages = compacted
			}
			compacted, ok := a.Context.Compact(messages)
			if !ok {
				return nil, ErrContextBudget
			}
			if len(compacted) != before {
				messages = compacted
				if a.Hooks.OnCompaction != nil {
					if err := a.Hooks.OnCompaction(ctx, runID, before, len(compacted)); err != nil {
						return nil, err
					}
				}
			}
		}

		req := model.Request{
			Messages:       messages,
			Tools:          a.toolSpecs(),
			ToolChoice:     a.ToolChoice,
			ResponseFormat: a.ResponseFormat,
		}
		if a.PromptCache != nil {
			req.CacheHint = a.PromptCache(messages)
		}
		mc := &ModelCall{RunID: runID, SessionID: session.ID, Request: &req}
		if err := a.beforeModel(ctx, mc); err != nil {
			return nil, err
		}
		if a.Hooks.OnModelCall != nil {
			if err := a.Hooks.OnModelCall(ctx, runID, req); err != nil {
				return nil, err
			}
		}

		var resp model.Response
		if mc.Skip {
			if mc.Response == nil {
				return nil, errors.New("agent: model middleware skipped without a response")
			}
			resp = *mc.Response
		} else if err := a.Retry.Do(ctx, func() error {
			var callErr error
			resp, callErr = a.generate(ctx, req)
			return callErr
		}); err != nil {
			return nil, err
		}
		if err := a.afterModel(ctx, mc, &resp); err != nil {
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

		if a.StructuredOutput != nil && a.StructuredOutput.Strategy == StructuredOutputTool {
			for _, call := range resp.Message.ToolCalls {
				if call.Name != a.StructuredOutput.outputName() {
					continue
				}
				if err := a.StructuredOutput.validateArguments(call.Arguments); err != nil {
					return nil, fmt.Errorf("%w: %v", ErrStructuredOutput, err)
				}
				raw, err := json.Marshal(call.Arguments)
				if err != nil {
					return nil, err
				}
				result = &Result{RunID: runID, Output: string(raw), Steps: step, Usage: usage}
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
			tc := &ToolCall{RunID: runID, SessionID: session.ID, Call: &call}
			if err := a.beforeTool(ctx, tc); err != nil {
				return nil, err
			}
			if tc.Skip {
				prepared = append(prepared, preparedTool{call: call, skip: true, result: tc.Result, err: tc.Err})
				continue
			}
			if a.InterruptOn[call.Name] {
				if a.OnInterruptDecision == nil && a.OnInterrupt == nil {
					return nil, fmt.Errorf("%w: %s", ErrInterruptUnhandled, call.Name)
				}
				if err := a.emit(ctx, event.Event{
					Type: "tool.interrupt", SessionID: session.ID, RunID: runID,
					Data: map[string]any{"name": call.Name, "arguments": call.Arguments},
				}); err != nil {
					return nil, err
				}
				interrupt := Interrupt{RunID: runID, SessionID: session.ID, Call: call}
				if a.OnInterruptDecision != nil {
					decision, err := a.OnInterruptDecision(ctx, interrupt)
					if err != nil {
						return nil, err
					}
					switch decision.Action {
					case InterruptApprove:
					case InterruptEdit:
						if decision.Arguments == nil {
							return nil, fmt.Errorf("%w: edit requires arguments", ErrInterruptDecisionInvalid)
						}
						call.Arguments = decision.Arguments
					case InterruptReject:
						return nil, fmt.Errorf("%w: %s: %s", ErrApprovalDenied, call.Name, decision.Reason)
					case InterruptRespond:
						prepared = append(prepared, preparedTool{call: call, skip: true, result: decision.Response})
						continue
					default:
						return nil, fmt.Errorf("%w: %q", ErrInterruptDecisionInvalid, decision.Action)
					}
				} else {
					approved, err := a.OnInterrupt(ctx, interrupt)
					if err != nil {
						return nil, err
					}
					if !approved {
						return nil, fmt.Errorf("%w: %s", ErrApprovalDenied, call.Name)
					}
				}
			}
			if a.Tools == nil {
				return nil, errors.New("agent: model requested a tool but no registry is configured")
			}
			t, err := a.Tools.Get(call.Name)
			if err != nil {
				return nil, err
			}
			if a.ToolRetry != nil {
				t = tool.Wrap(t, tool.Retry(*a.ToolRetry))
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
			result := &ToolResult{Value: outcome.value, Err: outcome.err}
			if err := a.afterTool(ctx, &ToolCall{RunID: runID, SessionID: session.ID, Call: &call}, result); err != nil {
				return nil, err
			}
			if a.Hooks.OnToolResult != nil {
				if err := a.Hooks.OnToolResult(ctx, runID, call, result.Value, result.Err); err != nil {
					return nil, err
				}
			}
			if result.Err != nil {
				return nil, result.Err
			}
			raw, err := json.Marshal(result.Value)
			if err != nil {
				return nil, err
			}
			content := string(raw)
			if a.Offloader != nil && a.OffloadThresholdBytes > 0 && len(raw) > a.OffloadThresholdBytes {
				ref, err := a.Offloader.Offload(ctx, call.Name, call.ID, raw)
				if err != nil {
					return nil, err
				}
				if ref == "" {
					return nil, errors.New("agent: offloader returned an empty placeholder")
				}
				content = ref
				if a.Hooks.OnOffload != nil {
					if err := a.Hooks.OnOffload(ctx, runID, call.Name, len(raw), len(ref)); err != nil {
						return nil, err
					}
				}
			}
			messages = append(messages, model.Message{Role: model.RoleTool, ToolID: call.ID, Content: content})
		}
	}

	return nil, ErrMaxSteps
}

type preparedTool struct {
	call   model.ToolCall
	tool   tool.Tool
	skip   bool
	result any
	err    error
}

type toolOutcome struct {
	value any
	err   error
}

func runTools(ctx context.Context, prepared []preparedTool, parallel int) []toolOutcome {
	out := make([]toolOutcome, len(prepared))
	if parallel <= 1 || len(prepared) <= 1 {
		for i := range prepared {
			if prepared[i].skip {
				out[i].value, out[i].err = prepared[i].result, prepared[i].err
				continue
			}
			out[i].value, out[i].err = invokeTool(ctx, prepared[i].tool, prepared[i].call)
		}
		return out
	}

	sem := make(chan struct{}, parallel)
	var wg sync.WaitGroup
	for i := range prepared {
		if prepared[i].skip {
			out[i].value, out[i].err = prepared[i].result, prepared[i].err
			continue
		}
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
	var specs []model.ToolSpec
	if a.Tools != nil {
		specs = a.Tools.Specs()
	}
	if a.StructuredOutput != nil && a.StructuredOutput.Strategy == StructuredOutputTool {
		name := a.StructuredOutput.outputName()
		found := false
		for _, spec := range specs {
			if spec.Name == name {
				found = true
				break
			}
		}
		if !found {
			specs = append(specs, a.StructuredOutput.ToolSpec())
		}
	}
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
