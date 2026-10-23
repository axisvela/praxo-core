// Package a2a adapts a PRAXO-CORE agent to an A2A AgentExecutor.
package a2a

import (
	"context"
	"errors"
	"iter"
	"strings"

	sdk "github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2asrv"
	"github.com/axisvela/praxo-core/v2/pkg/agent"
)

// ErrAgentRequired is returned when the executor has no agent runner.
var ErrAgentRequired = errors.New("a2a: agent runner is required")

// Runner is the PRAXO-CORE agent surface used by the A2A executor.
type Runner interface {
	Run(ctx context.Context, session agent.Session, prompt string) (*agent.Result, error)
}

// Executor implements a2asrv.AgentExecutor with a PRAXO-CORE agent.
type Executor struct {
	Agent Runner
	// Session maps the A2A execution context to a PRAXO-CORE session. When nil,
	// ContextID becomes Session.ID, Tenant becomes TenantID, and the workspaceId
	// metadata field becomes WorkspaceID.
	Session func(*a2asrv.ExecutorContext) agent.Session
}

var _ a2asrv.AgentExecutor = Executor{}

// Execute runs the agent and emits one agent text message.
func (e Executor) Execute(ctx context.Context, execCtx *a2asrv.ExecutorContext) iter.Seq2[sdk.Event, error] {
	return func(yield func(sdk.Event, error) bool) {
		if e.Agent == nil {
			yield(nil, ErrAgentRequired)
			return
		}
		if execCtx == nil || execCtx.Message == nil {
			yield(nil, errors.New("a2a: message is required"))
			return
		}
		prompt, err := messageText(execCtx.Message)
		if err != nil {
			yield(nil, err)
			return
		}
		result, err := e.Agent.Run(ctx, e.session(execCtx), prompt)
		if err != nil {
			yield(nil, err)
			return
		}
		if result == nil {
			yield(nil, errors.New("a2a: agent returned no result"))
			return
		}
		yield(sdk.NewMessage(sdk.MessageRoleAgent, sdk.NewTextPart(result.Output)), nil)
	}
}

// Cancel emits a canceled task status.
func (Executor) Cancel(_ context.Context, execCtx *a2asrv.ExecutorContext) iter.Seq2[sdk.Event, error] {
	return func(yield func(sdk.Event, error) bool) {
		yield(sdk.NewStatusUpdateEvent(execCtx, sdk.TaskStateCanceled, nil), nil)
	}
}

func (e Executor) session(execCtx *a2asrv.ExecutorContext) agent.Session {
	if e.Session != nil {
		return e.Session(execCtx)
	}
	id := execCtx.ContextID
	if id == "" {
		id = string(execCtx.TaskID)
	}
	workspaceID := ""
	if value, ok := execCtx.Metadata["workspaceId"].(string); ok {
		workspaceID = value
	}
	return agent.Session{
		ID:          id,
		TenantID:    execCtx.Tenant,
		WorkspaceID: workspaceID,
	}
}

func messageText(message *sdk.Message) (string, error) {
	parts := make([]string, 0, len(message.Parts))
	for _, part := range message.Parts {
		if text, ok := part.Content.(sdk.Text); ok {
			parts = append(parts, string(text))
		}
	}
	if len(parts) == 0 {
		return "", errors.New("a2a: message has no text parts")
	}
	return strings.Join(parts, "\n"), nil
}
