package sandbox

import "context"

// FuncSandbox adapts a function to the Sandbox interface.
type FuncSandbox func(context.Context, Spec, []string) (Result, error)

// Run implements Sandbox.
func (f FuncSandbox) Run(ctx context.Context, spec Spec, command []string) (Result, error) {
	return f(ctx, spec, command)
}
