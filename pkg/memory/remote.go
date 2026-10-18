package memory

import "context"

// Backend is a remote memory backend such as Mnemovela.
type Backend interface {
	Commit(ctx context.Context, sessionID string, record Record) error
	Search(ctx context.Context, sessionID, query string, limit int) ([]Record, error)
}

// RemoteStore adapts a Backend to the Store interface.
type RemoteStore struct {
	Backend Backend
}

// Put implements Store.
func (s RemoteStore) Put(ctx context.Context, sessionID string, record Record) error {
	if s.Backend == nil {
		return nil
	}
	return s.Backend.Commit(ctx, sessionID, record)
}

// Search implements Store.
func (s RemoteStore) Search(ctx context.Context, sessionID, query string, limit int) ([]Record, error) {
	if s.Backend == nil {
		return nil, nil
	}
	return s.Backend.Search(ctx, sessionID, query, limit)
}
