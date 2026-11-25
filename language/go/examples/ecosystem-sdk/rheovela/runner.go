// Package rheovela adapts PRAXO-CORE agent sessions to RHEOVELA runs.
package rheovela

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	rheovela "github.com/axisvela/rheovela-open/sdk/go/v3/rheovela"
)

// ErrClientRequired is returned when the RHEOVELA client is not configured.
var ErrClientRequired = errors.New("rheovela: client is required")

// Runner maps an agent session to a RHEOVELA workflow instance.
type Runner struct {
	Client    *rheovela.Client
	Workflow  string
	ProjectID string
	Actor     string
}

// Start opens a RHEOVELA run for the session.
func (r Runner) Start(ctx context.Context, session agent.Session) (*rheovela.Instance, error) {
	if r.Client == nil {
		return nil, ErrClientRequired
	}
	return r.Client.OpenRun(ctx, rheovela.OpenRunRequest{
		Workflow:  r.Workflow,
		ProjectID: r.ProjectID,
		Actor:     r.Actor,
		Variables: map[string]string{
			"session_id":   session.ID,
			"tenant_id":    session.TenantID,
			"workspace_id": session.WorkspaceID,
		},
		IdempotencyKey: session.ID,
	})
}

// Step advances the run at a stage.
func (r Runner) Step(ctx context.Context, instanceID, action, stage string) error {
	if r.Client == nil {
		return ErrClientRequired
	}
	return r.Client.Step(ctx, instanceID, rheovela.StepRequest{
		Action: action,
		Stage:  stage,
		Actor:  r.Actor,
	})
}

// Audit returns the run's audit chain.
func (r Runner) Audit(ctx context.Context, instanceID string) (json.RawMessage, error) {
	if r.Client == nil {
		return nil, ErrClientRequired
	}
	return r.Client.Audit(ctx, instanceID)
}
