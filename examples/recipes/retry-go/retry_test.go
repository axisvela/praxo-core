package retry_recipe

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

var errTransient = errors.New("transient")

type flakyTool struct {
	attempts int
	failures int
}

func (f *flakyTool) Name() string        { return "flaky" }
func (f *flakyTool) Description() string { return "Fails a fixed number of times." }

func (f *flakyTool) Invoke(context.Context, map[string]any) (any, error) {
	f.attempts++
	if f.attempts <= f.failures {
		return nil, errTransient
	}
	return "ok", nil
}

type chargeTool struct {
	effects            int
	applied            bool
	loseNextReponse    bool
	alwaysLoseResponse bool
}

func (t *chargeTool) Name() string        { return "charge" }
func (t *chargeTool) Description() string { return "Non-idempotent charge with a status query." }

func (t *chargeTool) Invoke(context.Context, map[string]any) (any, error) {
	t.effects++
	t.applied = true
	if t.alwaysLoseResponse {
		return nil, errors.New("response lost after the charge applied")
	}
	if t.loseNextReponse {
		t.loseNextReponse = false
		return nil, errors.New("response lost after the charge applied")
	}
	return "charged", nil
}

func (t *chargeTool) Status(context.Context, map[string]any) (bool, error) {
	return t.applied, nil
}

type statusAwareTool struct {
	next *chargeTool
}

func (t statusAwareTool) Name() string        { return t.next.Name() }
func (t statusAwareTool) Description() string { return t.next.Description() }

func (t statusAwareTool) Invoke(ctx context.Context, args map[string]any) (any, error) {
	value, err := t.next.Invoke(ctx, args)
	if err == nil {
		return value, nil
	}
	applied, statusErr := t.next.Status(ctx, args)
	if statusErr != nil {
		return nil, statusErr
	}
	if applied {
		return "charged", nil
	}
	return t.next.Invoke(ctx, args)
}

type cancellingTool struct {
	cancel   context.CancelFunc
	attempts int
}

func (c *cancellingTool) Name() string        { return "cancel" }
func (c *cancellingTool) Description() string { return "Cancels during the retry delay." }

func (c *cancellingTool) Invoke(context.Context, map[string]any) (any, error) {
	c.attempts++
	c.cancel()
	return nil, errTransient
}

func TestRetryZeroValueUsesOneAttempt(t *testing.T) {
	inner := &flakyTool{failures: 1}
	wrapped := tool.Wrap(inner, tool.Retry(tool.RetryPolicy{}))
	if _, err := wrapped.Invoke(context.Background(), nil); err == nil {
		t.Fatal("expected the transient error")
	}
	if inner.attempts != 1 {
		t.Fatalf("attempts = %d, want 1", inner.attempts)
	}
}

func TestRetryTransientWithPredicate(t *testing.T) {
	inner := &flakyTool{failures: 2}
	wrapped := tool.Wrap(inner, tool.Retry(tool.RetryPolicy{
		Attempts:    3,
		ShouldRetry: func(err error) bool { return errors.Is(err, errTransient) },
	}))
	value, err := wrapped.Invoke(context.Background(), nil)
	if err != nil {
		t.Fatal(err)
	}
	if value != "ok" || inner.attempts != 3 {
		t.Fatalf("value=%v attempts=%d", value, inner.attempts)
	}
}

func TestBlindRetryDuplicatesNonIdempotentEffect(t *testing.T) {
	inner := &chargeTool{alwaysLoseResponse: true}
	wrapped := tool.Wrap(inner, tool.Retry(tool.RetryPolicy{
		Attempts:    3,
		ShouldRetry: func(error) bool { return true },
	}))
	if _, err := wrapped.Invoke(context.Background(), nil); err == nil {
		t.Fatal("expected the lost-response error")
	}
	if inner.effects != 3 {
		t.Fatalf("blind retry effects = %d, want 3 (the hazard this recipe demonstrates)", inner.effects)
	}
}

func TestStatusAwareRetryDoesNotDuplicateEffect(t *testing.T) {
	inner := &chargeTool{loseNextReponse: true}
	wrapped := statusAwareTool{next: inner}
	value, err := wrapped.Invoke(context.Background(), nil)
	if err != nil {
		t.Fatal(err)
	}
	if value != "charged" || inner.effects != 1 {
		t.Fatalf("value=%v effects=%d, want charged/1", value, inner.effects)
	}
}

func TestRetryStopsOnCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	inner := &cancellingTool{cancel: cancel}
	wrapped := tool.Wrap(inner, tool.Retry(tool.RetryPolicy{
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
