// Package process implements the Process Plugin Host of the Runtime Plugin
// Plane: it runs a runtime plugin as a child process and mediates typed
// invocations over a local authenticated JSON-Lines channel on the child's
// stdio. The channel is authenticated by a per-process random token
// provisioned to the child via environment, never argv.
//
// The host enforces process containment and resource limits through the
// platform supervisor (a Windows Job Object or POSIX per-process rlimits),
// bounds invocations by the caller context and the configured InvokeTimeout,
// and guarantees cancellation: a canceled or timed-out invocation terminates
// the child process, reaps it, fails sibling calls, and emits terminal
// evidence. The package is stdlib-only apart from the platform supervisor.
//
// Containment guarantees are platform-specific and intentional:
//
//   - Windows (RequireLimits): the child is created suspended and assigned to
//     a kill-on-close Job Object before it runs, so it cannot spawn an
//     unaccounted descendant in the post-spawn window. Assignment or resume
//     failure is a start error.
//   - Linux: containment uses per-process rlimits plus a dedicated process
//     group (Setpgid) that is SIGKILLed as a tree. RLIMIT_NPROC counts all
//     processes of the real UID system-wide rather than per-containment, and a
//     child that calls setsid(2) leaves the process group. Linux therefore
//     does not provide the same hard containment guarantee as the Windows Job
//     Object; see limits_linux.go.
//   - Other platforms: no supervisor; a RequireLimits host fails to start.
package process

import (
	"bufio"
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"os/exec"
	"sync"
	"sync/atomic"
	"time"

	"github.com/axisvela/praxo-core/pkg/plugin"
)

// Well-known host control channel. The plugin must answer health during
// Start, abandon in-flight work on cancel, and exit cleanly after shutdown.
const (
	ControlService = "host.control"
	MethodHealth   = "health"
	MethodShutdown = "shutdown"
	// MethodCancel asks a plugin to abandon an in-flight invocation. It is best
	// effort: an uncooperative plugin is force-terminated after CancelGrace.
	MethodCancel = "cancel"
)

// CodeCanceled classifies an invocation terminated by caller cancellation,
// keeping it distinct from a deadline (plugin.CodeTimeout). It mirrors the
// WASM host's typed cancellation.
const CodeCanceled plugin.CallErrorCode = "CANCELED"

// tokenEnvVar carries the per-process channel token to the child.
const tokenEnvVar = "PRAXOVELA_PLUGIN_TOKEN"

// Host defaults and bounds.
const (
	DefaultStartTimeout  = 10 * time.Second
	DefaultInvokeTimeout = 30 * time.Second
	DefaultGracePeriod   = 5 * time.Second
	// DefaultCancelGrace bounds the cooperative window between a cancel frame
	// and forced termination of an uncooperative child.
	DefaultCancelGrace = 250 * time.Millisecond
	// DefaultMaxFrame bounds one wire frame (request or response line).
	DefaultMaxFrame = 8 << 20
	// maxStderrCapture bounds captured child stderr for diagnostics.
	maxStderrCapture = 16 << 10
	// forceReapTimeout bounds how long forceTerminate waits for a killed child
	// to be reaped before returning.
	forceReapTimeout = 5 * time.Second
)

// traceTier mirrors sandbox.Tier1 (process isolation) without importing the
// sandbox package from a host implementation.
const traceTier = 1

// ErrLimitsUnsupported reports that the platform has no resource-limit
// supervisor. A RequireLimits host fails to start rather than running
// unconstrained.
var ErrLimitsUnsupported = errors.New("pluginrt/process: resource limits unsupported on this platform")

// resourceHandle is the platform supervisor bound to one plugin process. Its
// Usage must be read before Close; Close releases the containment and (on
// Windows) kills any surviving descendant.
type resourceHandle interface {
	Close() error
	Usage() (plugin.ResourceUsage, error)
}

