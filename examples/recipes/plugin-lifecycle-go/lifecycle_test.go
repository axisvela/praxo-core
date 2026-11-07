package plugin_lifecycle_recipe

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/plugin"
)

func activeLifecycle(t *testing.T) *plugin.Lifecycle {
	t.Helper()
	lifecycle := plugin.NewLifecycle()
	for _, next := range []plugin.State{
		plugin.StateValidated,
		plugin.StateLoaded,
		plugin.StateActive,
	} {
		if err := lifecycle.Transit(next); err != nil {
			t.Fatal(err)
		}
	}
	return lifecycle
}

func TestLifecycleRequiresActive(t *testing.T) {
	lifecycle := plugin.NewLifecycle()
	if err := lifecycle.Acquire(); !errors.Is(err, plugin.ErrNotActive) {
		t.Fatalf("err = %v, want ErrNotActive", err)
	}
	active := activeLifecycle(t)
	if err := active.Acquire(); err != nil {
		t.Fatal(err)
	}
	if active.Inflight() != 1 {
		t.Fatalf("inflight = %d, want 1", active.Inflight())
	}
	if err := active.Release(); err != nil {
		t.Fatal(err)
	}
	if err := active.Release(); !errors.Is(err, plugin.ErrUnderflow) {
		t.Fatalf("err = %v, want ErrUnderflow", err)
	}
}

func TestLifecycleRejectsSkippedTransition(t *testing.T) {
	lifecycle := plugin.NewLifecycle()
	if err := lifecycle.Transit(plugin.StateActive); !errors.Is(err, plugin.ErrInvalidTransition) {
		t.Fatalf("err = %v, want ErrInvalidTransition", err)
	}
	if lifecycle.State() != plugin.StateFetched {
		t.Fatalf("state = %s, want FETCHED", lifecycle.State())
	}
}

func TestLifecycleDrainWaitsForInflight(t *testing.T) {
	lifecycle := activeLifecycle(t)
	if err := lifecycle.Acquire(); err != nil {
		t.Fatal(err)
	}
	if err := lifecycle.Transit(plugin.StateDraining); err != nil {
		t.Fatal(err)
	}
	done := make(chan error, 1)
	go func() { done <- lifecycle.Drain(context.Background()) }()
	time.Sleep(10 * time.Millisecond)
	if err := lifecycle.Release(); err != nil {
		t.Fatal(err)
	}
	select {
	case err := <-done:
		if err != nil {
			t.Fatal(err)
		}
	case <-time.After(time.Second):
		t.Fatal("drain did not finish after the last release")
	}
	if lifecycle.State() != plugin.StateStopped {
		t.Fatalf("state = %s, want STOPPED", lifecycle.State())
	}
}

func TestLifecycleDrainTimeoutAndCancel(t *testing.T) {
	lifecycle := activeLifecycle(t)
	if err := lifecycle.Acquire(); err != nil {
		t.Fatal(err)
	}
	if err := lifecycle.Transit(plugin.StateDraining); err != nil {
		t.Fatal(err)
	}
	deadline, cancel := context.WithTimeout(context.Background(), 10*time.Millisecond)
	defer cancel()
	if err := lifecycle.Drain(deadline); !errors.Is(err, plugin.ErrDrainTimeout) {
		t.Fatalf("err = %v, want ErrDrainTimeout", err)
	}
	if lifecycle.State() != plugin.StateDraining {
		t.Fatalf("state = %s, want DRAINING", lifecycle.State())
	}

	canceled, cancelNow := context.WithCancel(context.Background())
	cancelNow()
	if err := lifecycle.Drain(canceled); !errors.Is(err, plugin.ErrDrainCanceled) {
		t.Fatalf("err = %v, want ErrDrainCanceled", err)
	}
	if err := lifecycle.Release(); err != nil {
		t.Fatal(err)
	}
}

func TestLifecycleRevoke(t *testing.T) {
	lifecycle := activeLifecycle(t)
	if err := lifecycle.Revoke(context.Background()); err != nil {
		t.Fatal(err)
	}
	if lifecycle.State() != plugin.StateUnloaded {
		t.Fatalf("state = %s, want UNLOADED", lifecycle.State())
	}
	if err := lifecycle.Revoke(context.Background()); err != nil {
		t.Fatalf("second revoke from UNLOADED = %v", err)
	}
}

func TestLifecycleQuarantineIsTerminal(t *testing.T) {
	lifecycle := activeLifecycle(t)
	if err := lifecycle.Quarantine(); err != nil {
		t.Fatal(err)
	}
	if lifecycle.State() != plugin.StateQuarantined {
		t.Fatalf("state = %s, want QUARANTINED", lifecycle.State())
	}
	if err := lifecycle.Transit(plugin.StateFailed); !errors.Is(err, plugin.ErrInvalidTransition) {
		t.Fatalf("err = %v, want ErrInvalidTransition", err)
	}
	if err := lifecycle.Revoke(context.Background()); !errors.Is(err, plugin.ErrInvalidTransition) {
		t.Fatalf("revoke err = %v, want ErrInvalidTransition", err)
	}
}
