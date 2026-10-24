package conformance

import (
	"context"
	"errors"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/sandbox"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

func TestCheckEventSink(t *testing.T) {
	var got event.Event
	sink := event.FuncSink(func(_ context.Context, ev event.Event) error {
		got = ev
		return nil
	})
	if err := CheckEventSink(context.Background(), sink); err != nil {
		t.Fatal(err)
	}
	if got.Type != "conformance.event" || got.SessionID == "" || got.Data["token"] == "" {
		t.Fatalf("event = %#v", got)
	}
	if err := CheckEventSink(context.Background(), nil); err == nil {
		t.Fatal("nil sink accepted")
	}
}

func TestCheckPolicyHook(t *testing.T) {
	hook := policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
		if action.ToolName == "allowed" {
			return policy.Decision{Allowed: true, Reason: "allowed by test"}, nil
		}
		return policy.Decision{Allowed: false, Reason: "denied by test"}, nil
	})
	cases := []PolicyCase{
		{Name: "allow", Action: policy.Action{Kind: "tool.invoke", ToolName: "allowed"}, WantAllowed: true, WantReasonContains: "allowed"},
		{Name: "deny", Action: policy.Action{Kind: "tool.invoke", ToolName: "blocked"}, WantAllowed: false, WantReasonContains: "denied"},
	}
	if err := CheckPolicyHook(context.Background(), hook, cases...); err != nil {
		t.Fatal(err)
	}
	if err := CheckPolicyHook(context.Background(), hook, PolicyCase{Action: policy.Action{Kind: "tool.invoke", ToolName: "allowed"}}); err == nil {
		t.Fatal("mismatched policy expectation passed")
	}
}

type fakeGateway struct {
	tools []tool.GatewayInfo
	err   error
}

func (g fakeGateway) ListTools() []tool.GatewayInfo { return g.tools }

func (g fakeGateway) Execute(_ context.Context, name string, _ map[string]any, _ string) (any, error) {
	if g.err != nil {
		return nil, g.err
	}
	return name, nil
}

func TestCheckGateway(t *testing.T) {
	gateway := fakeGateway{tools: []tool.GatewayInfo{{Name: "echo", Description: "Echo"}}}
	if err := CheckGateway(gateway); err != nil {
		t.Fatal(err)
	}
	if err := CheckGatewayExecute(context.Background(), gateway, GatewayCase{Tool: "echo"}); err != nil {
		t.Fatal(err)
	}
	if err := CheckGateway(fakeGateway{tools: []tool.GatewayInfo{{Name: "echo"}, {Name: "echo"}}}); err == nil {
		t.Fatal("duplicate tool names passed")
	}
	if err := CheckGateway(fakeGateway{tools: []tool.GatewayInfo{{Name: ""}}}); err == nil {
		t.Fatal("empty tool name passed")
	}
	if err := CheckGatewayExecute(context.Background(), fakeGateway{err: errors.New("denied")}, GatewayCase{Tool: "echo"}); err == nil {
		t.Fatal("unexpected gateway error passed")
	}
}

func TestCheckSandbox(t *testing.T) {
	runner := sandbox.FuncSandbox(func(_ context.Context, _ sandbox.Spec, _ []string) (sandbox.Result, error) {
		return sandbox.Result{ExitCode: 0, Stdout: "sandbox ok"}, nil
	})
	if err := CheckSandbox(context.Background(), runner, SandboxCase{
		Command:            []string{"true"},
		WantStdoutContains: "sandbox ok",
	}); err != nil {
		t.Fatal(err)
	}
	if err := CheckSandbox(context.Background(), runner, SandboxCase{
		Command:      []string{"true"},
		WantExitCode: 1,
	}); err == nil {
		t.Fatal("mismatched exit code passed")
	}
}
