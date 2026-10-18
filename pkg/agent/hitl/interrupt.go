package hitl

import (
	"context"
	"errors"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

// Interrupt describes a tool call awaiting approval.
type Interrupt struct {
	RunID     string
	SessionID string
	Call      model.ToolCall
}

// InterruptAction is a human decision for a tool call awaiting approval.
type InterruptAction string

const (
	// InterruptApprove executes the tool call unchanged.
	InterruptApprove InterruptAction = "approve"
	// InterruptEdit replaces the tool arguments and executes the call.
	InterruptEdit InterruptAction = "edit"
	// InterruptReject aborts the run without executing the call.
	InterruptReject InterruptAction = "reject"
	// InterruptRespond skips the tool and feeds Response back to the model.
	InterruptRespond InterruptAction = "respond"
)

// InterruptDecision is one human decision on an interrupt.
type InterruptDecision struct {
	Action    InterruptAction
	Arguments map[string]any
	Response  string
	Reason    string
}

// ErrInterruptDecisionInvalid reports an unsupported or incomplete decision.
var ErrInterruptDecisionInvalid = errors.New("agent: invalid interrupt decision")

// InterruptHandler resolves an interrupt with an explicit decision.
type InterruptHandler func(ctx context.Context, interrupt Interrupt) (InterruptDecision, error)
