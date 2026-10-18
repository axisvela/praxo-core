package tool

import (
	"context"
	"sort"
)

// GatewayInfo is tool metadata from an external gateway.
type GatewayInfo struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Risk        string `json:"risk"`
}

// Gateway executes tools owned by another runtime, such as PRAXOVELA/Janus.
// Use it for product-owned external gateways; use pkg/plugin/bridge for
// runtime plugins that implement pkg/plugin.Host.
type Gateway interface {
	Execute(ctx context.Context, name string, input map[string]any, token string) (any, error)
	ListTools() []GatewayInfo
}

// GatewayTool adapts one gateway tool to the Tool interface.
type GatewayTool struct {
	Gateway Gateway
	Info    GatewayInfo
}

// Name implements Tool.
func (t GatewayTool) Name() string { return t.Info.Name }

// Description implements Tool.
func (t GatewayTool) Description() string { return t.Info.Description }

// Invoke implements Tool.
func (t GatewayTool) Invoke(ctx context.Context, args map[string]any) (any, error) {
	return t.Gateway.Execute(ctx, t.Info.Name, args, "")
}

// NewGatewayTools returns gateway tools sorted by name.
func NewGatewayTools(gw Gateway) []Tool {
	if gw == nil {
		return nil
	}
	infos := gw.ListTools()
	sort.Slice(infos, func(i, j int) bool { return infos[i].Name < infos[j].Name })
	out := make([]Tool, 0, len(infos))
	for _, info := range infos {
		out = append(out, GatewayTool{Gateway: gw, Info: info})
	}
	return out
}
