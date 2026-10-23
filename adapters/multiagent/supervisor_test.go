package multiagent

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/agent/delegation"
)

type fakeRunner struct {
	mu       sync.Mutex
	requests []delegation.SubagentRequest
	fail     map[string]bool
	block    bool
}

func (f *fakeRunner) Run(ctx context.Context, req delegation.SubagentRequest) (delegation.SubagentResult, error) {
	f.mu.Lock()
	f.requests = append(f.requests, req)
	f.mu.Unlock()
	if f.block {
		<-ctx.Done()
		return delegation.SubagentResult{}, ctx.Err()
	}
	if f.fail[req.AgentID] {
		return delegation.SubagentResult{}, errors.New("worker failed")
	}
	return delegation.SubagentResult{AgentID: req.AgentID, Output: req.AgentID + ":" + req.Prompt}, nil
}

func (f *fakeRunner) recorded() []delegation.SubagentRequest {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]delegation.SubagentRequest(nil), f.requests...)
}

func TestRunParallel(t *testing.T) {
	runner := &fakeRunner{}
	supervisor := Supervisor{Runner: runner, Timeout: time.Second}
	outputs, err := supervisor.Run(context.Background(), "session-1", []Worker{
		{Name: "researcher", AgentID: "research", Prompt: "find"},
		{Name: "writer", AgentID: "write", Prompt: "draft"},
	})
	if err != nil {
		t.Fatal(err)
	}
	if outputs["researcher"] != "research:find" || outputs["writer"] != "write:draft" {
		t.Fatalf("outputs = %#v", outputs)
	}
	if len(runner.recorded()) != 2 {
		t.Fatalf("requests = %d", len(runner.recorded()))
	}
}

func TestSequentialPassesPrevious(t *testing.T) {
	runner := &fakeRunner{}
	supervisor := Supervisor{Runner: runner, Timeout: time.Second}
	outputs, err := supervisor.Sequential(context.Background(), "session-1", []Worker{
		{Name: "first", AgentID: "a", Prompt: "one"},
		{Name: "second", AgentID: "b", Prompt: "two"},
	})
	if err != nil {
		t.Fatal(err)
	}
	if outputs["first"] != "a:one" || outputs["second"] != "b:two" {
		t.Fatalf("outputs = %#v", outputs)
	}
	requests := runner.recorded()
	if len(requests) != 2 {
		t.Fatalf("requests = %d", len(requests))
	}
	if requests[1].Context["previous"] != "a:one" {
		t.Fatalf("previous = %#v", requests[1].Context)
	}
}

func TestWorkerFailure(t *testing.T) {
	supervisor := Supervisor{
		Runner:  &fakeRunner{fail: map[string]bool{"b": true}},
		Timeout: time.Second,
	}
	_, err := supervisor.Run(context.Background(), "session-1", []Worker{
		{AgentID: "a", Prompt: "one"},
		{AgentID: "b", Prompt: "two"},
	})
	if err == nil {
		t.Fatal("expected an error")
	}
}

func TestSupervisorTimeout(t *testing.T) {
	supervisor := Supervisor{
		Runner:       &fakeRunner{block: true},
		Timeout:      20 * time.Millisecond,
		PollInterval: 2 * time.Millisecond,
	}
	_, err := supervisor.Run(context.Background(), "session-1", []Worker{{AgentID: "a", Prompt: "wait"}})
	if !errors.Is(err, ErrTimeout) {
		t.Fatalf("got %v, want %v", err, ErrTimeout)
	}
}

func TestValidation(t *testing.T) {
	if _, err := (Supervisor{}).Run(context.Background(), "session-1", nil); !errors.Is(err, ErrRunnerRequired) {
		t.Fatalf("got %v, want %v", err, ErrRunnerRequired)
	}
	supervisor := Supervisor{Runner: &fakeRunner{}}
	if _, err := supervisor.Run(context.Background(), "session-1", []Worker{{Prompt: "missing id"}}); err == nil {
		t.Fatal("expected an error for a missing agent ID")
	}
	if _, err := supervisor.Run(context.Background(), "session-1", []Worker{
		{AgentID: "a"}, {AgentID: "a"},
	}); err == nil {
		t.Fatal("expected an error for duplicate workers")
	}
}
