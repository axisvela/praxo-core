package bridge

import (
	"context"

	"github.com/axisvela/praxo-core/v2/pkg/plugin"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
)

// Policy adapts a policy.provider.v1 host to policy.Hook.
type Policy struct{ caller }

// NewPolicy returns a policy bridge.
func NewPolicy(inv Invoker, contract plugin.Contract, opts ...Option) *Policy {
	return &Policy{caller: newCaller(inv, contract, opts...)}
}

// Authorize implements policy.Hook.
func (p *Policy) Authorize(ctx context.Context, action policy.Action) (policy.Decision, error) {
	var out policy.Decision
	err := p.request(ctx, action, &out)
	return out, err
}
