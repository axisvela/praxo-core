package agent

import "time"

// StreamKind identifies a typed run-stream projection.
type StreamKind string

const (
	// StreamValues is a run-level state snapshot.
	StreamValues StreamKind = "values"
	// StreamUpdates reports incremental state changes.
	StreamUpdates StreamKind = "updates"
	// StreamMessages reports model messages.
	StreamMessages StreamKind = "messages"
	// StreamTasks reports tool-task lifecycle changes.
	StreamTasks StreamKind = "tasks"
	// StreamDebug reports internal diagnostics.
	StreamDebug StreamKind = "debug"
	// StreamCheckpoint reports a durable run checkpoint.
	StreamCheckpoint StreamKind = "checkpoint"
)

// StreamPart is one typed projection emitted by an agent run.
type StreamPart struct {
	RunID     string
	SessionID string
	Kind      StreamKind
	Step      int
	Data      any
	At        time.Time
}
