package plugin

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestLifecycleRejectsCallsBeforeActive(t *testing.T) {
	l := NewLifecycle()
	if l.State() != StateFetched {
		t.Fatalf("state = %s", l.State())
	}
	if err := l.Acquire(); !errors.Is(err, ErrNotActive) {
		t.Fatalf("err = %v, want ErrNotActive", err)
	}
}

func TestLifecycleRejectsInvalidTransition(t *testing.T) {
	l := NewLifecycle()
	if err := l.Transit(StateActive); !errors.Is(err, ErrInvalidTransition) {
		t.Fatalf("err = %v, want ErrInvalidTransition", err)
	}
	if l.State() != StateFetched {
		t.Fatalf("state changed to %s", l.State())
	}
}

func TestLifecycleAcquireReleaseUnderflow(t *testing.T) {
	l := NewLifecycle()
	for _, state := range []State{StateValidated, StateLoaded, StateActive} {
		if err := l.Transit(state); err != nil {
			t.Fatal(err)
		}
	}
	if err := l.Acquire(); err != nil {
		t.Fatal(err)
	}
	if err := l.Release(); err != nil {
		t.Fatal(err)
	}
	if err := l.Release(); !errors.Is(err, ErrUnderflow) {
		t.Fatalf("err = %v, want ErrUnderflow", err)
	}
	if l.Inflight() != 0 {
		t.Fatalf("inflight = %d", l.Inflight())
	}
}

func TestLifecycleDrainRequiresDraining(t *testing.T) {
	l := NewLifecycle()
	for _, state := range []State{StateValidated, StateLoaded, StateActive} {
		if err := l.Transit(state); err != nil {
			t.Fatal(err)
		}
	}
	if err := l.Drain(context.Background()); !errors.Is(err, ErrInvalidTransition) {
		t.Fatalf("err = %v, want ErrInvalidTransition", err)
	}
	if l.State() != StateActive {
		t.Fatalf("state = %s", l.State())
	}
}

func TestLifecycleDrainWaitsForInflight(t *testing.T) {
	l := NewLifecycle()
	for _, state := range []State{StateValidated, StateLoaded, StateActive} {
		if err := l.Transit(state); err != nil {
			t.Fatal(err)
		}
	}
	if err := l.Acquire(); err != nil {
		t.Fatal(err)
	}
	if err := l.Transit(StateDraining); err != nil {
		t.Fatal(err)
	}
	done := make(chan error, 1)
	go func() { done <- l.Drain(context.Background()) }()
	select {
	case err := <-done:
		t.Fatalf("drain returned before release: %v", err)
	case <-time.After(10 * time.Millisecond):
	}
	if err := l.Release(); err != nil {
		t.Fatal(err)
	}
	if err := <-done; err != nil {
		t.Fatal(err)
	}
	if l.State() != StateStopped {
		t.Fatalf("state = %s", l.State())
	}
}

func TestLifecycleDrainTimeoutAndCancel(t *testing.T) {
	for name, want := range map[string]error{
		"timeout": ErrDrainTimeout,
		"cancel":  ErrDrainCanceled,
	} {
		t.Run(name, func(t *testing.T) {
			l := NewLifecycle()
			l.drainPollInterval = time.Hour
			for _, state := range []State{StateValidated, StateLoaded, StateActive} {
				if err := l.Transit(state); err != nil {
					t.Fatal(err)
				}
			}
			if err := l.Acquire(); err != nil {
				t.Fatal(err)
			}
			if err := l.Transit(StateDraining); err != nil {
				t.Fatal(err)
			}
			var ctx context.Context
			var cancel context.CancelFunc
			if name == "timeout" {
				ctx, cancel = context.WithTimeout(context.Background(), 10*time.Millisecond)
			} else {
				ctx, cancel = context.WithCancel(context.Background())
				cancel()
			}
			defer cancel()
			if err := l.Drain(ctx); !errors.Is(err, want) {
				t.Fatalf("err = %v, want %v", err, want)
			}
			if l.State() != StateDraining {
				t.Fatalf("state = %s", l.State())
			}
		})
	}
}

func TestLifecycleTerminalStatesAreIrreversible(t *testing.T) {
	l := NewLifecycle()
	if err := l.Fail(); err != nil {
		t.Fatal(err)
	}
	if err := l.Quarantine(); err != nil {
		t.Fatal(err)
	}
	if err := l.Transit(StateLoaded); !errors.Is(err, ErrInvalidTransition) {
		t.Fatalf("err = %v, want ErrInvalidTransition", err)
	}
	if l.State() != StateQuarantined {
		t.Fatalf("state = %s", l.State())
	}
}
