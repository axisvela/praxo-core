package tool

import (
	"context"
	"errors"
	"testing"
	"time"
)

type flakyTool struct {
	attempts int
	failures int
}

func (f *flakyTool) Name() string        { return "flaky" }
func (f *flakyTool) Description() string { return "flaky tool" }
func (f *flakyTool) Invoke(context.Context, map[string]any) (any, error) {
	f.attempts++
	if f.attempts <= f.failures {
		return nil, errors.New("transient")
	}
	return "ok", nil
}

func TestRetryMiddlewareRetriesUntilSuccess(t *testing.T) {
	inner := &flakyTool{failures: 2}
	wrapped := Wrap(inner, Retry(RetryPolicy{Attempts: 3}))
	value, err := wrapped.Invoke(context.Background(), nil)
	if err != nil {
		t.Fatal(err)
	}
	if value != "ok" || inner.attempts != 3 {
		t.Fatalf("value=%v attempts=%d", value, inner.attempts)
	}
}

func TestRetryMiddlewareHonorsShouldRetry(t *testing.T) {
	inner := &flakyTool{failures: 1}
	wrapped := Wrap(inner, Retry(RetryPolicy{
		Attempts:    3,
		ShouldRetry: func(error) bool { return false },
	}))
	if _, err := wrapped.Invoke(context.Background(), nil); err == nil {
		t.Fatal("expected error")
	}
	if inner.attempts != 1 {
		t.Fatalf("attempts = %d, want 1", inner.attempts)
	}
}

func TestRetryMiddlewareZeroValueDoesNotRetry(t *testing.T) {
	inner := &flakyTool{failures: 1}
	wrapped := Wrap(inner, Retry(RetryPolicy{}))
	if _, err := wrapped.Invoke(context.Background(), nil); err == nil {
		t.Fatal("expected error")
	}
	if inner.attempts != 1 {
		t.Fatalf("attempts = %d, want 1", inner.attempts)
	}
}

type sideEffectTool struct {
	effects int
}

func (s *sideEffectTool) Name() string        { return "charge" }
func (s *sideEffectTool) Description() string { return "records a non-idempotent effect" }
func (s *sideEffectTool) Invoke(context.Context, map[string]any) (any, error) {
	s.effects++
	return nil, errors.New("connection reset after request")
}

func TestRetryMiddlewareWithoutShouldRetryRepeatsNonIdempotentEffect(t *testing.T) {
	inner := &sideEffectTool{}
	wrapped := Wrap(inner, Retry(RetryPolicy{Attempts: 3}))
	if _, err := wrapped.Invoke(context.Background(), nil); err == nil {
		t.Fatal("expected error")
	}
	if inner.effects != 3 {
		t.Fatalf("effects = %d, want the documented 3 attempts", inner.effects)
	}
}

func TestRetryMiddlewareShouldRetryPreventsUnknownEffectDuplicate(t *testing.T) {
	inner := &sideEffectTool{}
	wrapped := Wrap(inner, Retry(RetryPolicy{
		Attempts:    3,
		ShouldRetry: func(error) bool { return false },
	}))
	if _, err := wrapped.Invoke(context.Background(), nil); err == nil {
		t.Fatal("expected error")
	}
	if inner.effects != 1 {
		t.Fatalf("effects = %d, want 1", inner.effects)
	}
}

type cancelRetryTool struct {
	cancel   context.CancelFunc
	attempts int
}

func (c *cancelRetryTool) Name() string        { return "cancel-retry" }
func (c *cancelRetryTool) Description() string { return "cancels during retry" }
func (c *cancelRetryTool) Invoke(context.Context, map[string]any) (any, error) {
	c.attempts++
	c.cancel()
	return nil, errors.New("retryable")
}

func TestRetryMiddlewareStopsOnContextCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	inner := &cancelRetryTool{cancel: cancel}
	wrapped := Wrap(inner, Retry(RetryPolicy{
		Attempts:    3,
		BaseDelay:   time.Hour,
		ShouldRetry: func(error) bool { return true },
	}))
	if _, err := wrapped.Invoke(ctx, nil); !errors.Is(err, context.Canceled) {
		t.Fatalf("err = %v, want context.Canceled", err)
	}
	if inner.attempts != 1 {
		t.Fatalf("attempts = %d, want 1", inner.attempts)
	}
}
