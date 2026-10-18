package bridge

import (
	"context"

	"github.com/axisvela/praxo-core/v2/pkg/plugin"
	"github.com/axisvela/praxo-core/v2/pkg/sandbox"
)

type sandboxExecuteRequest struct {
	Spec    sandbox.Spec `json:"spec"`
	Command []string     `json:"command"`
}

// Sandbox adapts a sandbox.provider.v1 host to sandbox.Sandbox.
type Sandbox struct{ caller }

// NewSandbox returns a sandbox bridge.
func NewSandbox(inv Invoker, contract plugin.Contract, opts ...Option) *Sandbox {
	return &Sandbox{caller: newCaller(inv, contract, opts...)}
}

// Run implements sandbox.Sandbox.
func (s *Sandbox) Run(ctx context.Context, spec sandbox.Spec, command []string) (sandbox.Result, error) {
	var out sandbox.Result
	err := s.request(ctx, sandboxExecuteRequest{Spec: spec, Command: command}, &out)
	return out, err
}
