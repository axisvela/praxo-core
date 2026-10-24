package conformance

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/axisvela/praxo-core/v2/pkg/policy"
)

// PolicyCase is one authorization expectation.
type PolicyCase struct {
	// Name labels the case in errors. Empty names get an index label.
	Name string
	// Action is sent to the hook.
	Action policy.Action
	// WantAllowed is the required decision when WantError is false.
	WantAllowed bool
	// WantReasonContains checks the reason text when non-empty.
	WantReasonContains string
	// WantError requires the hook to return an error instead of a decision.
	WantError bool
}

// CheckPolicyHook verifies caller-supplied authorization expectations. Policy
// semantics are product-specific, so the caller must provide at least one case.
func CheckPolicyHook(ctx context.Context, hook policy.Hook, cases ...PolicyCase) error {
	if hook == nil {
		return errors.New("conformance: policy hook is nil")
	}
	if len(cases) == 0 {
		return errors.New("conformance: at least one policy case is required")
	}
	for i, tc := range cases {
		label := tc.Name
		if label == "" {
			label = fmt.Sprintf("case-%d", i)
		}
		decision, err := hook.Authorize(ctx, tc.Action)
		if tc.WantError {
			if err == nil {
				return fmt.Errorf("conformance: policy %s: expected an error", label)
			}
			continue
		}
		if err != nil {
			return fmt.Errorf("conformance: policy %s: %w", label, err)
		}
		if decision.Allowed != tc.WantAllowed {
			return fmt.Errorf("conformance: policy %s: allowed = %v, want %v", label, decision.Allowed, tc.WantAllowed)
		}
		if tc.WantReasonContains != "" && !strings.Contains(decision.Reason, tc.WantReasonContains) {
			return fmt.Errorf("conformance: policy %s: reason = %q, want substring %q", label, decision.Reason, tc.WantReasonContains)
		}
	}
	return nil
}
