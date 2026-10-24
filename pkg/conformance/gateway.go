package conformance

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

// CheckGateway verifies that every listed tool has a non-empty unique name.
// A gateway may legitimately expose zero tools.
func CheckGateway(gateway tool.Gateway) error {
	if gateway == nil {
		return errors.New("conformance: tool gateway is nil")
	}
	seen := map[string]bool{}
	for _, info := range gateway.ListTools() {
		name := strings.TrimSpace(info.Name)
		if name == "" {
			return errors.New("conformance: gateway listed an empty tool name")
		}
		if seen[name] {
			return fmt.Errorf("conformance: gateway listed duplicate tool %q", name)
		}
		seen[name] = true
	}
	return nil
}

// GatewayCase is one execution expectation.
type GatewayCase struct {
	// Name labels the case in errors. Empty names get an index label.
	Name string
	// Tool is passed to Execute.
	Tool string
	// Input is passed to Execute.
	Input map[string]any
	// Token is passed to Execute.
	Token string
	// WantError requires Execute to return an error.
	WantError bool
}

// CheckGatewayExecute verifies caller-supplied gateway execution expectations.
func CheckGatewayExecute(ctx context.Context, gateway tool.Gateway, cases ...GatewayCase) error {
	if gateway == nil {
		return errors.New("conformance: tool gateway is nil")
	}
	if len(cases) == 0 {
		return errors.New("conformance: at least one gateway case is required")
	}
	for i, tc := range cases {
		label := tc.Name
		if label == "" {
			label = fmt.Sprintf("case-%d", i)
		}
		if strings.TrimSpace(tc.Tool) == "" {
			return fmt.Errorf("conformance: gateway %s: tool is required", label)
		}
		_, err := gateway.Execute(ctx, tc.Tool, tc.Input, tc.Token)
		if tc.WantError {
			if err == nil {
				return fmt.Errorf("conformance: gateway %s: expected an error", label)
			}
			continue
		}
		if err != nil {
			return fmt.Errorf("conformance: gateway %s: %w", label, err)
		}
	}
	return nil
}
