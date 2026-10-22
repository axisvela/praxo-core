// Package ecosystem provides AxisVela adapter skeletons for the PRAXO-CORE seams.
package ecosystem

import (
	"context"
	"errors"

	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/memory"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/retriever"
	"github.com/axisvela/praxo-core/v2/pkg/sandbox"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

// ErrNotConfigured is returned when an adapter callback is not set.
var ErrNotConfigured = errors.New("ecosystem: adapter is not configured")

// Model adapts a model backend to model.Model.
type Model struct {
	GenerateFunc func(context.Context, model.Request) (model.Response, error)
}

// Generate calls GenerateFunc.
func (m Model) Generate(ctx context.Context, req model.Request) (model.Response, error) {
	if m.GenerateFunc == nil {
		return model.Response{}, ErrNotConfigured
	}
	return m.GenerateFunc(ctx, req)
}

// Provider adapts a chat backend to model.Provider.
type Provider struct {
	ChatFunc       func([]model.Message) ([]model.Message, error)
	ChatStreamFunc func([]model.Message) (<-chan model.StreamEvent, error)
}

// Chat calls ChatFunc.
func (p Provider) Chat(messages []model.Message) ([]model.Message, error) {
	if p.ChatFunc == nil {
		return nil, ErrNotConfigured
	}
	return p.ChatFunc(messages)
}

// ChatStream calls ChatStreamFunc.
func (p Provider) ChatStream(messages []model.Message) (<-chan model.StreamEvent, error) {
	if p.ChatStreamFunc == nil {
		return nil, ErrNotConfigured
	}
	return p.ChatStreamFunc(messages)
}

// Memory adapts a memory backend such as Mnemovela to memory.Store.
type Memory struct {
	PutFunc    func(context.Context, string, memory.Record) error
	SearchFunc func(context.Context, string, string, int) ([]memory.Record, error)
}

// Put calls PutFunc.
func (m Memory) Put(ctx context.Context, sessionID string, record memory.Record) error {
	if m.PutFunc == nil {
		return ErrNotConfigured
	}
	return m.PutFunc(ctx, sessionID, record)
}

// Search calls SearchFunc.
func (m Memory) Search(ctx context.Context, sessionID, query string, limit int) ([]memory.Record, error) {
	if m.SearchFunc == nil {
		return nil, ErrNotConfigured
	}
	return m.SearchFunc(ctx, sessionID, query, limit)
}

// Events adapts an event backend such as Harmovela to event.Sink.
type Events struct {
	EmitFunc func(context.Context, event.Event) error
}

// Emit calls EmitFunc.
func (e Events) Emit(ctx context.Context, ev event.Event) error {
	if e.EmitFunc == nil {
		return ErrNotConfigured
	}
	return e.EmitFunc(ctx, ev)
}

// Retriever adapts a retrieval backend such as GNOSIVELA to retriever.Retriever.
type Retriever struct {
	RetrieveFunc func(context.Context, string, int) ([]retriever.Document, error)
}

// Retrieve calls RetrieveFunc.
func (r Retriever) Retrieve(ctx context.Context, query string, limit int) ([]retriever.Document, error) {
	if r.RetrieveFunc == nil {
		return nil, ErrNotConfigured
	}
	return r.RetrieveFunc(ctx, query, limit)
}

// Policy adapts an authorization backend such as AEGIVELA to policy.Hook.
type Policy struct {
	AuthorizeFunc func(context.Context, policy.Action) (policy.Decision, error)
}

// Authorize calls AuthorizeFunc.
func (p Policy) Authorize(ctx context.Context, action policy.Action) (policy.Decision, error) {
	if p.AuthorizeFunc == nil {
		return policy.Decision{}, ErrNotConfigured
	}
	return p.AuthorizeFunc(ctx, action)
}

// Sandbox adapts an execution backend such as Vulcan Forge to sandbox.Sandbox.
type Sandbox struct {
	RunFunc func(context.Context, sandbox.Spec, []string) (sandbox.Result, error)
}

// Run calls RunFunc.
func (s Sandbox) Run(ctx context.Context, spec sandbox.Spec, command []string) (sandbox.Result, error) {
	if s.RunFunc == nil {
		return sandbox.Result{}, ErrNotConfigured
	}
	return s.RunFunc(ctx, spec, command)
}

// Interpreter adapts an in-process runtime to sandbox.Interpreter.
type Interpreter struct {
	EvalFunc func(context.Context, string) (any, error)
}

// Eval calls EvalFunc.
func (i Interpreter) Eval(ctx context.Context, script string) (any, error) {
	if i.EvalFunc == nil {
		return nil, ErrNotConfigured
	}
	return i.EvalFunc(ctx, script)
}

// Gateway adapts an external gateway such as Janus to tool.Gateway.
type Gateway struct {
	ExecuteFunc   func(context.Context, string, map[string]any, string) (any, error)
	ListToolsFunc func() []tool.GatewayInfo
}

// Execute calls ExecuteFunc.
func (g Gateway) Execute(ctx context.Context, name string, input map[string]any, token string) (any, error) {
	if g.ExecuteFunc == nil {
		return nil, ErrNotConfigured
	}
	return g.ExecuteFunc(ctx, name, input, token)
}

// ListTools calls ListToolsFunc.
func (g Gateway) ListTools() []tool.GatewayInfo {
	if g.ListToolsFunc == nil {
		return nil
	}
	return g.ListToolsFunc()
}
