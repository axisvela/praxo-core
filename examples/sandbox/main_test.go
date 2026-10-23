package main

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/sandbox"
)

func allowGoVersion(t *testing.T) policy.Hook {
	t.Helper()
	return policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
		command := commandFromArguments(action.Arguments)
		if len(command) == 2 && command[0] == "go" && command[1] == "version" {
			return policy.Decision{Allowed: true}, nil
		}
		return policy.Decision{Allowed: false, Reason: "command is not allowlisted"}, nil
	})
}

func TestSandboxRunsAllowedCommand(t *testing.T) {
	result, err := (commandSandbox{}).Run(context.Background(), sandbox.Spec{
		Timeout: 10 * time.Second,
	}, []string{"go", "version"})
	if err != nil {
		t.Fatal(err)
	}
	if result.ExitCode != 0 || !strings.Contains(result.Stdout, "go version") {
		t.Fatalf("result = %#v", result)
	}
}

func TestPolicyDeniesNonAllowlistedCommand(t *testing.T) {
	decision, err := allowGoVersion(t).Authorize(context.Background(), policy.Action{
		Kind:      "sandbox",
		ToolName:  "exec",
		Arguments: map[string]any{"command": []any{"rm", "-rf", "/"}},
	})
	if err != nil {
		t.Fatal(err)
	}
	if decision.Allowed || decision.Reason != "command is not allowlisted" {
		t.Fatalf("decision = %#v", decision)
	}
}

func TestDeniedCommandIsNotExecuted(t *testing.T) {
	called := false
	runner := sandbox.FuncSandbox(func(context.Context, sandbox.Spec, []string) (sandbox.Result, error) {
		called = true
		return sandbox.Result{}, nil
	})
	decision, _, executed, err := authorizeAndRun(context.Background(), allowGoVersion(t), runner, []string{"rm", "-rf", "/"})
	if err != nil {
		t.Fatal(err)
	}
	if executed || decision.Allowed {
		t.Fatalf("decision = %#v executed = %v", decision, executed)
	}
	if called {
		t.Fatal("denied command reached the sandbox")
	}
}
