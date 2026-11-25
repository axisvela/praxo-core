package rheovela

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/rheovela-open/sdk/go/v3/worker"
)

func TestDurableWorkerCommitsResult(t *testing.T) {
	store := &fakeStore{items: []worker.WorkItem{{ID: "wi-1", InstanceID: "i1", ActivityID: "stage1"}}}
	runner := stepRunner(func(context.Context, worker.WorkItem) (StepResult, error) {
		return StepResult{
			Result:        map[string]any{"ok": true},
			CheckpointRef: "ckpt-1",
			EffectCursor:  "eff-1",
		}, nil
	})
	instance, err := NewDurableWorkerWithStore(store, runner)
	if err != nil {
		t.Fatal(err)
	}
	processed, err := instance.RunOnce(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if processed != 1 {
		t.Fatalf("processed = %d", processed)
	}
	if store.completed == nil || store.completed.Status != "success" {
		t.Fatalf("completed = %#v", store.completed)
	}
	if store.completed.CheckpointRef != "ckpt-1" || store.completed.EffectCursor != "eff-1" {
		t.Fatalf("refs = %#v", store.completed)
	}
	if !strings.Contains(string(store.completed.Result), `"ok":true`) {
		t.Fatalf("result = %s", store.completed.Result)
	}
}

func TestDurableWorkerRequestsApproval(t *testing.T) {
	store := &fakeStore{items: []worker.WorkItem{{ID: "wi-2", InstanceID: "i1", ActivityID: "stage1"}}}
	runner := stepRunner(func(context.Context, worker.WorkItem) (StepResult, error) {
		return StepResult{
			CheckpointRef: "ckpt-2",
			EffectCursor:  "eff-2",
			Approval: &worker.ApprovalRequest{
				Reason:    "manual review",
				FinalArgs: json.RawMessage(`{"amount":10}`),
			},
		}, nil
	})
	instance, err := NewDurableWorkerWithStore(store, runner)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := instance.RunOnce(context.Background()); err != nil {
		t.Fatal(err)
	}
	if store.approval == nil {
		t.Fatal("approval was not requested")
	}
	if store.approval.Reason != "manual review" || store.approval.CheckpointRef != "ckpt-2" || store.approval.EffectCursor != "eff-2" {
		t.Fatalf("approval = %#v", store.approval)
	}
}

func TestDurableWorkerFailsOnRunnerError(t *testing.T) {
	store := &fakeStore{items: []worker.WorkItem{{ID: "wi-3", InstanceID: "i1", ActivityID: "stage1"}}}
	runner := stepRunner(func(context.Context, worker.WorkItem) (StepResult, error) {
		return StepResult{}, errors.New("model unavailable")
	})
	instance, err := NewDurableWorkerWithStore(store, runner)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := instance.RunOnce(context.Background()); err != nil {
		t.Fatal(err)
	}
	if store.failed != "model unavailable" {
		t.Fatalf("failed = %q", store.failed)
	}
}

func TestDurableWorkerFailsOnPanic(t *testing.T) {
	store := &fakeStore{items: []worker.WorkItem{{ID: "wi-4", InstanceID: "i1", ActivityID: "stage1"}}}
	runner := stepRunner(func(context.Context, worker.WorkItem) (StepResult, error) {
		panic("boom")
	})
	instance, err := NewDurableWorkerWithStore(store, runner)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := instance.RunOnce(context.Background()); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(store.failed, "step panic: boom") {
		t.Fatalf("failed = %q", store.failed)
	}
}

func TestAgentRunner(t *testing.T) {
	ag, err := agent.New(agent.Options{Model: finalModel{}, MaxSteps: 2})
	if err != nil {
		t.Fatal(err)
	}
	runner := AgentRunner{
		Agent:  ag,
		Prompt: func(worker.WorkItem) string { return "hello" },
	}
	step, err := runner.RunStep(context.Background(), worker.WorkItem{ID: "wi-5", InstanceID: "session-1"})
	if err != nil {
		t.Fatal(err)
	}
	result, ok := step.Result.(*agent.Result)
	if !ok || result.Output != "done" {
		t.Fatalf("result = %#v", step.Result)
	}
}

func TestDurableWorkerRequiresStoreAndRunner(t *testing.T) {
	if _, err := NewDurableWorker(nil, stepRunner(nil)); !errors.Is(err, ErrClientRequired) {
		t.Fatalf("nil client: %v", err)
	}
	if _, err := NewDurableWorkerWithStore(&fakeStore{}, nil); !errors.Is(err, ErrStepRunnerRequired) {
		t.Fatalf("nil runner: %v", err)
	}
}

type stepRunner func(context.Context, worker.WorkItem) (StepResult, error)

func (f stepRunner) RunStep(ctx context.Context, item worker.WorkItem) (StepResult, error) {
	return f(ctx, item)
}

type finalModel struct{}

func (finalModel) Generate(context.Context, model.Request) (model.Response, error) {
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "done"}}, nil
}

type fakeStore struct {
	items     []worker.WorkItem
	completed *worker.WorkResult
	approval  *worker.ApprovalRequest
	failed    string
}

func (s *fakeStore) PollReady() ([]worker.WorkItem, error) { return s.items, nil }

func (s *fakeStore) Claim(string, time.Duration) (string, error) { return "tok", nil }

func (s *fakeStore) Heartbeat(string, string, time.Duration) error { return nil }

func (s *fakeStore) Complete(string, string) error {
	s.completed = &worker.WorkResult{Status: "success"}
	return nil
}

func (s *fakeStore) CompleteWithResult(_ string, _ string, result worker.WorkResult) error {
	s.completed = &result
	return nil
}

func (s *fakeStore) RequestApproval(_ string, _ string, request worker.ApprovalRequest) error {
	s.approval = &request
	return nil
}

func (s *fakeStore) Fail(_ string, _ string, errMsg string) error {
	s.failed = errMsg
	return nil
}

var (
	_ worker.WorkStore     = (*fakeStore)(nil)
	_ worker.ResultStore   = (*fakeStore)(nil)
	_ worker.ApprovalStore = (*fakeStore)(nil)
)