// Config describes one process plugin to host.
type Config struct {
	// PluginID is the runtime plugin instance identity.
	PluginID string
	// Provider identifies the selected provider, carried on every event so
	// evidence names the authority behind an invocation (G2-9/G2-10).
	Provider plugin.ProviderIdentity
	// Sink receives structured telemetry; nil disables emission in
	// development. A production host must set Sink (see RequireEvidence).
	Sink plugin.TelemetrySink
	// RequireEvidence makes a nil Sink a construction error, so a production
	// host can never silently drop security evidence.
	RequireEvidence bool
	// OnEvidenceError is invoked whenever the durable sink rejects an event.
	// Terminal/containment evidence cannot fail the caller (the child is
	// already gone), so this hook makes a dropped fact observable instead of
	// silently lost. In a RequireEvidence host with no hook, the failure is
	// logged.
	OnEvidenceError func(error)
	// Path is the plugin executable; Args and Dir are child argv/cwd.
	Path string
	Args []string
	Dir  string
	// Env, when non-nil, replaces the child environment base. The channel
	// token is always appended by the host.
	Env []string
	// Token overrides the channel token; empty generates a random one.
	Token string
	// TokenEnvVar overrides the environment variable that carries the channel
	// token to the child. Empty applies the v1 default.
	TokenEnvVar string
	// StartTimeout bounds spawn + health handshake.
	StartTimeout time.Duration
	// InvokeTimeout is the default per-call bound when the caller's context
	// has no earlier deadline.
	InvokeTimeout time.Duration
	// GracePeriod bounds graceful shutdown before Stop escalates to Kill.
	GracePeriod time.Duration
	// CancelGrace bounds the cooperative window between a cancel frame and
	// forced termination. Zero applies DefaultCancelGrace.
	CancelGrace time.Duration
	// MaxFrame bounds one wire frame in bytes.
	MaxFrame int
	// Limits bounds the plugin process's resource consumption. On Windows the
	// limits are applied to a kill-on-close Job Object; on Linux as
	// per-process rlimits.
	Limits plugin.ResourceLimits
	// RequireLimits, when true, makes failure to install the platform
	// supervisor a Start error. It must be true in production so limits can
	// never silently degrade to a no-op.
	RequireLimits bool

	// limitInstaller, when non-nil, replaces the platform limit installer for
	// this host only. It is a test seam for injecting assignment outcomes;
	// nil uses the platform implementation. Keeping it per-Config (rather than
	// a package global) makes hosts independent and race-free under parallel
	// tests.
	limitInstaller func(pid int, limits plugin.ResourceLimits) (resourceHandle, error)

	// resumeInstaller, when non-nil, replaces the resume step that releases a
	// suspended child after containment is installed. It is a test seam for
	// deterministically asserting the assign-before-resume ordering; nil uses
	// the platform implementation.
	resumeInstaller func(pid int) error
}

func (c Config) withDefaults() Config {
	if c.StartTimeout <= 0 {
		c.StartTimeout = DefaultStartTimeout
	}
	if c.InvokeTimeout <= 0 {
		c.InvokeTimeout = DefaultInvokeTimeout
	}
	if c.GracePeriod <= 0 {
		c.GracePeriod = DefaultGracePeriod
	}
	if c.CancelGrace <= 0 {
		c.CancelGrace = DefaultCancelGrace
	}
	if c.MaxFrame <= 0 {
		c.MaxFrame = DefaultMaxFrame
	}
	return c
}

// Host owns one plugin child process and its authenticated RPC channel.
type Host struct {
	cfg   Config
	token string

	cmd    *exec.Cmd
	stdin  io.WriteCloser
	stderr *boundedBuffer

	resMu     sync.Mutex
	resources resourceHandle
	resOnce   sync.Once

	writeMu sync.Mutex

	termOnce   sync.Once
	termReason string

	mu      sync.Mutex
	pending map[string]chan Response
	started bool
	stopped bool
	done    bool
	exitErr error

	seq    atomic.Uint64
	exited chan struct{}
	wg     sync.WaitGroup
}

