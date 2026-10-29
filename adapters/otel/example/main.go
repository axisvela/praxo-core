package main

import (
	"context"
	"fmt"
	"log"
	"sort"

	otelsink "github.com/axisvela/praxo-core/adapters/otel"
	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
)

type clockTool struct{}

func (clockTool) Name() string        { return "clock.now" }
func (clockTool) Description() string { return "Return the current fixture time" }
func (clockTool) Invoke(context.Context, map[string]any) (any, error) {
	return "12:00", nil
}

type toolThenAnswer struct{ calls int }

func (m *toolThenAnswer) Generate(_ context.Context, req model.Request) (model.Response, error) {
	m.calls++
	if m.calls == 1 {
		return model.Response{Message: model.Message{
			Role:      model.RoleAssistant,
			ToolCalls: []model.ToolCall{{ID: "clock-1", Name: "clock.now"}},
		}}, nil
	}
	for i := len(req.Messages) - 1; i >= 0; i-- {
		if req.Messages[i].Role == model.RoleTool {
			return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "It is 12:00."}}, nil
		}
	}
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "done"}}, nil
}

func newProvider(exporter *tracetest.InMemoryExporter) *sdktrace.TracerProvider {
	return sdktrace.NewTracerProvider(sdktrace.WithSyncer(exporter))
}

func run(ctx context.Context, provider *sdktrace.TracerProvider) error {
	sink := otelsink.New(provider)
	sink.AllowedDataKeys = []string{"name"}

	registry := tool.NewRegistry()
	registry.Register(clockTool{})
	ag, err := agent.New(agent.Options{
		Model:        &toolThenAnswer{},
		Tools:        registry,
		AllowedTools: []string{"clock.now"},
		Events:       sink,
		MaxSteps:     2,
	})
	if err != nil {
		return err
	}
	_, err = ag.Run(ctx, agent.Session{ID: "otel-demo", TenantID: "local"}, "what time is it?")
	return err
}

func main() {
	exporter := tracetest.NewInMemoryExporter()
	provider := newProvider(exporter)
	defer provider.Shutdown(context.Background())
	if err := run(context.Background(), provider); err != nil {
		log.Fatal(err)
	}
	for _, span := range exporter.GetSpans() {
		attributes := map[string]string{}
		for _, item := range span.Attributes {
			attributes[string(item.Key)] = item.Value.AsString()
		}
		keys := make([]string, 0, len(attributes))
		for key := range attributes {
			keys = append(keys, key)
		}
		sort.Strings(keys)
		fmt.Println(span.Name)
		for _, key := range keys {
			fmt.Printf("  %s=%s\n", key, attributes[key])
		}
	}
}
