package tck

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/pkg/plugin"
)

func TestCheckLifecyclePasses(t *testing.T) {
	if err := CheckLifecycle(plugin.NewLifecycle()); err != nil {
		t.Fatalf("CheckLifecycle: %v", err)
	}
}

func TestCheckLifecycleRejectsAdvancedState(t *testing.T) {
	lc := plugin.NewLifecycle()
	if err := lc.Transit(plugin.StateValidated); err != nil {
		t.Fatal(err)
	}
	if err := CheckLifecycle(lc); err == nil {
		t.Fatal("CheckLifecycle accepted a lifecycle that was not FETCHED")
	}
}

func TestCheckRegistry(t *testing.T) {
	r := plugin.NewAdapterRegistry()
	pass := func(next plugin.AdapterInvoke) plugin.AdapterInvoke { return next }
	a := plugin.Adapter{
		Contract: plugin.ServiceRef{Service: plugin.ToolProvider.Service, Version: plugin.ToolProvider.Version},
		Name:     "tck-probe",
		Provider: plugin.ProviderIdentity{ID: "tck-probe", Kind: string(plugin.KindToolProvider), Version: plugin.ToolProvider.Version},
		Invoke:   func(context.Context, []byte) ([]byte, error) { return nil, nil },
	}
	if err := RegisterTrusted(r, a, plugin.GuardSet{Policy: pass, Trace: pass, Sandbox: pass}); err != nil {
		t.Fatal(err)
	}
	if err := CheckRegistry(r); err != nil {
		t.Fatalf("CheckRegistry: %v", err)
	}
}

func TestCheckHostPasses(t *testing.T) {
	if err := CheckHost(fakeFactory{}); err != nil {
		t.Fatalf("CheckHost: %v", err)
	}
}

func TestCheckHostRejectsBadEcho(t *testing.T) {
	if err := CheckHost(badFactory{}); err == nil {
		t.Fatal("CheckHost accepted a host that does not echo the payload")
	}
}

type fakeHost struct {
	contract plugin.Contract
	active   bool
}

func (f *fakeHost) Start(context.Context) error { f.active = true; return nil }
func (f *fakeHost) Stop(context.Context) error  { f.active = false; return nil }
func (f *fakeHost) PluginID() string            { return "tck-plugin" }
func (f *fakeHost) Contract() plugin.Contract   { return f.contract }
func (f *fakeHost) Methods() HostMethods {
	return HostMethods{Echo: "echo", Block: "block", Denied: "deny", Timeout: 20 * time.Millisecond}
}

func (f *fakeHost) Invoke(ctx context.Context, service, method string, payload []byte) ([]byte, error) {
	if !f.active {
		return nil, plugin.NewCallError(plugin.CodeNotActive, f.PluginID(), service, method, "not active")
	}
	switch method {
	case "echo":
		return payload, nil
	case "block":
		<-ctx.Done()
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			return nil, plugin.NewCallError(plugin.CodeTimeout, f.PluginID(), service, method, "deadline")
		}
		return nil, plugin.NewCallError(plugin.CallErrorCode("CANCELED"), f.PluginID(), service, method, "canceled")
	case "deny":
		return nil, plugin.NewCallError(plugin.CodeCapabilityDenied, f.PluginID(), service, method, "denied")
	default:
		return nil, plugin.NewCallError(plugin.CodeNotFound, f.PluginID(), service, method, "unknown method")
	}
}

type fakeFactory struct{}

func (fakeFactory) NewHost() (HostHarness, error) {
	return &fakeHost{contract: plugin.ToolProvider}, nil
}

type badFactory struct{}

func (badFactory) NewHost() (HostHarness, error) {
	return &badHost{fakeHost: fakeHost{contract: plugin.ToolProvider}}, nil
}

type badHost struct{ fakeHost }

func (b *badHost) Invoke(ctx context.Context, service, method string, payload []byte) ([]byte, error) {
	if method == "echo" {
		return []byte("wrong"), nil
	}
	return b.fakeHost.Invoke(ctx, service, method, payload)
}
