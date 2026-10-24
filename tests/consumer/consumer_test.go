package consumer_test

import (
	"context"
	"encoding/json"
	"os"
	"os/exec"
	"strings"
	"sync"
	"testing"
	"time"

	a2aadapter "github.com/axisvela/praxo-core/adapters/a2a"
	"github.com/axisvela/praxo-core/adapters/anthropic"
	"github.com/axisvela/praxo-core/adapters/gemini"
	"github.com/axisvela/praxo-core/adapters/harmovela"
	mcpadapter "github.com/axisvela/praxo-core/adapters/mcp"
	"github.com/axisvela/praxo-core/adapters/multiagent"
	oteladapter "github.com/axisvela/praxo-core/adapters/otel"
	"github.com/axisvela/praxo-core/v2/adapters/openaicompat"
	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/agent/delegation"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

var (
	_ model.StreamingModel = openaicompat.Adapter{}
	_ model.StreamingModel = anthropic.Adapter{}
	_ model.StreamingModel = gemini.Adapter{}
	_ tool.Gateway         = (*mcpadapter.Gateway)(nil)
	_ event.Sink           = oteladapter.Sink{}
	_ event.Sink           = harmovela.Sink{}
	_                      = a2aadapter.Executor{}
	_                      = multiagent.Supervisor{}
	_                      = openaicompat.Adapter{IncludeUsage: true}
	_                      = multiagent.Supervisor{MaxConcurrency: 1}
	_                      = (*delegation.SubagentManager).Wait
	_                      = (*delegation.SubagentManager).Prune
)

type finalModel struct{}

func (finalModel) Generate(context.Context, model.Request) (model.Response, error) {
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "consumer ok"}}, nil
}

func TestPublishedAgent(t *testing.T) {
	ag, err := agent.New(agent.Options{Model: finalModel{}, MaxSteps: 2})
	if err != nil {
		t.Fatal(err)
	}
	result, err := ag.Run(context.Background(), agent.Session{ID: "consumer"}, "hello")
	if err != nil {
		t.Fatal(err)
	}
	if result.Output != "consumer ok" {
		t.Fatalf("output = %q", result.Output)
	}
}

func TestPublishedDependencyGraph(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	cmd := exec.CommandContext(ctx, "go", "list", "-m", "-json", "all")
	cmd.Env = append(os.Environ(), "GOWORK=off")
	output, err := cmd.Output()
	if err != nil {
		t.Fatal(err)
	}
	expected := map[string]string{
		"github.com/axisvela/praxo-core/v2":                  "v2.3.6",
		"github.com/axisvela/praxo-core/adapters/a2a":        "v0.1.0",
		"github.com/axisvela/praxo-core/adapters/anthropic":  "v0.1.0",
		"github.com/axisvela/praxo-core/adapters/gemini":     "v0.1.1",
		"github.com/axisvela/praxo-core/adapters/harmovela":  "v0.1.0",
		"github.com/axisvela/praxo-core/adapters/mcp":        "v0.3.0",
		"github.com/axisvela/praxo-core/adapters/multiagent": "v0.2.0",
		"github.com/axisvela/praxo-core/adapters/otel":       "v0.2.0",
	}
	decoder := json.NewDecoder(strings.NewReader(string(output)))
	for decoder.More() {
		var module struct {
			Path    string
			Version string
			Replace json.RawMessage
		}
		if err := decoder.Decode(&module); err != nil {
			t.Fatal(err)
		}
		if len(module.Replace) != 0 {
			t.Fatalf("unexpected replacement: %s", module.Path)
		}
		if version, ok := expected[module.Path]; ok {
			if module.Version != version {
				t.Fatalf("%s: got %s, want %s", module.Path, module.Version, version)
			}
			delete(expected, module.Path)
		}
	}
	if len(expected) != 0 {
		t.Fatalf("missing modules: %v", expected)
	}
}

type publishedRunner struct{}

func (publishedRunner) Run(_ context.Context, req delegation.SubagentRequest) (delegation.SubagentResult, error) {
	return delegation.SubagentResult{TaskID: "task", AgentID: req.AgentID, Output: "done"}, nil
}

type blockingPublishedRunner struct {
	release chan struct{}
}

func (r *blockingPublishedRunner) Run(ctx context.Context, req delegation.SubagentRequest) (delegation.SubagentResult, error) {
	select {
	case <-r.release:
		return delegation.SubagentResult{TaskID: "task", AgentID: req.AgentID, Output: "done"}, nil
	case <-ctx.Done():
		return delegation.SubagentResult{}, ctx.Err()
	}
}

func TestPublishedSubagentLifecycle(t *testing.T) {
	ctx := context.Background()
	manager := delegation.NewSubagentManager(publishedRunner{})
	task, err := manager.Launch(ctx, delegation.SubagentRequest{
		ParentSessionID: "consumer",
		AgentID:         "child",
	})
	if err != nil {
		t.Fatal(err)
	}
	done, err := manager.Wait(ctx, task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if done.Status != delegation.SubagentCompleted || done.Output != "done" {
		t.Fatalf("task = %#v", done)
	}
	if removed := manager.Prune(0); removed != 1 {
		t.Fatalf("pruned = %d", removed)
	}
	if _, ok := manager.Check(task.ID); ok {
		t.Fatal("pruned task is still present")
	}
}

func TestPublishedSubagentWaitersSurvivePrune(t *testing.T) {
	ctx := context.Background()
	runner := &blockingPublishedRunner{release: make(chan struct{})}
	manager := delegation.NewSubagentManager(runner)
	task, err := manager.Launch(ctx, delegation.SubagentRequest{
		ParentSessionID: "consumer",
		AgentID:         "child",
	})
	if err != nil {
		t.Fatal(err)
	}

	const waiters = 4
	type outcome struct {
		task delegation.SubagentTask
		err  error
	}
	results := make(chan outcome, waiters)
	var started sync.WaitGroup
	started.Add(waiters)
	for i := 0; i < waiters; i++ {
		go func() {
			started.Done()
			done, err := manager.Wait(ctx, task.ID)
			results <- outcome{task: done, err: err}
		}()
	}
	started.Wait()
	time.Sleep(20 * time.Millisecond)
	close(runner.release)

	done, err := manager.Wait(ctx, task.ID)
	if err != nil {
		t.Fatal(err)
	}
	if done.Status != delegation.SubagentCompleted || done.Output != "done" {
		t.Fatalf("task = %#v", done)
	}
	if removed := manager.Prune(0); removed != 1 {
		t.Fatalf("pruned = %d", removed)
	}
	for i := 0; i < waiters; i++ {
		select {
		case result := <-results:
			if result.err != nil {
				t.Fatal(result.err)
			}
			if result.task.Status != delegation.SubagentCompleted || result.task.Output != "done" {
				t.Fatalf("waiter task = %#v", result.task)
			}
		case <-time.After(3 * time.Second):
			t.Fatal("waiter did not return")
		}
	}
}
