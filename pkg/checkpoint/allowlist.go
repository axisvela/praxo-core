package checkpoint

import (
	"encoding/json"
	"errors"
	"fmt"
	"sync"
)

// ErrTypeNotAllowed reports a payload type that is not registered in the
// allowlist.
var ErrTypeNotAllowed = errors.New("checkpoint: payload type not allowed")

// Envelope is the persisted form of an allowlisted payload.
type Envelope struct {
	Type string          `json:"type"`
	Data json.RawMessage `json:"data"`
}

// Allowlist maps explicit payload type names to constructors. It prevents
// deserializing arbitrary types from persisted state.
type Allowlist struct {
	mu        sync.RWMutex
	factories map[string]func() any
}

// NewAllowlist returns an empty allowlist.
func NewAllowlist() *Allowlist {
	return &Allowlist{factories: make(map[string]func() any)}
}

// Register adds one type constructor. Re-registering a name replaces it.
func (a *Allowlist) Register(name string, factory func() any) error {
	if name == "" {
		return errors.New("checkpoint: allowlist type name is required")
	}
	if factory == nil {
		return errors.New("checkpoint: allowlist factory is required")
	}
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.factories == nil {
		a.factories = make(map[string]func() any)
	}
	a.factories[name] = factory
	return nil
}

// Marshal wraps value in an envelope for an allowed type.
func (a *Allowlist) Marshal(name string, value any) ([]byte, error) {
	if !a.allowed(name) {
		return nil, fmt.Errorf("%w: %s", ErrTypeNotAllowed, name)
	}
	data, err := json.Marshal(value)
	if err != nil {
		return nil, err
	}
	return json.Marshal(Envelope{Type: name, Data: data})
}

// Unmarshal decodes an envelope only when its type is registered.
func (a *Allowlist) Unmarshal(data []byte) (any, error) {
	var envelope Envelope
	if err := json.Unmarshal(data, &envelope); err != nil {
		return nil, err
	}
	a.mu.RLock()
	factory, ok := a.factories[envelope.Type]
	a.mu.RUnlock()
	if !ok {
		return nil, fmt.Errorf("%w: %s", ErrTypeNotAllowed, envelope.Type)
	}
	target := factory()
	if target == nil {
		return nil, fmt.Errorf("checkpoint: factory for %s returned nil", envelope.Type)
	}
	if err := json.Unmarshal(envelope.Data, target); err != nil {
		return nil, err
	}
	return target, nil
}

func (a *Allowlist) allowed(name string) bool {
	a.mu.RLock()
	defer a.mu.RUnlock()
	_, ok := a.factories[name]
	return ok
}