// New validates cfg and returns a host ready to Start.
func New(cfg Config) (*Host, error) {
	if cfg.PluginID == "" {
		return nil, errors.New("pluginrt/process: PluginID is required")
	}
	if cfg.Path == "" {
		return nil, errors.New("pluginrt/process: Path is required")
	}
	if cfg.RequireEvidence && cfg.Sink == nil {
		return nil, errors.New("pluginrt/process: evidence sink is required in production")
	}
	token := cfg.Token
	if token == "" {
		buf := make([]byte, 32)
		if _, err := rand.Read(buf); err != nil {
			return nil, fmt.Errorf("pluginrt/process: generate token: %w", err)
		}
		token = hex.EncodeToString(buf)
	}
	return &Host{
		cfg:     cfg.withDefaults(),
		token:   token,
		pending: make(map[string]chan Response),
		exited:  make(chan struct{}),
	}, nil
}

// Start spawns the plugin process, installs the platform resource supervisor,
// provisions the channel token via environment, and completes the health
// handshake within StartTimeout. When RequireLimits is set, an uninstallable
// supervisor is a start error and the child is reaped.
func (h *Host) Start(ctx context.Context) error {
	h.mu.Lock()
	if h.started {
		h.mu.Unlock()
		return errors.New("pluginrt/process: host already started")
	}
	h.mu.Unlock()

	cmd := exec.Command(h.cfg.Path, h.cfg.Args...)
	cmd.Dir = h.cfg.Dir
	// When limits are required, spawn the child suspended on Windows so it is
	// bound to the Job Object before it executes a single instruction; this
	// closes the post-spawn window in which a descendant could escape
	// containment. Platforms without a suspend primitive ignore this.
	suspend := h.cfg.RequireLimits
	configureProcess(cmd, suspend)
	if h.cfg.Env != nil {
		cmd.Env = append([]string(nil), h.cfg.Env...)
	}
	envVar := h.cfg.TokenEnvVar
	if envVar == "" {
		envVar = tokenEnvVar
	}
	cmd.Env = append(cmd.Env, envVar+"="+h.token)

	stdin, err := cmd.StdinPipe()
	if err != nil {
		return fmt.Errorf("pluginrt/process: stdin pipe: %w", err)
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("pluginrt/process: stdout pipe: %w", err)
	}
	h.stderr = &boundedBuffer{max: maxStderrCapture}
	cmd.Stderr = h.stderr

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("pluginrt/process: spawn %s: %w", h.cfg.Path, err)
	}

	// Install the containment/limit supervisor before the child runs (it is
	// suspended when required) so no invocation, and no descendant, can run
	// unconstrained. Assignment failure is fatal in production (RequireLimits)
	// and degrades to an unconstrained dev host otherwise.
	handle, lerr := h.applyLimits(cmd.Process.Pid)
	if lerr != nil {
		if h.cfg.RequireLimits {
			_ = cmd.Process.Kill()
			_ = cmd.Wait()
			h.markExited(lerr)
			// A production host that cannot install containment fails closed;
			// record why so the failure is a durable fact, not just an error
			// returned to the caller.
			h.emitTerminal(plugin.EventResourceLimit, map[string]any{
				"reason": "limits_install_failed",
				"error":  lerr.Error(),
			}, plugin.ResourceUsage{})
			h.closeResources()
			return fmt.Errorf("pluginrt/process: apply resource limits: %w", lerr)
		}
		// Development host: continue unconstrained rather than fail. The
		// production assembly sets RequireLimits so this path is unreachable.
	} else {
		h.resMu.Lock()
		h.resources = handle
		h.resMu.Unlock()
	}

	// Resume the suspended child only after it is contained. Assignment must
	// complete first; the ordering is pinned by tests via resumeInstaller.
	if suspend {
		resume := resumeProcess
		if h.cfg.resumeInstaller != nil {
			resume = h.cfg.resumeInstaller
		}
		if rerr := resume(cmd.Process.Pid); rerr != nil {
			_ = cmd.Process.Kill()
			_ = cmd.Wait()
			h.markExited(rerr)
			h.emitTerminal(plugin.EventTerminated, map[string]any{
				"reason": "resume_failed",
				"error":  rerr.Error(),
			}, plugin.ResourceUsage{})
			h.closeResources()
			return fmt.Errorf("pluginrt/process: resume suspended child: %w", rerr)
		}
	}

	h.mu.Lock()
	h.cmd = cmd
	h.stdin = stdin
	h.mu.Unlock()

	h.wg.Add(2)
	go h.waitLoop()
	go h.readLoop(stdout)

	h.mu.Lock()
	h.started = true
	h.mu.Unlock()

	// Emit start lifecycle event
	_ = h.emit(ctx, plugin.EventStart, ControlService, MethodHealth,
		"", nil, traceTier)

	healthCtx, cancel := context.WithTimeout(ctx, h.cfg.StartTimeout)
	defer cancel()
	if _, err := h.roundtrip(healthCtx, ControlService, MethodHealth, nil); err != nil {
		reason := "start_failed"
		var ce *plugin.CallError
		if errors.As(err, &ce) && ce.Code() == plugin.CodeTimeout {
			reason = "start_timeout"
		}
		h.forceTerminate(reason)
		h.wg.Wait()
		return fmt.Errorf("pluginrt/process: health handshake: %w", err)
	}
	return nil
}

