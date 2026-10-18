// Package memory defines the framework's memory and context boundary.
package memory

import (
	"context"
	"time"
)

// Frame is a typed memory frame.
type Frame string

// Memory frame kinds.
const (
	FrameEvent          Frame = "event"
	FrameDecision       Frame = "decision"
	FrameExperience     Frame = "experience"
	FrameProcedure      Frame = "procedure"
	FrameWorkspaceState Frame = "workspace_state"
	FrameConstraint     Frame = "constraint"
	FrameIntention      Frame = "intention"
)

// Record is one memory entry.
type Record struct {
	ID        string         `json:"id"`
	Frame     Frame          `json:"frame"`
	Content   string         `json:"content"`
	Metadata  map[string]any `json:"metadata,omitempty"`
	CreatedAt time.Time      `json:"createdAt"`
}

// Store is the memory boundary. Implementations may wrap Mnemovela.
type Store interface {
	Put(ctx context.Context, sessionID string, record Record) error
	Search(ctx context.Context, sessionID, query string, limit int) ([]Record, error)
}
