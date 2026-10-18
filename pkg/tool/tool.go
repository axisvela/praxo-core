// Package tool defines governed tool contracts and an in-memory registry.
package tool

import (
	"context"
	"errors"
	"sort"
	"sync"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

// ErrNotFound is returned when a tool is not registered.
var ErrNotFound = errors.New("tool not found")

// Tool is one invokable capability.
type Tool interface {
	Name() string
	Description() string
	Invoke(ctx context.Context, args map[string]any) (any, error)
}

// Registry stores tools by name.
type Registry struct {
	mu    sync.RWMutex
	tools map[string]Tool
}

// NewRegistry returns an empty registry.
func NewRegistry() *Registry {
	return &Registry{tools: map[string]Tool{}}
}

// Register adds or replaces a tool.
func (r *Registry) Register(t Tool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.tools[t.Name()] = t
}

// Get returns a tool by name.
func (r *Registry) Get(name string) (Tool, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	t, ok := r.tools[name]
	if !ok {
		return nil, ErrNotFound
	}
	return t, nil
}

// Specs returns model-visible tool specifications.
func (r *Registry) Specs() []model.ToolSpec {
	r.mu.RLock()
	defer r.mu.RUnlock()
	out := make([]model.ToolSpec, 0, len(r.tools))
	for _, t := range r.tools {
		if provider, ok := t.(SpecProvider); ok {
			out = append(out, provider.Spec())
			continue
		}
		out = append(out, model.ToolSpec{Name: t.Name(), Description: t.Description()})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	return out
}
