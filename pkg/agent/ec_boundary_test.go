package agent

import (
	"context"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/policy"
)

func TestEC05UnchangedFinalArgumentsSkipSecondAuthorization(t *testing.T) {
	impl := &recordingTool{}
	ag := interruptAgent(&interruptModel{}, impl, func(context.Context, Interrupt) (InterruptDecision, error) {
		return InterruptDecision{Action: InterruptApprove}, nil
	})
	checks := 0
	ag.Policy = policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
		if action.Kind != "tool.invoke" {
			return policy.Decision{Allowed: true}, nil
		}
		checks++
		if checks > 1 {
			return policy.Decision{Reason: "authorization revoked"}, nil
		}
		return policy.Decision{Allowed: true}, nil
	})
	if _, err := ag.Run(context.Background(), Session{ID: "ec-05"}, "go"); err != nil {
		t.Fatal(err)
	}
	if impl.args == nil {
		t.Fatal("tool did not execute")
	}
	if checks != 1 {
		t.Fatalf("policy checks = %d, want 1: unchanged final arguments were reauthorized", checks)
	}
}
