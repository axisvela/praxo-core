package mcp

import (
	"context"
	"errors"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/tool"
	sdk "github.com/modelcontextprotocol/go-sdk/mcp"
)

var _ tool.Gateway = (*Gateway)(nil)

type echoInput struct {
	Name string `json:"name"`
}

func echo(_ context.Context, _ *sdk.CallToolRequest, input echoInput) (*sdk.CallToolResult, any, error) {
	return &sdk.CallToolResult{Content: []sdk.Content{
		&sdk.TextContent{Text: "echo: " + input.Name},
	}}, nil, nil
}

func newSession(t *testing.T) *sdk.ClientSession {
	t.Helper()
	ctx := context.Background()
	serverTransport, clientTransport := sdk.NewInMemoryTransports()

	server := sdk.NewServer(&sdk.Implementation{Name: "test-server", Version: "v0.0.1"}, nil)
	sdk.AddTool(server, &sdk.Tool{Name: "echo", Description: "Echo a name"}, echo)
	serverSession, err := server.Connect(ctx, serverTransport, nil)
	if err != nil {
		t.Fatal(err)
	}

	client := sdk.NewClient(&sdk.Implementation{Name: "test-client", Version: "v0.0.1"}, nil)
	clientSession, err := client.Connect(ctx, clientTransport, nil)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_ = clientSession.Close()
		_ = serverSession.Wait()
	})
	return clientSession
}

func TestGatewayListsAndCallsTools(t *testing.T) {
	ctx := context.Background()
	gateway, err := NewGateway(ctx, newSession(t))
	if err != nil {
		t.Fatal(err)
	}
	infos := gateway.ListTools()
	if len(infos) != 1 || infos[0].Name != "echo" || infos[0].Description != "Echo a name" {
		t.Fatalf("tools = %#v", infos)
	}

	tools := tool.NewGatewayTools(gateway)
	if len(tools) != 1 || tools[0].Name() != "echo" {
		t.Fatalf("adapted tools = %#v", tools)
	}
	value, err := tools[0].Invoke(ctx, map[string]any{"name": "Ada"})
	if err != nil {
		t.Fatal(err)
	}
	if value != "echo: Ada" {
		t.Fatalf("value = %#v", value)
	}
}

func TestGatewayRequiresSession(t *testing.T) {
	ctx := context.Background()
	if _, err := NewGateway(ctx, nil); !errors.Is(err, ErrSessionRequired) {
		t.Fatalf("got %v, want %v", err, ErrSessionRequired)
	}
	if _, err := (&Gateway{}).Execute(ctx, "echo", nil, ""); !errors.Is(err, ErrSessionRequired) {
		t.Fatalf("got %v, want %v", err, ErrSessionRequired)
	}
}

func TestNewToolsPreservesSchema(t *testing.T) {
	ctx := context.Background()
	tools, err := NewTools(ctx, newSession(t))
	if err != nil {
		t.Fatal(err)
	}
	registry := tool.NewRegistry()
	for _, item := range tools {
		registry.Register(item)
	}
	specs := registry.Specs()
	if len(specs) != 1 || specs[0].Parameters["type"] != "object" {
		t.Fatalf("specs = %#v", specs)
	}
	properties, ok := specs[0].Parameters["properties"].(map[string]any)
	if !ok || properties["name"] == nil {
		t.Fatalf("schema = %#v", specs[0].Parameters)
	}
	required, ok := specs[0].Parameters["required"].([]any)
	if !ok || len(required) != 1 || required[0] != "name" {
		t.Fatalf("required = %#v", specs[0].Parameters["required"])
	}
	value, err := tools[0].Invoke(ctx, map[string]any{"name": "Ada"})
	if err != nil || value != "echo: Ada" {
		t.Fatalf("value=%v err=%v", value, err)
	}
	if _, err := NewTools(ctx, nil); !errors.Is(err, ErrSessionRequired) {
		t.Fatalf("nil session: %v", err)
	}
}
