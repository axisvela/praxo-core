package tool

import (
	"context"
	"testing"
)

type fakeGateway struct{}

func (fakeGateway) Execute(_ context.Context, name string, input map[string]any, _ string) (any, error) {
	return name + ":" + input["value"].(string), nil
}
func (fakeGateway) ListTools() []GatewayInfo {
	return []GatewayInfo{{Name: "fs.list", Description: "list", Risk: "low"}}
}

func TestGatewayTools(t *testing.T) {
	tools := NewGatewayTools(fakeGateway{})
	if len(tools) != 1 || tools[0].Name() != "fs.list" {
		t.Fatalf("tools = %+v", tools)
	}
	value, err := tools[0].Invoke(context.Background(), map[string]any{"value": "ok"})
	if err != nil || value != "fs.list:ok" {
		t.Fatalf("value=%v err=%v", value, err)
	}
}
