package bridge

import (
	"context"

	"github.com/axisvela/praxo-core/v2/pkg/plugin"
)

// Adapter returns a contract-bound adapter for the guarded AdapterRegistry.
// The caller still supplies a concrete GuardSet when registering it.
func Adapter(inv Invoker, contract plugin.Contract, opts ...Option) plugin.Adapter {
	cfg := newConfig(contract, opts...)
	return plugin.Adapter{
		Contract: plugin.ServiceRef{Service: contract.Service, Version: contract.Version},
		Name:     string(contract.Kind),
		Provider: cfg.provider,
		Invoke: func(ctx context.Context, payload []byte) ([]byte, error) {
			return caller{inv: inv, contract: contract, cfg: cfg}.call(ctx, payload)
		},
	}
}
