package agent

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/memory"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

type preparedTool struct {
	authorizedCall []byte
	call           model.ToolCall
	tool           tool.Tool
	skip           bool
	result         any
	err            error
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
			if err := ctx.Err(); err != nil {
				out[i].err = err
				continue
			}
			out[i].value, out[i].err = invokeTool(ctx, prepared[i].tool, prepared[i].call)
		}
		return out
	}

	workers := parallel
	if workers > len(prepared) {
		workers = len(prepared)
	}
	jobs := make(chan int)
	var wg sync.WaitGroup
	for worker := 0; worker < workers; worker++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := range jobs {
				if err := ctx.Err(); err != nil {
					out[i].err = err
					continue
				}
				out[i].value, out[i].err = invokeTool(ctx, prepared[i].tool, prepared[i].call)
			}
		}()
	}
	for i := range prepared {
		if prepared[i].skip {
			out[i].value, out[i].err = prepared[i].result, prepared[i].err
			continue
		}
		select {
		case jobs <- i:
		case <-ctx.Done():
			out[i].err = ctx.Err()
		}
	}
	close(jobs)
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

func (a *Agent) stream(part StreamPart) error {
	if a.OnStream == nil {
		return nil
	}
	if part.At.IsZero() {
		part.At = time.Now().UTC()
	}
	return a.OnStream(part)
}

func (a *Agent) toolSpecs() []model.ToolSpec {
	var specs []model.ToolSpec
	if a.Tools != nil {
		specs = a.Tools.Specs()
	}
	if a.StructuredOutput != nil && a.StructuredOutput.Strategy == StructuredOutputTool {
		name := a.StructuredOutput.OutputName()
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

func (a *Agent) completeRun(ctx context.Context, sessionID string, result *Result) (bool, error) {
	if a.Hooks.OnRunComplete != nil {
		notification := *result
		if err := a.Hooks.OnRunComplete(ctx, &notification); err != nil {
			return false, err
		}
	}
	if err := a.stream(StreamPart{
		RunID: result.RunID, SessionID: sessionID, Kind: StreamCheckpoint, Step: result.Steps, Data: *result,
	}); err != nil {
		return false, err
	}
	if err := a.remember(ctx, result.RunID, sessionID, result); err != nil {
		return false, err
	}
	return true, a.emit(ctx, event.Event{Type: "run.completed", SessionID: sessionID, RunID: result.RunID})
}
