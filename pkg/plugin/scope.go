package plugin

import (
	"fmt"
	"sync"
)

// Disposer is a registration owned by a plugin scope. The scope invokes
// disposers in LIFO order exactly once when it is disposed.
type Disposer func()

// Scope is the per-plugin child scope that owns the disposers of one plugin
// instance. Disabling, revoking, crashing, or uninstalling the plugin disposes
// the scope as one unit; Dispose is idempotent.
//
// Disposers are never invoked while holding the scope lock: Dispose snapshots
// the registrations and marks the scope disposed under the lock, then runs the
// disposers afterwards. A disposer may therefore call Add, Dispose, or
// Disposed reentrantly without deadlocking.
type Scope struct {
	mu        sync.Mutex
	pluginID  string
	disposers []Disposer
	disposed  bool
}

// NewScope returns a child scope owned by the named plugin.
func NewScope(pluginID string) *Scope {
	return &Scope{pluginID: pluginID}
}

// PluginID returns the plugin that owns this scope.
func (s *Scope) PluginID() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.pluginID
}

// Add registers a disposer. If the scope has already been disposed, the
// disposer is invoked immediately, outside the lock.
func (s *Scope) Add(d Disposer) {
	s.mu.Lock()
	if s.disposed {
		s.mu.Unlock()
		d()
		return
	}
	s.disposers = append(s.disposers, d)
	s.mu.Unlock()
}

// Dispose invokes every registered disposer exactly once, in LIFO order
// (reverse of registration), then clears the scope. Subsequent calls are
// no-ops that return nil.
//
// Disposers run outside the lock and are panic-contained: if one disposer
// panics, the remaining disposers still run and the first failure is returned
// as an error rather than aborting the teardown.
func (s *Scope) Dispose() error {
	s.mu.Lock()
	if s.disposed {
		s.mu.Unlock()
		return nil
	}
	s.disposed = true
	disposers := s.disposers
	s.disposers = nil
	s.mu.Unlock()

	var first error
	for i := len(disposers) - 1; i >= 0; i-- {
		func() {
			defer func() {
				if r := recover(); r != nil && first == nil {
					first = fmt.Errorf("pluginrt: disposer panic: %v", r)
				}
			}()
			disposers[i]()
		}()
	}
	return first
}

// Disposed reports whether the scope has been disposed.
func (s *Scope) Disposed() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.disposed
}