// applyLimits installs the platform supervisor, honoring the per-host
// injection seam.
func (h *Host) applyLimits(pid int) (resourceHandle, error) {
	if h.cfg.limitInstaller != nil {
		return h.cfg.limitInstaller(pid, h.cfg.Limits)
	}
	return assignLimits(pid, h.cfg.Limits)
}

// active reports whether the host can execute calls.
func (h *Host) active() bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.started && !h.stopped && !h.done
}

// Invoke sends one typed request and awaits the response, bounded by the
// host's InvokeTimeout and the caller's context. A deadline or cancellation is
// terminal: the child is terminated and reaped, and sibling calls fail.
// Failures are typed plugin.CallError values.
func (h *Host) Invoke(ctx context.Context, service, method string, payload []byte) ([]byte, error) {
	if !h.active() {
		err := plugin.NewCallError(plugin.CodeNotActive, h.cfg.PluginID, service, method, "host not active")
		_ = h.emit(ctx, plugin.EventFailure, service, method,
			"", map[string]interface{}{"code": string(plugin.CodeNotActive)}, traceTier)
		return nil, err
	}

	start := time.Now()
	callCtx, cancel := context.WithTimeout(ctx, h.cfg.InvokeTimeout)
	defer cancel()
	resp, err := h.roundtrip(callCtx, service, method, payload)
	if err != nil {
		code := string(plugin.CodeInternal)
		var ce *plugin.CallError
		if errors.As(err, &ce) {
			code = string(ce.Code())
			switch ce.Code() {
			case plugin.CodeTimeout:
				h.forceTerminate("invoke_timeout")
			case CodeCanceled:
				h.forceTerminate("invoke_canceled")
			}
		}
		_ = h.emit(callCtx, plugin.EventFailure, service, method,
			"", map[string]interface{}{"code": code, "duration_ms": time.Since(start).Milliseconds()}, traceTier)
		return nil, err
	}
	_ = h.emit(callCtx, plugin.EventSuccess, service, method,
		"", map[string]interface{}{"duration_ms": time.Since(start).Milliseconds()}, traceTier)
	return resp.Payload, nil
}

