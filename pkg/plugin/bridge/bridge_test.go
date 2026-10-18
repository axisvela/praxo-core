package bridge

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/plugin"
)

type captureInvoker struct {
	service string
	method  string
	payload []byte
	reply   []byte
	err     error
	block   bool
}

func (c *captureInvoker) Invoke(ctx context.Context, service, method string, payload []byte) ([]byte, error) {
	c.service, c.method, c.payload = service, method, payload
	if c.block {
		<-ctx.Done()
		return nil, ctx.Err()
	}
	return c.reply, c.err
}

type failCodec struct{}

func (failCodec) Encode(any) ([]byte, error) { return nil, errors.New("encode boom") }
func (failCodec) Decode([]byte, any) error   { return errors.New("decode boom") }

func TestAdapterUsesContractIdentity(t *testing.T) {
	inv := &captureInvoker{reply: []byte(`{}`)}
	a := Adapter(inv, plugin.ToolProvider, WithPluginID("plugin-1"))

	wantRef := plugin.ServiceRef{Service: plugin.ToolProvider.Service, Version: plugin.ToolProvider.Version}
	if a.Contract != wantRef {
		t.Fatalf("contract = %+v, want %+v", a.Contract, wantRef)
	}
	if a.Provider.Kind != string(plugin.KindToolProvider) {
		t.Fatalf("provider kind = %q, want %q", a.Provider.Kind, plugin.KindToolProvider)
	}
	if _, err := a.Invoke(context.Background(), []byte(`{"x":1}`)); err != nil {
		t.Fatalf("invoke: %v", err)
	}
	if inv.service != plugin.ToolProvider.Service || inv.method != "invoke" {
		t.Fatalf("host call = %s.%s, want %s.invoke", inv.service, inv.method, plugin.ToolProvider.Service)
	}
}

func TestAdapterMethodOverride(t *testing.T) {
	inv := &captureInvoker{reply: []byte(`{}`)}
	a := Adapter(inv, plugin.ToolProvider, WithMethod("custom"))
	if _, err := a.Invoke(context.Background(), nil); err != nil {
		t.Fatal(err)
	}
	if inv.method != "custom" {
		t.Fatalf("method = %q, want custom", inv.method)
	}
}

func TestAdapterTimeout(t *testing.T) {
	inv := &captureInvoker{block: true}
	a := Adapter(inv, plugin.ToolProvider, WithTimeout(10*time.Millisecond))
	_, err := a.Invoke(context.Background(), nil)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("err = %v, want deadline exceeded", err)
	}
}

func TestAdapterNilInvoker(t *testing.T) {
	a := Adapter(nil, plugin.ToolProvider)
	_, err := a.Invoke(context.Background(), nil)
	var ce *plugin.CallError
	if !errors.As(err, &ce) || ce.Code() != plugin.CodeInternal {
		t.Fatalf("err = %v, want INTERNAL CallError", err)
	}
}

func TestHostInvokerAddsPluginID(t *testing.T) {
	h := &captureHost{}
	inv := HostInvoker{Host: h, PluginID: "plugin-1"}
	_, err := inv.Invoke(context.Background(), "svc", "method", []byte("x"))
	if err != nil {
		t.Fatal(err)
	}
	if h.pluginID != "plugin-1" || h.service != "svc" || h.method != "method" {
		t.Fatalf("host call = %+v", h)
	}
}

type captureHost struct {
	pluginID string
	service  string
	method   string
	payload  []byte
}

func (h *captureHost) Invoke(_ context.Context, pluginID, service, method string, payload []byte) ([]byte, error) {
	h.pluginID, h.service, h.method, h.payload = pluginID, service, method, payload
	return []byte(`{}`), nil
}

func TestJSONCodecRoundTrip(t *testing.T) {
	in := map[string]any{"a": "b"}
	raw, err := (JSONCodec{}).Encode(in)
	if err != nil {
		t.Fatal(err)
	}
	var out map[string]any
	if err := (JSONCodec{}).Decode(raw, &out); err != nil {
		t.Fatal(err)
	}
	if out["a"] != "b" {
		t.Fatalf("out = %+v", out)
	}
}

func TestCodecFailureSurfaces(t *testing.T) {
	codec := failCodec{}
	if _, err := codec.Encode(map[string]any{"x": 1}); err == nil {
		t.Fatal("expected encode error")
	}
	var out map[string]any
	if err := codec.Decode([]byte(`{}`), &out); err == nil {
		t.Fatal("expected decode error")
	}
}
