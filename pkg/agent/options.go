package agent

import (
	"context"
	"errors"
	"strings"

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

// Profile is a reusable bundle of defaults. Explicit Options values win.
type Profile struct {
	Name             string
	SystemPrompt     string
	ToolChoice       string
	MaxSteps         int
	MaxTokens        int64
	MaxParallelTools int
	Context          *ContextBudget
	Retry            RetryPolicy
}

// Apply fills zero-valued options from the profile.
func (p Profile) Apply(opts Options) Options {
	if opts.SystemPrompt == "" {
		opts.SystemPrompt = p.SystemPrompt
	}
	if opts.ToolChoice == "" {
		opts.ToolChoice = p.ToolChoice
	}
	if opts.MaxSteps == 0 {
		opts.MaxSteps = p.MaxSteps
	}
	if opts.MaxTokens == 0 {
		opts.MaxTokens = p.MaxTokens
	}
	if opts.MaxParallelTools == 0 {
		opts.MaxParallelTools = p.MaxParallelTools
	}
	if opts.Context == nil {
		opts.Context = p.Context
	}
	if opts.Retry.Attempts == 0 && opts.Retry.BaseDelay == 0 && opts.Retry.MaxDelay == 0 && opts.Retry.ShouldRetry == nil {
		opts.Retry = p.Retry
	}
	return opts
}

// Options is the constructor bundle for a governed agent.
type Options struct {
	Profile               *Profile
	Middleware            []Middleware
	ModelMiddleware       []ModelMiddleware
	Model                 model.Model
	SystemPrompt          string
	MemoryFiles           []string
	Tools                 *tool.Registry
	Memory                memory.Store
	Skills                SkillProvider
	SkillsLimit           int
	Events                event.Sink
	Policy                policy.Hook
	MaxSteps              int
	MaxParallelTools      int
	MaxTokens             int64
	Context               *ContextBudget
	Compactor             ContextCompactor
	Offloader             Offloader
	OffloadThresholdBytes int
	PromptCache           func([]model.Message) *model.CacheHint
	ToolChoice            string
	AllowedTools          []string
	ResponseFormat        *model.ResponseFormat
	Recall                bool
	RecallLimit           int
	InterruptOn           map[string]bool
	OnInterrupt           func(ctx context.Context, interrupt Interrupt) (bool, error)
	OnInterruptDecision   InterruptHandler
	Retry                 RetryPolicy
	// StructuredOutput validates and optionally repairs the final output.
	StructuredOutput *StructuredOutput
	// FallbackModel is used when the primary model call fails.
	FallbackModel model.Model
	// ToolSelector narrows advertised tools before each model call.
	ToolSelector ToolSelector
	// PIIRedactor redacts model-bound messages and tool results.
	PIIRedactor *PIIRedactor
	// ModelCallLimit and ToolCallLimit bound calls per run. Zero is unlimited.
	ModelCallLimit int
	ToolCallLimit  int
	// ToolRetry retries failed tool invocations.
	ToolRetry *tool.RetryPolicy
	Hooks     Hooks
	OnStream  func(StreamPart) error
	OnDelta   func(delta string)
}

// New validates options and builds an agent.
func New(opts Options) (*Agent, error) {
	if opts.Profile != nil {
		opts = opts.Profile.Apply(opts)
	}
	if opts.Model == nil {
		return nil, errors.New("agent: model is required")
	}
	memory, err := LoadAgentsMD(opts.MemoryFiles...)
	if err != nil {
		return nil, err
	}
	if memory != "" {
		opts.SystemPrompt = strings.TrimSpace(opts.SystemPrompt + "\n\n" + memory)
	}
	middleware := append([]Middleware(nil), opts.Middleware...)
	if opts.StructuredOutput != nil {
		middleware = append(middleware, opts.StructuredOutput.Middleware())
	}
	if opts.ToolSelector != nil {
		middleware = append(middleware, ToolSelectionMiddleware(opts.ToolSelector))
	}
	if opts.PIIRedactor != nil {
		middleware = append(middleware, PIIMiddleware(*opts.PIIRedactor))
	}
	if opts.ModelCallLimit > 0 || opts.ToolCallLimit > 0 {
		middleware = append(middleware, CallLimitMiddleware(opts.ModelCallLimit, opts.ToolCallLimit))
	}
	modelMiddleware := append([]ModelMiddleware(nil), opts.ModelMiddleware...)
	if opts.FallbackModel != nil {
		modelMiddleware = append(modelMiddleware, FallbackModel(opts.FallbackModel))
	}
	return &Agent{
		Middleware:            mergeMiddleware(middleware),
		ModelMiddleware:       modelMiddleware,
		Model:                 opts.Model,
		SystemPrompt:          opts.SystemPrompt,
		Tools:                 opts.Tools,
		Memory:                opts.Memory,
		Skills:                opts.Skills,
		SkillsLimit:           opts.SkillsLimit,
		Events:                opts.Events,
		Policy:                opts.Policy,
		MaxSteps:              opts.MaxSteps,
		MaxParallelTools:      opts.MaxParallelTools,
		MaxTokens:             opts.MaxTokens,
		Context:               opts.Context,
		Compactor:             opts.Compactor,
		Offloader:             opts.Offloader,
		OffloadThresholdBytes: opts.OffloadThresholdBytes,
		PromptCache:           opts.PromptCache,
		StructuredOutput:      opts.StructuredOutput,
		ToolChoice:            opts.ToolChoice,
		AllowedTools:          opts.AllowedTools,
		ResponseFormat:        opts.ResponseFormat,
		Recall:                opts.Recall,
		RecallLimit:           opts.RecallLimit,
		InterruptOn:           opts.InterruptOn,
		OnInterrupt:           opts.OnInterrupt,
		OnInterruptDecision:   opts.OnInterruptDecision,
		Retry:                 opts.Retry,
		ToolRetry:             opts.ToolRetry,
		Hooks:                 opts.Hooks,
		OnStream:              opts.OnStream,
		OnDelta:               opts.OnDelta,
	}, nil
}
