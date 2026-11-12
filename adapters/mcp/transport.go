package mcp

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"os/exec"
	"strings"
	"time"

	sdk "github.com/modelcontextprotocol/go-sdk/mcp"
)

const (
	clientName    = "praxo-core"
	clientVersion = "2.7.0"
)

var (
	// ErrCommandRequired is returned when a stdio command is missing.
	ErrCommandRequired = errors.New("mcp: command is required")
	// ErrEndpointRequired is returned when a streamable HTTP endpoint is missing.
	ErrEndpointRequired = errors.New("mcp: endpoint is required")
	// ErrHTTPSRequired is returned for a non-loopback, non-HTTPS endpoint.
	ErrHTTPSRequired = errors.New("mcp: endpoint must use https")
)

// ConnectStdio starts cmd and connects to it over stdin/stdout using
// newline-delimited JSON-RPC.
func ConnectStdio(ctx context.Context, cmd *exec.Cmd, opts *sdk.ClientSessionOptions) (*sdk.ClientSession, error) {
	if cmd == nil {
		return nil, ErrCommandRequired
	}
	client := sdk.NewClient(clientImplementation(), nil)
	return client.Connect(ctx, &sdk.CommandTransport{Command: cmd}, opts)
}

// NewStdioGateway connects to a stdio MCP server and exposes its tools.
func NewStdioGateway(ctx context.Context, cmd *exec.Cmd, opts *sdk.ClientSessionOptions) (*Gateway, error) {
	session, err := ConnectStdio(ctx, cmd, opts)
	if err != nil {
		return nil, err
	}
	return gatewayForSession(ctx, session)
}

// ConnectStreamableHTTP connects to an MCP Streamable HTTP endpoint using the
// 2025-03-26 transport. A nil client uses a bounded default HTTP client.
func ConnectStreamableHTTP(ctx context.Context, endpoint string, httpClient *http.Client, opts *sdk.ClientSessionOptions) (*sdk.ClientSession, error) {
	if strings.TrimSpace(endpoint) == "" {
		return nil, ErrEndpointRequired
	}
	parsed, err := url.Parse(endpoint)
	if err != nil {
		return nil, fmt.Errorf("mcp: invalid endpoint: %w", err)
	}
	if parsed.Scheme != "https" && !loopbackHost(parsed.Hostname()) {
		return nil, fmt.Errorf("%w: %q", ErrHTTPSRequired, parsed.Scheme)
	}
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 30 * time.Second}
	}
	client := sdk.NewClient(clientImplementation(), nil)
	transport := &sdk.StreamableClientTransport{
		Endpoint:   endpoint,
		HTTPClient: httpClient,
	}
	return client.Connect(ctx, transport, opts)
}

// NewStreamableHTTPGateway connects to a Streamable HTTP MCP server and exposes
// its tools.
func NewStreamableHTTPGateway(ctx context.Context, endpoint string, httpClient *http.Client, opts *sdk.ClientSessionOptions) (*Gateway, error) {
	session, err := ConnectStreamableHTTP(ctx, endpoint, httpClient, opts)
	if err != nil {
		return nil, err
	}
	return gatewayForSession(ctx, session)
}

func gatewayForSession(ctx context.Context, session *sdk.ClientSession) (*Gateway, error) {
	gateway, err := NewGateway(ctx, session)
	if err != nil {
		_ = session.Close()
		return nil, err
	}
	return gateway, nil
}

func clientImplementation() *sdk.Implementation {
	return &sdk.Implementation{Name: clientName, Version: clientVersion}
}

func loopbackHost(host string) bool {
	if strings.EqualFold(host, "localhost") {
		return true
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}
