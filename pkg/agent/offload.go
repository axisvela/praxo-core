package agent

import "context"

// Offloader stores a large tool result outside the prompt and returns the
// placeholder text that replaces it.
type Offloader interface {
	Offload(ctx context.Context, toolName, toolCallID string, data []byte) (string, error)
}

// OffloadFunc adapts a function to Offloader.
type OffloadFunc func(context.Context, string, string, []byte) (string, error)

// Offload calls f.
func (f OffloadFunc) Offload(ctx context.Context, toolName, toolCallID string, data []byte) (string, error) {
	return f(ctx, toolName, toolCallID, data)
}
