package tool

import (
	"context"
	"testing"

	"github.com/axisvela/praxo-core/pkg/model"
)

type echoTool struct{ name string }

func (e echoTool) Name() string        { return e.name }
func (e echoTool) Description() string { return "echo" }
func (e echoTool) Spec() model.ToolSpec {
	return model.ToolSpec{Name: e.name, Description: "echo", Risk: "low", Parameters: map[string]any{"type": "object"}}
}
func (e echoTool) Invoke(_ context.Context, args map[string]any) (any, error) { return args, nil }

func TestRegistrySpecsUseSpecProvider(t *testing.T) {
	r := NewRegistry()
	r.Register(echoTool{name: "echo"})
	specs := r.Specs()
	if len(specs) != 1 || specs[0].Risk != "low" || specs[0].Parameters == nil {
		t.Fatalf("specs = %+v", specs)
	}
}

func TestWrapMiddleware(t *testing.T) {
	called := false
	mw := MiddlewareFunc("wrapped", "wrapped tool", func(_ context.Context, args map[string]any) (any, error) {
		called = true
		return args["value"], nil
	})
	wrapped := Wrap(echoTool{name: "echo"}, mw)
	if wrapped.Name() != "wrapped" {
		t.Fatalf("name = %q", wrapped.Name())
	}
	value, err := wrapped.Invoke(context.Background(), map[string]any{"value": "ok"})
	if err != nil || value != "ok" || !called {
		t.Fatalf("value=%v err=%v called=%v", value, err, called)
	}
}