// roundtrip performs one request/response exchange without lifecycle gating.
// A done context yields a typed CallError but does not itself terminate the
// child; callers decide whether the failure is terminal.
func (h *Host) roundtrip(ctx context.Context, service, method string, payload []byte) (Response, error) {
	id := fmt.Sprintf("%s-%d", h.cfg.PluginID, h.seq.Add(1))
	req := Request{
		ID:       id,
		Version:  ProtocolVersion,
		PluginID: h.cfg.PluginID,
		Service:  service,
		Method:   method,
		Token:    h.token,
		Payload:  payload,
	}

	frame, err := json.Marshal(req)
	if err != nil {
		return Response{}, plugin.NewCallError(plugin.CodeInvalidRequest, h.cfg.PluginID, service, method, "marshal: "+err.Error())
	}
	frame = append(frame, '\n')
	if len(frame) > h.cfg.MaxFrame {
		return Response{}, plugin.NewCallError(plugin.CodeInvalidRequest, h.cfg.PluginID, service, method, "request frame exceeds MaxFrame")
	}

	ch := make(chan Response, 1)
	h.mu.Lock()
	if h.exitErr != nil {
		h.mu.Unlock()
		return Response{}, plugin.NewCallError(plugin.CodeNotActive, h.cfg.PluginID, service, method, "plugin process not running")
	}
	h.pending[id] = ch
	h.mu.Unlock()
	defer h.unregister(id)

	h.writeMu.Lock()
	_, werr := h.stdin.Write(frame)
	h.writeMu.Unlock()
	if werr != nil {
		return Response{}, plugin.NewCallError(plugin.CodeInternal, h.cfg.PluginID, service, method, "write: "+werr.Error())
	}

	select {
	case resp := <-ch:
		if !resp.OK {
			return Response{}, resp.callError(h.cfg.PluginID, service, method)
		}
		return resp, nil
	case <-h.exited:
		return Response{}, plugin.NewCallError(plugin.CodeInternal, h.cfg.PluginID, service, method, "plugin process exited")
	case <-ctx.Done():
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			return Response{}, plugin.NewCallError(plugin.CodeTimeout, h.cfg.PluginID, service, method, "invoke deadline exceeded")
		}
		return Response{}, plugin.NewCallError(CodeCanceled, h.cfg.PluginID, service, method, "invoke canceled")
	}
}

// Stop gracefully shuts the plugin down: it sends the shutdown control
// request, waits up to GracePeriod, then force-terminates an uncooperative
// child and any descendants. Stop is idempotent and reaps all host goroutines
// before returning.
func (h *Host) Stop(ctx context.Context) error {
	h.mu.Lock()
	if h.stopped {
		h.mu.Unlock()
		return nil
	}
	h.stopped = true
	started := h.started
	h.mu.Unlock()
	if !started {
		return nil
	}

	// The terminal stop/crash lifecycle event is emitted exactly once by
	// waitLoop (carrying exit and resource evidence). Stop must not emit a
	// duplicate stop event.
	graceCtx, cancel := context.WithTimeout(ctx, h.cfg.GracePeriod)
	defer cancel()
	_, _ = h.roundtrip(graceCtx, ControlService, MethodShutdown, nil)

	select {
	case <-h.exited:
	case <-graceCtx.Done():
		h.forceTerminate("shutdown_timeout")
	}

	// Ensure no descendant survives Stop (POSIX process group; the Windows Job
	// Object is killed on handle close). waitLoop is the sole owner of
	// resource usage capture and handle release, so Stop does not close the
	// supervisor early (that could race usage capture and lose evidence).
	h.killTree()
	h.wg.Wait()
	return nil
}

// forceTerminate runs the cancellation protocol exactly once: send a cancel
// frame, allow a bounded cooperative grace, then force-kill the process tree
// and wait for it to be reaped. Concurrent callers block until the window
// closes.
func (h *Host) forceTerminate(reason string) {
	h.termOnce.Do(func() {
		h.mu.Lock()
		h.termReason = reason
		h.mu.Unlock()

		h.sendCancelFrame()

		select {
		case <-h.exited:
		case <-time.After(h.cfg.CancelGrace):
		}

		// Always contain the tree: a cooperative child may have exited while a
		// descendant survives (POSIX path). Killing an already-exited process
		// is harmless.
		h.killTree()

		select {
		case <-h.exited:
		case <-time.After(forceReapTimeout):
		}
	})
}

// sendCancelFrame writes a best-effort cancel control frame to the child.
func (h *Host) sendCancelFrame() {
	h.mu.Lock()
	stdin := h.stdin
	h.mu.Unlock()
	if stdin == nil {
		return
	}
	id := fmt.Sprintf("%s-cancel-%d", h.cfg.PluginID, h.seq.Add(1))
	req := Request{
		ID:       id,
		Version:  ProtocolVersion,
		PluginID: h.cfg.PluginID,
		Service:  ControlService,
		Method:   MethodCancel,
		Token:    h.token,
	}
	frame, err := json.Marshal(req)
	if err != nil {
		return
	}
	frame = append(frame, '\n')
	h.writeMu.Lock()
	defer h.writeMu.Unlock()
	_, _ = stdin.Write(frame)
}

