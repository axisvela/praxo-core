package bridge

import (
	"context"

	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/plugin"
)

// Model adapts a model.provider.v1 host to model.Model.
type Model struct{ caller }

// NewModel returns a model bridge.
func NewModel(inv Invoker, contract plugin.Contract, opts ...Option) *Model {
	return &Model{caller: newCaller(inv, contract, opts...)}
}

// Generate implements model.Model.
func (m *Model) Generate(ctx context.Context, req model.Request) (model.Response, error) {
	var out model.Response
	err := m.request(ctx, req, &out)
	return out, err
}
