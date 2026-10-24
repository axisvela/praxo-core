package conformance

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/axisvela/praxo-core/v2/pkg/sandbox"
)

// SandboxCase is one sandbox execution expectation. Commands are environment
// specific, so the caller supplies the command and expected result.
type SandboxCase struct {
	// Name labels the case in errors. Empty names get an index label.
	Name string
	// Spec is passed to Run.
	Spec sandbox.Spec
	// Command is passed to Run.
	Command []string
	// WantExitCode is the required exit code.
	WantExitCode int
	// WantStdoutContains checks stdout when non-empty.
	WantStdoutContains string
	// WantStderrContains checks stderr when non-empty.
	WantStderrContains string
}

// CheckSandbox verifies caller-supplied sandbox execution expectations.
func CheckSandbox(ctx context.Context, runner sandbox.Sandbox, cases ...SandboxCase) error {
	if runner == nil {
		return errors.New("conformance: sandbox is nil")
	}
	if len(cases) == 0 {
		return errors.New("conformance: at least one sandbox case is required")
	}
	for i, tc := range cases {
		label := tc.Name
		if label == "" {
			label = fmt.Sprintf("case-%d", i)
		}
		if len(tc.Command) == 0 {
			return fmt.Errorf("conformance: sandbox %s: command is required", label)
		}
		result, err := runner.Run(ctx, tc.Spec, tc.Command)
		if err != nil {
			return fmt.Errorf("conformance: sandbox %s: %w", label, err)
		}
		if result.ExitCode != tc.WantExitCode {
			return fmt.Errorf("conformance: sandbox %s: exit = %d, want %d", label, result.ExitCode, tc.WantExitCode)
		}
		if tc.WantStdoutContains != "" && !strings.Contains(result.Stdout, tc.WantStdoutContains) {
			return fmt.Errorf("conformance: sandbox %s: stdout = %q, want substring %q", label, result.Stdout, tc.WantStdoutContains)
		}
		if tc.WantStderrContains != "" && !strings.Contains(result.Stderr, tc.WantStderrContains) {
			return fmt.Errorf("conformance: sandbox %s: stderr = %q, want substring %q", label, result.Stderr, tc.WantStderrContains)
		}
	}
	return nil
}
