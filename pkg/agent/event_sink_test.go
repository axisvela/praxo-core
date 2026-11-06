package agent

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

func TestEventSinkFailureBeforeToolPreventsInvocation(t *testing.T) {
	impl := &echoTool{}
	registry := tool.NewRegistry()
	registry.Register(impl)
	ag := &Agent{
		Model: &fakeModel{},
		Tools: registry,
		Events: event.FuncSink(func(_ context.Context, e event.Event) error {
			if e.Type == "tool.call" {
				return errors.New("sink unavailable")
			}
			return nil
		}),
	}
	_, err := ag.Run(context.Background(), Session{ID: "sink"}, "go")
	if err == nil || !strings.Contains(err.Error(), "sink unavailable") {
		t.Fatalf("err = %v, want sink failure", err)
	}
	if impl.calls != 0 {
		t.Fatalf("tool calls = %d, want 0", impl.calls)
	}
}

type failingModel struct {
	err error
}

func (m failingModel) Generate(context.Context, model.Request) (model.Response, error) {
	return model.Response{}, m.err
}

func TestFailedEventSinkFailureDoesNotMaskOriginalError(t *testing.T) {
	original := errors.New("model failed")
	ag := &Agent{
		Model: failingModel{err: original},
		Events: event.FuncSink(func(_ context.Context, e event.Event) error {
			if e.Type == "run.failed" {
				return errors.New("failed-event sink unavailable")
			}
			return nil
		}),
	}
	_, err := ag.Run(context.Background(), Session{ID: "sink"}, "go")
	if !errors.Is(err, original) {
		t.Fatalf("err = %v, want original model error", err)
	}
}
