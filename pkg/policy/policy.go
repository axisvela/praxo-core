// Package policy defines the authorization boundary for agent actions.
package policy

import "context"

// Action is an agent action that may require authorization.
type Action struct {
	Kind      string         `json:"kind"`
	SessionID string         `json:"sessionId"`
	ToolName  string         `json:"toolName,omitempty"`
	Arguments map[string]any `json:"arguments,omitempty"`
}

// Decision is an authorization result.
type Decision struct {
	Allowed bool   `json:"allowed"`
	Reason  string `json:"reason,omitempty"`
}

// Hook authorizes agent actions. Implementations may call AEGIVELA.
type Hook interface {
	Authorize(ctx context.Context, action Action) (Decision, error)
}
