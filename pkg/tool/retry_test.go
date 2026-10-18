package tool

import (
	"context"
	"errors"
	"testing"
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
