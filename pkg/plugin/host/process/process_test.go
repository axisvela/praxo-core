package process

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"sync"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/pkg/plugin"
)

// TestMain runs the hermetic fake plugin when the test binary is re-executed
// as a child process, avoiding any separate build step.
func TestMain(m *testing.M) {
	if os.Getenv("PRAXOVELA_FAKE_GRANDCHILD") == "1" {
		runFakeGrandchild()
		return
	}
	if os.Getenv("PRAXOVELA_FAKE_PLUGIN") == "1" {
		runFakePlugin()
		return
	}
	os.Exit(m.Run())
}

// runFakeGrandchild is the grandchild entrypoint used by process-containment
// tests. It signals that it started, outlives the parent plugin, and then
// writes a liveness marker that must never appear if containment works.
func runFakeGrandchild() {
	marker := os.Getenv("FAKE_GRANDCHILD_MARKER")
	_ = os.WriteFile(marker+".started", []byte("1"), 0o600)
	time.Sleep(2 * time.Second)
	_ = os.WriteFile(marker+".alive", []byte("1"), 0o600)
	os.Exit(0)
}

// spawnGrandchild starts another copy of the test binary in grandchild mode.
func spawnGrandchild(marker string) error {
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	c := exec.Command(exe, "-test.run=^$")
	c.Env = append(os.Environ(),
		"PRAXOVELA_FAKE_GRANDCHILD=1",
		"FAKE_GRANDCHILD_MARKER="+marker,
	)
	if err := c.Start(); err != nil {
		return err
	}
	go func() { _ = c.Wait() }()
	return nil
}

// runFakePlugin is the child-process entrypoint. It speaks the host wire
// protocol over stdio and validates the channel token on every request.
// Behavior knobs via environment:
//
//	FAKE_EXPECT_TOKEN   - expected token override (simulates token mismatch)
//	FAKE_DIE_AFTER_HEALTH - exit(3) after the health handshake (crash test)
//
// Method behaviors: "echo" returns the payload, "block" sleeps 30s,
// "crash" exits(2), anything else replies NOT_FOUND.
func runFakePlugin() {
	token := os.Getenv(tokenEnvVar)
	if exp := os.Getenv("FAKE_EXPECT_TOKEN"); exp != "" {
		token = exp
	}
	dieAfterHealth := os.Getenv("FAKE_DIE_AFTER_HEALTH") == "1"

	// FAKE_SPAWN_ON_START makes the plugin spawn a grandchild as its very first
	// action, before it processes any frame. Under suspended-spawn containment
	// the grandchild is created only after the job assignment, so it cannot
	// escape the containment unit.
	if marker := os.Getenv("FAKE_SPAWN_ON_START"); marker != "" {
		if err := spawnGrandchild(marker); err != nil {
			os.Exit(6)
		}
	}

	scanner := bufio.NewScanner(os.Stdin)
	scanner.Buffer(make([]byte, 64<<10), DefaultMaxFrame)
	var writeMu sync.Mutex
	write := func(resp Response) {
		frame, err := json.Marshal(resp)
		if err != nil {
			os.Exit(4)
		}
		writeMu.Lock()
		defer writeMu.Unlock()
		if _, err := os.Stdout.Write(append(frame, '\n')); err != nil {
			os.Exit(5)
		}
	}

	for scanner.Scan() {
		var req Request
		if err := json.Unmarshal(scanner.Bytes(), &req); err != nil {
			continue
		}
		resp := Response{ID: req.ID, Version: ProtocolVersion, OK: true}

		if req.Token != token {
			resp.OK = false
			resp.Code = string(plugin.CodeCapabilityDenied)
			resp.Message = "bad token"
			write(resp)
			continue
		}

		switch {
		case req.Service == ControlService && req.Method == MethodHealth:
			write(resp)
			if dieAfterHealth {
				os.Exit(3)
			}
		case req.Service == ControlService && req.Method == MethodShutdown:
			write(resp)
			os.Exit(0)
		case req.Method == "echo":
			resp.Payload = req.Payload
			write(resp)
		case req.Method == "block":
			go func(r Response) {
				time.Sleep(30 * time.Second)
				write(r)
			}(resp)
		case req.Method == "alloc":
			n, err := strconv.Atoi(string(req.Payload))
			if err != nil {
				resp.OK = false
				resp.Code = string(plugin.CodeInvalidRequest)
				resp.Message = "alloc: bad size"
				write(resp)
				continue
			}
			buf := make([]byte, n)
			for i := 0; i < len(buf); i += 4096 {
				buf[i] = 1
			}
			runtime.KeepAlive(buf)
			resp.Payload = []byte(strconv.Itoa(len(buf)))
			write(resp)
		case req.Method == "spawn":
			if err := spawnGrandchild(string(req.Payload)); err != nil {
				resp.OK = false
				resp.Code = string(plugin.CodeInternal)
				resp.Message = "spawn: " + err.Error()
			}
			write(resp)
		case req.Method == "crash":
			os.Exit(2)
		default:
			resp.OK = false
			resp.Code = string(plugin.CodeNotFound)
			resp.Message = "unknown method"
			write(resp)
		}
	}
}

