package agent

import (
	"context"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

func mergeMiddleware(in []Middleware) []Middleware {
	out := make([]Middleware, 0, len(in))
	index := make(map[string]int, len(in))
	for _, m := range in {
		if m.Name == "" {
			out = append(out, m)
			continue
		}
		if i, ok := index[m.Name]; ok {
			out[i] = m
			continue
		}
		index[m.Name] = len(out)
		out = append(out, m)
	}
	return out
}

func (a *Agent) beforeRun(ctx context.Context, state *RunState) error {
	for _, m := range a.Middleware {
		if m.BeforeRun == nil {
			continue
		}
		if err := m.BeforeRun(ctx, state); err != nil {
			return err
		}
	}
	return nil
}

func (a *Agent) beforeModel(ctx context.Context, call *ModelCall) error {
	for _, m := range a.Middleware {
		if m.BeforeModel == nil {
			continue
		}
		if err := m.BeforeModel(ctx, call); err != nil {
			return err
		}
		if call.Skip {
			break
		}
	}
	return nil
}

func (a *Agent) afterModel(ctx context.Context, call *ModelCall, resp *model.Response) error {
	for _, m := range a.Middleware {
		if m.AfterModel == nil {
			continue
		}
		if err := m.AfterModel(ctx, call, resp); err != nil {
			return err
		}
	}
	return nil
}

func (a *Agent) beforeTool(ctx context.Context, call *ToolCall) error {
	for _, m := range a.Middleware {
		if m.BeforeTool == nil {
			continue
		}
		if err := m.BeforeTool(ctx, call); err != nil {
			return err
		}
		if call.Skip {
			break
		}
	}
	return nil
}

func (a *Agent) afterTool(ctx context.Context, call *ToolCall, result *ToolResult) error {
	for _, m := range a.Middleware {
		if m.AfterTool == nil {
			continue
		}
		if err := m.AfterTool(ctx, call, result); err != nil {
			return err
		}
	}
	return nil
}

func (a *Agent) afterRun(ctx context.Context, result *Result, runErr error) error {
	for _, m := range a.Middleware {
		if m.AfterRun == nil {
			continue
		}
		if err := m.AfterRun(ctx, result, runErr); err != nil {
			return err
		}
	}
	return nil
}
