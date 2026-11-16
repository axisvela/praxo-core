package tool

import (
	"context"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

// RetryPolicy controls retries around a tool invocation. The zero value
// performs a single attempt. When Attempts > 1 and ShouldRetry is nil, every
// error is retried. A transport, timeout, or cancellation error does not prove
// that a non-idempotent tool produced no effect. Supply a ShouldRetry predicate
// that returns false for unknown outcomes, or use an idempotency key or status
// lookup, before enabling retries for a side-effecting tool.
type RetryPolicy struct {
	Attempts    int
	BaseDelay   time.Duration
	MaxDelay    time.Duration
	ShouldRetry func(error) bool
}

// Retry returns a middleware that retries failed tool invocations according to
// policy.
func Retry(policy RetryPolicy) Middleware {
	return func(next Tool) Tool {
		return &retryTool{next: next, policy: policy}
	}
}

type retryTool struct {
	next   Tool
	policy RetryPolicy
}

func (t *retryTool) Name() string        { return t.next.Name() }
func (t *retryTool) Description() string { return t.next.Description() }

func (t *retryTool) Spec() model.ToolSpec {
	if provider, ok := t.next.(SpecProvider); ok {
		return provider.Spec()
	}
	return model.ToolSpec{Name: t.next.Name(), Description: t.next.Description()}
}

func (t *retryTool) Invoke(ctx context.Context, args map[string]any) (any, error) {
	attempts := t.policy.Attempts
	if attempts <= 0 {
		attempts = 1
	}
	delay := t.policy.BaseDelay
	var lastErr error
	for attempt := 0; attempt < attempts; attempt++ {
		if lastErr = ctx.Err(); lastErr != nil {
			return nil, lastErr
		}
		value, err := t.next.Invoke(ctx, args)
		if err == nil {
			return value, nil
		}
		lastErr = err
		if t.policy.ShouldRetry != nil && !t.policy.ShouldRetry(err) {
			return nil, err
		}
		if attempt == attempts-1 {
			break
		}
		if delay > 0 {
			if t.policy.MaxDelay > 0 && delay > t.policy.MaxDelay {
				delay = t.policy.MaxDelay
			}
			select {
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-time.After(delay):
			}
			delay *= 2
		}
	}
	return nil, lastErr
}
