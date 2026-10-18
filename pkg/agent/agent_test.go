package agent

import (
	"context"
	"testing"

	"github.com/axisvela/praxo-core/v3/pkg/event"
	"github.com/axisvela/praxo-core/v3/pkg/model"
	"github.com/axisvela/praxo-core/v3/pkg/policy"
	"github.com/axisvela/praxo-core/v3/pkg/tool"
)

type fakeModel struct {
	calls int
}

func (f *fakeModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	f.calls++
	if f.calls == 1 {
		return model.Response{
			Message: model.Message{
				Role: model.RoleAssistant,
				ToolCalls: []model.ToolCall{{
					ID: "call-1", Name: "echo", Arguments: map[string]any{"value": "hi"},
				}},
			},
			Usage: model.Usage{InputTokens: 10, OutputTokens: 2},
		}, nil
	}
	return model.Response{
		Message: model.Message{Role: model.RoleAssistant, Content: "final"},
		Usage:   model.Usage{InputTokens: 4, OutputTokens: 1},
	}, nil
}

type echoTool struct{ calls int }

func (e *echoTool) Name() string        { return "echo" }
func (e *echoTool) Description() string { return "echo a value" }
func (e *echoTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	e.calls++
	return args["value"], nil
}

type denyPolicy struct{}

func (denyPolicy) Authorize(context.Context, policy.Action) (policy.Decision, error) {
	return policy.Decision{Allowed: false, Reason: "test deny"}, nil
}

type allowPolicy struct{}

func (allowPolicy) Authorize(context.Context, policy.Action) (policy.Decision, error) {
	return policy.Decision{Allowed: true}, nil
}

func TestRunExecutesToolAndCompletes(t *testing.T) {
	tools := tool.NewRegistry()
	echo := &echoTool{}
	tools.Register(echo)
	var events []string

	ag := &Agent{
		Model:  &fakeModel{},
		Tools:  tools,
		Policy: allowPolicy{},
		Events: event.FuncSink(func(_ context.Context, e event.Event) error {
			events = append(events, e.Type)
			return nil
		}),
		MaxSteps: 4,
	}
	result, err := ag.Run(context.Background(), Session{ID: "s1", TenantID: "acme"}, "do it")
	if err != nil {
		t.Fatal(err)
	}
	if result.Output != "final" || result.Steps != 2 {
		t.Fatalf("result = %+v", result)
	}
	if echo.calls != 1 {
		t.Fatalf("tool calls = %d, want 1", echo.calls)
	}
	if result.Usage.InputTokens != 14 || result.Usage.OutputTokens != 3 {
		t.Fatalf("usage = %+v", result.Usage)
	}
	if len(events) < 3 || events[0] != "run.started" || events[len(events)-1] != "run.completed" {
		t.Fatalf("events = %+v", events)
	}
}

func TestRunFailsClosedOnPolicyDenial(t *testing.T) {
	ag := &Agent{Model: &fakeModel{}, Policy: denyPolicy{}}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); err == nil {
		t.Fatal("expected policy denial")
	}
}

func TestRunRequiresModel(t *testing.T) {
	ag := &Agent{}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); err == nil {
		t.Fatal("expected an error")
	}
}
