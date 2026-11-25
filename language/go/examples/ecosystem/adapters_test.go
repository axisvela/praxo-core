package ecosystem

import (
	"context"
	"errors"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/memory"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/retriever"
	"github.com/axisvela/praxo-core/v2/pkg/sandbox"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

var (
	_ model.Model         = Model{}
	_ model.Provider      = Provider{}
	_ memory.Store        = Memory{}
	_ event.Sink          = Events{}
	_ retriever.Retriever = Retriever{}
	_ policy.Hook         = Policy{}
	_ sandbox.Sandbox     = Sandbox{}
	_ sandbox.Interpreter = Interpreter{}
	_ tool.Gateway        = Gateway{}
)

func TestUnconfiguredAdapters(t *testing.T) {
	ctx := context.Background()
	tests := []struct {
		name string
		call func() error
	}{
		{"model", func() error { _, err := (Model{}).Generate(ctx, model.Request{}); return err }},
		{"provider chat", func() error { _, err := (Provider{}).Chat(nil); return err }},
		{"provider stream", func() error { _, err := (Provider{}).ChatStream(nil); return err }},
		{"memory put", func() error { return (Memory{}).Put(ctx, "s", memory.Record{}) }},
		{"memory search", func() error { _, err := (Memory{}).Search(ctx, "s", "q", 1); return err }},
		{"events", func() error { return (Events{}).Emit(ctx, event.Event{}) }},
		{"retriever", func() error { _, err := (Retriever{}).Retrieve(ctx, "q", 1); return err }},
		{"policy", func() error { _, err := (Policy{}).Authorize(ctx, policy.Action{}); return err }},
		{"sandbox", func() error { _, err := (Sandbox{}).Run(ctx, sandbox.Spec{}, nil); return err }},
		{"interpreter", func() error { _, err := (Interpreter{}).Eval(ctx, "1"); return err }},
		{"gateway", func() error { _, err := (Gateway{}).Execute(ctx, "t", nil, ""); return err }},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if err := tt.call(); !errors.Is(err, ErrNotConfigured) {
				t.Fatalf("got %v, want %v", err, ErrNotConfigured)
			}
		})
	}
	if got := (Gateway{}).ListTools(); got != nil {
		t.Fatalf("ListTools() = %v, want nil", got)
	}
}

