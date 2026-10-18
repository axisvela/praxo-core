package bridge

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/memory"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/plugin"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/sandbox"
)

func TestToolRoundTrip(t *testing.T) {
	inv := &captureInvoker{reply: []byte(`{"result":1}`)}
	tool := NewTool(inv, plugin.ToolProvider, WithToolIdentity("search", "find things"))

	if tool.Name() != "search" || tool.Description() != "find things" {
		t.Fatalf("identity = %q/%q", tool.Name(), tool.Description())
	}
	got, err := tool.Invoke(context.Background(), map[string]any{"q": "x"})
	if err != nil {
		t.Fatal(err)
	}
	var req struct {
		Name      string         `json:"name"`
		Arguments map[string]any `json:"arguments"`
	}
	if err := json.Unmarshal(inv.payload, &req); err != nil {
		t.Fatal(err)
	}
	if req.Name != "search" || req.Arguments["q"] != "x" {
		t.Fatalf("request = %+v", req)
	}
	m, ok := got.(map[string]any)
	if !ok || m["result"].(float64) != 1 {
		t.Fatalf("result = %#v", got)
	}
}

func TestToolFallsBackToRawString(t *testing.T) {
	inv := &captureInvoker{reply: []byte(`not-json`)}
	tool := NewTool(inv, plugin.ToolProvider, WithToolIdentity("search", ""))
	got, err := tool.Invoke(context.Background(), nil)
	if err != nil {
		t.Fatal(err)
	}
	if got != "not-json" {
		t.Fatalf("result = %#v, want raw string", got)
	}
}

func TestModelRoundTrip(t *testing.T) {
	inv := &captureInvoker{reply: []byte(`{"message":{"role":"assistant","content":"hi"}}`)}
	m := NewModel(inv, plugin.ModelProvider)
	resp, err := m.Generate(context.Background(), model.Request{Model: "m"})
	if err != nil {
		t.Fatal(err)
	}
	if resp.Message.Content != "hi" {
		t.Fatalf("response = %+v", resp)
	}
	if inv.method != "generate" {
		t.Fatalf("method = %q, want generate", inv.method)
	}
}

func TestPolicyRoundTrip(t *testing.T) {
	inv := &captureInvoker{reply: []byte(`{"allowed":true,"reason":"ok"}`)}
	p := NewPolicy(inv, plugin.PolicyProvider)
	decision, err := p.Authorize(context.Background(), policy.Action{Kind: "tool"})
	if err != nil {
		t.Fatal(err)
	}
	if !decision.Allowed || decision.Reason != "ok" {
		t.Fatalf("decision = %+v", decision)
	}
	if inv.method != "evaluate" {
		t.Fatalf("method = %q, want evaluate", inv.method)
	}
}

func TestMemoryRoundTrip(t *testing.T) {
	inv := &captureInvoker{reply: []byte(`{"records":[{"id":"m1","frame":"event","content":"x"}]}`)}
	store := NewMemory(inv, plugin.MemoryProvider)

	recs, err := store.Search(context.Background(), "s1", "q", 3)
	if err != nil {
		t.Fatal(err)
	}
	if len(recs) != 1 || recs[0].ID != "m1" {
		t.Fatalf("records = %+v", recs)
	}
	var req map[string]any
	if err := json.Unmarshal(inv.payload, &req); err != nil {
		t.Fatal(err)
	}
	if req["operation"] != "search" || req["sessionID"] != "s1" || req["query"] != "q" {
		t.Fatalf("request = %+v", req)
	}
}

func TestMemoryPut(t *testing.T) {
	inv := &captureInvoker{reply: []byte(`{}`)}
	store := NewMemory(inv, plugin.MemoryProvider)
	err := store.Put(context.Background(), "s1", memory.Record{ID: "m1", Content: "x"})
	if err != nil {
		t.Fatal(err)
	}
	var req map[string]any
	if err := json.Unmarshal(inv.payload, &req); err != nil {
		t.Fatal(err)
	}
	if req["operation"] != "put" {
		t.Fatalf("request = %+v", req)
	}
}

func TestSandboxRoundTrip(t *testing.T) {
	inv := &captureInvoker{reply: []byte(`{"exitCode":0,"stdout":"ok"}`)}
	s := NewSandbox(inv, plugin.SandboxProvider)
	res, err := s.Run(context.Background(), sandbox.Spec{Image: "img"}, []string{"echo", "ok"})
	if err != nil {
		t.Fatal(err)
	}
	if res.ExitCode != 0 || res.Stdout != "ok" {
		t.Fatalf("result = %+v", res)
	}
	if inv.method != "execute" {
		t.Fatalf("method = %q, want execute", inv.method)
	}
}

func TestEncodeFailureIsInvalidRequest(t *testing.T) {
	inv := &captureInvoker{}
	tool := NewTool(inv, plugin.ToolProvider, WithCodec(failCodec{}))
	_, err := tool.Invoke(context.Background(), map[string]any{"x": 1})
	var ce *plugin.CallError
	if !errors.As(err, &ce) || ce.Code() != plugin.CodeInvalidRequest {
		t.Fatalf("err = %v, want INVALID_REQUEST CallError", err)
	}
}

func TestDecodeFailureIsInternal(t *testing.T) {
	inv := &captureInvoker{reply: []byte(`{`)}
	m := NewModel(inv, plugin.ModelProvider)
	_, err := m.Generate(context.Background(), model.Request{})
	var ce *plugin.CallError
	if !errors.As(err, &ce) || ce.Code() != plugin.CodeInternal {
		t.Fatalf("err = %v, want INTERNAL CallError", err)
	}
}

func TestHostErrorPassthrough(t *testing.T) {
	sentinel := plugin.NewCallError(plugin.CodeCapabilityDenied, "p", "s", "m", "denied")
	inv := &captureInvoker{err: sentinel}
	p := NewPolicy(inv, plugin.PolicyProvider)
	_, err := p.Authorize(context.Background(), policy.Action{})
	if err != sentinel {
		t.Fatalf("err = %v, want the original host error", err)
	}
}
