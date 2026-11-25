package rheovela

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	rheovela "github.com/axisvela/rheovela-open/sdk/go/v3/rheovela"
	"github.com/axisvela/rheovela-open/sdk/go/v3/worker"
)

// ErrStepRunnerRequired is returned when no step runner is configured.
var ErrStepRunnerRequired = errors.New("rheovela: step runner is required")

// StepRunner executes one durable work item. It owns the agent loop and
// returns the typed result, checkpoint/effect references, or an approval
// request.
type StepRunner interface {
	RunStep(ctx context.Context, item worker.WorkItem) (StepResult, error)
}

// StepResult is one runner outcome.
type StepResult struct {
	// Result is marshaled as the durable step result. nil is allowed.
	Result any
	// CheckpointRef points at the worker's durable checkpoint.
	CheckpointRef string
	// EffectCursor points at the worker's effect-ledger cursor.
	EffectCursor string
	// Approval requests human approval instead of completing the item.
	Approval *worker.ApprovalRequest
}

// AgentRunner runs a PRAXO agent for one work item. It is a simple example:
// approval and checkpoint policy belong to a product-specific StepRunner.
type AgentRunner struct {
	Agent   *agent.Agent
	Prompt  func(worker.WorkItem) string
	Session func(worker.WorkItem) agent.Session
}

// RunStep implements StepRunner.
func (r AgentRunner) RunStep(ctx context.Context, item worker.WorkItem) (StepResult, error) {
	if r.Agent == nil {
		return StepResult{}, errors.New("rheovela: agent is required")
	}
	prompt := ""
	if r.Prompt != nil {
		prompt = r.Prompt(item)
	}
	session := agent.Session{ID: item.InstanceID}
	if r.Session != nil {
		session = r.Session(item)
	}
	result, err := r.Agent.Run(ctx, session, prompt)
	if err != nil {
		return StepResult{}, err
	}
	return StepResult{Result: result}, nil
}

// DurableWorker drives RHEOVELA work items through a StepRunner.
type DurableWorker struct {
	worker *worker.Worker
	logf   func(format string, args ...any)
	poll   time.Duration
}

type durableConfig struct {
	lease             time.Duration
	heartbeatInterval time.Duration
	poll              time.Duration
	logf              func(format string, args ...any)
}

// DurableOption configures a DurableWorker.
type DurableOption func(*durableConfig)

// WithLease sets the work-item lease. Defaults to 30 seconds.
func WithLease(d time.Duration) DurableOption {
	return func(c *durableConfig) {
		if d > 0 {
			c.lease = d
		}
	}
}

// WithHeartbeatInterval sets the work-store heartbeat interval.
func WithHeartbeatInterval(d time.Duration) DurableOption {
	return func(c *durableConfig) {
		if d > 0 {
			c.heartbeatInterval = d
		}
	}
}

// WithPollInterval sets the Run loop delay between empty polls.
func WithPollInterval(d time.Duration) DurableOption {
	return func(c *durableConfig) {
		if d > 0 {
			c.poll = d
		}
	}
}

// WithLogger sets the worker log function.
func WithLogger(logf func(format string, args ...any)) DurableOption {
	return func(c *durableConfig) {
		if logf != nil {
			c.logf = logf
		}
	}
}

func defaultDurableConfig() durableConfig {
	return durableConfig{
		lease: 30 * time.Second,
		poll:  1 * time.Second,
		logf:  func(string, ...any) {},
	}
}

// NewDurableWorker builds a worker over the RHEOVELA HTTP work store.
func NewDurableWorker(client *rheovela.Client, runner StepRunner, opts ...DurableOption) (*DurableWorker, error) {
	if client == nil {
		return nil, ErrClientRequired
	}
	return newDurableWorker(rheovela.NewHTTPWorkStore(client), runner, opts...)
}

// NewDurableWorkerWithStore builds a worker over a caller-supplied work store.
func NewDurableWorkerWithStore(store worker.WorkStore, runner StepRunner, opts ...DurableOption) (*DurableWorker, error) {
	return newDurableWorker(store, runner, opts...)
}

func newDurableWorker(store worker.WorkStore, runner StepRunner, opts ...DurableOption) (*DurableWorker, error) {
	if store == nil {
		return nil, errors.New("rheovela: work store is required")
	}
	if runner == nil {
		return nil, ErrStepRunnerRequired
	}
	cfg := defaultDurableConfig()
	for _, opt := range opts {
		opt(&cfg)
	}
	options := []worker.Option{worker.WithLogger(cfg.logf)}
	if cfg.heartbeatInterval > 0 {
		options = append(options, worker.WithHeartbeatInterval(cfg.heartbeatInterval))
	}
	instance := &DurableWorker{
		worker: worker.New(store, func(ctx context.Context, item worker.WorkItem) worker.WorkResult {
			return runStep(ctx, runner, item)
		}, cfg.lease, options...),
		logf: cfg.logf,
		poll: cfg.poll,
	}
	return instance, nil
}

// RunOnce processes every currently claimable work item once.
func (d *DurableWorker) RunOnce(ctx context.Context) (int, error) {
	return d.worker.ProcessOnce(ctx)
}

// Run polls until the context ends. Processing errors are logged and retried.
func (d *DurableWorker) Run(ctx context.Context) error {
	ticker := time.NewTicker(d.poll)
	defer ticker.Stop()
	for {
		if _, err := d.RunOnce(ctx); err != nil && ctx.Err() == nil {
			d.logf("process work items: %v", err)
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
		}
	}
}

func runStep(ctx context.Context, runner StepRunner, item worker.WorkItem) (result worker.WorkResult) {
	defer func() {
		if recovered := recover(); recovered != nil {
			result = worker.WorkResult{Status: "failure", Error: fmt.Sprintf("step panic: %v", recovered)}
		}
	}()
	step, err := runner.RunStep(ctx, item)
	if err != nil {
		return worker.WorkResult{Status: "failure", Error: err.Error()}
	}
	if step.Approval != nil {
		return worker.WorkResult{
			Status:        "approval",
			Approval:      step.Approval,
			CheckpointRef: step.CheckpointRef,
			EffectCursor:  step.EffectCursor,
		}
	}
	payload, err := marshalResult(step.Result)
	if err != nil {
		return worker.WorkResult{Status: "failure", Error: err.Error()}
	}
	return worker.WorkResult{
		Status:        "success",
		Result:        payload,
		CheckpointRef: step.CheckpointRef,
		EffectCursor:  step.EffectCursor,
	}
}

func marshalResult(value any) (json.RawMessage, error) {
	if value == nil {
		return nil, nil
	}
	switch typed := value.(type) {
	case json.RawMessage:
		if !json.Valid(typed) {
			return nil, errors.New("rheovela: result is not valid JSON")
		}
		return typed, nil
	case []byte:
		if !json.Valid(typed) {
			return nil, errors.New("rheovela: result is not valid JSON")
		}
		return json.RawMessage(typed), nil
	default:
		return json.Marshal(value)
	}
}
