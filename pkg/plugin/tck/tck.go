// Package tck provides conformance assertions for the plugin contract layer.
// Any implementation or composition of the lifecycle, adapter registry, and
// plugin host can be run through these checks to prove protocol-level behavior
// without depending on product governance.
package tck

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/plugin"
)

// CheckLifecycle asserts the canonical FETCHED->VALIDATED walk succeeds from a
// fresh lifecycle and leaves the machine in VALIDATED.
func CheckLifecycle(lc *plugin.Lifecycle) error {
	if lc.State() != plugin.StateFetched {
		return fmt.Errorf("tck: lifecycle must start FETCHED, got %s", lc.State())
	}
	if err := lc.Transit(plugin.StateValidated); err != nil {
		return fmt.Errorf("tck: FETCHED->VALIDATED failed: %w", err)
	}
	if lc.State() != plugin.StateValidated {
		return fmt.Errorf("tck: state after walk = %s, want VALIDATED", lc.State())
	}
	return nil
}

// CheckRegistry asserts every registered service contract resolves to exactly
// one adapter and that Bind round-trips for each listed reference. It also
// attests that each adapter carries a provider identity and a non-nil guarded
// invoke: a registry holding an ungated adapter is not conformant.
func CheckRegistry(r *plugin.AdapterRegistry) error {
	seen := map[string]string{}
	for _, ref := range r.List() {
		a, ok := r.Bind(ref.Service, ref.Version)
		if !ok {
			return fmt.Errorf("tck: %s.%s listed but unbindable", ref.Service, ref.Version)
		}
		if a.Provider.ID == "" || a.Provider.Kind == "" || a.Provider.Version == "" {
			return fmt.Errorf("tck: %s registered without provider identity (guarded registration bypassed)", ref)
		}
		if a.Invoke == nil {
			return fmt.Errorf("tck: %s registered without a guarded invoke (registration bypassed)", ref)
		}
		key := ref.String()
		if prev, dup := seen[key]; dup && prev != a.Name {
			return fmt.Errorf("tck: duplicate binding %s (%s vs %s)", key, prev, a.Name)
		}
		seen[key] = a.Name
	}
	return nil
}

// RegisterTrusted is the only adapter registration door the TCK exposes. It is
// a guarded pass-through: there is deliberately no TCK API that omits a
// GuardSet, so trusted-core status can never bypass the governance planes
// enforced by plugin.AdapterRegistry.Register.
func RegisterTrusted(r *plugin.AdapterRegistry, a plugin.Adapter, guards plugin.GuardSet) error {
	return r.Register(a, guards)
}

// HostMethods names the fixture methods a host must expose to run CheckHost.
// Empty fields fall back to the documented defaults below.
type HostMethods struct {
	// Echo returns the request payload unchanged.
	Echo string
	// Block waits until the invocation context is done.
	Block string
	// Denied returns a CAPABILITY_DENIED call error.
	Denied string
	// Timeout bounds the blocking invocation used by the timeout check.
	Timeout time.Duration
}

// HostHarness is one plugin host instance under conformance test. Stop must be
// idempotent: the not-active check stops the host before CheckHost's own stop.
type HostHarness interface {
	Start(context.Context) error
	Stop(context.Context) error
	Invoke(ctx context.Context, service, method string, payload []byte) ([]byte, error)
	PluginID() string
	Contract() plugin.Contract
	Methods() HostMethods
}

// HostFactory creates a fresh host for each check. Timeout and cancellation
// checks terminate the host under test, so a single instance cannot be reused.
type HostFactory interface {
	NewHost() (HostHarness, error)
}

