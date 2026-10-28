package agent

import (
	"context"
	"errors"
	"reflect"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/memory"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

func waitCancelStart(t *testing.T, started <-chan struct{}) {
	t.Helper()
	select {
	case <-started:
	case <-time.After(5 * time.Second):
		t.Fatal("cancellation callback did not start")
	}
}

type cancelWaitModel struct {
	started chan struct{}
}

func (m *cancelWaitModel) Generate(ctx context.Context, _ model.Request) (model.Response, error) {
	close(m.started)
	<-ctx.Done()
	return model.Response{}, ctx.Err()
}

func TestRunCancellationDuringAfterRunStopsCompletion(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	started := make(chan struct{})
	release := make(chan struct{})
	store := memory.NewMemoryStore()
	var callbackErr error
	var events []string
	var checkpoints, memoryHooks, completed int
	var onRunErr error
	ag := &Agent{
		Model:  simpleModel{},
		Memory: store,
		Middleware: []Middleware{{AfterRun: func(cbCtx context.Context, _ *Result, _ error) error {
			close(started)
			<-release
			callbackErr = cbCtx.Err()
			return callbackErr
		}}},
		Events: event.FuncSink(func(_ context.Context, e event.Event) error {
			events = append(events, e.Type)
			return nil
		}),
		OnStream: func(part StreamPart) error {
			if part.Kind == StreamCheckpoint {
				checkpoints++
			}
			return nil
		},
		Hooks: Hooks{
			OnRunComplete: func(context.Context, *Result) error {
				completed++
				return nil
			},
			OnMemoryWrite: func(context.Context, string, memory.Record) error {
				memoryHooks++
				return nil
			},
			OnRunError: func(_ context.Context, _ string, err error) {
				onRunErr = err
			},
		},
	}
	done := make(chan error, 1)
	go func() {
		_, err := ag.Run(ctx, Session{ID: "session"}, "answer")
		done <- err
	}()
	waitCancelStart(t, started)
	cancel()
	close(release)
	err := <-done
	records, searchErr := store.Search(context.Background(), "session", "", 0)
	if searchErr != nil {
		t.Fatal(searchErr)
	}
	if !errors.Is(err, context.Canceled) || callbackErr != context.Canceled || !errors.Is(onRunErr, context.Canceled) {
		t.Fatalf("error=%v callback=%v on-run-error=%v", err, callbackErr, onRunErr)
	}
	if !reflect.DeepEqual(events, []string{"run.started", "run.failed"}) ||
		checkpoints != 0 || memoryHooks != 0 || completed != 0 || len(records) != 0 {
		t.Fatalf("events=%v checkpoints=%d memory-hooks=%d completed=%d records=%v",
			events, checkpoints, memoryHooks, completed, records)
	}
}

func TestRunCancellationKeepsOriginalErrorOverAfterRunError(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	model := &cancelWaitModel{started: make(chan struct{})}
	callbackFailure := errors.New("after-run failed")
	var callbackCtxErr, callbackRunErr error
	var after, completed int
	var events []string
	var onRunErr error
	ag := &Agent{
		Model: model,
		Middleware: []Middleware{{AfterRun: func(cbCtx context.Context, result *Result, runErr error) error {
			after++
			callbackCtxErr = cbCtx.Err()
			callbackRunErr = runErr
			if result != nil {
				t.Errorf("result = %+v", result)
			}
			return callbackFailure
		}}},
		Events: event.FuncSink(func(_ context.Context, e event.Event) error {
			events = append(events, e.Type)
			return nil
		}),
		Hooks: Hooks{
			OnRunComplete: func(context.Context, *Result) error {
				completed++
				return nil
			},
			OnRunError: func(_ context.Context, _ string, err error) {
				onRunErr = err
			},
		},
	}
	done := make(chan error, 1)
	go func() {
		_, err := ag.Run(ctx, Session{ID: "session"}, "answer")
		done <- err
	}()
	waitCancelStart(t, model.started)
	cancel()
	err := <-done
	if !errors.Is(err, context.Canceled) || errors.Is(err, callbackFailure) || !errors.Is(onRunErr, context.Canceled) {
		t.Fatalf("error=%v on-run-error=%v", err, onRunErr)
	}
	if callbackCtxErr != context.Canceled || !errors.Is(callbackRunErr, context.Canceled) {
		t.Fatalf("callback context=%v run error=%v", callbackCtxErr, callbackRunErr)
	}
	if after != 1 || completed != 0 || !reflect.DeepEqual(events, []string{"run.started", "run.failed"}) {
		t.Fatalf("after=%d completed=%d events=%v", after, completed, events)
	}
}

func TestRunCancellationDuringRepairStopsCompletion(t *testing.T) {
	for _, mode := range []string{"context", "callback"} {
		t.Run(mode, func(t *testing.T) {
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			started := make(chan struct{})
			release := make(chan struct{})
			callbackFailure := errors.New("repair failed")
			store := memory.NewMemoryStore()
			var callbackCtxErr error
			var events []string
			var checkpoints, memoryHooks, completed int
			var onRunErr error
			ag, err := New(Options{
				Model:  &stubModel{response: model.Response{Message: model.Message{Content: "invalid"}}},
				Memory: store,
				StructuredOutput: &StructuredOutput{
					Name: "answer", Schema: answerSchema(), MaxRepairs: 1,
					Repair: func(cbCtx context.Context, _ string, _ error) (string, error) {
						close(started)
						<-release
						callbackCtxErr = cbCtx.Err()
						if mode == "context" {
							return "", callbackCtxErr
						}
						return "", callbackFailure
					},
				},
				Events: event.FuncSink(func(_ context.Context, e event.Event) error {
					events = append(events, e.Type)
					return nil
				}),
				OnStream: func(part StreamPart) error {
					if part.Kind == StreamCheckpoint {
						checkpoints++
					}
					return nil
				},
				Hooks: Hooks{
					OnRunComplete: func(context.Context, *Result) error {
						completed++
						return nil
					},
					OnMemoryWrite: func(context.Context, string, memory.Record) error {
						memoryHooks++
						return nil
					},
					OnRunError: func(_ context.Context, _ string, err error) {
						onRunErr = err
					},
				},
			})
			if err != nil {
				t.Fatal(err)
			}
			done := make(chan error, 1)
			go func() {
				_, runErr := ag.Run(ctx, Session{ID: "session"}, "answer")
				done <- runErr
			}()
			waitCancelStart(t, started)
			cancel()
			close(release)
			runErr := <-done
			records, searchErr := store.Search(context.Background(), "session", "", 0)
			if searchErr != nil {
				t.Fatal(searchErr)
			}
			wantErr := context.Canceled
			if mode == "callback" {
				wantErr = callbackFailure
			}
			if !errors.Is(runErr, wantErr) || !errors.Is(onRunErr, wantErr) || callbackCtxErr != context.Canceled {
				t.Fatalf("error=%v want=%v on-run-error=%v callback-context=%v", runErr, wantErr, onRunErr, callbackCtxErr)
			}
			if !reflect.DeepEqual(events, []string{"run.started", "run.failed"}) ||
				checkpoints != 0 || memoryHooks != 0 || completed != 0 || len(records) != 0 {
				t.Fatalf("events=%v checkpoints=%d memory-hooks=%d completed=%d records=%v",
					events, checkpoints, memoryHooks, completed, records)
			}
		})
	}
}

func TestRunCancellationDuringCompletionHasSingleTerminalEvent(t *testing.T) {
	for _, stage := range []string{"hook", "checkpoint", "memory-hook", "memory-put", "completed"} {
		t.Run(stage, func(t *testing.T) {
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			started := make(chan struct{})
			release := make(chan struct{})
			var sawCancel bool
			block := func(cbCtx context.Context) error {
				close(started)
				<-release
				sawCancel = cbCtx.Err() == context.Canceled
				return cbCtx.Err()
			}
			store := memory.NewMemoryStore()
			var events []string
			var hookCalls, checkpoints, memoryHooks, memoryPuts, completedEvents int
			var onRunErr error
			mem := completionStore{Store: store, put: func(cbCtx context.Context, sessionID string, record memory.Record) error {
				memoryPuts++
				if stage == "memory-put" {
					return block(cbCtx)
				}
				return store.Put(cbCtx, sessionID, record)
			}}
			ag := &Agent{
				Model:  simpleModel{},
				Memory: mem,
				Events: event.FuncSink(func(cbCtx context.Context, e event.Event) error {
					events = append(events, e.Type)
					if stage == "completed" && e.Type == "run.completed" {
						completedEvents++
						return block(cbCtx)
					}
					return nil
				}),
				OnStream: func(part StreamPart) error {
					if part.Kind != StreamCheckpoint {
						return nil
					}
					checkpoints++
					if stage == "checkpoint" {
						return block(ctx)
					}
					return nil
				},
				Hooks: Hooks{
					OnRunComplete: func(cbCtx context.Context, _ *Result) error {
						hookCalls++
						if stage == "hook" {
							return block(cbCtx)
						}
						return nil
					},
					OnMemoryWrite: func(cbCtx context.Context, _ string, _ memory.Record) error {
						memoryHooks++
						if stage == "memory-hook" {
							return block(cbCtx)
						}
						return nil
					},
					OnRunError: func(_ context.Context, _ string, err error) {
						onRunErr = err
					},
				},
			}
			done := make(chan error, 1)
			go func() {
				_, err := ag.Run(ctx, Session{ID: "session"}, "answer")
				done <- err
			}()
			waitCancelStart(t, started)
			cancel()
			close(release)
			err := <-done
			records, searchErr := store.Search(context.Background(), "session", "", 0)
			if searchErr != nil {
				t.Fatal(searchErr)
			}
			wantHook, wantCheckpoint, wantMemoryHook, wantMemoryPut := 1, 1, 1, 1
			wantEvents := []string{"run.started", "run.failed"}
			wantRecords := 0
			switch stage {
			case "hook":
				wantCheckpoint, wantMemoryHook, wantMemoryPut = 0, 0, 0
			case "checkpoint":
				wantMemoryHook, wantMemoryPut = 0, 0
			case "memory-hook":
				wantMemoryPut = 0
			case "completed":
				wantEvents = []string{"run.started", "run.completed"}
				wantRecords = 1
			}
			if !errors.Is(err, context.Canceled) || !sawCancel || !errors.Is(onRunErr, context.Canceled) {
				t.Fatalf("error=%v saw-cancel=%v on-run-error=%v", err, sawCancel, onRunErr)
			}
			if hookCalls != wantHook || checkpoints != wantCheckpoint || memoryHooks != wantMemoryHook ||
				memoryPuts != wantMemoryPut || completedEvents != map[bool]int{true: 1, false: 0}[stage == "completed"] {
				t.Fatalf("hook=%d checkpoints=%d memory-hooks=%d memory-puts=%d completed-events=%d",
					hookCalls, checkpoints, memoryHooks, memoryPuts, completedEvents)
			}
			if !reflect.DeepEqual(events, wantEvents) || len(records) != wantRecords {
				t.Fatalf("events=%v records=%v", events, records)
			}
		})
	}
}
