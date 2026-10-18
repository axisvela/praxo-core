package policy

import "context"

// FuncHook adapts a function to the Hook interface.
type FuncHook func(context.Context, Action) (Decision, error)

// Authorize implements Hook.
func (f FuncHook) Authorize(ctx context.Context, action Action) (Decision, error) {
	return f(ctx, action)
}
