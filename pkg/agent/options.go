package agent

import (
	"context"
	"time"

	"github.com/axisvela/praxo-core/pkg/model"
)

// RetryPolicy controls retries around model calls. The zero value performs a
// single attempt.
type RetryPolicy struct {
	Attempts    int
	BaseDelay   time.Duration
	MaxDelay    time.Duration
	ShouldRetry func(error) bool
}

// Do runs fn until it succeeds, the attempt budget is exhausted, ShouldRetry
// rejects the error, or the context is cancelled.
func (p RetryPolicy) Do(ctx context.Context, fn func() error) error {
	attempts := p.Attempts
	if attempts <= 0 {
		attempts = 1
	}
	delay := p.BaseDelay
	var err error
	for attempt := 0; attempt < attempts; attempt++ {
		if err = fn(); err == nil {
			return nil
		}
		if p.ShouldRetry != nil && !p.ShouldRetry(err) {
			return err
		}
		if attempt == attempts-1 {
			break
		}
		if delay > 0 {
			if p.MaxDelay > 0 && delay > p.MaxDelay {
				delay = p.MaxDelay
			}
			select {
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(delay):
			}
			delay *= 2
		}
	}
	return err
}

// Hooks are optional lifecycle callbacks. Returning an error aborts the run.
type Hooks struct {
	OnRunStart    func(ctx context.Context, runID string, session Session) error
	OnStep        func(ctx context.Context, runID string, step int, messages []model.Message) error
	OnModelCall   func(ctx context.Context, runID string, req model.Request) error
	OnModelResult func(ctx context.Context, runID string, resp model.Response) error
	OnToolCall    func(ctx context.Context, runID string, call model.ToolCall) error
	OnToolResult  func(ctx context.Context, runID string, call model.ToolCall, result any, err error) error
	OnRunComplete func(ctx context.Context, result *Result) error
	OnRunError    func(ctx context.Context, runID string, err error)
}
