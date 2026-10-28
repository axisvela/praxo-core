package agent

import (
	"context"
	"errors"
	"reflect"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/memory"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

func TestRunValidatesBeforeSuccessProjections(t *testing.T) {
	for _, structured := range []bool{false, true} {
		t.Run(map[bool]string{false: "text", true: "structured-tool"}[structured], func(t *testing.T) {
			store := memory.NewMemoryStore()
			var events []string
			var checkpoints []Result
			var completed, after int
			invalid := errors.New("invalid output")
			ag := &Agent{
				Model: simpleModel{}, Memory: store,
				Middleware: []Middleware{{AfterRun: func(context.Context, *Result, error) error {
					after++
					return invalid
				}}},
				Events: event.FuncSink(func(_ context.Context, e event.Event) error {
					events = append(events, e.Type)
					return nil
				}),
				OnStream: func(part StreamPart) error {
					if part.Kind == StreamCheckpoint {
						checkpoints = append(checkpoints, part.Data.(Result))
					}
					return nil
				},
				Hooks: Hooks{OnRunComplete: func(context.Context, *Result) error {
					completed++
					return nil
				}},
			}
			if structured {
				ag.Model = &structuredToolModel{}
				ag.StructuredOutput = &StructuredOutput{Name: "answer", Schema: answerSchema(), Strategy: StructuredOutputTool}
			}
			_, err := ag.Run(context.Background(), Session{ID: "session"}, "answer")
			if !errors.Is(err, invalid) {
				t.Fatalf("error = %v", err)
			}
			records, err := store.Search(context.Background(), "session", "", 0)
			if err != nil {
				t.Fatal(err)
			}
			if after != 1 || completed != 0 || len(checkpoints) != 0 || len(records) != 0 {
				t.Fatalf("after=%d complete=%d checkpoints=%v records=%v", after, completed, checkpoints, records)
			}
			if !reflect.DeepEqual(events, []string{"run.started", "run.failed"}) {
				t.Fatalf("events = %v", events)
			}
		})
	}
}

func TestRunRepairsBeforeSuccessProjections(t *testing.T) {
	store := memory.NewMemoryStore()
	const repaired = `{"answer":"repaired"}`
	var checkpoint Result
	var hookOutput string
	var repairs int
	ag, err := New(Options{
		Model:  &stubModel{response: model.Response{Message: model.Message{Content: "invalid"}}},
		Memory: store,
		StructuredOutput: &StructuredOutput{
			Name: "answer", Schema: answerSchema(), MaxRepairs: 1,
			Repair: func(context.Context, string, error) (string, error) {
				repairs++
				return repaired, nil
			},
		},
		OnStream: func(part StreamPart) error {
			if part.Kind == StreamCheckpoint {
				checkpoint = part.Data.(Result)
			}
			return nil
		},
		Hooks: Hooks{OnRunComplete: func(_ context.Context, result *Result) error {
			hookOutput = result.Output
			return nil
		}},
	})
	if err != nil {
		t.Fatal(err)
	}
	result, err := ag.Run(context.Background(), Session{ID: "session"}, "answer")
	if err != nil {
		t.Fatal(err)
	}
	records, err := store.Search(context.Background(), "session", "", 0)
	if err != nil {
		t.Fatal(err)
	}
	if repairs != 1 || result.Output != repaired || checkpoint.Output != repaired || hookOutput != repaired ||
		len(records) != 1 || records[0].Content != repaired {
		t.Fatalf("repairs=%d result=%+v checkpoint=%+v hook=%q records=%v", repairs, result, checkpoint, hookOutput, records)
	}
}

func TestRunCompletionCallbackFailureHasSingleTerminalEvent(t *testing.T) {
	for _, stage := range []string{"hook", "checkpoint", "memory", "memory-put", "completed"} {
		t.Run(stage, func(t *testing.T) {
			failure := errors.New("completion failed")
			var events []string
			var after, errorHooks int
			ag := &Agent{
				Model: simpleModel{}, Memory: memory.NewMemoryStore(),
				Middleware: []Middleware{{AfterRun: func(context.Context, *Result, error) error {
					after++
					return nil
				}}},
				Events: event.FuncSink(func(_ context.Context, e event.Event) error {
					events = append(events, e.Type)
					if stage == "completed" && e.Type == "run.completed" {
						return failure
					}
					return nil
				}),
				OnStream: func(part StreamPart) error {
					if stage == "checkpoint" && part.Kind == StreamCheckpoint {
						return failure
					}
					return nil
				},
				Hooks: Hooks{
					OnRunComplete: func(context.Context, *Result) error {
						if stage == "hook" {
							return failure
						}
						return nil
					},
					OnMemoryWrite: func(context.Context, string, memory.Record) error {
						if stage == "memory" {
							return failure
						}
						return nil
					},
					OnRunError: func(_ context.Context, _ string, err error) {
						errorHooks++
						if !errors.Is(err, failure) {
							t.Errorf("error hook = %v", err)
						}
					},
				},
			}
			if stage == "memory-put" {
				ag.Memory = completionStore{Store: ag.Memory, put: func(context.Context, string, memory.Record) error {
					return failure
				}}
			}
			_, err := ag.Run(context.Background(), Session{ID: "session"}, "answer")
			if !errors.Is(err, failure) || after != 1 || errorHooks != 1 {
				t.Fatalf("error=%v after=%d error hooks=%d", err, after, errorHooks)
			}
			terminal := "run.failed"
			if stage == "completed" {
				terminal = "run.completed"
			}
			if !reflect.DeepEqual(events, []string{"run.started", terminal}) {
				t.Fatalf("events = %v", events)
			}
		})
	}
}

type completionStore struct {
	memory.Store
	put func(context.Context, string, memory.Record) error
}

func (s completionStore) Put(ctx context.Context, sessionID string, record memory.Record) error {
	return s.put(ctx, sessionID, record)
}

func TestRunCompletionHookCannotRewriteValidatedResult(t *testing.T) {
	const output = `{"answer":"valid"}`
	store := memory.NewMemoryStore()
	var checkpoint Result
	var startedID, completedID string
	ag, err := New(Options{
		Model:            &stubModel{response: model.Response{Message: model.Message{Content: output}}},
		Memory:           store,
		StructuredOutput: &StructuredOutput{Name: "answer", Schema: answerSchema()},
		Hooks: Hooks{OnRunComplete: func(_ context.Context, result *Result) error {
			result.Output = "invalid"
			result.RunID = "rewritten"
			result.Steps = 100
			result.Usage.OutputTokens = 100
			return nil
		}},
		OnStream: func(part StreamPart) error {
			if part.Kind == StreamCheckpoint {
				checkpoint = part.Data.(Result)
			}
			return nil
		},
		Events: event.FuncSink(func(_ context.Context, e event.Event) error {
			if e.Type == "run.started" {
				startedID = e.RunID
			}
			if e.Type == "run.completed" {
				completedID = e.RunID
			}
			return nil
		}),
	})
	if err != nil {
		t.Fatal(err)
	}
	result, err := ag.Run(context.Background(), Session{ID: "session"}, "answer")
	if err != nil {
		t.Fatal(err)
	}
	records, err := store.Search(context.Background(), "session", "", 0)
	if err != nil {
		t.Fatal(err)
	}
	if result.Output != output || result.RunID != startedID || completedID != startedID ||
		checkpoint != *result || result.Steps != 1 || result.Usage.OutputTokens != 0 ||
		len(records) != 1 || records[0].Content != output || records[0].ID != startedID {
		t.Fatalf("result=%+v checkpoint=%+v started=%s completed=%s records=%v", result, checkpoint, startedID, completedID, records)
	}
}

func TestRunCompletionOrder(t *testing.T) {
	var order []string
	store := memory.NewMemoryStore()
	ag := &Agent{
		Model: simpleModel{},
		Memory: completionStore{Store: store, put: func(ctx context.Context, id string, record memory.Record) error {
			order = append(order, "memory")
			return store.Put(ctx, id, record)
		}},
		Middleware: []Middleware{{AfterRun: func(context.Context, *Result, error) error {
			order = append(order, "after-run")
			return nil
		}}},
		Hooks: Hooks{OnRunComplete: func(context.Context, *Result) error {
			order = append(order, "hook")
			return nil
		}},
		OnStream: func(part StreamPart) error {
			if part.Kind == StreamCheckpoint {
				order = append(order, "checkpoint")
			}
			return nil
		},
		Events: event.FuncSink(func(_ context.Context, e event.Event) error {
			if e.Type == "run.completed" {
				order = append(order, "completed")
			}
			return nil
		}),
	}
	if _, err := ag.Run(context.Background(), Session{ID: "session"}, "answer"); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(order, []string{"after-run", "hook", "checkpoint", "memory", "completed"}) {
		t.Fatalf("order = %v", order)
	}
}

func TestRunFailurePreservesOriginalError(t *testing.T) {
	failure := errors.New("model failed")
	cleanupFailure := errors.New("cleanup failed")
	var after int
	ag := &Agent{
		Model: &stubModel{err: failure},
		Middleware: []Middleware{{AfterRun: func(_ context.Context, result *Result, err error) error {
			after++
			if result != nil || !errors.Is(err, failure) {
				t.Errorf("result=%+v error=%v", result, err)
			}
			return cleanupFailure
		}}},
	}
	result, err := ag.Run(context.Background(), Session{ID: "session"}, "answer")
	if result != nil || !errors.Is(err, failure) || after != 1 {
		t.Fatalf("result=%+v error=%v after=%d", result, err, after)
	}
}

func TestRunPanicDoesNotAttemptCompletion(t *testing.T) {
	failure := errors.New("step panicked")
	var after, completed int
	ag := &Agent{
		Model: simpleModel{},
		Middleware: []Middleware{{AfterRun: func(context.Context, *Result, error) error {
			after++
			return nil
		}}},
		Hooks: Hooks{
			OnStep: func(context.Context, string, int, []model.Message) error { panic(failure) },
			OnRunComplete: func(context.Context, *Result) error {
				completed++
				return nil
			},
		},
	}
	defer func() {
		if got := recover(); got != failure || after != 1 || completed != 0 {
			t.Errorf("panic=%v after=%d completed=%d", got, after, completed)
		}
	}()
	_, _ = ag.Run(context.Background(), Session{ID: "session"}, "answer")
	t.Fatal("expected original panic")
}
