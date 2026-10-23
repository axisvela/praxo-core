package limenora

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	sdk "github.com/axisvela/LIMENORA-open/sdk/go/v3"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

var _ tool.Gateway = Gateway{}

type fakeNetwork struct {
	request sdk.GatewayRequest
	result  *sdk.GatewayResult
	err     error
}

func (f *fakeNetwork) Do(_ context.Context, request sdk.GatewayRequest) (*sdk.GatewayResult, error) {
	f.request = request
	return f.result, f.err
}

func TestGatewayRequiresClient(t *testing.T) {
	if _, err := (Gateway{}).Execute(context.Background(), "lookup", nil, ""); !errors.Is(err, ErrClientRequired) {
		t.Fatalf("got %v, want %v", err, ErrClientRequired)
	}
}

func TestGatewayUsesNetwork(t *testing.T) {
	network := &fakeNetwork{result: &sdk.GatewayResult{
		Status: 200,
		Body:   []byte(`{"status":"green"}`),
	}}
	gateway := Gateway{
		Client: network,
		Tools: map[string]Route{
			"lookup": {
				URL:         "https://api.example.com/status",
				Method:      "POST",
				Description: "Look up status",
				Headers:     map[string]string{"x-tenant": "acme"},
			},
		},
		Ctx: sdk.AuthzContext{TenantID: "acme", WorkspaceID: "default", ActorID: "agent-1"},
	}

	tools := tool.NewGatewayTools(gateway)
	if len(tools) != 1 || tools[0].Name() != "lookup" {
		t.Fatalf("tools = %#v", tools)
	}
	value, err := tools[0].Invoke(context.Background(), map[string]any{"key": "status"})
	if err != nil {
		t.Fatal(err)
	}
	output, ok := value.(map[string]any)
	if !ok || output["status"] != "green" {
		t.Fatalf("value = %#v", value)
	}
	if network.request.URL != "https://api.example.com/status" || network.request.Method != "POST" {
		t.Fatalf("request = %#v", network.request)
	}
	if network.request.Headers["x-tenant"] != "acme" {
		t.Fatalf("headers = %#v", network.request.Headers)
	}
	if network.request.Ctx.ActorID != "agent-1" {
		t.Fatalf("context = %#v", network.request.Ctx)
	}
	var body map[string]any
	if err := json.Unmarshal(network.request.Body, &body); err != nil || body["key"] != "status" {
		t.Fatalf("body = %s", network.request.Body)
	}
}

func TestGatewayUnknownTool(t *testing.T) {
	gateway := Gateway{Client: &fakeNetwork{}}
	if _, err := gateway.Execute(context.Background(), "missing", nil, ""); err == nil {
		t.Fatal("expected an error")
	}
}
