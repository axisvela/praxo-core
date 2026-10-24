// Package contract defines the provider-neutral workspace/session evaluation
// contract. It is not part of pkg/ and must not be promoted until at least two
// provider adapters fit without provider-specific fields.
package contract

import (
	"context"
	"errors"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/sandbox"
	"github.com/axisvela/praxo-core/v2/pkg/vfs"
)

var (
	// ErrNotSupported reports a capability the provider does not implement.
	ErrNotSupported = errors.New("workspace: not supported")
	// ErrNotFound reports a missing session.
	ErrNotFound = errors.New("workspace: session not found")
	// ErrClosed reports an operation on a closed session.
	ErrClosed = errors.New("workspace: session closed")
)

// Spec describes one workspace session request.
type Spec struct {
	Image    string
	WorkDir  string
	Env      map[string]string
	Timeout  time.Duration
	Metadata map[string]string
}

// Session combines the existing VFS and sandbox seams with session lifecycle
// and file transfer.
type Session interface {
	ID() string
	sandbox.Sandbox
	vfs.Backend
	Upload(ctx context.Context, path string, data []byte) error
	Download(ctx context.Context, path string) ([]byte, error)
	Close(ctx context.Context) error
}

// Provider creates or attaches to workspace sessions.
type Provider interface {
	Create(ctx context.Context, spec Spec) (Session, error)
	Attach(ctx context.Context, id string) (Session, error)
}

// Pauser is an optional session capability.
type Pauser interface {
	Pause(ctx context.Context) error
	Resume(ctx context.Context) error
}

// Snapshotter is an optional session capability.
type Snapshotter interface {
	Snapshot(ctx context.Context) (string, error)
}
