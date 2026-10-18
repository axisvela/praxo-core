// Package checkpoint defines durable execution snapshots and the store
// contract used to resume a run without re-applying committed effects.
package checkpoint

import (
	"context"
	"time"
)

// Message is a serializable message within a session snapshot.
type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
	// ContentBlocks carries multimodal content blocks verbatim. Typed as any
	// to avoid a dependency from this package on a model contract; it is
	// JSON-serializable.
	ContentBlocks any `json:"content_blocks,omitempty"`
}

// RunSnapshot is a serializable projection of an in-memory run.
// Channels/context are process-local and excluded.
type RunSnapshot struct {
	ID        string    `json:"id"`
	SessionID string    `json:"session_id"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
}

// EffectCursor identifies the last committed effect for a run.
type EffectCursor struct {
	RunID         string `json:"run_id"`
	LastEffectID  string `json:"last_effect_id"`
	LastCreatedAt int64  `json:"last_created_at"`
}

// Checkpoint is a durable execution snapshot.
type Checkpoint struct {
	ID              string        `json:"id"`
	SessionID       string        `json:"session_id"`
	RunID           string        `json:"run_id"`
	Version         int           `json:"version"`
	Title           string        `json:"title,omitempty"`
	ModelID         string        `json:"model_id,omitempty"`
	Status          string        `json:"status"`
	TenantID        string        `json:"tenant_id,omitempty"`
	WorkspaceID     string        `json:"workspace_id,omitempty"`
	ParentSessionID string        `json:"parent_session_id,omitempty"`
	ParentRunID     string        `json:"parent_run_id,omitempty"`
	AgentID         string        `json:"agent_id,omitempty"`
	Messages        []Message     `json:"messages,omitempty"`
	Runs            []RunSnapshot `json:"runs,omitempty"`
	EffectCursor    *EffectCursor `json:"effect_cursor,omitempty"`
	CreatedAt       time.Time     `json:"created_at"`
}

// RecoveryReport describes the outcome of a recovery attempt.
type RecoveryReport struct {
	CheckpointID   string        `json:"checkpoint_id"`
	SessionID      string        `json:"session_id"`
	RunID          string        `json:"run_id"`
	Restored       bool          `json:"restored"`
	MessageCount   int           `json:"message_count"`
	CursorVerified bool          `json:"cursor_verified"`
	Cursor         *EffectCursor `json:"cursor,omitempty"`
	Reason         string        `json:"reason,omitempty"`
}

// Store persists checkpoints.
type Store interface {
	// Save persists a checkpoint. Saving over the same (sessionID, runID) replaces it.
	Save(ctx context.Context, cp *Checkpoint) error
	// Load returns the latest checkpoint for a session (by CreatedAt desc). (nil, nil) if none.
	Load(ctx context.Context, sessionID string) (*Checkpoint, error)
	// LoadScoped is Load restricted to a tenant. An empty tenantID applies no
	// filter.
	LoadScoped(ctx context.Context, tenantID, sessionID string) (*Checkpoint, error)
	// LoadRun returns the latest checkpoint for a specific run. (nil, nil) if none.
	LoadRun(ctx context.Context, runID string) (*Checkpoint, error)
	// LoadRunScoped is LoadRun restricted to a tenant. An empty tenantID
	// applies no filter.
	LoadRunScoped(ctx context.Context, tenantID, runID string) (*Checkpoint, error)
	// List returns all checkpoints for a session, newest first.
	List(ctx context.Context, sessionID string) ([]Checkpoint, error)
	// Delete removes a checkpoint by ID.
	Delete(ctx context.Context, checkpointID string) error
}
