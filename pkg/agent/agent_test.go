package agent

import (
	"context"
	"errors"
	"testing"

	"github.com/axisvela/praxo-core/pkg/event"
	"github.com/axisvela/praxo-core/pkg/model"
	"github.com/axisvela/praxo-core/pkg/policy"
	"github.com/axisvela/praxo-core/pkg/tool"
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

type flakyModel struct {
	failures int
	calls    int
	err      error
}

func (f *flakyModel) Generate(context.Context, model.Request) (model.Response, error) {
	f.calls++
	if f.calls <= f.failures {
		return model.Response{}, f.err
	}
	return model.Response{
		Message: model.Message{Role: model.RoleAssistant, Content: "recovered"},
	}, nil
}

func TestRetryPolicyRetriesTransientErrors(t *testing.T) {
	m := &flakyModel{failures: 2, err: errors.New("transient")}
	ag := &Agent{Model: m, Retry: RetryPolicy{Attempts: 3}}
	result, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it")
	if err != nil {
		t.Fatal(err)
	}
	if m.calls != 3 || result.Output != "recovered" {
		t.Fatalf("calls=%d result=%+v", m.calls, result)
	}
}

func TestRetryPolicyHonorsShouldRetry(t *testing.T) {
	sentinel := errors.New("permanent")
	m := &flakyModel{failures: 1, err: sentinel}
	ag := &Agent{
		Model: m,
		Retry: RetryPolicy{
			Attempts:    3,
			ShouldRetry: func(err error) bool { return !errors.Is(err, sentinel) },
		},
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); !errors.Is(err, sentinel) {
		t.Fatalf("err = %v", err)
	}
	if m.calls != 1 {
		t.Fatalf("calls = %d, want 1", m.calls)
	}
}

type streamingModel struct {
	deltas []string
}

func (s *streamingModel) Generate(context.Context, model.Request) (model.Response, error) {
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "hello"}}, nil
}

func (s *streamingModel) GenerateStream(_ context.Context, _ model.Request, onDelta func(string)) (model.Response, error) {
	for _, d := range s.deltas {
		onDelta(d)
	}
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "hello"}}, nil
}

func TestRunStreamsDeltas(t *testing.T) {
	m := &streamingModel{deltas: []string{"he", "llo"}}
	var got []string
	ag := &Agent{Model: m, OnDelta: func(d string) { got = append(got, d) }}
	result, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it")
	if err != nil {
		t.Fatal(err)
	}
	if result.Output != "hello" || len(got) != 2 || got[0] != "he" || got[1] != "llo" {
		t.Fatalf("result=%+v deltas=%v", result, got)
	}
}

type simpleModel struct{}

func (simpleModel) Generate(context.Context, model.Request) (model.Response, error) {
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "ok"}}, nil
}

func TestRunInvokesHooksInOrder(t *testing.T) {
	var order []string
	ag := &Agent{
		Model: simpleModel{},
		Hooks: Hooks{
			OnRunStart: func(context.Context, string, Session) error {
				order = append(order, "start")
				return nil
			},
			OnStep: func(context.Context, string, int, []model.Message) error {
				order = append(order, "step")
				return nil
			},
			OnModelCall: func(context.Context, string, model.Request) error {
				order = append(order, "model.call")
				return nil
			},
			OnModelResult: func(context.Context, string, model.Response) error {
				order = append(order, "model.result")
				return nil
			},
			OnRunComplete: func(context.Context, *Result) error {
				order = append(order, "complete")
				return nil
			},
		},
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); err != nil {
		t.Fatal(err)
	}
	want := []string{"start", "step", "model.call", "model.result", "complete"}
	if len(order) != len(want) {
		t.Fatalf("order = %v", order)
	}
	for i := range want {
		if order[i] != want[i] {
			t.Fatalf("order = %v, want %v", order, want)
		}
	}
}

func TestRunDoesNotMutateMaxSteps(t *testing.T) {
	ag := &Agent{Model: simpleModel{}}
	if _, err := ag.Run(context.Background(), Session{ID: "s1"}, "do it"); err != nil {
		t.Fatal(err)
	}
	if ag.MaxSteps != 0 {
		t.Fatalf("MaxSteps = %d, want 0", ag.MaxSteps)
	}
}