// fakeConfig builds a host Config that re-executes the test binary as the
// fake plugin.
func fakeConfig(t *testing.T, extraEnv ...string) Config {
	t.Helper()
	exe, err := os.Executable()
	if err != nil {
		t.Fatalf("os.Executable: %v", err)
	}
	return Config{
		PluginID:      "fake.test",
		Path:          exe,
		Args:          []string{"-test.run=^$"},
		Env:           append([]string{"PRAXOVELA_FAKE_PLUGIN=1"}, extraEnv...),
		StartTimeout:  10 * time.Second,
		InvokeTimeout: 2 * time.Second,
		GracePeriod:   2 * time.Second,
	}
}

func startFake(t *testing.T, extraEnv ...string) *Host {
	t.Helper()
	h, err := New(fakeConfig(t, extraEnv...))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if err := h.Start(context.Background()); err != nil {
		t.Fatalf("Start: %v", err)
	}
	t.Cleanup(func() { _ = h.Stop(context.Background()) })
	return h
}

// startFakeConfig starts a host built from a caller-supplied Config (for
// resource-limit and evidence tests).
func startFakeConfig(t *testing.T, cfg Config) *Host {
	t.Helper()
	h, err := New(cfg)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if err := h.Start(context.Background()); err != nil {
		t.Fatalf("Start: %v", err)
	}
	t.Cleanup(func() { _ = h.Stop(context.Background()) })
	return h
}

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

