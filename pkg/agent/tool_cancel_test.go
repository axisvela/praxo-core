package agent

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

type cancelBlockingTool struct {
	name    string
	started chan struct{}
	calls   atomic.Int32
}

func (t *cancelBlockingTool) Name() string        { return t.name }
func (t *cancelBlockingTool) Description() string { return "waits for cancellation" }
func (t *cancelBlockingTool) Invoke(ctx context.Context, _ map[string]any) (any, error) {
	t.calls.Add(1)
	close(t.started)
	<-ctx.Done()
	return nil, ctx.Err()
}

type cancelCountingTool struct {
	calls atomic.Int32
}

func (t *cancelCountingTool) Name() string        { return "count" }
func (t *cancelCountingTool) Description() string { return "counts invocations" }
func (t *cancelCountingTool) Invoke(context.Context, map[string]any) (any, error) {
	t.calls.Add(1)
	return "counted", nil
}

type cancelToolModel struct {
	calls int
	tools []model.ToolCall
}

func (m *cancelToolModel) Generate(context.Context, model.Request) (model.Response, error) {
	m.calls++
	if m.calls == 1 {
		return model.Response{Message: model.Message{ToolCalls: m.tools}}, nil
	}
	return model.Response{Message: model.Message{Content: "done"}}, nil
}

func TestRunStopsStartingToolsAfterCancellation(t *testing.T) {
	t.Run("sequential", func(t *testing.T) {
		block := &cancelBlockingTool{name: "block", started: make(chan struct{})}
		count := &cancelCountingTool{}
		registry := tool.NewRegistry()
		registry.Register(block)
		registry.Register(count)
		agent := &Agent{
			Model: &cancelToolModel{tools: []model.ToolCall{
				{ID: "one", Name: "block"},
				{ID: "two", Name: "count"},
			}},
			Tools: registry, MaxParallelTools: 1,
		}

		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()
		done := make(chan error, 1)
		go func() {
			_, err := agent.Run(ctx, Session{ID: "cancel"}, "go")
			done <- err
		}()
		select {
		case <-block.started:
		case <-time.After(5 * time.Second):
			t.Fatal("blocking tool did not start")
		}
		cancel()
		select {
		case err := <-done:
			if !errors.Is(err, context.Canceled) {
				t.Fatalf("error = %v", err)
			}
		case <-time.After(5 * time.Second):
			t.Fatal("run did not return after cancellation")
		}
		if block.calls.Load() != 1 || count.calls.Load() != 0 {
			t.Fatalf("block calls=%d count calls=%d", block.calls.Load(), count.calls.Load())
		}
	})

	t.Run("parallel-slot", func(t *testing.T) {
		first := &cancelBlockingTool{name: "first", started: make(chan struct{})}
		second := &cancelBlockingTool{name: "second", started: make(chan struct{})}
		count := &cancelCountingTool{}
		registry := tool.NewRegistry()
		registry.Register(first)
		registry.Register(second)
		registry.Register(count)
		agent := &Agent{
			Model: &cancelToolModel{tools: []model.ToolCall{
				{ID: "one", Name: "first"},
				{ID: "two", Name: "second"},
				{ID: "three", Name: "count"},
			}},
			Tools: registry, MaxParallelTools: 2,
		}

		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()
		done := make(chan error, 1)
		go func() {
			_, err := agent.Run(ctx, Session{ID: "cancel"}, "go")
			done <- err
		}()
		for _, started := range []<-chan struct{}{first.started, second.started} {
			select {
			case <-started:
			case <-time.After(5 * time.Second):
				t.Fatal("blocking tool did not start")
			}
		}
		cancel()
		select {
		case err := <-done:
			if !errors.Is(err, context.Canceled) {
				t.Fatalf("error = %v", err)
			}
		case <-time.After(5 * time.Second):
			t.Fatal("run did not return after cancellation")
		}
		if first.calls.Load() != 1 || second.calls.Load() != 1 || count.calls.Load() != 0 {
			t.Fatalf("first=%d second=%d count=%d", first.calls.Load(), second.calls.Load(), count.calls.Load())
		}
	})
}
