package plugin

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"sync"
)

// ServiceRef identifies a service seam by contract+version only.
type ServiceRef struct {
	Service string
	Version string
}

// String returns the canonical "<service>.<version>" form.
func (s ServiceRef) String() string { return s.Service + "." + s.Version }

// AdapterInvoke is the guarded invocation an adapter exposes: context plus an
// opaque payload in, an opaque payload out. The registry stores only this
// after wrapping it with the required governance middleware.
//
// Note: registry.go deliberately does not reuse the host-oriented InvokeFunc
// from contracts.go (which carries pluginID/service/method); this narrower
// shape is what middleware composes over.
type AdapterInvoke func(context.Context, []byte) ([]byte, error)

// Middleware wraps an adapter invocation. Composing middleware is how a
// governance plane (policy, trace, network, sandbox) intercepts every call; a
// nil Middleware is a missing plane.
type Middleware func(AdapterInvoke) AdapterInvoke

// GuardSet declares the concrete middleware wiring for an adapter. A plane
// left nil is treated as absent and is rejected wherever the per-kind matrix
// requires it.
type GuardSet struct {
	Policy  Middleware
	Trace   Middleware
	Network Middleware
	Sandbox Middleware
}

// ProviderIdentity is the non-empty identity a provider adapter must present.
type ProviderIdentity struct {
	ID      string
	Kind    string
	Version string
}

// Adapter is a provider adapter bound to a service contract. It carries its
// identity and a base invocation; Register composes the base invocation with
// the required guards and stores only the wrapped result.
type Adapter struct {
	Contract ServiceRef
	Name     string
	Provider ProviderIdentity
	Invoke   AdapterInvoke
}

// GuardSet field order is the deterministic invocation order: an outermost
// Policy wraps Trace, which wraps Network, which wraps Sandbox, which wraps
// the adapter's base invoke.

// AdapterRegistry binds provider adapters to service contracts by exact
// contract+version. The runtime never resolves service versions at call time:
// a plugin declares an exact contract+version and the registry binds it or
// reports absence. Registration is only reachable through Register, which
// requires a concrete GuardSet; there is no bare (unguarded) door.
type AdapterRegistry struct {
	mu      sync.RWMutex
	entries map[ServiceRef]Adapter
}

// NewAdapterRegistry returns an empty registry.
func NewAdapterRegistry() *AdapterRegistry {
	return &AdapterRegistry{entries: make(map[ServiceRef]Adapter)}
}

// guardRequirement says which planes the five-kind matrix demands.
type guardRequirement struct {
	policy, trace, sandbox bool
}

// requirementFor maps a canonical kind to its mandatory governance planes.
// Network is optional: no kind requires it, and nothing records it yet; when a
// Network middleware is supplied it is applied like any other plane. Unknown
// kinds report false.
func requirementFor(k Kind) (guardRequirement, bool) {
	switch k {
	case KindToolProvider, KindSandboxProvider:
		return guardRequirement{policy: true, trace: true, sandbox: true}, true
	case KindModelProvider, KindMemoryProvider:
		return guardRequirement{policy: true, trace: true}, true
	case KindPolicyProvider:
		return guardRequirement{trace: true}, true
	default:
		return guardRequirement{}, false
	}
}

// Register binds an adapter to its canonical contract after validating and
// applying the required guards. It rejects unknown or noncanonical contracts
// (including split refs whose concatenation merely collides with a canonical
// kind), empty or kind-mismatched provider identity, a nil base invoke,
// missing required middleware, and duplicate bindings. Only the wrapped
// invocation is stored: there is no bare registration path.
func (r *AdapterRegistry) Register(a Adapter, guards GuardSet) error {
	if a.Contract.Service == "" || a.Contract.Version == "" {
		return fmt.Errorf("pluginrt: adapter contract must carry service and version")
	}
	kind := Kind(a.Contract.String())
	c, ok := Lookup(kind)
	if !ok {
		return fmt.Errorf("pluginrt: unknown contract %s", a.Contract)
	}
	if a.Contract.Service != c.Service || a.Contract.Version != c.Version {
		return fmt.Errorf("pluginrt: noncanonical contract %s (want %s.%s)", a.Contract, c.Service, c.Version)
	}
	if a.Provider.ID == "" || a.Provider.Kind == "" || a.Provider.Version == "" {
		return fmt.Errorf("pluginrt: adapter %s must carry a complete provider identity", a.Contract)
	}
	if a.Provider.Kind != string(kind) {
		return fmt.Errorf("pluginrt: provider %q declares kind %q, contract is %q", a.Provider.ID, a.Provider.Kind, kind)
	}
	req, reqOK := requirementFor(kind)
	if !reqOK {
		return fmt.Errorf("pluginrt: unknown contract %s", a.Contract)
	}
	if err := checkGuards(a.Contract, req, guards); err != nil {
		return err
	}
	if a.Invoke == nil {
		return fmt.Errorf("pluginrt: adapter %s must carry a non-nil invoke", a.Contract)
	}

	stored := a
	stored.Invoke = applyGuards(guards, a.Invoke)

	r.mu.Lock()
	defer r.mu.Unlock()
	if _, exists := r.entries[a.Contract]; exists {
		return fmt.Errorf("pluginrt: adapter already bound to %s", a.Contract)
	}
	r.entries[a.Contract] = stored
	return nil
}

