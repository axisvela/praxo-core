package main

import (
	"context"
	"errors"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

func governedOptions(m model.Model, tools *tool.Registry, hook policy.Hook, allowed []string) (agent.Options, error) {
	if hook == nil {
		return agent.Options{}, errors.New("governed: mandatory policy is missing")
	}
	if len(allowed) == 0 {
		return agent.Options{}, errors.New("governed: explicit tool scope is required")
	}
	return agent.Options{
		Model: m, Tools: tools, MaxSteps: 3, Policy: hook, AllowedTools: allowed,
	}, nil
}

func publicOnly(checked *[]string) policy.Hook {
	return policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
		switch action.Kind {
		case "model.generate":
			return policy.Decision{Allowed: true}, nil
		case "tool.invoke":
			target, _ := action.Arguments["target"].(string)
			*checked = append(*checked, target)
			return policy.Decision{
				Allowed: target == "public",
				Reason:  "only the public target is permitted",
			}, nil
		default:
			return policy.Decision{Reason: "unsupported action"}, nil
		}
	})
}

func TestGovernedRejectsMissingPolicy(t *testing.T) {
	impl := &recordTool{}
	tools := tool.NewRegistry()
	tools.Register(impl)
	if _, err := governedOptions(fixtureModel{target: "public"}, tools, nil, []string{"record"}); err == nil {
		t.Fatal("missing policy was accepted")
	}
	if impl.calls != 0 {
		t.Fatalf("effects=%d", impl.calls)
	}
}

func TestGovernedRejectsEmptyToolScope(t *testing.T) {
	impl := &recordTool{}
	tools := tool.NewRegistry()
	tools.Register(impl)
	if _, err := governedOptions(fixtureModel{target: "public"}, tools, publicOnly(&[]string{}), nil); err == nil {
		t.Fatal("empty tool scope was accepted")
	}
	if impl.calls != 0 {
		t.Fatalf("effects=%d", impl.calls)
	}
}

func TestGovernedReauthorizesFinalArguments(t *testing.T) {
	impl := &recordTool{}
	tools := tool.NewRegistry()
	tools.Register(impl)
	var checked []string
	options, err := governedOptions(fixtureModel{target: "public"}, tools, publicOnly(&checked), []string{"record"})
	if err != nil {
		t.Fatal(err)
	}
	options.Middleware = []agent.Middleware{{BeforeTool: func(_ context.Context, call *agent.ToolCall) error {
		call.Call.Arguments["target"] = "private"
		return nil
	}}}
	ag, err := agent.New(options)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ag.Run(context.Background(), agent.Session{ID: "governed-final-args"}, "record"); err == nil {
		t.Fatal("mutated arguments were not denied")
	}
	if impl.calls != 0 {
		t.Fatalf("effects=%d", impl.calls)
	}
	if len(checked) != 2 || checked[0] != "public" || checked[1] != "private" {
		t.Fatalf("authorized targets=%v", checked)
	}
}

func TestGovernedReauthorizesApprovalEdit(t *testing.T) {
	impl := &recordTool{}
	tools := tool.NewRegistry()
	tools.Register(impl)
	var checked []string
	options, err := governedOptions(fixtureModel{target: "public"}, tools, publicOnly(&checked), []string{"record"})
	if err != nil {
		t.Fatal(err)
	}
	options.InterruptOn = map[string]bool{"record": true}
	options.OnInterruptDecision = func(context.Context, agent.Interrupt) (agent.InterruptDecision, error) {
		return agent.InterruptDecision{
			Action:    agent.InterruptEdit,
			Arguments: map[string]any{"target": "private"},
		}, nil
	}
	ag, err := agent.New(options)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ag.Run(context.Background(), agent.Session{ID: "governed-approval-edit"}, "record"); err == nil {
		t.Fatal("edited approval arguments were not denied")
	}
	if impl.calls != 0 {
		t.Fatalf("effects=%d", impl.calls)
	}
	if len(checked) != 2 || checked[0] != "public" || checked[1] != "private" {
		t.Fatalf("authorized targets=%v", checked)
	}
}

func TestGovernedFailsClosedOnPolicyError(t *testing.T) {
	impl := &recordTool{}
	tools := tool.NewRegistry()
	tools.Register(impl)
	hook := policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
		if action.Kind == "tool.invoke" {
			return policy.Decision{}, errors.New("policy service unavailable")
		}
		return policy.Decision{Allowed: true}, nil
	})
	options, err := governedOptions(fixtureModel{target: "public"}, tools, hook, []string{"record"})
	if err != nil {
		t.Fatal(err)
	}
	ag, err := agent.New(options)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ag.Run(context.Background(), agent.Session{ID: "governed-policy-error"}, "record"); err == nil {
		t.Fatal("policy failure was not propagated")
	}
	if impl.calls != 0 {
		t.Fatalf("effects=%d", impl.calls)
	}
}
