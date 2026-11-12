package mcp

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"testing"
	"time"

	sdk "github.com/modelcontextprotocol/go-sdk/mcp"
)

const stdioHelperEnv = "PRAXO_MCP_STDIO_HELPER"

func TestMain(m *testing.M) {
	if os.Getenv(stdioHelperEnv) == "1" {
		if err := runStdioServer(); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		os.Exit(0)
	}
	os.Exit(m.Run())
}

func runStdioServer() error {
	return newStreamableToolServer().Run(context.Background(), &sdk.StdioTransport{})
}

func newStreamableToolServer() *sdk.Server {
	server := sdk.NewServer(&sdk.Implementation{Name: "praxo-test", Version: "test"}, nil)
	server.AddTool(&sdk.Tool{
		Name:        "echo",
		Description: "Echo text",
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"text": map[string]any{"type": "string"},
			},
			"required": []string{"text"},
		},
	}, func(_ context.Context, req *sdk.CallToolRequest) (*sdk.CallToolResult, error) {
		var args struct {
			Text string `json:"text"`
		}
		if err := json.Unmarshal(req.Params.Arguments, &args); err != nil {
			return nil, err
		}
		return &sdk.CallToolResult{Content: []sdk.Content{
			&sdk.TextContent{Text: args.Text},
		}}, nil
	})
	return server
}

func TestStdioGateway(t *testing.T) {
	cmd := exec.Command(os.Args[0])
	cmd.Env = append(os.Environ(), stdioHelperEnv+"=1")
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	gateway, err := NewStdioGateway(ctx, cmd, nil)
	if err != nil {
		t.Fatalf("NewStdioGateway: %v", err)
	}
	defer gateway.Close()
	tools := gateway.ListTools()
	if len(tools) != 1 || tools[0].Name != "echo" {
		t.Fatalf("tools = %+v, want echo", tools)
	}
	got, err := gateway.Execute(ctx, "echo", map[string]any{"text": "hello"}, "")
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if got != "hello" {
		t.Fatalf("Execute = %v, want hello", got)
	}
}

func TestStreamableHTTPGatewayTLS(t *testing.T) {
	server := newStreamableToolServer()
	handler := sdk.NewStreamableHTTPHandler(func(*http.Request) *sdk.Server {
		return server
	}, &sdk.StreamableHTTPOptions{JSONResponse: true})
	httpServer := httptest.NewTLSServer(handler)
	defer httpServer.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	gateway, err := NewStreamableHTTPGateway(ctx, httpServer.URL, httpServer.Client(), nil)
	if err != nil {
		t.Fatalf("NewStreamableHTTPGateway: %v", err)
	}
	defer gateway.Close()
	tools := gateway.ListTools()
	if len(tools) != 1 || tools[0].Name != "echo" {
		t.Fatalf("tools = %+v, want echo", tools)
	}
	got, err := gateway.Execute(ctx, "echo", map[string]any{"text": "secure"}, "")
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if got != "secure" {
		t.Fatalf("Execute = %v, want secure", got)
	}
}

func TestStreamableHTTPSessionUses20250326OrLater(t *testing.T) {
	server := newStreamableToolServer()
	handler := sdk.NewStreamableHTTPHandler(func(*http.Request) *sdk.Server {
		return server
	}, &sdk.StreamableHTTPOptions{JSONResponse: true})
	httpServer := httptest.NewTLSServer(handler)
	defer httpServer.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	session, err := ConnectStreamableHTTP(ctx, httpServer.URL, httpServer.Client(), nil)
	if err != nil {
		t.Fatalf("ConnectStreamableHTTP: %v", err)
	}
	defer session.Close()
	result := session.InitializeResult()
	if result == nil || result.ProtocolVersion < "2025-03-26" {
		t.Fatalf("protocol version = %v, want >= 2025-03-26", result)
	}
}

func TestConnectStdioRequiresCommand(t *testing.T) {
	_, err := ConnectStdio(context.Background(), nil, nil)
	if !errors.Is(err, ErrCommandRequired) {
		t.Fatalf("err = %v, want ErrCommandRequired", err)
	}
}

func TestConnectStreamableHTTPRequiresEndpoint(t *testing.T) {
	_, err := ConnectStreamableHTTP(context.Background(), " ", nil, nil)
	if !errors.Is(err, ErrEndpointRequired) {
		t.Fatalf("err = %v, want ErrEndpointRequired", err)
	}
}

func TestConnectStreamableHTTPRequiresHTTPS(t *testing.T) {
	_, err := ConnectStreamableHTTP(context.Background(), "http://example.com/mcp", nil, nil)
	if !errors.Is(err, ErrHTTPSRequired) {
		t.Fatalf("err = %v, want ErrHTTPSRequired", err)
	}
}
