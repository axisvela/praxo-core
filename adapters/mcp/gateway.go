// Package mcp adapts an MCP client session to the PRAXO-CORE tool gateway.
package mcp

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"
	"sync"

	"github.com/axisvela/praxo-core/v2/pkg/tool"
	sdk "github.com/modelcontextprotocol/go-sdk/mcp"
)

// ErrSessionRequired is returned when the gateway has no MCP session.
var ErrSessionRequired = errors.New("mcp: client session is required")

// Gateway exposes MCP tools through tool.Gateway.
//
// MCP authentication is bound to the client session; the token argument in
// tool.Gateway.Execute is ignored.
type Gateway struct {
	session *sdk.ClientSession

	mu    sync.RWMutex
	tools []tool.GatewayInfo
}

// NewGateway lists the session's tools and returns a gateway.
func NewGateway(ctx context.Context, session *sdk.ClientSession) (*Gateway, error) {
	if session == nil {
		return nil, ErrSessionRequired
	}
	gateway := &Gateway{session: session}
	if err := gateway.Refresh(ctx); err != nil {
		return nil, err
	}
	return gateway, nil
}

// Refresh reloads the cached tool list from the MCP session.
func (g *Gateway) Refresh(ctx context.Context) error {
	if g == nil || g.session == nil {
		return ErrSessionRequired
	}
	result, err := g.session.ListTools(ctx, nil)
	if err != nil {
		return err
	}
	infos := make([]tool.GatewayInfo, 0, len(result.Tools))
	for _, item := range result.Tools {
		infos = append(infos, tool.GatewayInfo{
			Name:        item.Name,
			Description: item.Description,
		})
	}
	sort.Slice(infos, func(i, j int) bool { return infos[i].Name < infos[j].Name })
	g.mu.Lock()
	g.tools = infos
	g.mu.Unlock()
	return nil
}

// ListTools returns a copy of the cached tool list.
func (g *Gateway) ListTools() []tool.GatewayInfo {
	if g == nil {
		return nil
	}
	g.mu.RLock()
	defer g.mu.RUnlock()
	return append([]tool.GatewayInfo(nil), g.tools...)
}

// Execute calls one MCP tool.
func (g *Gateway) Execute(ctx context.Context, name string, input map[string]any, _ string) (any, error) {
	if g == nil || g.session == nil {
		return nil, ErrSessionRequired
	}
	result, err := g.session.CallTool(ctx, &sdk.CallToolParams{
		Name:      name,
		Arguments: input,
	})
	if err != nil {
		return nil, err
	}
	if result == nil {
		return nil, fmt.Errorf("mcp: tool %s returned no result", name)
	}
	if result.IsError {
		return nil, fmt.Errorf("mcp: tool %s failed: %s", name, textContent(result))
	}
	if result.StructuredContent != nil {
		return result.StructuredContent, nil
	}
	texts := textContents(result)
	switch len(texts) {
	case 0:
		return nil, nil
	case 1:
		return texts[0], nil
	default:
		return texts, nil
	}
}

func textContents(result *sdk.CallToolResult) []string {
	out := make([]string, 0, len(result.Content))
	for _, content := range result.Content {
		if text, ok := content.(*sdk.TextContent); ok {
			out = append(out, text.Text)
		}
	}
	return out
}

func textContent(result *sdk.CallToolResult) string {
	return strings.Join(textContents(result), "\n")
}
