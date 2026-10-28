package process

import (
	"bufio"
	"context"
	"encoding/json"
	"net"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"sync"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/plugin"
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
	dieAfterHealth := os.Getenv("FAKE_DIE_AFTER_HEALTH")

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
			if dieAfterHealth != "" {
				conn, err := net.DialTimeout("tcp", dieAfterHealth, 3*time.Second)
				if err != nil {
					os.Exit(7)
				}
				var signal [1]byte
				if _, err := conn.Read(signal[:]); err != nil || signal[0] != 1 {
					os.Exit(8)
				}
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
