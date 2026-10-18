package agent

import (
	"context"
	"errors"
	"time"

	"github.com/axisvela/praxo-core/pkg/event"
	"github.com/axisvela/praxo-core/pkg/memory"
	"github.com/axisvela/praxo-core/pkg/model"
	"github.com/axisvela/praxo-core/pkg/policy"
	"github.com/axisvela/praxo-core/pkg/tool"
)

// Skill is on-demand knowledge injected for a run.
type Skill struct {
	Name        string
	Description string
	Content     string
}

// SkillProvider selects skills for a prompt.
type SkillProvider interface {
	Skills(ctx context.Context, query string) ([]Skill, error)
}

// Interrupt describes a tool call awaiting approval.
type Interrupt struct {
	RunID     string
	SessionID string
	Call      model.ToolCall
}

// RunContext carries per-run values (user ids, flags, credentials references).
type RunContext map[string]any

type runContextKey struct{}

// WithRunContext attaches per-run values to a context.
func WithRunContext(ctx context.Context, rc RunContext) context.Context {
	if rc == nil {
		return ctx
	}
	return context.WithValue(ctx, runContextKey{}, rc)
}

// RunContextFrom returns the per-run values attached to ctx, if any.
func RunContextFrom(ctx context.Context) RunContext {
	rc, _ := ctx.Value(runContextKey{}).(RunContext)
	return rc
}

// Options is the constructor bundle for a governed agent.
type Options struct {
	Model            model.Model
	SystemPrompt     string
	Tools            *tool.Registry
	Memory           memory.Store
	Skills           SkillProvider
	SkillsLimit      int
	Events           event.Sink
	Policy           policy.Hook
	MaxSteps         int
	MaxParallelTools int
	MaxTokens        int64
	ToolChoice       string
	AllowedTools     []string
	ResponseFormat   *model.ResponseFormat
	Recall           bool
	RecallLimit      int
	InterruptOn      map[string]bool
	OnInterrupt      func(ctx context.Context, interrupt Interrupt) (bool, error)
	Retry            RetryPolicy
	Hooks            Hooks
	OnDelta          func(delta string)
}

// New validates options and builds an agent.
func New(opts Options) (*Agent, error) {
	if opts.Model == nil {
		return nil, errors.New("agent: model is required")
	}
	return &Agent{
		Model:            opts.Model,
		SystemPrompt:     opts.SystemPrompt,
		Tools:            opts.Tools,
		Memory:           opts.Memory,
		Skills:           opts.Skills,
		SkillsLimit:      opts.SkillsLimit,
		Events:           opts.Events,
		Policy:           opts.Policy,
		MaxSteps:         opts.MaxSteps,
		MaxParallelTools: opts.MaxParallelTools,
		MaxTokens:        opts.MaxTokens,
		ToolChoice:       opts.ToolChoice,
		AllowedTools:     opts.AllowedTools,
		ResponseFormat:   opts.ResponseFormat,
		Recall:           opts.Recall,
		RecallLimit:      opts.RecallLimit,
		InterruptOn:      opts.InterruptOn,
		OnInterrupt:      opts.OnInterrupt,
		Retry:            opts.Retry,
		Hooks:            opts.Hooks,
		OnDelta:          opts.OnDelta,
	}, nil
}

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
	OnRunComplete func(ctx context.Context, result *Result) error
	OnRunError    func(ctx context.Context, runID string, err error)
}
