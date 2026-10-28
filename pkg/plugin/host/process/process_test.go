package process

import (
	"bytes"
	"context"
	"errors"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/plugin"
)

func TestStartHealthInvokeRoundtrip(t *testing.T) {
	h := startFake(t)

	payload := []byte(`{"tool":"demo","args":[1,2,3]}`)
	got, err := h.Invoke(context.Background(), "tool.provider", "echo", payload)
	if err != nil {
		t.Fatalf("Invoke echo: %v", err)
	}
	if !bytes.Equal(got, payload) {
		t.Fatalf("echo payload = %q, want %q", got, payload)
	}

	_, err = h.Invoke(context.Background(), "tool.provider", "nope", nil)
	var callErr *plugin.CallError
	if !errors.As(err, &callErr) || callErr.Code() != plugin.CodeNotFound {
		t.Fatalf("unknown method error = %v, want CallError NOT_FOUND", err)
	}
}

func TestInvokeTimeout(t *testing.T) {
	cfg := fakeConfig(t)
	cfg.InvokeTimeout = 150 * time.Millisecond
	h := startFakeConfig(t, cfg)

	_, err := h.Invoke(context.Background(), "tool.provider", "block", nil)
	var callErr *plugin.CallError
	if !errors.As(err, &callErr) || callErr.Code() != plugin.CodeTimeout {
		t.Fatalf("timeout error = %v, want CallError TIMEOUT", callErr)
	}

	// A timed-out invocation is terminal: the child is terminated and reaped.
	select {
	case <-h.Exited():
	case <-time.After(5 * time.Second):
		t.Fatal("child was not terminated after host invoke timeout")
	}
}

func TestInvokeContextCancel(t *testing.T) {
	h := startFake(t)

	ctx, cancel := context.WithCancel(context.Background())
	go func() {
		time.Sleep(100 * time.Millisecond)
		cancel()
	}()
	_, err := h.Invoke(ctx, "tool.provider", "block", nil)
	var callErr *plugin.CallError
	if !errors.As(err, &callErr) || callErr.Code() != CodeCanceled {
		t.Fatalf("cancel error = %v, want CallError CANCELED", err)
	}
	select {
	case <-h.Exited():
	case <-time.After(5 * time.Second):
		t.Fatal("child was not terminated after invocation cancellation")
	}
}

func TestBadTokenRejected(t *testing.T) {
	h, err := New(fakeConfig(t, "FAKE_EXPECT_TOKEN=not-the-host-token"))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	err = h.Start(context.Background())
	var callErr *plugin.CallError
	if !errors.As(err, &callErr) || callErr.Code() != plugin.CodeCapabilityDenied {
		t.Fatalf("Start with bad token = %v, want CallError CAPABILITY_DENIED", err)
	}

	select {
	case <-h.Exited():
	case <-time.After(3 * time.Second):
		t.Fatal("failed-start child was not reaped")
	}
}

func TestCrashDetection(t *testing.T) {
	h := startFake(t)

	if _, err := h.Invoke(context.Background(), "tool.provider", "crash", nil); err == nil {
		t.Fatal("Invoke on crashing plugin succeeded, want error")
	}

	select {
	case <-h.Exited():
	case <-time.After(3 * time.Second):
		t.Fatal("Exited channel not closed after plugin crash")
	}
	if h.ExitError() == nil {
		t.Fatal("ExitError = nil after crash, want non-nil")
	}

	_, err := h.Invoke(context.Background(), "tool.provider", "echo", nil)
	var callErr *plugin.CallError
	if !errors.As(err, &callErr) {
		t.Fatalf("post-crash error = %v, want CallError", err)
	}
}

func TestStop(t *testing.T) {
	h := startFake(t)

	if err := h.Stop(context.Background()); err != nil {
		t.Fatalf("Stop: %v", err)
	}
	select {
	case <-h.Exited():
	default:
		t.Fatal("Exited channel open after Stop")
	}

	_, err := h.Invoke(context.Background(), "tool.provider", "echo", nil)
	var callErr *plugin.CallError
	if !errors.As(err, &callErr) || callErr.Code() != plugin.CodeNotActive {
		t.Fatalf("post-Stop error = %v, want CallError NOT_ACTIVE", err)
	}

	if err := h.Stop(context.Background()); err != nil {
		t.Fatalf("second Stop: %v", err)
	}
}

// TestCanceledInvocationTerminatesUncooperativeChild proves that a canceled
// invocation cannot leave a child that ignores cooperative shutdown running:
// the host bounds the grace window and then force-terminates and reaps it.
func TestCanceledInvocationTerminatesUncooperativeChild(t *testing.T) {
	h := startFake(t)

	ctx, cancel := context.WithCancel(context.Background())
	errCh := make(chan error, 1)
	go func() {
		_, err := h.Invoke(ctx, "tool.provider", "block", nil)
		errCh <- err
	}()
	time.Sleep(100 * time.Millisecond)
	cancel()

	err := <-errCh
	var callErr *plugin.CallError
	if !errors.As(err, &callErr) || callErr.Code() != CodeCanceled {
		t.Fatalf("canceled invoke error = %v, want CallError CANCELED", err)
	}

	select {
	case <-h.Exited():
	case <-time.After(5 * time.Second):
		t.Fatal("uncooperative child was not terminated after cancellation")
	}
	if h.ExitError() == nil {
		t.Fatal("ExitError = nil after forced termination, want non-nil")
	}
}

// TestTimeoutTerminatesAndReapsChild proves an invocation deadline terminates
// the child and reaps host goroutines rather than leaking a background call.
func TestTimeoutTerminatesAndReapsChild(t *testing.T) {
	h := startFake(t)

	ctx, cancel := context.WithTimeout(context.Background(), 150*time.Millisecond)
	defer cancel()
	start := time.Now()
	_, err := h.Invoke(ctx, "tool.provider", "block", nil)
	var callErr *plugin.CallError
	if !errors.As(err, &callErr) || callErr.Code() != plugin.CodeTimeout {
		t.Fatalf("timed-out invoke error = %v, want CallError TIMEOUT", err)
	}

	select {
	case <-h.Exited():
	case <-time.After(5 * time.Second):
		t.Fatal("child was not terminated and reaped after timeout")
	}
	if elapsed := time.Since(start); elapsed > 3*time.Second {
		t.Fatalf("timeout termination took %v; must be bounded", elapsed)
	}
	if _, err := h.Invoke(context.Background(), "tool.provider", "echo", nil); err == nil {
		t.Fatal("invoke after forced termination succeeded, want error")
	}
}

// TestHostHealthyReflectsProcessState pins the real process-host health signal
// the production assembly gates activation on: an unstarted host is unhealthy,
// a running host is healthy, and a stopped/reaped host is unhealthy again.
func TestHostHealthyReflectsProcessState(t *testing.T) {
	h, err := New(fakeConfig(t))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if err := h.Healthy(context.Background()); err == nil {
		t.Fatal("an unstarted process host must be unhealthy")
	}
	if err := h.Start(context.Background()); err != nil {
		t.Fatalf("Start: %v", err)
	}
	if err := h.Healthy(context.Background()); err != nil {
		t.Fatalf("a running process host must be healthy: %v", err)
	}
	if err := h.Stop(context.Background()); err != nil {
		t.Fatalf("Stop: %v", err)
	}
	if err := h.Healthy(context.Background()); err == nil {
		t.Fatal("a stopped process host must be unhealthy")
	}
}
