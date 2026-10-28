package agent

import (
	"context"
	"errors"
	"reflect"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

func TestRunCleansUpAfterMiddlewareFailure(t *testing.T) {
	failure := errors.New("validation failed")
	var cleaned int
	ag := &Agent{
		Model: simpleModel{},
		Middleware: []Middleware{
			{AfterRun: func(context.Context, *Result, error) error { return failure }},
			{AfterRun: func(_ context.Context, _ *Result, runErr error) error {
				cleaned++
				if !errors.Is(runErr, failure) {
					t.Errorf("cleanup error = %v", runErr)
				}
				return errors.New("later cleanup error")
			}},
		},
	}
	_, err := ag.Run(context.Background(), Session{ID: "session"}, "answer")
	if !errors.Is(err, failure) || cleaned != 1 {
		t.Fatalf("error=%v cleaned=%d", err, cleaned)
	}
}

func TestRunCleansUpEnteredMiddlewareOnStartFailure(t *testing.T) {
	for _, panics := range []bool{false, true} {
		t.Run(map[bool]string{false: "error", true: "panic"}[panics], func(t *testing.T) {
			failure := errors.New("before run failed")
			var entered, cleaned []int
			var events []string
			ag := &Agent{Model: simpleModel{}}
			for i := 0; i < 3; i++ {
				ag.Middleware = append(ag.Middleware, Middleware{
					BeforeRun: func(context.Context, *RunState) error {
						entered = append(entered, i)
						if i == 1 {
							if panics {
								panic(failure)
							}
							return failure
						}
						return nil
					},
					AfterRun: func(context.Context, *Result, error) error {
						cleaned = append(cleaned, i)
						return nil
					},
				})
			}
			ag.Events = event.FuncSink(func(_ context.Context, e event.Event) error {
				events = append(events, e.Type)
				return nil
			})
			var recovered any
			func() {
				defer func() { recovered = recover() }()
				_, err := ag.Run(context.Background(), Session{ID: "session"}, "answer")
				if panics || !errors.Is(err, failure) {
					t.Errorf("error = %v", err)
				}
			}()
			if panics && recovered != failure || !panics && recovered != nil {
				t.Errorf("panic = %v", recovered)
			}
			if !reflect.DeepEqual(entered, []int{0, 1}) || !reflect.DeepEqual(cleaned, []int{0, 1}) || len(events) != 0 {
				t.Fatalf("entered=%v cleaned=%v events=%v", entered, cleaned, events)
			}
		})
	}
}

func TestRunBuiltInStateCleansUpAfterFailedModel(t *testing.T) {
	failure := errors.New("model failed")
	var id string
	ag, err := New(Options{
		Model: &stubModel{err: failure}, ModelCallLimit: 1,
		ToolSelector: &fakeSelector{names: []string{"echo"}},
		Middleware: []Middleware{{
			BeforeRun: func(_ context.Context, state *RunState) error { id = state.RunID; return nil },
			AfterRun:  func(context.Context, *Result, error) error { return errors.New("cleanup failed") },
		}},
	})
	if err != nil {
		t.Fatal(err)
	}
	for iteration := 0; iteration < 50; iteration++ {
		if _, err := ag.Run(context.Background(), Session{ID: "session"}, "answer"); !errors.Is(err, failure) {
			t.Fatal(err)
		}
		for _, mw := range ag.Middleware {
			switch mw.Name {
			case "call-limit":
				if err := mw.BeforeModel(context.Background(), &ModelCall{RunID: id}); err != nil {
					t.Fatalf("retained call count: %v", err)
				}
			case "tool-selection":
				if err := mw.BeforeTool(context.Background(), &ToolCall{RunID: id, Call: &model.ToolCall{Name: "other"}}); err != nil {
					t.Fatalf("retained selection: %v", err)
				}
			}
			if mw.AfterRun != nil {
				_ = mw.AfterRun(context.Background(), &Result{RunID: id}, failure)
			}
		}
	}
}
