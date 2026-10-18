// Package flow provides composable runnables and chains.
package flow

import "context"

// Runnable is a composable unit of work.
type Runnable[I, O any] interface {
	Invoke(ctx context.Context, input I) (O, error)
}

// Func adapts a function to a Runnable.
type Func[I, O any] func(context.Context, I) (O, error)

// Invoke implements Runnable.
func (f Func[I, O]) Invoke(ctx context.Context, input I) (O, error) {
	return f(ctx, input)
}

// Chain composes two runnables.
type Chain[A, B, C any] struct {
	First  Runnable[A, B]
	Second Runnable[B, C]
}

// Invoke runs the first stage, then the second.
func (c Chain[A, B, C]) Invoke(ctx context.Context, input A) (C, error) {
	var zero C
	mid, err := c.First.Invoke(ctx, input)
	if err != nil {
		return zero, err
	}
	return c.Second.Invoke(ctx, mid)
}

// Parallel runs independent runnables over the same input.
type Parallel[I, O any] struct {
	Runnables []Runnable[I, O]
}

// Invoke runs all runnables and returns their outputs in order.
func (p Parallel[I, O]) Invoke(ctx context.Context, input I) ([]O, error) {
	out := make([]O, 0, len(p.Runnables))
	for _, runnable := range p.Runnables {
		value, err := runnable.Invoke(ctx, input)
		if err != nil {
			return nil, err
		}
		out = append(out, value)
	}
	return out, nil
}
