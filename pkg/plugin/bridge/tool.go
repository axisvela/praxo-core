package bridge

import (
	"context"
	"encoding/json"

	"github.com/axisvela/praxo-core/pkg/plugin"
)

type toolInvokeRequest struct {
	Name      string         `json:"name"`
	Arguments map[string]any `json:"arguments"`
}

// Tool adapts a tool.provider.v1 host to tool.Tool.
type Tool struct {
	caller
	name        string
	description string
}

// NewTool returns a tool bridge.
func NewTool(inv Invoker, contract plugin.Contract, opts ...Option) *Tool {
	c := newCaller(inv, contract, opts...)
	name := c.cfg.toolName
	if name == "" {
		name = contract.Service
	}
	return &Tool{caller: c, name: name, description: c.cfg.toolDescription}
}

// Name implements tool.Tool.
func (t *Tool) Name() string { return t.name }

// Description implements tool.Tool.
func (t *Tool) Description() string { return t.description }

// Invoke implements tool.Tool.
func (t *Tool) Invoke(ctx context.Context, args map[string]any) (any, error) {
	raw, err := t.invokeRaw(ctx, toolInvokeRequest{Name: t.name, Arguments: args})
	if err != nil {
		return nil, err
	}
	if len(raw) == 0 {
		return nil, nil
	}
	var out any
	if err := json.Unmarshal(raw, &out); err != nil {
		return string(raw), nil
	}
	return out, nil
}
