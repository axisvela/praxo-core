package main

import (
	"bytes"
	"context"
	"fmt"
	"log"
	"os/exec"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/sandbox"
)

func main() {
	ctx := context.Background()
	hook := policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
		command := commandFromArguments(action.Arguments)
		if len(command) == 2 && command[0] == "go" && command[1] == "version" {
			return policy.Decision{Allowed: true}, nil
		}
		return policy.Decision{Allowed: false, Reason: "command is not allowlisted"}, nil
	})
	runner := commandSandbox{}

	run(ctx, hook, runner, []string{"go", "version"})
	run(ctx, hook, runner, []string{"rm", "-rf", "/"})
}

func run(ctx context.Context, hook policy.Hook, runner sandbox.Sandbox, command []string) {
	decision, result, executed, err := authorizeAndRun(ctx, hook, runner, command)
	if err != nil {
		log.Fatal(err)
	}
	if !executed {
		fmt.Println("denied:", decision.Reason)
		return
	}
	fmt.Printf("exit=%d stdout=%q\n", result.ExitCode, result.Stdout)
}

func authorizeAndRun(ctx context.Context, hook policy.Hook, runner sandbox.Sandbox, command []string) (policy.Decision, sandbox.Result, bool, error) {
	decision, err := hook.Authorize(ctx, policy.Action{
		Kind:      "sandbox",
		ToolName:  "exec",
		Arguments: map[string]any{"command": toAny(command)},
	})
	if err != nil {
		return policy.Decision{}, sandbox.Result{}, false, err
	}
	if !decision.Allowed {
		return decision, sandbox.Result{}, false, nil
	}
	result, err := runner.Run(ctx, sandbox.Spec{Timeout: 5 * time.Second}, command)
	if err != nil {
		return decision, sandbox.Result{}, false, err
	}
	return decision, result, true, nil
}

type commandSandbox struct{}

func (commandSandbox) Run(ctx context.Context, spec sandbox.Spec, command []string) (sandbox.Result, error) {
	if len(command) == 0 {
		return sandbox.Result{}, fmt.Errorf("sandbox: command is required")
	}
	runCtx := ctx
	var cancel context.CancelFunc
	if spec.Timeout > 0 {
		runCtx, cancel = context.WithTimeout(ctx, spec.Timeout)
		defer cancel()
	}
	cmd := exec.CommandContext(runCtx, command[0], command[1:]...)
	if spec.WorkDir != "" {
		cmd.Dir = spec.WorkDir
	}
	for key, value := range spec.Env {
		cmd.Env = append(cmd.Env, key+"="+value)
	}
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	result := sandbox.Result{Stdout: stdout.String(), Stderr: stderr.String()}
	if err != nil {
		if exit, ok := err.(*exec.ExitError); ok {
			result.ExitCode = exit.ExitCode()
			return result, nil
		}
		return sandbox.Result{}, err
	}
	return result, nil
}

func commandFromArguments(arguments map[string]any) []string {
	switch value := arguments["command"].(type) {
	case []string:
		return value
	case []any:
		out := make([]string, 0, len(value))
		for _, item := range value {
			text, ok := item.(string)
			if !ok {
				return nil
			}
			out = append(out, text)
		}
		return out
	default:
		return nil
	}
}

func toAny(command []string) []any {
	out := make([]any, len(command))
	for i, item := range command {
		out[i] = item
	}
	return out
}
