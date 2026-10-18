// Package types holds shared run-state contracts used by the agent capability
// packages. Products should normally import pkg/agent, which re-exports these
// names.
package types

import (
	"context"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/memory"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

// Session is the execution scope.
type Session struct {
	ID          string          `json:"id"`
	TenantID    string          `json:"tenantId"`
	WorkspaceID string          `json:"workspaceId"`
	Messages    []model.Message `json:"messages,omitempty"`
}

// Result is one completed run.
type Result struct {
	RunID  string      `json:"runId"`
	Output string      `json:"output"`
	Steps  int         `json:"steps"`
	Usage  model.Usage `json:"usage"`
}

// Middleware intercepts a run at model and tool boundaries. All callbacks are
// optional. Returning an error aborts the run.
type Middleware struct {
	Name string

	BeforeRun   func(ctx context.Context, state *RunState) error
	BeforeModel func(ctx context.Context, call *ModelCall) error
	AfterModel  func(ctx context.Context, call *ModelCall, resp *model.Response) error
	BeforeTool  func(ctx context.Context, call *ToolCall) error
	AfterTool   func(ctx context.Context, call *ToolCall, result *ToolResult) error
	AfterRun    func(ctx context.Context, result *Result, err error) error
}

// RunState is the mutable run start state.
type RunState struct {
	RunID   string
	Session *Session
	Prompt  *string
}

// ModelCall is one model invocation. Middleware may rewrite Request, or set
// Skip with a canned Response.
type ModelCall struct {
	RunID     string
	SessionID string
	Request   *model.Request
	Skip      bool
	Response  *model.Response
}

// ToolCall is one tool invocation. Middleware may rewrite Call, or set Skip
// with a Result/Err.
type ToolCall struct {
	RunID     string
	SessionID string
	Call      *model.ToolCall
	Skip      bool
	Result    any
	Err       error
}

// ToolResult is the mutable outcome of a tool invocation.
type ToolResult struct {
	Value any
	Err   error
}

// ModelMiddleware wraps a model call.
type ModelMiddleware func(next func(context.Context, model.Request) (model.Response, error)) func(context.Context, model.Request) (model.Response, error)

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
	OnMemoryRead  func(ctx context.Context, runID string, records []memory.Record) error
	OnMemoryWrite func(ctx context.Context, runID string, record memory.Record) error
	OnCompaction  func(ctx context.Context, runID string, before, after int) error
	OnOffload     func(ctx context.Context, runID, toolName string, originalBytes, offloadedBytes int) error
	OnRunComplete func(ctx context.Context, result *Result) error
	OnRunError    func(ctx context.Context, runID string, err error)
}

// SessionStore persists portable session state. Implementations may add
// product-specific columns, but must round-trip the fields on Session.
type SessionStore interface {
	Load(ctx context.Context, sessionID string) (*Session, error)
	Save(ctx context.Context, session *Session) error
}
