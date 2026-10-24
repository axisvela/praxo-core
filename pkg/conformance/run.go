package conformance

import (
	"errors"
	"fmt"
)

// Check is one named conformance check.
type Check struct {
	// Name labels the check in the combined error.
	Name string
	// Run executes the check.
	Run func() error
}

// Run executes every check and joins all failures into one error. It does not
// stop at the first failure.
func Run(checks ...Check) error {
	errs := make([]error, 0, len(checks))
	for i, check := range checks {
		label := caseLabel(check.Name, i)
		if check.Run == nil {
			errs = append(errs, fmt.Errorf("conformance: %s: nil check", label))
			continue
		}
		if err := check.Run(); err != nil {
			errs = append(errs, fmt.Errorf("conformance: %s: %w", label, err))
		}
	}
	return errors.Join(errs...)
}
