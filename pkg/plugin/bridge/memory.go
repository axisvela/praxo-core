package bridge

import (
	"context"

	"github.com/axisvela/praxo-core/v2/pkg/memory"
	"github.com/axisvela/praxo-core/v2/pkg/plugin"
)

type memoryAccessRequest struct {
	Operation string         `json:"operation"`
	SessionID string         `json:"sessionID"`
	Record    *memory.Record `json:"record,omitempty"`
	Query     string         `json:"query,omitempty"`
	Limit     int            `json:"limit,omitempty"`
}

type memoryAccessResponse struct {
	Record  *memory.Record  `json:"record,omitempty"`
	Records []memory.Record `json:"records,omitempty"`
}

// Memory adapts a memory.provider.v1 host to memory.Store.
type Memory struct{ caller }

// NewMemory returns a memory bridge.
func NewMemory(inv Invoker, contract plugin.Contract, opts ...Option) *Memory {
	return &Memory{caller: newCaller(inv, contract, opts...)}
}

// Put implements memory.Store.
func (m *Memory) Put(ctx context.Context, sessionID string, record memory.Record) error {
	var out memoryAccessResponse
	return m.request(ctx, memoryAccessRequest{
		Operation: "put",
		SessionID: sessionID,
		Record:    &record,
	}, &out)
}

// Search implements memory.Store.
func (m *Memory) Search(ctx context.Context, sessionID, query string, limit int) ([]memory.Record, error) {
	var out memoryAccessResponse
	err := m.request(ctx, memoryAccessRequest{
		Operation: "search",
		SessionID: sessionID,
		Query:     query,
		Limit:     limit,
	}, &out)
	return out.Records, err
}
