package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"reflect"
	"sync"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

var errWorkspaceGuard = errors.New("workspace execution guard rejected operation")

func runGovernedWorkspace(ctx context.Context, opts agent.Options, session agent.Session, prompt string) (*agent.Result, error) {
	for name, control := range map[string]any{"model": opts.Model, "policy": opts.Policy, "events": opts.Events} {
		if workspaceControlMissing(control) {
			return nil, fmt.Errorf("workspace: %s is required", name)
		}
	}
	if opts.Tools == nil || len(opts.AllowedTools) == 0 {
		return nil, errors.New("workspace: registered tools and explicit scope are required")
	}
	if opts.ToolRetry != nil {
		return nil, errors.New("workspace: automatic tool retries are not supported")
	}
	sensitive := map[string]bool{
		"fs.list": false, "fs.read": false, "fs.glob": false, "fs.grep": false,
		"fs.write": true, "fs.edit": true, "fs.delete": true,
	}
	for _, name := range opts.AllowedTools {
		write, known := sensitive[name]
		if !known {
			return nil, fmt.Errorf("workspace: unsupported tool %q", name)
		}
		if _, err := opts.Tools.Get(name); err != nil {
			return nil, err
		}
		if write && (!opts.InterruptOn[name] || opts.OnInterruptDecision == nil) {
			return nil, fmt.Errorf("workspace: approval gate and handler required for %s", name)
		}
	}

	var mu sync.Mutex
	approvals := make(map[string]int)
	var guardFailure error
	if approve := opts.OnInterruptDecision; approve != nil {
		opts.OnInterruptDecision = func(ctx context.Context, interrupt agent.Interrupt) (agent.InterruptDecision, error) {
			decision, err := approve(ctx, interrupt)
			if err != nil {
				return decision, err
			}
			if decision.Action == agent.InterruptApprove || decision.Action == agent.InterruptEdit {
				args := interrupt.Call.Arguments
				if decision.Action == agent.InterruptEdit {
					args = decision.Arguments
				}
				raw, err := json.Marshal(args)
				if err != nil {
					return agent.InterruptDecision{}, err
				}
				mu.Lock()
				approvals[interrupt.Call.Name+":"+string(raw)]++
				mu.Unlock()
			}
			return decision, nil
		}
	}
	registry := tool.NewRegistry()
	for _, name := range opts.AllowedTools {
		next, _ := opts.Tools.Get(name)
		registry.Register(workspaceTool{Tool: next, invoke: func(ctx context.Context, args map[string]any) (any, error) {
			guard := func() (map[string]any, error) {
				mu.Lock()
				rejection := guardFailure
				mu.Unlock()
				if rejection != nil {
					return nil, rejection
				}
				if err := ctx.Err(); err != nil {
					return nil, err
				}
				raw, err := json.Marshal(args)
				if err != nil {
					return nil, err
				}
				var snapshot map[string]any
				if err := json.Unmarshal(raw, &snapshot); err != nil {
					return nil, err
				}
				decision, err := opts.Policy.Authorize(ctx, policy.Action{
					Kind: "tool.invoke", SessionID: session.ID, ToolName: name, Arguments: snapshot,
				})
				if err != nil {
					return nil, err
				}
				if !decision.Allowed {
					return nil, errors.New("workspace: execution denied")
				}
				if err := ctx.Err(); err != nil {
					return nil, err
				}
				if sensitive[name] {
					raw, err = json.Marshal(snapshot)
					if err != nil {
						return nil, err
					}
					key := name + ":" + string(raw)
					mu.Lock()
					approved := approvals[key] > 0
					if approved {
						approvals[key]--
					}
					mu.Unlock()
					if !approved {
						return nil, errors.New("workspace: approval does not match final operation")
					}
				}
				return snapshot, nil
			}
			snapshot, err := guard()
			if err != nil {
				rejection := errors.Join(errWorkspaceGuard, err)
				mu.Lock()
				if guardFailure == nil {
					guardFailure = rejection
				}
				mu.Unlock()
				return nil, rejection
			}
			return next.Invoke(ctx, snapshot)
		}})
	}
	opts.Tools = registry
	opts.AllowedTools = append([]string(nil), opts.AllowedTools...)
	gates := make(map[string]bool, len(opts.InterruptOn))
	for name, enabled := range opts.InterruptOn {
		gates[name] = enabled
	}
	opts.InterruptOn = gates
	onResult := opts.Hooks.OnToolResult
	opts.Hooks.OnToolResult = func(ctx context.Context, runID string, call model.ToolCall, result any, toolErr error) error {
		mu.Lock()
		rejection := guardFailure
		mu.Unlock()
		if rejection != nil {
			return rejection
		}
		if onResult != nil {
			return onResult(ctx, runID, call, result, toolErr)
		}
		return nil
	}
	ag, err := agent.New(opts)
	if err != nil {
		return nil, err
	}
	return ag.Run(ctx, session, prompt)
}

func workspaceControlMissing(control any) bool {
	value := reflect.ValueOf(control)
	if !value.IsValid() {
		return true
	}
	switch value.Kind() {
	case reflect.Chan, reflect.Func, reflect.Interface, reflect.Map, reflect.Pointer, reflect.Slice:
		return value.IsNil()
	}
	return false
}

type workspaceTool struct {
	tool.Tool
	invoke func(context.Context, map[string]any) (any, error)
}

func (t workspaceTool) Invoke(ctx context.Context, args map[string]any) (any, error) {
	return t.invoke(ctx, args)
}

func (t workspaceTool) Spec() model.ToolSpec {
	if provider, ok := t.Tool.(tool.SpecProvider); ok {
		return provider.Spec()
	}
	return model.ToolSpec{Name: t.Name(), Description: t.Description()}
}
