package middleware

import (
	"context"
	"strings"

	"github.com/axisvela/praxo-core/v2/pkg/agent/types"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

// ContextEdit controls declarative prompt pruning before a model call.
type ContextEdit struct {
	// KeepToolResults is the number of trailing tool results to keep. Older
	// tool results are replaced with Placeholder. Zero disables editing.
	KeepToolResults int
	// Placeholder replaces cleared tool results.
	Placeholder string
}

// ContextEditingMiddleware clears old tool results while preserving message
// pairing. It does not drop messages.
func ContextEditingMiddleware(edit ContextEdit) types.Middleware {
	placeholder := edit.Placeholder
	if strings.TrimSpace(placeholder) == "" {
		placeholder = "[tool result cleared]"
	}
	return types.Middleware{
		Name: "context-editing",
		BeforeModel: func(_ context.Context, call *types.ModelCall) error {
			if call.Request == nil || edit.KeepToolResults <= 0 {
				return nil
			}
			messages := call.Request.Messages
			toolIndexes := make([]int, 0)
			for i, message := range messages {
				if message.Role == model.RoleTool {
					toolIndexes = append(toolIndexes, i)
				}
			}
			clearUntil := len(toolIndexes) - edit.KeepToolResults
			if clearUntil <= 0 {
				return nil
			}
			out := make([]model.Message, len(messages))
			copy(out, messages)
			for _, index := range toolIndexes[:clearUntil] {
				out[index].Content = placeholder
			}
			call.Request.Messages = out
			return nil
		},
	}
}
