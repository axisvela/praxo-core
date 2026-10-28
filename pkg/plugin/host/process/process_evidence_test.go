package process

import (
	"context"
	"errors"
	"runtime"
	"sync"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/plugin"
)

// recordingSink is a concurrency-safe structured TelemetrySink for tests.
type recordingSink struct {
	mu     sync.Mutex
	events []plugin.Event
}

func (s *recordingSink) RecordPluginEvent(_ context.Context, ev plugin.Event) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	cp := make(map[string]any, len(ev.Detail))
	for k, v := range ev.Detail {
		cp[k] = v
	}
	ev.Detail = cp
	s.events = append(s.events, ev)
	return nil
}

func (s *recordingSink) first(kind plugin.EventKind) (plugin.Event, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, e := range s.events {
		if e.Kind == kind {
			return e, true
		}
	}
	return plugin.Event{}, false
}

func (s *recordingSink) kinds() []plugin.EventKind {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]plugin.EventKind, 0, len(s.events))
	for _, e := range s.events {
		out = append(out, e.Kind)
	}
	return out
}

func (s *recordingSink) count(kind plugin.EventKind) int {
	s.mu.Lock()
	defer s.mu.Unlock()
	n := 0
	for _, e := range s.events {
		if e.Kind == kind {
			n++
		}
	}
	return n
}

// TestTerminationIncludesExitAndResourceEvidence proves forced termination
// emits exit and resource evidence through the telemetry seam.
func TestTerminationIncludesExitAndResourceEvidence(t *testing.T) {
	sink := &recordingSink{}
	cfg := fakeConfig(t)
	cfg.Sink = sink
	limits := plugin.ResourceLimits{CPUSeconds: 30}
	if runtime.GOOS == "windows" {
		limits.MemoryMB = 256
		limits.MaxProcesses = 4
	}
	cfg.Limits = limits
	h := startFakeConfig(t, cfg)

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		_, _ = h.Invoke(ctx, "tool.provider", "block", nil)
		close(done)
	}()
	time.Sleep(100 * time.Millisecond)
	cancel()
	<-done
	select {
	case <-h.Exited():
	case <-time.After(5 * time.Second):
		t.Fatal("child was not terminated")
	}

	ev, ok := sink.first(plugin.EventCanceled)
	if !ok {
		deadline := time.Now().Add(2 * time.Second)
		for !ok && time.Now().Before(deadline) {
			time.Sleep(10 * time.Millisecond)
			ev, ok = sink.first(plugin.EventCanceled)
		}
	}
	if !ok {
		t.Fatalf("no cancellation evidence emitted; events=%v", sink.kinds())
	}
	for _, key := range []string{"reason", "exit_code"} {
		if _, present := ev.Detail[key]; !present {
			t.Fatalf("termination evidence missing %q; detail=%v", key, ev.Detail)
		}
	}
	if ev.Limits.CPUSeconds != 30 ||
		(runtime.GOOS == "windows" && (ev.Limits.MemoryMB != 256 || ev.Limits.MaxProcesses != 4)) {
		t.Fatalf("termination evidence missing enforced limits: %+v", ev.Limits)
	}
	// The supervisor handle must still be open when usage is captured, so the
	// evidence must carry real (non-zero) consumption. On Windows the Job
	// Object reports peak committed memory and CPU time; Linux rlimits leave
	// no durable accounting object, so the strict check is Windows-scoped.
	if runtime.GOOS == "windows" {
		if ev.Usage.PeakMemoryMB <= 0 && ev.Usage.CPUSecondsUsed <= 0 {
			t.Fatalf("termination evidence captured empty usage (evidence race): %+v", ev.Usage)
		}
	}
}

// TestCancellationAndForcedTerminationAreRecorded proves cancellation terminates
// controlled execution and the terminal fact reaches the telemetry sink.
func TestCancellationAndForcedTerminationAreRecorded(t *testing.T) {
	sink := &recordingSink{}
	cfg := fakeConfig(t)
	cfg.Sink = sink
	h := startFakeConfig(t, cfg)

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		_, _ = h.Invoke(ctx, "tool.provider", "block", nil)
		close(done)
	}()
	time.Sleep(100 * time.Millisecond)
	cancel()
	<-done
	select {
	case <-h.Exited():
	case <-time.After(5 * time.Second):
		t.Fatal("child was not terminated after cancellation")
	}

	deadline := time.Now().Add(3 * time.Second)
	for {
		if _, ok := sink.first(plugin.EventCanceled); ok {
			return
		}
		if time.Now().After(deadline) {
			t.Fatalf("cancellation was not recorded: %v", sink.kinds())
		}
		time.Sleep(20 * time.Millisecond)
	}
}

// TestProductionHostRejectsNilEvidenceSink proves a production host refuses to
// be constructed without an evidence sink, so security facts cannot silently
// vanish.
func TestProductionHostRejectsNilEvidenceSink(t *testing.T) {
	cfg := fakeConfig(t)
	cfg.RequireEvidence = true
	cfg.Sink = nil
	if _, err := New(cfg); err == nil {
		t.Fatal("production host accepted a nil evidence sink")
	}
}

