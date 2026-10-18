package middleware

import (
	"context"
	"errors"
	"sync"

	"github.com/axisvela/praxo-core/v2/pkg/agent/types"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

// ErrToolNotSelected is returned when the model calls a tool that the
// selection middleware did not advertise for the current run.
var ErrToolNotSelected = errors.New("agent: tool not selected")

// ToolSelector chooses which tool names to advertise for a query. Products may
// implement it with keyword matching or a small classifier model.
type ToolSelector interface {
	Select(ctx context.Context, query string, tools []model.ToolSpec) ([]string, error)
}

// ToolSelectionMiddleware narrows the advertised tool set before each model
// call and rejects calls to tools that were not selected for that run.
func ToolSelectionMiddleware(selector ToolSelector) types.Middleware {
	var mu sync.Mutex
	selected := make(map[string]map[string]struct{})

	return types.Middleware{
		Name: "tool-selection",
		BeforeModel: func(ctx context.Context, call *types.ModelCall) error {
			if call.Request == nil || selector == nil {
				return nil
			}
			names, err := selector.Select(ctx, lastUserMessage(call.Request.Messages), call.Request.Tools)
			if err != nil {
				return err
			}
			set := make(map[string]struct{}, len(names))
			for _, name := range names {
				set[name] = struct{}{}
			}
			mu.Lock()
			selected[call.RunID] = set
			mu.Unlock()

			filtered := make([]model.ToolSpec, 0, len(names))
			for _, spec := range call.Request.Tools {
				if _, ok := set[spec.Name]; ok {
					filtered = append(filtered, spec)
				}
			}
			call.Request.Tools = filtered
			return nil
		},
		BeforeTool: func(_ context.Context, call *types.ToolCall) error {
			if call.Call == nil {
				return nil
			}
			mu.Lock()
			set, ok := selected[call.RunID]
			mu.Unlock()
			if !ok {
				return nil
			}
			if _, ok := set[call.Call.Name]; !ok {
				return ErrToolNotSelected
			}
			return nil
		},
		AfterRun: func(_ context.Context, result *types.Result, _ error) error {
			if result == nil {
				return nil
			}
			mu.Lock()
			defer mu.Unlock()
			delete(selected, result.RunID)
			return nil
		},
	}
}

func lastUserMessage(messages []model.Message) string {
	for i := len(messages) - 1; i >= 0; i-- {
		if messages[i].Role == model.RoleUser {
			return messages[i].Content
		}
	}
	return ""
}