// checkGuards fails closed when a required plane has no concrete middleware.
func checkGuards(ref ServiceRef, req guardRequirement, g GuardSet) error {
	var missing []string
	if req.policy && g.Policy == nil {
		missing = append(missing, "policy")
	}
	if req.trace && g.Trace == nil {
		missing = append(missing, "trace")
	}
	if req.sandbox && g.Sandbox == nil {
		missing = append(missing, "sandbox")
	}
	if len(missing) > 0 {
		return fmt.Errorf("pluginrt: %s missing required %s middleware", ref, strings.Join(missing, ", "))
	}
	return nil
}

// applyGuards composes middleware innermost-first so invocation order is
// policy -> trace -> network -> sandbox -> base (deterministic, observable).
func applyGuards(g GuardSet, base AdapterInvoke) AdapterInvoke {
	wrapped := base
	if g.Sandbox != nil {
		wrapped = g.Sandbox(wrapped)
	}
	if g.Network != nil {
		wrapped = g.Network(wrapped)
	}
	if g.Trace != nil {
		wrapped = g.Trace(wrapped)
	}
	if g.Policy != nil {
		wrapped = g.Policy(wrapped)
	}
	return wrapped
}

// Unregister removes the adapter bound to the exact contract+version and
// reports whether a binding was present. It is the reversible counterpart of
// Register: a torn-down plugin frees its contract so a later generation (or a
// fresh install) can bind it again. An absent binding is a no-op.
func (r *AdapterRegistry) Unregister(service, version string) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	ref := ServiceRef{Service: service, Version: version}
	if _, ok := r.entries[ref]; !ok {
		return false
	}
	delete(r.entries, ref)
	return true
}

// List returns the registered contract+version pairs, optionally filtered to
// the given services. The result is sorted for determinism.
func (r *AdapterRegistry) List(services ...string) []ServiceRef {
	r.mu.RLock()
	defer r.mu.RUnlock()
	filter := make(map[string]bool, len(services))
	for _, s := range services {
		filter[s] = true
	}
	out := make([]ServiceRef, 0, len(r.entries))
	for ref := range r.entries {
		if len(filter) > 0 && !filter[ref.Service] {
			continue
		}
		out = append(out, ref)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].String() < out[j].String() })
	return out
}

// Bind returns the adapter registered for the exact contract+version. It
// performs no version negotiation or resolution.
func (r *AdapterRegistry) Bind(service, version string) (Adapter, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	a, ok := r.entries[ServiceRef{Service: service, Version: version}]
	return a, ok
}

// SelectedBundle pins one plugin bundle by version and digest.
type SelectedBundle struct {
	BundleID string
	Version  string
	Digest   string
}

// ResolutionLock is the deterministic result of a control-plane resolution.
// The runtime never resolves requirements itself: it materializes the lock it
// is handed.
type ResolutionLock struct {
	LockID   string
	Selected []SelectedBundle
}

// PluginInfo is immutable plugin metadata surfaced by the manager.
type PluginInfo struct {
	PluginID     string
	Version      string
	State        State
	Capabilities []string
}

// PluginManager is the L5 runtime-plugin management contract. It deliberately
// exposes no Resolve: requirement resolution lives on the control plane, so
// plugins are materialized from a ResolutionLock rather than resolved by the
// runtime.
type PluginManager interface {
	// Materialize instantiates the plugin bundles pinned by a control-plane
	// ResolutionLock.
	Materialize(ctx context.Context, lock ResolutionLock) error
	// Enable transitions an installed instance to ACTIVE.
	Enable(ctx context.Context, pluginID string) error
	// Disable disposes the plugin's scope and stops the instance.
	Disable(ctx context.Context, pluginID string) error
	// Revoke tears down an instance through DRAINING -> STOPPED -> UNLOADED.
	Revoke(ctx context.Context, pluginID string) error
	// Uninstall removes a stopped, unloaded plugin entirely.
	Uninstall(ctx context.Context, pluginID string) error
	// Invoke mediates a call into a plugin, verifying ACTIVE state and the
	// required capability before dispatch.
	Invoke(ctx context.Context, pluginID string, service string, method string, payload []byte) ([]byte, error)
	// State reports the lifecycle state of a plugin instance.
	State(pluginID string) (State, error)
	// List returns installed plugin metadata.
	List() []PluginInfo
}
