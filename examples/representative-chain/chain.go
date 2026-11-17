package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"time"

	harmovela "github.com/axisvela/praxo-core/adapters/harmovela"
	mcpx "github.com/axisvela/praxo-core/adapters/mcp"
	otelsink "github.com/axisvela/praxo-core/adapters/otel"
	"github.com/axisvela/praxo-core/v2/adapters/openaicompat"
	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
	sdk "github.com/modelcontextprotocol/go-sdk/mcp"
	"go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
)

type config struct {
	BaseURL string
	Model   string
	APIKey  string
}

type summary struct {
	Output       string
	Effects      map[string]int
	ChildCalls   int
	Spans        []string
	Events       []string
	DeniedEffect int
	DenialError  string
}

type effectLog struct {
	mu     sync.Mutex
	counts map[string]int
}

func newEffectLog() *effectLog {
	return &effectLog{counts: map[string]int{}}
}

func (e *effectLog) add(target string) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.counts[target]++
}

func (e *effectLog) count(target string) int {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.counts[target]
}

func (e *effectLog) snapshot() map[string]int {
	e.mu.Lock()
	defer e.mu.Unlock()
	out := make(map[string]int, len(e.counts))
	for key, value := range e.counts {
		out[key] = value
	}
	return out
}

type eventLog struct {
	mu    sync.Mutex
	types []string
}

func (e *eventLog) add(kind string) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.types = append(e.types, kind)
}

func (e *eventLog) snapshot() []string {
	e.mu.Lock()
	defer e.mu.Unlock()
	out := make([]string, len(e.types))
	copy(out, e.types)
	return out
}

type recordInput struct {
	Target string `json:"target"`
}

func newMCPRecord(ctx context.Context, effects *effectLog) (tool.Tool, func(), error) {
	serverTransport, clientTransport := sdk.NewInMemoryTransports()
	server := sdk.NewServer(&sdk.Implementation{Name: "chain-mcp", Version: "v0.0.1"}, nil)
	sdk.AddTool(server, &sdk.Tool{
		Name:        "record",
		Description: "Record a target in the representative chain",
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"target": map[string]any{"type": "string"},
			},
			"required": []string{"target"},
		},
	}, func(_ context.Context, _ *sdk.CallToolRequest, input recordInput) (*sdk.CallToolResult, any, error) {
		effects.add(input.Target)
		return &sdk.CallToolResult{Content: []sdk.Content{
			&sdk.TextContent{Text: "recorded:" + input.Target},
		}}, nil, nil
	})

	serverSession, err := server.Connect(ctx, serverTransport, nil)
	if err != nil {
		return nil, nil, err
	}
	client := sdk.NewClient(&sdk.Implementation{Name: "chain-client", Version: "v0.0.1"}, nil)
	clientSession, err := client.Connect(ctx, clientTransport, nil)
	if err != nil {
		_ = serverSession.Close()
		return nil, nil, err
	}
	gateway, err := mcpx.NewGateway(ctx, clientSession)
	if err != nil {
		_ = clientSession.Close()
		_ = serverSession.Close()
		return nil, nil, err
	}
	tools := tool.NewGatewayTools(gateway)
	if len(tools) != 1 || tools[0].Name() != "record" {
		_ = clientSession.Close()
		_ = serverSession.Close()
		return nil, nil, fmt.Errorf("unexpected MCP tools: %+v", tools)
	}
	cleanup := func() {
		_ = clientSession.Close()
		_ = serverSession.Wait()
	}
	return tools[0], cleanup, nil
}

type childModel struct {
	calls int
}

func (m *childModel) Generate(_ context.Context, _ model.Request) (model.Response, error) {
	m.calls++
	if m.calls == 1 {
		return model.Response{Message: model.Message{
			ToolCalls: []model.ToolCall{{
				ID:        "child-record",
				Name:      "record",
				Arguments: map[string]any{"target": "child"},
			}},
		}}, nil
	}
	return model.Response{Message: model.Message{Content: "CHILD-DONE"}}, nil
}

type composedPolicy []policy.Hook

func (p composedPolicy) Authorize(ctx context.Context, action policy.Action) (policy.Decision, error) {
	for _, hook := range p {
		decision, err := hook.Authorize(ctx, action)
		if err != nil {
			return decision, err
		}
		if !decision.Allowed {
			return decision, nil
		}
	}
	return policy.Decision{Allowed: true}, nil
}

type delegateTool struct {
	record tool.Tool
	model  *childModel
	log    *effectLog
	events event.Sink
}

func (d delegateTool) Name() string {
	return "delegate"
}

func (d delegateTool) Description() string {
	return "Run a governed child agent with the narrowed record scope"
}

func (d delegateTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        d.Name(),
		Description: d.Description(),
		Parameters: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"task": map[string]any{"type": "string"},
			},
			"required": []string{"task"},
		},
	}
}

func (d delegateTool) Invoke(ctx context.Context, _ map[string]any) (any, error) {
	registry := tool.NewRegistry()
	registry.Register(d.record)
	childPolicy := composedPolicy{
		policy.FuncHook(parentPolicy),
		policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
			switch action.Kind {
			case "model.generate":
				return policy.Decision{Allowed: true}, nil
			case "tool.invoke":
				if action.ToolName == "record" {
					return policy.Decision{Allowed: true}, nil
				}
				return policy.Decision{Allowed: false, Reason: "child may only record"}, nil
			default:
				return policy.Decision{Allowed: false, Reason: "unsupported action"}, nil
			}
		}),
	}
	child, err := agent.New(agent.Options{
		Model:            d.model,
		Tools:            registry,
		AllowedTools:     []string{"record"},
		Policy:           childPolicy,
		RequirePolicy:    true,
		RequireToolScope: true,
		MaxSteps:         3,
		Events:           d.events,
		ToolChoice:       model.ToolChoiceAuto,
	})
	if err != nil {
		return nil, err
	}
	result, err := child.Run(
		ctx,
		agent.Session{ID: "chain-child"},
		"Call record with target=child, then answer CHILD-DONE.",
	)
	if err != nil {
		return nil, err
	}
	return map[string]any{
		"output":  result.Output,
		"effects": d.log.count("child"),
	}, nil
}

