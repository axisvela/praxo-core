package limenora

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sort"

	sdk "github.com/axisvela/LIMENORA-open/sdk/go/v3"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

// ErrClientRequired is returned when the network gateway is not configured.
var ErrClientRequired = errors.New("limenora: network gateway is required")

// Route maps one tool name to a governed outbound request.
type Route struct {
	URL         string
	Method      string
	Description string
	Headers     map[string]string
}

// Gateway implements tool.Gateway with LIMENORA proxy egress.
type Gateway struct {
	Client sdk.NetworkGateway
	Tools  map[string]Route
	Ctx    sdk.AuthzContext
}

// ListTools returns the configured tools sorted by name.
func (g Gateway) ListTools() []tool.GatewayInfo {
	names := make([]string, 0, len(g.Tools))
	for name := range g.Tools {
		names = append(names, name)
	}
	sort.Strings(names)
	infos := make([]tool.GatewayInfo, 0, len(names))
	for _, name := range names {
		infos = append(infos, tool.GatewayInfo{
			Name:        name,
			Description: g.Tools[name].Description,
		})
	}
	return infos
}

// Execute sends one governed request through the LIMENORA network gateway.
func (g Gateway) Execute(ctx context.Context, name string, input map[string]any, _ string) (any, error) {
	if g.Client == nil {
		return nil, ErrClientRequired
	}
	route, ok := g.Tools[name]
	if !ok {
		return nil, fmt.Errorf("limenora: unknown tool %q", name)
	}
	body, err := json.Marshal(input)
	if err != nil {
		return nil, err
	}
	method := route.Method
	if method == "" {
		method = "POST"
	}
	result, err := g.Client.Do(ctx, sdk.GatewayRequest{
		URL:     route.URL,
		Method:  method,
		Headers: route.Headers,
		Body:    body,
		Ctx:     g.Ctx,
	})
	if err != nil {
		return nil, err
	}
	if result == nil {
		return nil, errors.New("limenora: empty gateway result")
	}
	if result.Status < 200 || result.Status >= 300 {
		return nil, fmt.Errorf("limenora: %s returned %d: %s", name, result.Status, string(result.Body))
	}
	var output any
	if err := json.Unmarshal(result.Body, &output); err != nil {
		return string(result.Body), nil
	}
	return output, nil
}
