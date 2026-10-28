package process

import (
	"context"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"sync"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/plugin"
)

// TestMemoryLimitTerminatesChild proves the configured memory limit is real:
// the same allocation succeeds unconstrained and kills the child when bounded.
func TestMemoryLimitTerminatesChild(t *testing.T) {
	if runtime.GOOS != "windows" && runtime.GOOS != "linux" {
		t.Skipf("resource limits unsupported on %s", runtime.GOOS)
	}
	if runtime.GOOS == "linux" {
		t.Skip("RLIMIT_AS is unreliable against the Go test-binary fixture; Windows Job Object covers the memory limit")
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
	if runtime.GOOS == "linux" {
		t.Skip("RLIMIT_NPROC is UID-wide and interacts with Go runtime threads; Windows Job Object covers process-count containment")
	}
	if os.Geteuid() == 0 {
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

// TestNoChildSurvivesHostStop proves descendants are contained: a grandchild
// spawned by the plugin cannot outlive the host.
func TestNoChildSurvivesHostStop(t *testing.T) {
	if runtime.GOOS != "windows" && runtime.GOOS != "linux" {
		t.Skipf("process containment unsupported on %s", runtime.GOOS)
	}
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

// TestContainmentOrderingAssignBeforeResume deterministically pins the
// containment pipeline order: the limit installer (job assignment) must
// complete before the suspended child is resumed. It is independent of timing.
func TestContainmentOrderingAssignBeforeResume(t *testing.T) {
	if runtime.GOOS != "windows" && runtime.GOOS != "linux" {
		t.Skipf("resource limits unsupported on %s", runtime.GOOS)
	}
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

// stubHandle is a no-op resource supervisor for injectable start-path tests.
type stubHandle struct{}

func (stubHandle) Close() error                         { return nil }
func (stubHandle) Usage() (plugin.ResourceUsage, error) { return plugin.ResourceUsage{}, nil }