func TestConfiguredAdapters(t *testing.T) {
	ctx := context.Background()

	t.Run("model", func(t *testing.T) {
		adapter := Model{GenerateFunc: func(_ context.Context, req model.Request) (model.Response, error) {
			return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: req.Model}}, nil
		}}
		resp, err := adapter.Generate(ctx, model.Request{Model: "model-1"})
		if err != nil {
			t.Fatal(err)
		}
		if resp.Message.Content != "model-1" {
			t.Fatalf("content = %q", resp.Message.Content)
		}
	})

	t.Run("provider", func(t *testing.T) {
		adapter := Provider{
			ChatFunc: func(messages []model.Message) ([]model.Message, error) {
				return append(messages, model.Message{Role: model.RoleAssistant, Content: "ok"}), nil
			},
			ChatStreamFunc: func([]model.Message) (<-chan model.StreamEvent, error) {
				ch := make(chan model.StreamEvent, 1)
				ch <- model.StreamEvent{Delta: "ok", Done: true}
				close(ch)
				return ch, nil
			},
		}
		messages, err := adapter.Chat([]model.Message{{Role: model.RoleUser, Content: "hi"}})
		if err != nil {
			t.Fatal(err)
		}
		if len(messages) != 2 || messages[1].Content != "ok" {
			t.Fatalf("messages = %#v", messages)
		}
		stream, err := adapter.ChatStream(nil)
		if err != nil {
			t.Fatal(err)
		}
		if delta := <-stream; delta.Delta != "ok" {
			t.Fatalf("delta = %q", delta.Delta)
		}
	})

	t.Run("memory", func(t *testing.T) {
		var stored memory.Record
		adapter := Memory{
			PutFunc: func(_ context.Context, sessionID string, record memory.Record) error {
				if sessionID != "s" {
					t.Fatalf("sessionID = %q", sessionID)
				}
				stored = record
				return nil
			},
			SearchFunc: func(_ context.Context, sessionID, query string, limit int) ([]memory.Record, error) {
				return []memory.Record{stored}, nil
			},
		}
		if err := adapter.Put(ctx, "s", memory.Record{Content: "remember"}); err != nil {
			t.Fatal(err)
		}
		records, err := adapter.Search(ctx, "s", "remember", 1)
		if err != nil {
			t.Fatal(err)
		}
		if len(records) != 1 || records[0].Content != "remember" {
			t.Fatalf("records = %#v", records)
		}
	})

	t.Run("events", func(t *testing.T) {
		var emitted event.Event
		adapter := Events{EmitFunc: func(_ context.Context, ev event.Event) error {
			emitted = ev
			return nil
		}}
		if err := adapter.Emit(ctx, event.Event{Type: "run.started"}); err != nil {
			t.Fatal(err)
		}
		if emitted.Type != "run.started" {
			t.Fatalf("type = %q", emitted.Type)
		}
	})

	t.Run("retriever", func(t *testing.T) {
		adapter := Retriever{RetrieveFunc: func(_ context.Context, query string, limit int) ([]retriever.Document, error) {
			return []retriever.Document{{ID: query, Content: "doc"}}, nil
		}}
		documents, err := adapter.Retrieve(ctx, "doc-1", 1)
		if err != nil {
			t.Fatal(err)
		}
		if len(documents) != 1 || documents[0].ID != "doc-1" {
			t.Fatalf("documents = %#v", documents)
		}
	})

	t.Run("policy", func(t *testing.T) {
		adapter := Policy{AuthorizeFunc: func(_ context.Context, action policy.Action) (policy.Decision, error) {
			return policy.Decision{Allowed: action.Kind == "tool"}, nil
		}}
		decision, err := adapter.Authorize(ctx, policy.Action{Kind: "tool"})
		if err != nil {
			t.Fatal(err)
		}
		if !decision.Allowed {
			t.Fatal("expected allowed decision")
		}
	})

	t.Run("sandbox", func(t *testing.T) {
		adapter := Sandbox{RunFunc: func(_ context.Context, spec sandbox.Spec, command []string) (sandbox.Result, error) {
			return sandbox.Result{ExitCode: len(command), Stdout: spec.Image}, nil
		}}
		result, err := adapter.Run(ctx, sandbox.Spec{Image: "image"}, []string{"echo"})
		if err != nil {
			t.Fatal(err)
		}
		if result.ExitCode != 1 || result.Stdout != "image" {
			t.Fatalf("result = %#v", result)
		}
	})

	t.Run("interpreter", func(t *testing.T) {
		adapter := Interpreter{EvalFunc: func(_ context.Context, script string) (any, error) {
			return script, nil
		}}
		value, err := adapter.Eval(ctx, "1+1")
		if err != nil {
			t.Fatal(err)
		}
		if value != "1+1" {
			t.Fatalf("value = %#v", value)
		}
	})

	t.Run("gateway", func(t *testing.T) {
		adapter := Gateway{
			ExecuteFunc: func(_ context.Context, name string, input map[string]any, token string) (any, error) {
				return map[string]any{"name": name, "input": input, "token": token}, nil
			},
			ListToolsFunc: func() []tool.GatewayInfo {
				return []tool.GatewayInfo{{Name: "search", Description: "Search documents"}}
			},
		}
		tools := tool.NewGatewayTools(adapter)
		if len(tools) != 1 {
			t.Fatalf("len(tools) = %d", len(tools))
		}
		value, err := tools[0].Invoke(ctx, map[string]any{"q": "x"})
		if err != nil {
			t.Fatal(err)
		}
		got := value.(map[string]any)
		if got["name"] != "search" || got["token"] != "" {
			t.Fatalf("value = %#v", value)
		}
	})
}
