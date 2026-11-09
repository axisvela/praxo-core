package longrunning

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"
	"testing"
)

func TestLongRunningExecutionIdempotent(t *testing.T) {
	path := filepath.Join(t.TempDir(), "execution.json")
	journal, err := openExecutionJournal(path)
	if err != nil {
		t.Fatal(err)
	}
	calls := 0
	execute := func(context.Context) error { calls++; return nil }
	for range 2 {
		record, err := journal.Run(context.Background(), "operation-1", "digest-1", execute)
		if err != nil || record.State != executionCompleted {
			t.Fatalf("record=%+v err=%v", record, err)
		}
	}
	reopened, err := openExecutionJournal(path)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := reopened.Run(context.Background(), "operation-1", "digest-1", execute); err != nil || calls != 1 {
		t.Fatalf("calls=%d err=%v", calls, err)
	}
}

func TestLongRunningExecutionConflict(t *testing.T) {
	journal, _ := openExecutionJournal(filepath.Join(t.TempDir(), "execution.json"))
	calls := 0
	execute := func(context.Context) error { calls++; return nil }
	_, err := journal.Run(context.Background(), "operation-1", "digest-1", execute)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := journal.Run(context.Background(), "operation-1", "digest-2", execute); !errors.Is(err, errExecutionConflict) || calls != 1 {
		t.Fatalf("calls=%d err=%v", calls, err)
	}
}

func TestLongRunningExecutionStartBeforeEffect(t *testing.T) {
	path := filepath.Join(t.TempDir(), "execution.json")
	journal, _ := openExecutionJournal(path)
	_, err := journal.Run(context.Background(), "operation-1", "digest-1", func(context.Context) error {
		raw, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		var snapshot executionSnapshot
		if err := json.Unmarshal(raw, &snapshot); err != nil {
			return err
		}
		if snapshot.Records["operation-1"].State != executionStartIntent {
			t.Fatal("executor entered before durable start intent")
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}

func TestLongRunningExecutionConcurrent(t *testing.T) {
	journal, _ := openExecutionJournal(filepath.Join(t.TempDir(), "execution.json"))
	var calls atomic.Int64
	var wait sync.WaitGroup
	for range 20 {
		wait.Add(1)
		go func() {
			defer wait.Done()
			record, err := journal.Run(context.Background(), "operation-1", "digest-1", func(context.Context) error {
				calls.Add(1)
				return nil
			})
			if err != nil || record.State != executionCompleted {
				t.Errorf("record=%+v err=%v", record, err)
			}
		}()
	}
	wait.Wait()
	if calls.Load() != 1 {
		t.Fatalf("executor calls=%d", calls.Load())
	}
}

func TestLongRunningExecutionPersistenceFailure(t *testing.T) {
	for _, stage := range []string{
		"admission.before-rename", "admission.after-rename", "start.before-rename",
		"start.after-rename", "finish.before-rename", "finish.after-rename",
	} {
		t.Run(stage, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "execution.json")
			journal, _ := openExecutionJournal(path)
			journal.commitHook = func(at string) error {
				if at == stage {
					return errors.New("injected commit failure")
				}
				return nil
			}
			calls := 0
			execute := func(context.Context) error { calls++; return nil }
			if _, err := journal.Run(context.Background(), "operation-1", "digest-1", execute); !errors.Is(err, errExecutionRecovery) {
				t.Fatalf("persistence error did not require recovery: %v", err)
			}
			if _, err := journal.Run(context.Background(), "other", "digest-1", execute); !errors.Is(err, errExecutionRecovery) {
				t.Fatal("poisoned journal allowed another operation")
			}
			reopened, err := openExecutionJournal(path)
			if err != nil {
				t.Fatal(err)
			}
			before := calls
			_, _ = reopened.Run(context.Background(), "operation-1", "digest-1", execute)
			if stage != "admission.before-rename" && calls != before {
				t.Fatal("recovery re-invoked existing work")
			}
			if before > 1 || (stage != "finish.before-rename" && stage != "finish.after-rename" && before != 0) {
				t.Fatalf("unexpected pre-recovery calls=%d", before)
			}
		})
	}
}

func TestLongRunningExecutionUnknown(t *testing.T) {
	for _, cancel := range []bool{false, true} {
		path := filepath.Join(t.TempDir(), "execution.json")
		journal, _ := openExecutionJournal(path)
		ctx, stop := context.WithCancel(context.Background())
		calls := 0
		execute := func(context.Context) error {
			calls++
			if cancel {
				stop()
				return nil
			}
			return errors.New("response lost after effect")
		}
		record, err := journal.Run(ctx, "operation-1", "digest-1", execute)
		stop()
		if !errors.Is(err, errExecutionUnknown) || record.State != executionUnknown {
			t.Fatalf("record=%+v err=%v", record, err)
		}
		reopened, err := openExecutionJournal(path)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := reopened.Run(context.Background(), "operation-1", "digest-1", execute); !errors.Is(err, errExecutionUnknown) || calls != 1 {
			t.Fatalf("unknown replayed: calls=%d err=%v", calls, err)
		}
	}
}

func TestLongRunningExecutionCorrupt(t *testing.T) {
	for _, contents := range []string{`{broken`, `{}`, `{"version":1,"records":null}`, `{"version":2,"records":{}}`, `{"version":1,"records":{"one":{"key":"two","digest":"d","state":"completed"}}}`} {
		path := filepath.Join(t.TempDir(), "execution.json")
		if err := os.WriteFile(path, []byte(contents), 0o600); err != nil {
			t.Fatal(err)
		}
		if _, err := openExecutionJournal(path); err == nil {
			t.Fatalf("accepted corrupt state: %s", contents)
		}
	}
}

func TestLongRunningExecutionCanceledBeforeInvoke(t *testing.T) {
	journal, _ := openExecutionJournal(filepath.Join(t.TempDir(), "execution.json"))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	journal.commitHook = func(stage string) error {
		if stage == "start.after-rename" {
			cancel()
		}
		return nil
	}
	calls := 0
	record, err := journal.Run(ctx, "operation-1", "digest-1", func(context.Context) error { calls++; return nil })
	if calls != 0 || !errors.Is(err, context.Canceled) || record.State != executionUnknown {
		t.Fatalf("invoked after cancellation: calls=%d record=%+v err=%v", calls, record, err)
	}
}

func TestLongRunningExecutionPanicPreservesIntent(t *testing.T) {
	path := filepath.Join(t.TempDir(), "execution.json")
	journal, _ := openExecutionJournal(path)
	func() {
		defer func() {
			if recover() == nil {
				t.Fatal("expected injected executor panic")
			}
		}()
		_, _ = journal.Run(context.Background(), "operation-1", "digest-1", func(context.Context) error { panic("executor failed") })
	}()
	if _, err := journal.Run(context.Background(), "other", "digest-1", func(context.Context) error { t.Fatal("poisoned executor ran"); return nil }); !errors.Is(err, errExecutionRecovery) {
		t.Fatal("panic did not poison journal")
	}
	reopened, err := openExecutionJournal(path)
	if err != nil {
		t.Fatal(err)
	}
	record, err := reopened.Run(context.Background(), "operation-1", "digest-1", func(context.Context) error { t.Fatal("panic replayed"); return nil })
	if !errors.Is(err, errExecutionUnknown) || record.State != executionUnknown {
		t.Fatalf("record=%+v err=%v", record, err)
	}
}
