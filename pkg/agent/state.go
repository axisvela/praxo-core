package agent

import "context"

// SessionStore persists portable session state. Implementations may add
// product-specific columns, but must round-trip the fields on Session.
type SessionStore interface {
	Load(ctx context.Context, sessionID string) (*Session, error)
	Save(ctx context.Context, session *Session) error
}
