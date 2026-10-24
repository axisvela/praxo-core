package benchmarks

import (
	"context"
	"fmt"
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/memory"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

type scriptedModel struct {
	responses []model.Response
	calls     int
}

func (m *scriptedModel) Generate(context.Context, model.Request) (model.Response, error) {
	if m.calls >= len(m.responses) {
		return m.responses[len(m.responses)-1], nil
	}
	response := m.responses[m.calls]
	m.calls++
	return response, nil
}

func (m *scriptedModel) reset() { m.calls = 0 }

type echoTool struct{}

func (echoTool) Name() string        { return "echo" }
func (echoTool) Description() string { return "Echo a value" }

func (echoTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	return args["value"], nil
}

func newAgent(b *testing.B, responses []model.Response, tools *tool.Registry, opts ...func(*agent.Options)) (*agent.Agent, *scriptedModel) {
	b.Helper()
	script := &scriptedModel{responses: responses}
	options := agent.Options{
		Model:    script,
		Tools:    tools,
		MaxSteps: len(responses) + 1,
	}
	for _, apply := range opts {
		apply(&options)
	}
	instance, err := agent.New(options)
	if err != nil {
		b.Fatal(err)
	}
	return instance, script
}

func BenchmarkAgentSimple(b *testing.B) {
	instance, script := newAgent(b, []model.Response{{
		Message: model.Message{Role: model.RoleAssistant, Content: "ok"},
	}}, nil)
	session := agent.Session{ID: "bench"}
	ctx := context.Background()

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		script.reset()
		if _, err := instance.Run(ctx, session, "hello"); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkAgentToolCall(b *testing.B) {
	tools := tool.NewRegistry()
	tools.Register(echoTool{})
	instance, script := newAgent(b, []model.Response{
		{Message: model.Message{Role: model.RoleAssistant, ToolCalls: []model.ToolCall{{
			ID:        "call-1",
			Name:      "echo",
			Arguments: map[string]any{"value": "ok"},
		}}}},
		{Message: model.Message{Role: model.RoleAssistant, Content: "done"}},
	}, tools)
	session := agent.Session{ID: "bench"}
	ctx := context.Background()

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		script.reset()
		if _, err := instance.Run(ctx, session, "run the tool"); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkAgentParallelTools(b *testing.B) {
	tools := tool.NewRegistry()
	tools.Register(echoTool{})
	calls := make([]model.ToolCall, 8)
	for i := range calls {
		calls[i] = model.ToolCall{
			ID:        fmt.Sprintf("call-%d", i),
			Name:      "echo",
			Arguments: map[string]any{"value": i},
		}
	}
	instance, script := newAgent(b, []model.Response{
		{Message: model.Message{Role: model.RoleAssistant, ToolCalls: calls}},
		{Message: model.Message{Role: model.RoleAssistant, Content: "done"}},
	}, tools, func(options *agent.Options) {
		options.MaxParallelTools = 8
	})
	session := agent.Session{ID: "bench"}
	ctx := context.Background()

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		script.reset()
		if _, err := instance.Run(ctx, session, "run the tools"); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkAgentMemoryRecall(b *testing.B) {
	ctx := context.Background()
	store := memory.NewMemoryStore()
	for i := 0; i < 20; i++ {
		record := memory.Record{
			Frame:   memory.FrameExperience,
			Content: fmt.Sprintf("deployment note %d: region %d is healthy", i, i),
		}
		if err := store.Put(ctx, "bench", record); err != nil {
			b.Fatal(err)
		}
	}
	instance, script := newAgent(b, []model.Response{{
		Message: model.Message{Role: model.RoleAssistant, Content: "ok"},
	}}, nil, func(options *agent.Options) {
		options.Memory = store
		options.Recall = true
		options.RecallLimit = 5
	})
	session := agent.Session{ID: "bench"}

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		script.reset()
		if _, err := instance.Run(ctx, session, "deployment status"); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkAgentContextBudget(b *testing.B) {
	messages := make([]model.Message, 40)
	for i := range messages {
		messages[i] = model.Message{
			Role:    model.RoleUser,
			Content: strings.Repeat("context ", 20),
		}
	}
	instance, script := newAgent(b, []model.Response{{
		Message: model.Message{Role: model.RoleAssistant, Content: "ok"},
	}}, nil, func(options *agent.Options) {
		options.Context = &agent.ContextBudget{MaxTokens: 800, KeepRecent: 4}
	})
	session := agent.Session{ID: "bench", Messages: messages}
	ctx := context.Background()

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		script.reset()
		if _, err := instance.Run(ctx, session, "summarize"); err != nil {
			b.Fatal(err)
		}
	}
}
