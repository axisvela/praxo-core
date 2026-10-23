// Package mcp adapts an MCP client session to the PRAXO-CORE tool gateway.
package mcp

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"strings"
	"sync"

	"github.com/axisvela/praxo-core/v2/pkg/model"
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
	specs map[string]model.ToolSpec
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
	infos := []tool.GatewayInfo{}
	specs := map[string]model.ToolSpec{}
	cursor := ""
	seen := map[string]bool{}
	for {
		result, err := g.session.ListTools(ctx, &sdk.ListToolsParams{Cursor: cursor})
		if err != nil {
			return err
		}
		for _, item := range result.Tools {
			if item == nil {
				return errors.New("mcp: nil tool definition")
			}
			raw, err := json.Marshal(item.InputSchema)
			if err != nil {
				return err
			}
			var parameters map[string]any
			if err := json.Unmarshal(raw, &parameters); err != nil {
				return err
			}
			if parameters == nil {
				return fmt.Errorf("mcp: missing input schema for %s", item.Name)
			}
			if _, exists := specs[item.Name]; exists {
				return fmt.Errorf("mcp: duplicate tool %s", item.Name)
			}
			infos = append(infos, tool.GatewayInfo{Name: item.Name, Description: item.Description})
			specs[item.Name] = model.ToolSpec{Name: item.Name, Description: item.Description, Parameters: parameters}
		}
		if result.NextCursor == "" {
			break
		}
		if seen[result.NextCursor] {
			return errors.New("mcp: repeated tool pagination cursor")
		}
		seen[result.NextCursor] = true
		cursor = result.NextCursor
	}
	sort.Slice(infos, func(i, j int) bool { return infos[i].Name < infos[j].Name })
	g.mu.Lock()
	g.tools = infos
	g.specs = specs
	g.mu.Unlock()
	return nil
}

func NewTools(ctx context.Context, session *sdk.ClientSession) ([]tool.Tool, error) {
	gateway, err := NewGateway(ctx, session)
	if err != nil {
		return nil, err
	}
	tools := make([]tool.Tool, 0, len(gateway.tools))
	for _, info := range gateway.tools {
		tools = append(tools, schemaTool{
			GatewayTool: tool.GatewayTool{Gateway: gateway, Info: info},
			spec:        gateway.specs[info.Name],
		})
	}
	return tools, nil
}

type schemaTool struct {
	tool.GatewayTool
	spec model.ToolSpec
}

func (t schemaTool) Spec() model.ToolSpec { return t.spec }

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