// CheckHost runs the host conformance matrix: payload framing, timeout,
// cancellation, capability denial, and the fail-closed not-active gate. Each
// check gets a fresh host from factory.
func CheckHost(factory HostFactory) error {
	checks := []struct {
		name string
		run  func(HostHarness, HostMethods) error
	}{
		{"echo", checkHostEcho},
		{"framing", checkHostFraming},
		{"timeout", checkHostTimeout},
		{"cancellation", checkHostCancellation},
		{"capability-denial", checkHostCapabilityDenied},
		{"not-active", checkHostNotActive},
	}
	for _, c := range checks {
		h, err := factory.NewHost()
		if err != nil {
			return fmt.Errorf("tck: host %s: new: %w", c.name, err)
		}
		if h == nil {
			return fmt.Errorf("tck: host %s: nil harness", c.name)
		}
		m := h.Methods()
		if m.Echo == "" {
			m.Echo = "echo"
		}
		if m.Block == "" {
			m.Block = "block"
		}
		if m.Denied == "" {
			m.Denied = "deny"
		}
		if m.Timeout <= 0 {
			m.Timeout = 50 * time.Millisecond
		}
		if err := h.Start(context.Background()); err != nil {
			return fmt.Errorf("tck: host %s: start: %w", c.name, err)
		}
		runErr := c.run(h, m)
		stopErr := h.Stop(context.Background())
		if runErr != nil {
			return fmt.Errorf("tck: host %s: %w", c.name, runErr)
		}
		if stopErr != nil {
			return fmt.Errorf("tck: host %s: stop: %w", c.name, stopErr)
		}
	}
	return nil
}

func checkHostEcho(h HostHarness, m HostMethods) error {
	payload := []byte(`{"tck":"echo"}`)
	out, err := h.Invoke(context.Background(), h.Contract().Service, m.Echo, payload)
	if err != nil {
		return err
	}
	if !bytes.Equal(out, payload) {
		return fmt.Errorf("echo returned %q, want %q", out, payload)
	}
	return nil
}

func checkHostFraming(h HostHarness, m HostMethods) error {
	payload := append([]byte("line1\nline2\x00"), bytes.Repeat([]byte("x"), 64<<10)...)
	out, err := h.Invoke(context.Background(), h.Contract().Service, m.Echo, payload)
	if err != nil {
		return err
	}
	if !bytes.Equal(out, payload) {
		return fmt.Errorf("framing round-trip changed %d bytes", len(payload))
	}
	return nil
}

func checkHostTimeout(h HostHarness, m HostMethods) error {
	ctx, cancel := context.WithTimeout(context.Background(), m.Timeout)
	defer cancel()
	_, err := h.Invoke(ctx, h.Contract().Service, m.Block, nil)
	if err == nil {
		return errors.New("blocking invoke succeeded")
	}
	if callCode(err) != plugin.CodeTimeout && !errors.Is(err, context.DeadlineExceeded) {
		return fmt.Errorf("timeout error = %v", err)
	}
	return nil
}

func checkHostCancellation(h HostHarness, m HostMethods) error {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() {
		time.Sleep(m.Timeout)
		cancel()
	}()
	_, err := h.Invoke(ctx, h.Contract().Service, m.Block, nil)
	if err == nil {
		return errors.New("blocking invoke succeeded")
	}
	if callCode(err) != plugin.CallErrorCode("CANCELED") && !errors.Is(err, context.Canceled) {
		return fmt.Errorf("cancellation error = %v", err)
	}
	return nil
}

func checkHostCapabilityDenied(h HostHarness, m HostMethods) error {
	_, err := h.Invoke(context.Background(), h.Contract().Service, m.Denied, nil)
	if err == nil {
		return errors.New("denied method succeeded")
	}
	if callCode(err) != plugin.CodeCapabilityDenied {
		return fmt.Errorf("denial error = %v, want CAPABILITY_DENIED", err)
	}
	return nil
}

func checkHostNotActive(h HostHarness, m HostMethods) error {
	if err := h.Stop(context.Background()); err != nil {
		return fmt.Errorf("stop before not-active check: %w", err)
	}
	_, err := h.Invoke(context.Background(), h.Contract().Service, m.Echo, nil)
	if !errors.Is(err, plugin.ErrNotActive) && callCode(err) != plugin.CodeNotActive {
		return fmt.Errorf("post-stop invoke error = %v, want NOT_ACTIVE", err)
	}
	return nil
}

func callCode(err error) plugin.CallErrorCode {
	var ce *plugin.CallError
	if errors.As(err, &ce) {
		return ce.Code()
	}
	return ""
}