// killTree force-kills the plugin process tree using the platform supervisor.
func (h *Host) killTree() {
	h.resMu.Lock()
	rh := h.resources
	h.resMu.Unlock()
	killProcessTree(rh, h.cmd)
}

// resourceUsage reads supervisor usage before the handle is released.
func (h *Host) resourceUsage() plugin.ResourceUsage {
	h.resMu.Lock()
	rh := h.resources
	h.resMu.Unlock()
	if rh == nil {
		return plugin.ResourceUsage{}
	}
	u, err := rh.Usage()
	if err != nil {
		return plugin.ResourceUsage{}
	}
	return u
}

// closeResources releases the supervisor handle exactly once.
func (h *Host) closeResources() {
	h.resOnce.Do(func() {
		h.resMu.Lock()
		rh := h.resources
		h.resources = nil
		h.resMu.Unlock()
		if rh != nil {
			_ = rh.Close()
		}
	})
}

// Exited returns a channel closed when the plugin process exits, enabling
// crash detection by the caller.
func (h *Host) Exited() <-chan struct{} {
	return h.exited
}

// ExitError reports how the plugin process exited, or nil if it exited
// cleanly or is still running.
func (h *Host) ExitError() error {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.exitErr
}

// Healthy is the health probe the production assembly gates activation on. A
// process host is healthy while the child is running and has not exited; a
// dead/exited/reaped child is unhealthy, so the assembly never activates (or
// keeps ACTIVE) a host whose controlled execution is gone.
func (h *Host) Healthy(context.Context) error {
	if h.active() {
		return nil
	}
	if err := h.ExitError(); err != nil {
		return fmt.Errorf("pluginrt/process: unhealthy: process exited: %w", err)
	}
	return errors.New("pluginrt/process: unhealthy: process not active")
}

// waitLoop is the sole owner of the child's terminal bookkeeping: it reaps the
// process, captures resource usage while the supervisor handle is still open,
// emits terminal evidence (crash for an abnormal exit, stop for a clean one),
// then releases the supervisor.
func (h *Host) waitLoop() {
	defer h.wg.Done()
	err := h.cmd.Wait()
	h.markExited(err)

	usage := h.resourceUsage()
	h.closeResources()

	h.mu.Lock()
	reason := h.termReason
	h.mu.Unlock()

	outcome := map[string]interface{}{
		"exit_clean": err == nil,
		"exit_code":  exitCodeOf(err),
	}
	if err != nil {
		outcome["exit_error"] = err.Error()
	}
	if reason != "" {
		outcome["reason"] = reason
	}
	// A clean exit is a stop, not a crash. A cancellation is a distinct
	// EventCanceled; an invocation time-limit hit is a distinct
	// EventResourceLimit; any other abnormal exit or forced termination is
	// EventTerminated. All terminal facts carry the enforced limits and
	// observed usage.
	kind := plugin.EventStop
	switch {
	case reason == "invoke_canceled":
		kind = plugin.EventCanceled
	case reason == "invoke_timeout":
		kind = plugin.EventResourceLimit
	case err != nil || reason != "":
		kind = plugin.EventTerminated
	}
	h.emitTerminal(kind, outcome, usage)
	h.failPending("plugin process exited")
}

// exitCodeOf extracts a process exit code from a Wait error.
func exitCodeOf(err error) int {
	if err == nil {
		return 0
	}
	var ee *exec.ExitError
	if errors.As(err, &ee) {
		return ee.ExitCode()
	}
	return -1
}

// markExited records terminal state exactly once and closes the stable Exited
// channel. A later non-nil error is retained if the first carried none.
func (h *Host) markExited(err error) bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.done {
		if h.exitErr == nil && err != nil {
			h.exitErr = err
		}
		return false
	}
	h.done = true
	h.exitErr = err
	close(h.exited)
	return true
}

