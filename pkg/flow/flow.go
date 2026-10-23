// Package flow provides composable runnables and chains.
package flow

import (
	"context"
	"sync"
)

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

// Invoke runs all runnables concurrently and returns their outputs in order.
func (p Parallel[I, O]) Invoke(ctx context.Context, input I) ([]O, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	values := make([]O, len(p.Runnables))
	errs := make([]error, len(p.Runnables))
	var wg sync.WaitGroup
	wg.Add(len(p.Runnables))
	for i, runnable := range p.Runnables {
		go func() {
			defer wg.Done()
			values[i], errs[i] = runnable.Invoke(ctx, input)
		}()
	}
	wg.Wait()
	for _, err := range errs {
		if err != nil {
			return nil, err
		}
	}
	return values, nil
}
