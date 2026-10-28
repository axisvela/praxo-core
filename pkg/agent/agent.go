package agent

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/axisvela/praxo-core/v2/internal/runid"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/memory"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
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
	// OnStream receives typed run-stream projections.
	OnStream func(StreamPart) error
	// OnDelta receives streamed text fragments when Model implements
	// model.StreamingModel. It may be nil.
	OnDelta func(delta string)
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
	ctx = runid.With(ctx, runID)
	entered := 0
	admitted := false
	defer func() {
		if afterErr := a.afterRun(ctx, result, err, entered); afterErr != nil && err == nil {
			err = afterErr
		}
		if !admitted {
			return
		}
		completed := false
		if err == nil && result != nil {
			completed, err = a.completeRun(ctx, session.ID, result)
		}
		if err == nil {
			return
		}
		if !completed {
			_ = a.emit(ctx, event.Event{
				Type: "run.failed", SessionID: session.ID, RunID: runID,
				Data: map[string]any{"error": err.Error()},
			})
		}
		if a.Hooks.OnRunError != nil {
			a.Hooks.OnRunError(ctx, runID, err)
		}
	}()
	if err = a.beforeRun(ctx, &RunState{RunID: runID, Session: &session, Prompt: &prompt}, &entered); err != nil {
		return nil, err
	}
	admitted = true

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

	if err := a.stream(StreamPart{
		RunID: runID, SessionID: session.ID, Kind: StreamValues,
		Data: map[string]any{"prompt": prompt, "messages": len(messages)},
	}); err != nil {
		return nil, err
	}
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
			overBudget := estimateTokens(messages) > a.Context.MaxTokens
			if a.Compactor != nil && overBudget {
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
			messages = compacted
			if overBudget {
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
		if err := a.stream(StreamPart{
			RunID: runID, SessionID: session.ID, Kind: StreamMessages, Step: step, Data: resp.Message,
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
			return result, nil
		}

		if a.StructuredOutput != nil && a.StructuredOutput.Strategy == StructuredOutputTool {
			for _, call := range resp.Message.ToolCalls {
				if call.Name != a.StructuredOutput.OutputName() {
					continue
				}
				if err := a.StructuredOutput.ValidateArguments(call.Arguments); err != nil {
					return nil, fmt.Errorf("%w: %v", ErrStructuredOutput, err)
				}
				raw, err := json.Marshal(call.Arguments)
				if err != nil {
					return nil, err
				}
				result = &Result{RunID: runID, Output: string(raw), Steps: step, Usage: usage}
				return result, nil
			}
		}

		prepared := make([]preparedTool, 0, len(resp.Message.ToolCalls))
		for _, call := range resp.Message.ToolCalls {
			if !a.toolAllowed(call.Name) {
				return nil, fmt.Errorf("agent: tool %s is not allowed", call.Name)
			}
			var authorizedCall []byte
			if a.Policy != nil {
				var err error
				authorizedCall, err = json.Marshal(call)
				if err != nil {
					return nil, err
				}
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
			if err := a.stream(StreamPart{
				RunID: runID, SessionID: session.ID, Kind: StreamTasks, Step: step,
				Data: map[string]any{"status": "start", "name": call.Name, "arguments": call.Arguments},
			}); err != nil {
				return nil, err
			}
			prepared = append(prepared, preparedTool{call: call, tool: t, authorizedCall: authorizedCall})
		}

		for _, item := range prepared {
			if item.skip {
				continue
			}
			if !a.toolAllowed(item.call.Name) {
				return nil, fmt.Errorf("agent: tool %s is not allowed", item.call.Name)
			}
			if a.Policy != nil {
				finalCall, err := json.Marshal(item.call)
				if err != nil {
					return nil, err
				}
				if !bytes.Equal(item.authorizedCall, finalCall) {
					if err := a.authorize(ctx, policy.Action{
						Kind: "tool.invoke", SessionID: session.ID, ToolName: item.call.Name, Arguments: item.call.Arguments,
					}); err != nil {
						return nil, err
					}
				}
			}
		}

		outcomes := runTools(ctx, prepared, a.MaxParallelTools)
		for i, outcome := range outcomes {
			call := prepared[i].call
			result := &ToolResult{Value: outcome.value, Err: outcome.err}
			if err := a.afterTool(ctx, &ToolCall{RunID: runID, SessionID: session.ID, Call: &call}, result); err != nil {
				return nil, err
			}
			taskData := map[string]any{"status": "end", "name": call.Name, "result": result.Value}
			if result.Err != nil {
				taskData["error"] = result.Err.Error()
			}
			if err := a.stream(StreamPart{
				RunID: runID, SessionID: session.ID, Kind: StreamTasks, Step: step, Data: taskData,
			}); err != nil {
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
			if err := a.stream(StreamPart{
				RunID: runID, SessionID: session.ID, Kind: StreamUpdates, Step: step,
				Data: map[string]any{"messages": len(messages), "tool": call.Name},
			}); err != nil {
				return nil, err
			}
		}
	}

	return nil, ErrMaxSteps
}