// readLoop decodes response frames and dispatches by request ID.
func (h *Host) readLoop(stdout io.Reader) {
	defer h.wg.Done()
	scanner := bufio.NewScanner(stdout)
	scanner.Buffer(make([]byte, 64<<10), h.cfg.MaxFrame)
	for scanner.Scan() {
		var resp Response
		if json.Unmarshal(scanner.Bytes(), &resp) != nil {
			continue
		}
		h.mu.Lock()
		ch, ok := h.pending[resp.ID]
		if ok {
			delete(h.pending, resp.ID)
		}
		h.mu.Unlock()
		if ok {
			// Emit success event when a response is delivered
			_ = h.emit(nil, plugin.EventSuccess,
				"", "", resp.ID, map[string]interface{}{"status": "delivered"}, traceTier)
			ch <- resp
		}
	}
	// Channel closed without delivery - emit failure
	_ = h.emit(nil, plugin.EventFailure,
		"", "", "channel_closed", map[string]interface{}{"reason": "plugin channel closed"}, traceTier)
	h.failPending("plugin channel closed")
}

// failPending terminates every outstanding call with an internal error.
func (h *Host) failPending(message string) {
	h.mu.Lock()
	orphans := h.pending
	h.pending = make(map[string]chan Response)
	h.mu.Unlock()
	for id, ch := range orphans {
		ch <- Response{
			ID:      id,
			Version: ProtocolVersion,
			OK:      false,
			Code:    string(plugin.CodeInternal),
			Message: message,
		}
	}
}

// unregister removes id from pending if the read loop has not delivered.
func (h *Host) unregister(id string) {
	h.mu.Lock()
	delete(h.pending, id)
	h.mu.Unlock()
}

// boundedBuffer captures a byte stream up to max bytes and discards the rest.
type boundedBuffer struct {
	buf bytes.Buffer
	max int
}

func (b *boundedBuffer) Write(p []byte) (int, error) {
	if remaining := b.max - b.buf.Len(); remaining > 0 {
		if len(p) > remaining {
			b.buf.Write(p[:remaining])
		} else {
			b.buf.Write(p)
		}
	}
	return len(p), nil
}

// record stamps the host identity onto ev and writes it to the sink. A rejected
// event is surfaced through OnEvidenceError (logged in a RequireEvidence host
// with no hook) so terminal evidence is never silently lost; the error is still
// returned so a denial caller can fail closed.
func (h *Host) record(ctx context.Context, ev plugin.Event) error {
	if h.cfg.Sink == nil {
		return nil
	}
	if ev.PluginID == "" {
		ev.PluginID = h.cfg.PluginID
	}
	if ev.Provider.ID == "" {
		ev.Provider = h.cfg.Provider
	}
	if err := h.cfg.Sink.RecordPluginEvent(ctx, ev); err != nil {
		h.reportEvidenceError(err)
		return err
	}
	return nil
}

// reportEvidenceError makes a dropped evidence fact observable.
func (h *Host) reportEvidenceError(err error) {
	if h.cfg.OnEvidenceError != nil {
		h.cfg.OnEvidenceError(err)
		return
	}
	if h.cfg.RequireEvidence {
		log.Printf("pluginrt/process: dropped evidence event: %v", err)
	}
}

// emit builds a structured event from the positional host call sites and
// records it. The error is returned so a caller recording a security-relevant
// fact can fail closed; lifecycle call sites without a stronger error path
// discard it (the hook still surfaces it).
func (h *Host) emit(ctx context.Context, kind plugin.EventKind, service, method, requestID string, detail map[string]any, sandboxTier int) error {
	ev := plugin.Event{
		Kind:        kind,
		Service:     service,
		Method:      method,
		RequestID:   requestID,
		SandboxTier: sandboxTier,
		Detail:      detail,
	}
	if c, ok := detail["code"].(string); ok {
		ev.Code = c
	}
	return h.record(ctx, ev)
}

// emitTerminal records the single terminal stop/cancel/limit/terminate fact
// with the enforced limits and observed usage attached, so resource evidence is
// complete.
func (h *Host) emitTerminal(kind plugin.EventKind, detail map[string]any, usage plugin.ResourceUsage) {
	ev := plugin.Event{
		Kind:        kind,
		Service:     ControlService,
		SandboxTier: traceTier,
		Limits:      h.cfg.Limits,
		Usage:       usage,
		Detail:      detail,
	}
	_ = h.record(context.Background(), ev)
}
