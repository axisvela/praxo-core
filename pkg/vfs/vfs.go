// Package vfs defines a virtual filesystem backend contract and filesystem
// result types used by framework tools.
package vfs

import (
	"context"
	"errors"
	"time"
)

// ErrNotFound reports a missing path.
var ErrNotFound = errors.New("vfs: not found")

// ErrUnsupported reports an operation the backend does not implement.
var ErrUnsupported = errors.New("vfs: unsupported operation")

// Entry describes one file or directory.
type Entry struct {
	Path    string    `json:"path"`
	Name    string    `json:"name"`
	Size    int64     `json:"size"`
	Mode    string    `json:"mode,omitempty"`
	IsDir   bool      `json:"isDir"`
	ModTime time.Time `json:"modTime"`
}

// Match is one grep match.
type Match struct {
	Path string `json:"path"`
	Line int    `json:"line"`
	Text string `json:"text"`
}

// Result is the outcome of an execute call.
type Result struct {
	ExitCode int    `json:"exitCode"`
	Stdout   string `json:"stdout"`
	Stderr   string `json:"stderr"`
}

// Backend is the virtual filesystem seam used by framework tools.
type Backend interface {
	Stat(ctx context.Context, path string) (Entry, error)
	Read(ctx context.Context, path string) ([]byte, error)
	Write(ctx context.Context, path string, data []byte) error
	List(ctx context.Context, path string) ([]Entry, error)
	Delete(ctx context.Context, path string, recursive bool) error
	Glob(ctx context.Context, pattern string) ([]string, error)
	Grep(ctx context.Context, pattern, path string) ([]Match, error)
}

// Executor is an optional backend capability for shell execution.
type Executor interface {
	Execute(ctx context.Context, command []string, dir string) (Result, error)
}
