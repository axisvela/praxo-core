package event_sink_recipe

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

type fakeModel struct{}

func (fakeModel) Generate(_ context.Context, request model.Request) (model.Response, error) {
	last := request.Messages[len(request.Messages)-1]
	if last.Role == model.RoleTool {
		return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "done"}}, nil
	}
	return model.Response{Message: model.Message{
		Role:      model.RoleAssistant,
		ToolCalls: []model.ToolCall{{Name: "record"}},
	}}, nil
}

type failingModel struct{ err error }

func (m failingModel) Generate(context.Context, model.Request) (model.Response, error) {
	return model.Response{}, m.err
}

type countingTool struct {
	calls int
}

func (t *countingTool) Name() string        { return "record" }
func (t *countingTool) Description() string { return "Count invocations." }

func (t *countingTool) Invoke(context.Context, map[string]any) (any, error) {
	t.calls++
	return "recorded", nil
}

func allowPolicy() policy.FuncHook {
	return func(context.Context, policy.Action) (policy.Decision, error) {
		return policy.Decision{Allowed: true}, nil
	}
}

func TestFilterSinkForwardsSelectedEvents(t *testing.T) {
	var received []string
	sink := event.FilterSink{
		Sink: event.FuncSink(func(_ context.Context, e event.Event) error {
			received = append(received, e.Type)
			return nil
		}),
		Predicate: func(e event.Event) bool { return e.Type == "run.completed" },
	}
	if err := sink.Emit(context.Background(), event.Event{Type: "run.started"}); err != nil {
		t.Fatal(err)
	}
	if err := sink.Emit(context.Background(), event.Event{Type: "run.completed"}); err != nil {
		t.Fatal(err)
	}
	if len(received) != 1 || received[0] != "run.completed" {
		t.Fatalf("received = %v, want [run.completed]", received)
	}
}

func TestMultiSinkStopsOnFailure(t *testing.T) {
	laterCalled := false
	sink := event.MultiSink{
		event.FuncSink(func(context.Context, event.Event) error {
			return errors.New("sink unavailable")
		}),
		event.FuncSink(func(context.Context, event.Event) error {
			laterCalled = true
			return nil
		}),
	}
	if err := sink.Emit(context.Background(), event.Event{Type: "run.started"}); err == nil {
		t.Fatal("expected the first sink error")
	}
	if laterCalled {
		t.Fatal("a later sink ran after the first failure")
	}
}

type fakePublisher struct {
	events []event.Event
}

func (p *fakePublisher) Publish(_ context.Context, e event.Event) error {
	p.events = append(p.events, e)
	return nil
}

func TestPublisherSinkDelegates(t *testing.T) {
	publisher := &fakePublisher{}
	sink := event.PublisherSink{Publisher: publisher}
	if err := sink.Emit(context.Background(), event.Event{Type: "run.completed"}); err != nil {
		t.Fatal(err)
	}
	if len(publisher.events) != 1 || publisher.events[0].Type != "run.completed" {
		t.Fatalf("published = %#v", publisher.events)
	}
}

func TestAgentSinkFailureBeforeToolPreventsInvocation(t *testing.T) {
	impl := &countingTool{}
	registry := tool.NewRegistry()
	registry.Register(impl)
	ag, err := agent.New(agent.Options{
		Model:    fakeModel{},
		Tools:    registry,
		MaxSteps: 3,
		Policy:   allowPolicy(),
		Events: event.FuncSink(func(_ context.Context, e event.Event) error {
			if e.Type == "tool.call" {
				return errors.New("sink unavailable")
			}
			return nil
		}),
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ag.Run(context.Background(), agent.Session{ID: "sink"}, "go"); err == nil ||
		!strings.Contains(err.Error(), "sink unavailable") {
		t.Fatalf("err = %v, want sink failure", err)
	}
	if impl.calls != 0 {
		t.Fatalf("tool calls = %d, want 0", impl.calls)
	}
}

func TestAgentTerminalSinkFailureDoesNotMaskOriginalError(t *testing.T) {
	original := errors.New("model failed")
	ag, err := agent.New(agent.Options{
		Model:    failingModel{err: original},
		Tools:    tool.NewRegistry(),
		MaxSteps: 3,
		Policy:   allowPolicy(),
		Events: event.FuncSink(func(_ context.Context, e event.Event) error {
			if e.Type == "run.failed" {
				return errors.New("failed-event sink unavailable")
			}
			return nil
		}),
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ag.Run(context.Background(), agent.Session{ID: "sink"}, "go"); !errors.Is(err, original) {
		t.Fatalf("err = %v, want the original model error", err)
	}
}
