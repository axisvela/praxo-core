package delegation

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"
)

type fakeSubRunner struct {
	once    sync.Once
	started chan struct{}
	release chan struct{}
	mu      sync.Mutex
	updates []string
}

func newFakeSubRunner() *fakeSubRunner {
	return &fakeSubRunner{started: make(chan struct{}), release: make(chan struct{})}
}

func (r *fakeSubRunner) Run(ctx context.Context, req SubagentRequest) (SubagentResult, error) {
	r.once.Do(func() { close(r.started) })
	select {
	case <-r.release:
		return SubagentResult{TaskID: "task", AgentID: req.AgentID, Output: "child result"}, nil
	case <-ctx.Done():
		return SubagentResult{}, ctx.Err()
	}
}

func (r *fakeSubRunner) Update(_ context.Context, taskID, prompt string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.updates = append(r.updates, taskID+":"+prompt)
	return nil
}

func waitStatus(t *testing.T, m *SubagentManager, id string, want SubagentStatus) SubagentTask {
	t.Helper()
	deadline := time.Now().Add(3 * time.Second)
	for {
		task, ok := m.Check(id)
		if !ok {
			t.Fatalf("task %s missing", id)
		}
		if task.Status == want {
			return task
		}
		if time.Now().After(deadline) {
			t.Fatalf("task status = %s, want %s", task.Status, want)
		}
		time.Sleep(10 * time.Millisecond)
	}
}

func TestSubagentManagerCompletes(t *testing.T) {
	r := newFakeSubRunner()
	m := NewSubagentManager(r)
	task, err := m.Launch(context.Background(), SubagentRequest{ParentSessionID: "p", AgentID: "child", Prompt: "work"})
	if err != nil {
		t.Fatal(err)
	}
	<-r.started
	close(r.release)
	done := waitStatus(t, m, task.ID, SubagentCompleted)
	if done.Output != "child result" {
		t.Fatalf("output = %q", done.Output)
	}
}

func TestSubagentManagerCancel(t *testing.T) {
	r := newFakeSubRunner()
	m := NewSubagentManager(r)
	task, err := m.Launch(context.Background(), SubagentRequest{ParentSessionID: "p", AgentID: "child"})
	if err != nil {
		t.Fatal(err)
	}
	<-r.started
	if err := m.Cancel(task.ID); err != nil {
		t.Fatal(err)
	}
	waitStatus(t, m, task.ID, SubagentCanceled)
}

func TestSubagentManagerUpdate(t *testing.T) {
	r := newFakeSubRunner()
	m := NewSubagentManager(r)
	defer close(r.release)
	task, err := m.Launch(context.Background(), SubagentRequest{ParentSessionID: "p", AgentID: "child"})
	if err != nil {
		t.Fatal(err)
	}
	<-r.started
	if err := m.Update(context.Background(), task.ID, "steer"); err != nil {
		t.Fatal(err)
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if len(r.updates) != 1 || r.updates[0] != task.ID+":steer" {
		t.Fatalf("updates = %v", r.updates)
	}
}

func TestSubagentManagerListFiltersParent(t *testing.T) {
	r := newFakeSubRunner()
	m := NewSubagentManager(r)
	defer close(r.release)
	a, err := m.Launch(context.Background(), SubagentRequest{ParentSessionID: "p1", AgentID: "a"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := m.Launch(context.Background(), SubagentRequest{ParentSessionID: "p2", AgentID: "b"}); err != nil {
		t.Fatal(err)
	}
	list := m.List("p1")
	if len(list) != 1 || list[0].ID != a.ID {
		t.Fatalf("list = %+v", list)
	}
}

func TestSubagentManagerCancelAfterCompletedIsNoop(t *testing.T) {
	r := newFakeSubRunner()
	m := NewSubagentManager(r)
	task, err := m.Launch(context.Background(), SubagentRequest{ParentSessionID: "p", AgentID: "child"})
	if err != nil {
		t.Fatal(err)
	}
	<-r.started
	close(r.release)
	waitStatus(t, m, task.ID, SubagentCompleted)
	if err := m.Cancel(task.ID); err != nil {
		t.Fatal(err)
	}
	got, ok := m.Check(task.ID)
	if !ok || got.Status != SubagentCompleted || got.Output != "child result" {
		t.Fatalf("task = %#v", got)
	}
}

func TestSubagentManagerUpdateTerminalFails(t *testing.T) {
	r := newFakeSubRunner()
	m := NewSubagentManager(r)
	task, err := m.Launch(context.Background(), SubagentRequest{ParentSessionID: "p", AgentID: "child"})
	if err != nil {
		t.Fatal(err)
	}
	<-r.started
	close(r.release)
	waitStatus(t, m, task.ID, SubagentCompleted)
	if err := m.Update(context.Background(), task.ID, "late"); err == nil {
		t.Fatal("expected an error updating a completed task")
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if len(r.updates) != 0 {
		t.Fatalf("updates = %v", r.updates)
	}
}

func TestSubagentManagerPrune(t *testing.T) {
	r := newFakeSubRunner()
	m := NewSubagentManager(r)
	task, err := m.Launch(context.Background(), SubagentRequest{ParentSessionID: "p", AgentID: "child"})
	if err != nil {
		t.Fatal(err)
	}
	<-r.started
	close(r.release)
	waitStatus(t, m, task.ID, SubagentCompleted)
	if removed := m.Prune(0); removed != 1 {
		t.Fatalf("removed = %d", removed)
	}
	if _, ok := m.Check(task.ID); ok {
		t.Fatal("completed task was not pruned")
	}
}

func TestSubagentManagerPruneKeepsRunning(t *testing.T) {
	r := newFakeSubRunner()
	m := NewSubagentManager(r)
	defer close(r.release)
	task, err := m.Launch(context.Background(), SubagentRequest{ParentSessionID: "p", AgentID: "child"})
	if err != nil {
		t.Fatal(err)
	}
	<-r.started
	if removed := m.Prune(0); removed != 0 {
		t.Fatalf("removed = %d", removed)
	}
	if _, ok := m.Check(task.ID); !ok {
		t.Fatal("running task was pruned")
	}
}

func TestSubagentManagerWait(t *testing.T) {
	r := newFakeSubRunner()
	m := NewSubagentManager(r)
	task, err := m.Launch(context.Background(), SubagentRequest{ParentSessionID: "p", AgentID: "child"})
	if err != nil {
		t.Fatal(err)
	}
	<-r.started
	go func() {
		time.Sleep(10 * time.Millisecond)
		close(r.release)
	}()
	done, err := m.Wait(context.Background(), task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if done.Status != SubagentCompleted || done.Output != "child result" {
		t.Fatalf("task = %#v", done)
	}
}

func TestSubagentManagerWaitContextCanceled(t *testing.T) {
	r := newFakeSubRunner()
	m := NewSubagentManager(r)
	task, err := m.Launch(context.Background(), SubagentRequest{ParentSessionID: "p", AgentID: "child"})
	if err != nil {
		t.Fatal(err)
	}
	<-r.started
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := m.Wait(ctx, task.ID); !errors.Is(err, context.Canceled) {
		t.Fatalf("err = %v", err)
	}
	if err := m.Cancel(task.ID); err != nil {
		t.Fatal(err)
	}
}

func TestSubagentManagerWaitUnknown(t *testing.T) {
	if _, err := NewSubagentManager(newFakeSubRunner()).Wait(context.Background(), "missing"); err == nil {
		t.Fatal("expected an error")
	}
}
