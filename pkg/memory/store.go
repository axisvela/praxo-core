package memory

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

type storedRecord struct {
	record Record
	search string
}

// MemoryStore is an in-memory Store for local tests and embedded use.
type MemoryStore struct {
	mu      sync.RWMutex
	records map[string][]storedRecord
	seq     atomic.Uint64
}

// NewMemoryStore returns an empty memory store.
func NewMemoryStore() *MemoryStore {
	return &MemoryStore{records: map[string][]storedRecord{}}
}

// Put appends a record for a session.
func (s *MemoryStore) Put(_ context.Context, sessionID string, record Record) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.records == nil {
		s.records = map[string][]storedRecord{}
	}
	if record.ID == "" {
		record.ID = fmt.Sprintf("mem-%d-%d", time.Now().UnixNano(), s.seq.Add(1))
	}
	if record.CreatedAt.IsZero() {
		record.CreatedAt = time.Now().UTC()
	}
	s.records[sessionID] = append(s.records[sessionID], storedRecord{
		record: record,
		search: strings.ToLower(record.Content),
	})
	return nil
}

// Search returns matching records, newest first.
func (s *MemoryStore) Search(_ context.Context, sessionID, query string, limit int) ([]Record, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	query = strings.ToLower(strings.TrimSpace(query))
	out := make([]Record, 0)
	for _, item := range s.records[sessionID] {
		if query == "" || strings.Contains(item.search, query) {
			out = append(out, item.record)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.After(out[j].CreatedAt) })
	if limit > 0 && len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

// ContextAssembler retrieves context for one task.
type ContextAssembler struct {
	Store Store
	Limit int
}

// Assemble returns query-relevant memory for a session.
func (a ContextAssembler) Assemble(ctx context.Context, sessionID, query string) ([]Record, error) {
	if a.Store == nil {
		return nil, nil
	}
	limit := a.Limit
	if limit <= 0 {
		limit = 8
	}
	return a.Store.Search(ctx, sessionID, query, limit)
}
