package tool

import (
	"context"

	"github.com/axisvela/praxo-core/pkg/model"
)

// SpecProvider lets a tool expose a full model-visible spec.
type SpecProvider interface {
	Spec() model.ToolSpec
}

// Middleware wraps a tool.
type Middleware func(next Tool) Tool

// Wrap applies middleware in order.
func Wrap(t Tool, middlewares ...Middleware) Tool {
	wrapped := t
	for i := len(middlewares) - 1; i >= 0; i-- {
		wrapped = middlewares[i](wrapped)
	}
	return wrapped
}

// MiddlewareFunc adapts a function to a named tool wrapper.
func MiddlewareFunc(name, description string, invoke func(context.Context, map[string]any) (any, error)) Middleware {
	return func(next Tool) Tool {
		return &wrappedTool{name: name, description: description, invoke: invoke, next: next}
	}
}

type wrappedTool struct {
	name        string
	description string
	invoke      func(context.Context, map[string]any) (any, error)
	next        Tool
}

func (w *wrappedTool) Name() string        { return w.name }
func (w *wrappedTool) Description() string { return w.description }
func (w *wrappedTool) Invoke(ctx context.Context, args map[string]any) (any, error) {
	return w.invoke(ctx, args)
}
