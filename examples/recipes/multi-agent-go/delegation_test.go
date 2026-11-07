package multi_agent_recipe

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/agent/delegation"
)

type resultRunner struct {
	output string
	err    error
}

func (r resultRunner) Run(_ context.Context, req delegation.SubagentRequest) (delegation.SubagentResult, error) {
	return delegation.SubagentResult{TaskID: "child", AgentID: req.AgentID, Output: r.output}, r.err
}

type blockingRunner struct {
	started chan struct{}
	updates chan string
}

func newBlockingRunner() *blockingRunner {
	return &blockingRunner{
		started: make(chan struct{}),
		updates: make(chan string, 1),
	}
}

func (r *blockingRunner) Run(ctx context.Context, _ delegation.SubagentRequest) (delegation.SubagentResult, error) {
	close(r.started)
	<-ctx.Done()
	return delegation.SubagentResult{}, ctx.Err()
}

func (r *blockingRunner) Update(_ context.Context, _ string, prompt string) error {
	r.updates <- prompt
	return nil
}

func launch(t *testing.T, manager *delegation.SubagentManager, parent, agent string) delegation.SubagentTask {
	t.Helper()
	task, err := manager.Launch(context.Background(), delegation.SubagentRequest{
		ParentSessionID: parent,
		AgentID:         agent,
		Prompt:          "do the work",
	})
	if err != nil {
		t.Fatal(err)
	}
	return task
}

func TestLaunchAndWaitCompletes(t *testing.T) {
	manager := delegation.NewSubagentManager(resultRunner{output: "child result"})
	task := launch(t, manager, "parent", "researcher")
	finished, err := manager.Wait(context.Background(), task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if finished.Status != delegation.SubagentCompleted || finished.Output != "child result" {
		t.Fatalf("finished = %#v", finished)
	}
	if finished.Mode != delegation.SubagentIsolated {
		t.Fatalf("mode = %s, want isolated", finished.Mode)
	}
}

func TestLaunchRequiresParentAndAgent(t *testing.T) {
	manager := delegation.NewSubagentManager(resultRunner{})
	if _, err := manager.Launch(context.Background(), delegation.SubagentRequest{AgentID: "agent"}); err == nil {
		t.Fatal("missing parent session was accepted")
	}
	if _, err := manager.Launch(context.Background(), delegation.SubagentRequest{ParentSessionID: "parent"}); err == nil {
		t.Fatal("missing agent id was accepted")
	}
}

func TestFailureStatus(t *testing.T) {
	manager := delegation.NewSubagentManager(resultRunner{err: errors.New("child failed")})
	task := launch(t, manager, "parent", "agent")
	finished, err := manager.Wait(context.Background(), task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if finished.Status != delegation.SubagentFailed || !strings.Contains(finished.Error, "child failed") {
		t.Fatalf("finished = %#v", finished)
	}
}

func TestCancelRunningTask(t *testing.T) {
	runner := newBlockingRunner()
	manager := delegation.NewSubagentManager(runner)
	task := launch(t, manager, "parent", "agent")
	<-runner.started
	if err := manager.Cancel(task.ID); err != nil {
		t.Fatal(err)
	}
	finished, err := manager.Wait(context.Background(), task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if finished.Status != delegation.SubagentCanceled {
		t.Fatalf("status = %s, want canceled", finished.Status)
	}
	if err := manager.Cancel(task.ID); err != nil {
		t.Fatalf("cancel after terminal = %v", err)
	}
}

func TestUpdateRunningTask(t *testing.T) {
	runner := newBlockingRunner()
	manager := delegation.NewSubagentManager(runner)
	task := launch(t, manager, "parent", "agent")
	<-runner.started
	if err := manager.Update(context.Background(), task.ID, "narrow the search"); err != nil {
		t.Fatal(err)
	}
	select {
	case prompt := <-runner.updates:
		if prompt != "narrow the search" {
			t.Fatalf("prompt = %q", prompt)
		}
	case <-time.After(time.Second):
		t.Fatal("update was not forwarded")
	}
	if err := manager.Cancel(task.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.Wait(context.Background(), task.ID); err != nil {
		t.Fatal(err)
	}
	if err := manager.Update(context.Background(), task.ID, "too late"); err == nil {
		t.Fatal("update after terminal was accepted")
	}
}

func TestUpdateUnsupported(t *testing.T) {
	manager := delegation.NewSubagentManager(resultRunner{output: "done"})
	task := launch(t, manager, "parent", "agent")
	if err := manager.Update(context.Background(), task.ID, "prompt"); !errors.Is(err, delegation.ErrSubagentUpdateUnsupported) {
		t.Fatalf("err = %v, want ErrSubagentUpdateUnsupported", err)
	}
	_, _ = manager.Wait(context.Background(), task.ID)
}

func TestListAndPrune(t *testing.T) {
	manager := delegation.NewSubagentManager(resultRunner{output: "done"})
	first := launch(t, manager, "parent-a", "agent-a")
	second := launch(t, manager, "parent-b", "agent-b")
	_, _ = manager.Wait(context.Background(), first.ID)
	_, _ = manager.Wait(context.Background(), second.ID)

	all := manager.List("")
	if len(all) != 2 {
		t.Fatalf("all = %d, want 2", len(all))
	}
	onlyA := manager.List("parent-a")
	if len(onlyA) != 1 || onlyA[0].AgentID != "agent-a" {
		t.Fatalf("parent-a = %#v", onlyA)
	}
	if removed := manager.Prune(0); removed != 2 {
		t.Fatalf("pruned = %d, want 2", removed)
	}
	if _, ok := manager.Check(first.ID); ok {
		t.Fatal("pruned task is still present")
	}
}

func TestPruneKeepsRunningTask(t *testing.T) {
	runner := newBlockingRunner()
	manager := delegation.NewSubagentManager(runner)
	task := launch(t, manager, "parent", "agent")
	<-runner.started
	if removed := manager.Prune(0); removed != 0 {
		t.Fatalf("pruned running task: %d", removed)
	}
	if err := manager.Cancel(task.ID); err != nil {
		t.Fatal(err)
	}
	_, _ = manager.Wait(context.Background(), task.ID)
}

func TestWaitContextCanceled(t *testing.T) {
	runner := newBlockingRunner()
	manager := delegation.NewSubagentManager(runner)
	task := launch(t, manager, "parent", "agent")
	<-runner.started
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := manager.Wait(ctx, task.ID); !errors.Is(err, context.Canceled) {
		t.Fatalf("err = %v, want context.Canceled", err)
	}
	if err := manager.Cancel(task.ID); err != nil {
		t.Fatal(err)
	}
	_, _ = manager.Wait(context.Background(), task.ID)
}

func TestWaitUnknownTask(t *testing.T) {
	manager := delegation.NewSubagentManager(resultRunner{})
	if _, err := manager.Wait(context.Background(), "missing"); err == nil {
		t.Fatal("unknown task was accepted")
	}
}
