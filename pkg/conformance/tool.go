package conformance

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

// ToolCase is one tool invocation expectation.
type ToolCase struct {
	// Name labels the case in errors. Empty names get an index label.
	Name string
	// Args is sent to Invoke.
	Args map[string]any
	// WantError requires Invoke to return an error.
	WantError bool
}

// CheckTool verifies the tool name, an optional SpecProvider name match, and
// caller-supplied invocation expectations.
func CheckTool(ctx context.Context, candidate tool.Tool, cases ...ToolCase) error {
	if candidate == nil {
		return errors.New("conformance: tool is nil")
	}
	if strings.TrimSpace(candidate.Name()) == "" {
		return errors.New("conformance: tool name is empty")
	}
	if provider, ok := candidate.(tool.SpecProvider); ok {
		spec := provider.Spec()
		if strings.TrimSpace(spec.Name) == "" {
			return errors.New("conformance: tool spec name is empty")
		}
		if spec.Name != candidate.Name() {
			return fmt.Errorf("conformance: tool name = %q, spec name = %q", candidate.Name(), spec.Name)
		}
	}
	for i, tc := range cases {
		label := caseLabel(tc.Name, i)
		_, err := candidate.Invoke(ctx, tc.Args)
		if tc.WantError {
			if err == nil {
				return fmt.Errorf("conformance: tool %s: expected an error", label)
			}
			continue
		}
		if err != nil {
			return fmt.Errorf("conformance: tool %s: %w", label, err)
		}
	}
	return nil
}