// waitForFile blocks until path exists or d elapses.
func waitForFile(t *testing.T, path string, d time.Duration) {
	t.Helper()
	deadline := time.Now().Add(d)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(path); err == nil {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for %s", path)
}

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

func TestDieAfterHealth(t *testing.T) {
	h := startFake(t, "FAKE_DIE_AFTER_HEALTH=1")

	deadline := time.Now().Add(3 * time.Second)
	for {
		_, err := h.Invoke(context.Background(), "tool.provider", "echo", nil)
		if err != nil {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("plugin death after health was never detected")
		}
		time.Sleep(10 * time.Millisecond)
	}

	select {
	case <-h.Exited():
	case <-time.After(time.Second):
		t.Fatal("Exited channel not closed after plugin exit")
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

// TestMemoryLimitTerminatesChild proves the configured memory limit is real:
// the same allocation succeeds unconstrained and kills the child when bounded.
func TestMemoryLimitTerminatesChild(t *testing.T) {
	if runtime.GOOS != "windows" && runtime.GOOS != "linux" {
		t.Skipf("resource limits unsupported on %s", runtime.GOOS)
	}
	// The same allocation must succeed unconstrained and kill the child when
	// bounded, so the only variable is the enforced limit.
	const allocBytes = 512 << 20

	unlimited := startFake(t)
	if _, err := unlimited.Invoke(context.Background(), "tool.provider", "alloc", []byte(strconv.Itoa(allocBytes))); err != nil {
		t.Fatalf("alloc without limit failed: %v", err)
	}

	cfg := fakeConfig(t)
	cfg.Limits = plugin.ResourceLimits{MemoryMB: 256}
	h := startFakeConfig(t, cfg)

	if _, err := h.Invoke(context.Background(), "tool.provider", "alloc", []byte(strconv.Itoa(allocBytes))); err == nil {
		t.Fatal("alloc beyond memory limit succeeded, want termination")
	}
	select {
	case <-h.Exited():
	case <-time.After(5 * time.Second):
		t.Fatal("child was not terminated after exceeding the memory limit")
	}
}

// TestProcessCountLimitBlocksGrandchild proves the process-count limit is
// enforced on real OS process creation within the plugin's containment unit.
func TestProcessCountLimitBlocksGrandchild(t *testing.T) {
	if runtime.GOOS != "windows" && runtime.GOOS != "linux" {
		t.Skipf("resource limits unsupported on %s", runtime.GOOS)
	}
	if runtime.GOOS == "linux" && os.Geteuid() == 0 {
		t.Skip("RLIMIT_NPROC is not enforced for uid 0")
	}
	dir := t.TempDir()

	// Control: without the limit, the grandchild starts.
	unlimited := startFake(t)
	if _, err := unlimited.Invoke(context.Background(), "tool.provider", "spawn", []byte(filepath.Join(dir, "gc-unlimited"))); err != nil {
		t.Fatalf("spawn without limit failed: %v", err)
	}

	cfg := fakeConfig(t)
	cfg.Limits = plugin.ResourceLimits{MaxProcesses: 1}
	h := startFakeConfig(t, cfg)

	if _, err := h.Invoke(context.Background(), "tool.provider", "spawn", []byte(filepath.Join(dir, "gc-limited"))); err == nil {
		t.Fatal("spawn beyond the process-count limit succeeded, want failure")
	}
}

// TestRequiredLimitsFailStartWhenUnavailable proves RequireLimits is
// fail-closed: an unavailable supervisor is a start error, never a silent
// unconstrained run.
func TestRequiredLimitsFailStartWhenUnavailable(t *testing.T) {
	cfg := fakeConfig(t)
	cfg.RequireLimits = true
	cfg.Limits = plugin.ResourceLimits{MemoryMB: 64}
	cfg.limitInstaller = func(int, plugin.ResourceLimits) (resourceHandle, error) {
		return nil, ErrLimitsUnsupported
	}
	h, err := New(cfg)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if err := h.Start(context.Background()); err == nil {
		t.Fatal("Start succeeded despite required limits being unavailable")
	}
	select {
	case <-h.Exited():
	case <-time.After(3 * time.Second):
		t.Fatal("failed-start child was not reaped")
	}
}

// TestLimitSetupFailureIsFatalInProduction pins the difference between
// production (RequireLimits) and development hosts when limit installation
// fails.
func TestLimitSetupFailureIsFatalInProduction(t *testing.T) {
	failing := func(int, plugin.ResourceLimits) (resourceHandle, error) {
		return nil, errors.New("injected limit failure")
	}

	t.Run("production_fails_closed", func(t *testing.T) {
		cfg := fakeConfig(t)
		cfg.RequireLimits = true
		cfg.Limits = plugin.ResourceLimits{MemoryMB: 64}
		cfg.limitInstaller = failing
		h, err := New(cfg)
		if err != nil {
			t.Fatalf("New: %v", err)
		}
		if err := h.Start(context.Background()); err == nil {
			t.Fatal("Start succeeded despite limit setup failure in production")
		}
		select {
		case <-h.Exited():
		case <-time.After(3 * time.Second):
			t.Fatal("failed-start child was not reaped")
		}
	})

	t.Run("dev_continues", func(t *testing.T) {
		cfg := fakeConfig(t)
		cfg.RequireLimits = false
		cfg.Limits = plugin.ResourceLimits{MemoryMB: 64}
		cfg.limitInstaller = failing
		h := startFakeConfig(t, cfg)
		if _, err := h.Invoke(context.Background(), "tool.provider", "echo", []byte("ok")); err != nil {
			t.Fatalf("Invoke after non-required limit failure: %v", err)
		}
	})
}

// TestTerminationIncludesExitAndResourceEvidence proves forced termination
// emits exit and resource evidence through the telemetry seam.
func TestTerminationIncludesExitAndResourceEvidence(t *testing.T) {
	sink := &recordingSink{}
	cfg := fakeConfig(t)
	cfg.Sink = sink
	cfg.Limits = plugin.ResourceLimits{MemoryMB: 256, MaxProcesses: 4, CPUSeconds: 30}
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
	if ev.Limits.MemoryMB != 256 || ev.Limits.MaxProcesses != 4 || ev.Limits.CPUSeconds != 30 {
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

// TestNoChildSurvivesHostStop proves descendants are contained: a grandchild
// spawned by the plugin cannot outlive the host.
func TestNoChildSurvivesHostStop(t *testing.T) {
	dir := t.TempDir()
	marker := filepath.Join(dir, "grandchild")

	h := startFake(t)
	if _, err := h.Invoke(context.Background(), "tool.provider", "spawn", []byte(marker)); err != nil {
		t.Fatalf("spawn grandchild: %v", err)
	}
	waitForFile(t, marker+".started", 3*time.Second)

	if err := h.Stop(context.Background()); err != nil {
		t.Fatalf("Stop: %v", err)
	}

	// The grandchild writes its liveness marker 2s after start; give it more
	// than that to surface if it survived Stop.
	time.Sleep(2500 * time.Millisecond)
	if _, err := os.Stat(marker + ".alive"); err == nil {
		t.Fatal("grandchild survived host Stop")
	}
}

// TestSuspendedSpawnContainsEarlyGrandchild proves the post-spawn containment
// window is closed on Windows when limits are required: the child is created
// suspended, bound to the Job Object, then resumed, so a grandchild spawned as
// the plugin's first action is already inside the containment unit and dies
// with it.
func TestSuspendedSpawnContainsEarlyGrandchild(t *testing.T) {
	if runtime.GOOS != "windows" {
		t.Skip("suspended-spawn containment is Windows-specific")
	}
	dir := t.TempDir()
	marker := filepath.Join(dir, "early-gc")

	cfg := fakeConfig(t, "FAKE_SPAWN_ON_START="+marker)
	cfg.RequireLimits = true
	cfg.Limits = plugin.ResourceLimits{MemoryMB: 512}
	h := startFakeConfig(t, cfg)

	// The grandchild ran, proving the suspended child was resumed after the
	// job assignment completed.
	waitForFile(t, marker+".started", 3*time.Second)

	if err := h.Stop(context.Background()); err != nil {
		t.Fatalf("Stop: %v", err)
	}
	time.Sleep(2500 * time.Millisecond)
	if _, err := os.Stat(marker + ".alive"); err == nil {
		t.Fatal("grandchild spawned during startup escaped containment")
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

// TestContainmentOrderingAssignBeforeResume deterministically pins the
// containment pipeline order: the limit installer (job assignment) must
// complete before the suspended child is resumed. It is independent of timing.
func TestContainmentOrderingAssignBeforeResume(t *testing.T) {
	var mu sync.Mutex
	var order []string
	assigned := false

	cfg := fakeConfig(t)
	cfg.RequireLimits = true
	cfg.limitInstaller = func(pid int, limits plugin.ResourceLimits) (resourceHandle, error) {
		mu.Lock()
		order = append(order, "assign")
		mu.Unlock()
		rh, err := assignLimits(pid, limits)
		if err == nil {
			mu.Lock()
			assigned = true
			mu.Unlock()
		}
		return rh, err
	}
	cfg.resumeInstaller = func(pid int) error {
		mu.Lock()
		order = append(order, "resume")
		ready := assigned
		mu.Unlock()
		if !ready {
			t.Error("resume invoked before containment assignment completed")
		}
		// Delegate to the real resume so the child actually runs.
		return resumeProcess(pid)
	}

	h := startFakeConfig(t, cfg)
	_ = h

	mu.Lock()
	defer mu.Unlock()
	if len(order) != 2 || order[0] != "assign" || order[1] != "resume" {
		t.Fatalf("containment ordering = %v, want [assign resume]", order)
	}
}

// TestResumeNotInvokedWhenAssignmentFails proves the resume step is skipped
// when containment cannot be installed.
func TestResumeNotInvokedWhenAssignmentFails(t *testing.T) {
	resumed := false
	cfg := fakeConfig(t)
	cfg.RequireLimits = true
	cfg.limitInstaller = func(int, plugin.ResourceLimits) (resourceHandle, error) {
		return nil, errors.New("injected assignment failure")
	}
	cfg.resumeInstaller = func(int) error {
		resumed = true
		return nil
	}
	h, err := New(cfg)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if err := h.Start(context.Background()); err == nil {
		t.Fatal("Start succeeded despite assignment failure")
	}
	if resumed {
		t.Fatal("resume invoked after assignment failure")
	}
	select {
	case <-h.Exited():
	case <-time.After(3 * time.Second):
		t.Fatal("failed-start child was not reaped")
	}
}

// TestConfigureProcessStartsSuspended pins the platform suspend/resume
// primitive directly: a child configured suspended does not execute until
// resumeProcess releases it, which is what closes the post-spawn containment
// window.
func TestConfigureProcessStartsSuspended(t *testing.T) {
	if runtime.GOOS != "windows" {
		t.Skip("CREATE_SUSPENDED is Windows-specific")
	}
	dir := t.TempDir()
	marker := filepath.Join(dir, "suspended")

	exe, err := os.Executable()
	if err != nil {
		t.Fatalf("os.Executable: %v", err)
	}
	cmd := exec.Command(exe, "-test.run=^$")
	cmd.Env = append(os.Environ(),
		"PRAXOVELA_FAKE_GRANDCHILD=1",
		"FAKE_GRANDCHILD_MARKER="+marker,
	)
	configureProcess(cmd, true)
	if err := cmd.Start(); err != nil {
		t.Fatalf("start suspended: %v", err)
	}
	defer func() { _ = cmd.Process.Kill(); _ = cmd.Wait() }()

	// While suspended the entrypoint must not have run. Poll over a short
	// window rather than a single sleep so a slow scheduler cannot be mistaken
	// for suspension, and any early execution is caught.
	for i := 0; i < 20; i++ {
		if _, err := os.Stat(marker + ".started"); err == nil {
			t.Fatal("suspended child ran before resume; CREATE_SUSPENDED was not applied")
		}
		time.Sleep(25 * time.Millisecond)
	}

	if err := resumeProcess(cmd.Process.Pid); err != nil {
		t.Fatalf("resumeProcess: %v", err)
	}
	waitForFile(t, marker+".started", 3*time.Second)
}

// failingSink always rejects an event, for surfacing tests.
type failingSink struct{ err error }

func (s failingSink) RecordPluginEvent(context.Context, plugin.Event) error { return s.err }

// stubHandle is a no-op resource supervisor for injectable start-path tests.
type stubHandle struct{}

func (stubHandle) Close() error                         { return nil }
func (stubHandle) Usage() (plugin.ResourceUsage, error) { return plugin.ResourceUsage{}, nil }

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
