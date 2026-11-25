package aegivela

import (
	"context"
	"errors"

	"github.com/axisvela/aegivela-open/sdk/go/v3/pepsdk"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
)

// ErrClientRequired is returned when the PEP client is not configured.
var ErrClientRequired = errors.New("aegivela: client is required")

// Hook implements policy.Hook with AEGIVELA policy evaluation.
type Hook struct {
	Client *pepsdk.Client
	Route  pepsdk.Route
	Input  pepsdk.AuthorizationInput
}

// Authorize evaluates the action and maps the outcome to a policy decision.
func (h Hook) Authorize(ctx context.Context, action policy.Action) (policy.Decision, error) {
	if h.Client == nil {
		return policy.Decision{}, ErrClientRequired
	}
	route := h.Route
	if action.ToolName != "" {
		route.Reference = action.ToolName
	}
	result, err := h.Client.Evaluate(ctx, route, h.Input)
	if err != nil {
		return policy.Decision{}, err
	}
	return policy.Decision{
		Allowed: result.Outcome == "allow",
		Reason:  result.Outcome,
	}, nil
}
