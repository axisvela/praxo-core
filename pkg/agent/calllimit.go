package agent

import (
	"context"
	"errors"
	"sync"
)

// ErrModelCallLimit is returned when a run exceeds its model call budget.
var ErrModelCallLimit = errors.New("agent: model call limit exceeded")

// ErrToolCallLimit is returned when a run exceeds its tool call budget.
var ErrToolCallLimit = errors.New("agent: tool call limit exceeded")

// CallLimitMiddleware bounds model and tool calls per run. A limit <= 0 is
// unlimited. Limits are isolated by RunID.
func CallLimitMiddleware(modelLimit, toolLimit int) Middleware {
	var mu sync.Mutex
	counts := make(map[string]*callCount)

	get := func(runID string) *callCount {
		mu.Lock()
		defer mu.Unlock()
		count := counts[runID]
		if count == nil {
			count = &callCount{}
			counts[runID] = count
		}
		return count
	}

	return Middleware{
		Name: "call-limit",
		BeforeRun: func(_ context.Context, state *RunState) error {
			mu.Lock()
			defer mu.Unlock()
			counts[state.RunID] = &callCount{}
			return nil
		},
		BeforeModel: func(_ context.Context, call *ModelCall) error {
			count := get(call.RunID)
			mu.Lock()
			defer mu.Unlock()
			count.models++
			if modelLimit > 0 && count.models > modelLimit {
				return ErrModelCallLimit
			}
			return nil
		},
		BeforeTool: func(_ context.Context, call *ToolCall) error {
			count := get(call.RunID)
			mu.Lock()
			defer mu.Unlock()
			count.tools++
			if toolLimit > 0 && count.tools > toolLimit {
				return ErrToolCallLimit
			}
			return nil
		},
		AfterRun: func(_ context.Context, result *Result, _ error) error {
			if result == nil {
				return nil
			}
			mu.Lock()
			defer mu.Unlock()
			delete(counts, result.RunID)
			return nil
		},
	}
}

type callCount struct {
	models int
	tools  int
}