func parentPolicy(_ context.Context, action policy.Action) (policy.Decision, error) {
	switch action.Kind {
	case "model.generate":
		return policy.Decision{Allowed: true}, nil
	case "tool.invoke":
		if action.ToolName == "record" && action.Arguments["target"] == "blocked" {
			return policy.Decision{Allowed: false, Reason: "blocked target"}, nil
		}
		if action.ToolName == "record" || action.ToolName == "delegate" {
			return policy.Decision{Allowed: true}, nil
		}
		return policy.Decision{Allowed: false, Reason: "parent tool is not allowed"}, nil
	default:
		return policy.Decision{Allowed: false, Reason: "unsupported action"}, nil
	}
}

type denialModel struct {
	calls int
}

func (m *denialModel) Generate(_ context.Context, _ model.Request) (model.Response, error) {
	m.calls++
	if m.calls == 1 {
		return model.Response{Message: model.Message{
			ToolCalls: []model.ToolCall{{
				ID:        "denied-record",
				Name:      "record",
				Arguments: map[string]any{"target": "safe"},
			}},
		}}, nil
	}
	return model.Response{Message: model.Message{Content: "UNEXPECTED"}}, nil
}

func runDenial(ctx context.Context, record tool.Tool, effects *effectLog, events event.Sink) (int, string, error) {
	registry := tool.NewRegistry()
	registry.Register(record)
	edit := agent.Middleware{BeforeTool: func(_ context.Context, call *agent.ToolCall) error {
		call.Call.Arguments["target"] = "blocked"
		return nil
	}}
	ag, err := agent.New(agent.Options{
		Model:            &denialModel{},
		Tools:            registry,
		AllowedTools:     []string{"record"},
		Policy:           policy.FuncHook(parentPolicy),
		RequirePolicy:    true,
		RequireToolScope: true,
		MaxSteps:         2,
		Events:           events,
		Middleware:       []agent.Middleware{edit},
	})
	if err != nil {
		return 0, "", err
	}
	_, runErr := ag.Run(ctx, agent.Session{ID: "chain-denial"}, "call record")
	message := ""
	if runErr != nil {
		message = runErr.Error()
	}
	return effects.count("blocked"), message, runErr
}

func runChain(ctx context.Context, cfg config) (summary, error) {
	effects := newEffectLog()
	record, cleanup, err := newMCPRecord(ctx, effects)
	if err != nil {
		return summary{}, err
	}
	defer cleanup()

	events := &eventLog{}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/events" {
			http.NotFound(w, r)
			return
		}
		var payload struct {
			Type string `json:"type"`
		}
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		events.add(payload.Type)
		w.WriteHeader(http.StatusAccepted)
	}))
	defer server.Close()

	exporter := tracetest.NewInMemoryExporter()
	provider := trace.NewTracerProvider(trace.WithSyncer(exporter))
	defer provider.Shutdown(context.Background())
	sinks := event.MultiSink{
		otelsink.New(provider),
		harmovela.Sink{
			BaseURL: server.URL,
			Source:  "representative-chain",
			HTTP:    server.Client(),
		},
	}

	child := &childModel{}
	parentTools := tool.NewRegistry()
	parentTools.Register(record)
	parentTools.Register(delegateTool{
		record: record,
		model:  child,
		log:    effects,
		events: sinks,
	})
	parent, err := agent.New(agent.Options{
		Model: openaicompat.Adapter{
			BaseURL: cfg.BaseURL,
			APIKey:  cfg.APIKey,
			Model:   cfg.Model,
			HTTP:    &http.Client{Timeout: 180 * time.Second},
		},
		Tools:            parentTools,
		AllowedTools:     []string{"record", "delegate"},
		Policy:           policy.FuncHook(parentPolicy),
		RequirePolicy:    true,
		RequireToolScope: true,
		MaxSteps:         6,
		Events:           sinks,
		ToolChoice:       model.ToolChoiceAuto,
	})
	if err != nil {
		return summary{}, err
	}
	result, err := parent.Run(
		ctx,
		agent.Session{ID: "chain-parent"},
		"Call record with target=parent. Then call delegate with task=child. Then answer DONE. Do not skip either tool.",
	)
	if err != nil {
		return summary{}, err
	}

	deniedEffect, denialError, denialRunErr := runDenial(ctx, record, effects, sinks)
	if denialRunErr == nil {
		return summary{}, fmt.Errorf("denial path unexpectedly succeeded")
	}
	if !strings.Contains(denialError, "denied") && !strings.Contains(denialError, "policy") {
		return summary{}, fmt.Errorf("unexpected denial error: %s", denialError)
	}

	spans := []string{}
	for _, span := range exporter.GetSpans() {
		spans = append(spans, span.Name)
	}
	return summary{
		Output:       result.Output,
		Effects:      effects.snapshot(),
		ChildCalls:   child.calls,
		Spans:        spans,
		Events:       events.snapshot(),
		DeniedEffect: deniedEffect,
		DenialError:  denialError,
	}, nil
}