// TestCleanExitIsNotReportedAsCrash pins the event kind: a graceful shutdown
// is a stop, not a crash.
func TestCleanExitIsNotReportedAsCrash(t *testing.T) {
	sink := &recordingSink{}
	cfg := fakeConfig(t)
	cfg.Sink = sink
	h := startFakeConfig(t, cfg)

	if err := h.Stop(context.Background()); err != nil {
		t.Fatalf("Stop: %v", err)
	}
	// Stop waits for waitLoop, so the terminal event is already emitted.
	if _, ok := sink.first(plugin.EventTerminated); ok {
		t.Fatalf("clean shutdown emitted a termination event; kinds=%v", sink.kinds())
	}
	if n := sink.count(plugin.EventStop); n != 1 {
		t.Fatalf("clean shutdown emitted %d stop events, want exactly 1; kinds=%v", n, sink.kinds())
	}
}

// failingSink always rejects an event, for surfacing tests.
type failingSink struct{ err error }

func (s failingSink) RecordPluginEvent(context.Context, plugin.Event) error { return s.err }

// TestResourceLimitEventIsEmittedOnTimeout proves an invocation time-limit hit
// emits the distinct EventResourceLimit kind carrying the enforced limits.
func TestResourceLimitEventIsEmittedOnTimeout(t *testing.T) {
	sink := &recordingSink{}
	cfg := fakeConfig(t)
	cfg.Sink = sink
	cfg.InvokeTimeout = 150 * time.Millisecond
	cfg.Limits = plugin.ResourceLimits{CPUSeconds: 1}
	h := startFakeConfig(t, cfg)

	if _, err := h.Invoke(context.Background(), "tool.provider", "block", nil); err == nil {
		t.Fatal("expected timeout")
	}
	select {
	case <-h.Exited():
	case <-time.After(5 * time.Second):
		t.Fatal("child was not terminated after timeout")
	}

	var ev plugin.Event
	var ok bool
	deadline := time.Now().Add(3 * time.Second)
	for {
		ev, ok = sink.first(plugin.EventResourceLimit)
		if ok || time.Now().After(deadline) {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	if !ok {
		t.Fatalf("no resource-limit event emitted; kinds=%v", sink.kinds())
	}
	if ev.Limits.CPUSeconds != 1 {
		t.Fatalf("resource-limit event limits = %+v, want CPUSeconds=1", ev.Limits)
	}
	if r, _ := ev.Detail["reason"].(string); r != "invoke_timeout" {
		t.Fatalf("resource-limit reason = %v, want invoke_timeout", ev.Detail["reason"])
	}
}

// TestLimitInstallFailureEmitsEvidence proves a production host that cannot
// install containment emits a durable resource-limit fact before failing closed.
func TestLimitInstallFailureEmitsEvidence(t *testing.T) {
	sink := &recordingSink{}
	cfg := fakeConfig(t)
	cfg.RequireLimits = true
	cfg.Limits = plugin.ResourceLimits{MemoryMB: 64}
	cfg.Sink = sink
	cfg.limitInstaller = func(int, plugin.ResourceLimits) (resourceHandle, error) {
		return nil, errors.New("injected limit failure")
	}
	h, err := New(cfg)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if err := h.Start(context.Background()); err == nil {
		t.Fatal("Start succeeded despite limit install failure")
	}
	ev, ok := sink.first(plugin.EventResourceLimit)
	if !ok {
		t.Fatalf("no resource-limit event on install failure; kinds=%v", sink.kinds())
	}
	if r, _ := ev.Detail["reason"].(string); r != "limits_install_failed" {
		t.Fatalf("reason = %v, want limits_install_failed", ev.Detail["reason"])
	}
}

// TestResumeFailureEmitsEvidence proves a containment resume failure emits a
// terminal fact before failing closed.
func TestResumeFailureEmitsEvidence(t *testing.T) {
	sink := &recordingSink{}
	cfg := fakeConfig(t)
	cfg.RequireLimits = true
	cfg.Limits = plugin.ResourceLimits{MemoryMB: 64}
	cfg.Sink = sink
	cfg.limitInstaller = func(int, plugin.ResourceLimits) (resourceHandle, error) {
		return stubHandle{}, nil
	}
	cfg.resumeInstaller = func(int) error { return errors.New("injected resume failure") }
	h, err := New(cfg)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if err := h.Start(context.Background()); err == nil {
		t.Fatal("Start succeeded despite resume failure")
	}
	ev, ok := sink.first(plugin.EventTerminated)
	if !ok {
		t.Fatalf("no terminated event on resume failure; kinds=%v", sink.kinds())
	}
	if r, _ := ev.Detail["reason"].(string); r != "resume_failed" {
		t.Fatalf("reason = %v, want resume_failed", ev.Detail["reason"])
	}
}

// TestDroppedTerminalEvidenceIsSurfaced proves a rejected terminal event is
// reported through OnEvidenceError rather than silently swallowed.
func TestDroppedTerminalEvidenceIsSurfaced(t *testing.T) {
	sentinel := errors.New("injected sink rejection")
	var mu sync.Mutex
	var surfaced []error
	cfg := fakeConfig(t)
	cfg.Sink = failingSink{err: sentinel}
	cfg.OnEvidenceError = func(err error) { mu.Lock(); surfaced = append(surfaced, err); mu.Unlock() }
	h := startFakeConfig(t, cfg)

	mu.Lock()
	surfaced = nil
	mu.Unlock()
	if err := h.Stop(context.Background()); err != nil {
		t.Fatalf("Stop: %v", err)
	}
	mu.Lock()
	n := len(surfaced)
	var first error
	if n > 0 {
		first = surfaced[0]
	}
	mu.Unlock()
	if n == 0 {
		t.Fatal("dropped terminal evidence was swallowed")
	}
	if !errors.Is(first, sentinel) {
		t.Fatalf("surfaced error = %v, want %v", first, sentinel)
	}
}
