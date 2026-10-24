package conformance

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

// ModelCase is one generation expectation. Requests are provider-specific, so
// the caller supplies them.
type ModelCase struct {
	// Name labels the case in errors. Empty names get an index label.
	Name string
	// Request is sent to Generate.
	Request model.Request
	// WantError requires Generate to return an error.
	WantError bool
	// WantContentContains checks response content when non-empty.
	WantContentContains string
	// WantFinishReason checks the finish reason when non-empty.
	WantFinishReason string
	// WantToolCall requires a tool call with this name.
	WantToolCall string
}

// CheckModel verifies caller-supplied generation expectations.
func CheckModel(ctx context.Context, generator model.Model, cases ...ModelCase) error {
	if generator == nil {
		return errors.New("conformance: model is nil")
	}
	if len(cases) == 0 {
		return errors.New("conformance: at least one model case is required")
	}
	for i, tc := range cases {
		label := caseLabel(tc.Name, i)
		response, err := generator.Generate(ctx, tc.Request)
		if tc.WantError {
			if err == nil {
				return fmt.Errorf("conformance: model %s: expected an error", label)
			}
			continue
		}
		if err != nil {
			return fmt.Errorf("conformance: model %s: %w", label, err)
		}
		if tc.WantContentContains != "" && !strings.Contains(response.Message.Content, tc.WantContentContains) {
			return fmt.Errorf("conformance: model %s: content = %q, want substring %q", label, response.Message.Content, tc.WantContentContains)
		}
		if tc.WantFinishReason != "" && response.FinishReason != tc.WantFinishReason {
			return fmt.Errorf("conformance: model %s: finish reason = %q, want %q", label, response.FinishReason, tc.WantFinishReason)
		}
		if tc.WantToolCall != "" && !hasToolCall(response.Message.ToolCalls, tc.WantToolCall) {
			return fmt.Errorf("conformance: model %s: missing tool call %q", label, tc.WantToolCall)
		}
	}
	return nil
}

// ModelStreamCase is one streaming expectation.
type ModelStreamCase struct {
	// Name labels the case in errors. Empty names get an index label.
	Name string
	// Request is sent to GenerateStream.
	Request model.Request
	// WantError requires GenerateStream to return an error.
	WantError bool
	// WantContentContains checks the final response content when non-empty.
	WantContentContains string
	// WantToolCall requires a tool call with this name.
	WantToolCall string
}

// CheckStreamingModel verifies caller-supplied streaming expectations. When
// the final response has text, the concatenated deltas must match it.
func CheckStreamingModel(ctx context.Context, generator model.StreamingModel, cases ...ModelStreamCase) error {
	if generator == nil {
		return errors.New("conformance: streaming model is nil")
	}
	if len(cases) == 0 {
		return errors.New("conformance: at least one streaming model case is required")
	}
	for i, tc := range cases {
		label := caseLabel(tc.Name, i)
		var deltas strings.Builder
		response, err := generator.GenerateStream(ctx, tc.Request, func(delta string) {
			deltas.WriteString(delta)
		})
		if tc.WantError {
			if err == nil {
				return fmt.Errorf("conformance: streaming model %s: expected an error", label)
			}
			continue
		}
		if err != nil {
			return fmt.Errorf("conformance: streaming model %s: %w", label, err)
		}
		if response.Message.Content != "" && deltas.String() != response.Message.Content {
			return fmt.Errorf("conformance: streaming model %s: deltas = %q, content = %q", label, deltas.String(), response.Message.Content)
		}
		if tc.WantContentContains != "" && !strings.Contains(response.Message.Content, tc.WantContentContains) {
			return fmt.Errorf("conformance: streaming model %s: content = %q, want substring %q", label, response.Message.Content, tc.WantContentContains)
		}
		if tc.WantToolCall != "" && !hasToolCall(response.Message.ToolCalls, tc.WantToolCall) {
			return fmt.Errorf("conformance: streaming model %s: missing tool call %q", label, tc.WantToolCall)
		}
	}
	return nil
}

func hasToolCall(calls []model.ToolCall, name string) bool {
	for _, call := range calls {
		if call.Name == name {
			return true
		}
	}
	return false
}
