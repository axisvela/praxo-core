// Package event defines the framework event boundary.
package event

import (
	"context"
	"time"
)

// Event is one agent lifecycle event.
type Event struct {
	Type      string         `json:"type"`
	SessionID string         `json:"sessionId"`
	RunID     string         `json:"runId,omitempty"`
	Data      map[string]any `json:"data,omitempty"`
	At        time.Time      `json:"at"`
}

// Sink receives events. Implementations may publish to Harmovela.
type Sink interface {
	Emit(ctx context.Context, event Event) error
}

// FuncSink adapts a function to a Sink.
type FuncSink func(context.Context, Event) error

// Emit implements Sink.
func (f FuncSink) Emit(ctx context.Context, event Event) error { return f(ctx, event) }
