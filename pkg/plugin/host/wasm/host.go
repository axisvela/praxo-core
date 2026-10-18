// Package wasm implements the WASM Plugin Host of the Runtime Plugin Plane.
// It runs a runtime plugin as an isolated wazero WASM/WASI module and
// mediates typed invocations over JSON-Lines frames exchanged through the
// guest's linear memory.
//
// Guest ABI contract (fail-closed if unmet):
//
//	export memory            – linear memory shared with the host
//	export alloc(len i32) i32 – bump allocator returning a pointer
//	export prax_request(ptr, len i32) – processes one request frame; MUST
//	    deliver exactly one reply by calling the imported host function below
//	import env.prax_respond(ptr, len i32) – host-provided reply channel;
//	    payload is one JSON Response frame terminated by '\n' (optional)
package wasm

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"sync"
	"sync/atomic"
	"time"

	"github.com/axisvela/praxo-core/pkg/plugin"
	"github.com/tetratelabs/wazero"
	"github.com/tetratelabs/wazero/api"
)

// Well-known host control channel.
const (
	ControlService = "host.control"
	MethodHealth   = "health"
	MethodShutdown = "shutdown"

	// Guest ABI symbols.
	guestAllocFn   = "alloc"
	guestRequestFn = "prax_request"
	hostRespondFn  = "prax_respond"
	hostModuleName = "env"

	// traceTier mirrors sandbox.Tier2 (WASM isolation) without importing the
	// sandbox package from a host implementation.
	traceTier = 2
)

// CodeCanceled classifies an invocation terminated by caller or host
// cancellation, keeping it distinct from a deadline (CodeTimeout).
const CodeCanceled plugin.CallErrorCode = "CANCELED"

// Host defaults and bounds.
const (
	DefaultStartTimeout  = 10 * time.Second
	DefaultInvokeTimeout = 30 * time.Second
	DefaultGracePeriod   = 5 * time.Second
	DefaultMaxFrame      = 8 << 20
	// DefaultMaxMemoryPages bounds guest linear memory at 16MiB (64KiB pages).
	DefaultMaxMemoryPages uint32 = 256
	// DefaultMaxConcurrency bounds simultaneous invocations. A single WASM
	// module is single-threaded, so the default serializes guest execution.
	DefaultMaxConcurrency = 1
)

// Config describes one WASM plugin to host.
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
	// Terminal/containment evidence cannot fail the caller (the guest is
	// already gone), so this hook makes a dropped fact observable instead of
	// silently lost. In a RequireEvidence host with no hook, the failure is
	// logged.
	OnEvidenceError func(error)
	// ModuleBinary is the raw .wasm image.
	ModuleBinary []byte
	// Token overrides the channel token; empty generates a random one.
	Token string
	// StartTimeout bounds compile + instantiate + health handshake.
	StartTimeout time.Duration
	// InvokeTimeout is the default per-call bound.
	InvokeTimeout time.Duration
	// GracePeriod bounds graceful shutdown before Stop force-closes.
	GracePeriod time.Duration
	// MaxFrame bounds one wire frame in bytes.
	MaxFrame int
	// MaxMemoryPages bounds guest linear memory (64KiB pages). Zero applies
	// DefaultMaxMemoryPages.
	MaxMemoryPages uint32
	// MaxConcurrency bounds simultaneous invocations. Zero (or negative)
	// applies DefaultMaxConcurrency.
	MaxConcurrency int
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
	if c.MaxFrame <= 0 {
		c.MaxFrame = DefaultMaxFrame
	}
	if c.MaxMemoryPages == 0 {
		c.MaxMemoryPages = DefaultMaxMemoryPages
	}
	if c.MaxConcurrency <= 0 {
		c.MaxConcurrency = DefaultMaxConcurrency
	}
	return c
}

// Host owns one WASM plugin instance and mediates invocations over the
// guest-memory frame bridge.
type Host struct {
	cfg   Config
	token string

	// runtime and module are guarded by mu; they are assigned during Start and
	// cleared by closeModule.
	runtime wazero.Runtime
	module  api.Module

	// writeCh is a capacity-1 lock serializing guest execution. It is
	// acquired through a context-aware select so a grace-bounded Stop can
	// return even while a CPU-bound guest holds it.
	writeCh chan struct{}

	mu      sync.Mutex
	pending map[string]chan Response
	started bool
	stopped bool
	done    bool
	exitErr error

	sem chan struct{}

	seq          atomic.Uint64
	inflight     atomic.Int64
	peakInflight atomic.Int64

	// hostCtx is cancelled by Stop to force-terminate any in-flight guest;
	// because the runtime sets CloseOnContextDone, cancelling it interrupts
	// the guest and releases writeCh.
	hostCtx    context.Context
	hostCancel context.CancelFunc

	// memoryEnforced records whether the caller explicitly configured a memory
	// bound (MaxMemoryPages > 0). A guest trap under an explicit bound is
	// attributed to that resource limit, because the guest ABI cannot
	// distinguish a memory-limit rejection from an arbitrary guest fault after
	// memory.grow returns -1 (the guest itself raises the trap).
	memoryEnforced bool

	exited chan struct{}
}

// New validates cfg and returns a host ready to Start.
func New(cfg Config) (*Host, error) {
	if cfg.PluginID == "" {
		return nil, errors.New("pluginrt/wasm: PluginID is required")
	}
	if len(cfg.ModuleBinary) == 0 {
		return nil, errors.New("pluginrt/wasm: ModuleBinary is required")
	}
	if cfg.RequireEvidence && cfg.Sink == nil {
		return nil, errors.New("pluginrt/wasm: evidence sink is required in production")
	}
	token := cfg.Token
	if token == "" {
		buf := make([]byte, 32)
		if _, err := rand.Read(buf); err != nil {
			return nil, fmt.Errorf("pluginrt/wasm: generate token: %w", err)
		}
		token = hex.EncodeToString(buf)
	}
	resolved := cfg.withDefaults()
	hostCtx, hostCancel := context.WithCancel(context.Background())
	return &Host{
		cfg:            resolved,
		token:          token,
		pending:        make(map[string]chan Response),
		sem:            make(chan struct{}, resolved.MaxConcurrency),
		writeCh:        make(chan struct{}, 1),
		hostCtx:        hostCtx,
		hostCancel:     hostCancel,
		memoryEnforced: cfg.MaxMemoryPages > 0,
		exited:         make(chan struct{}),
	}, nil
}

// Start instantiates the module, verifies the guest ABI, and completes the
// health handshake. Compilation, instantiation and the handshake are all
// bounded by StartTimeout, and the runtime is configured to enforce the
// memory limit and to terminate guest calls when a context is done.
func (h *Host) Start(ctx context.Context) error {
	h.mu.Lock()
	if h.started {
		h.mu.Unlock()
		return errors.New("pluginrt/wasm: host already started")
	}
	h.started = true
	h.mu.Unlock()

	startCtx, cancel := context.WithTimeout(ctx, h.cfg.StartTimeout)
	defer cancel()

	rt := wazero.NewRuntimeWithConfig(ctx,
		wazero.NewRuntimeConfig().
			WithMemoryLimitPages(h.cfg.MaxMemoryPages).
			WithCloseOnContextDone(true))
	h.mu.Lock()
	h.runtime = rt
	h.mu.Unlock()

	// Host-provided reply channel; the guest calls back into it.
	_, err := rt.NewHostModuleBuilder(hostModuleName).
		NewFunctionBuilder().
		WithGoModuleFunction(api.GoModuleFunc(h.guestRespond),
			[]api.ValueType{api.ValueTypeI32, api.ValueTypeI32}, nil).
		Export(hostRespondFn).
		Instantiate(startCtx)
	if err != nil {
		h.failStart(err, "start_failed")
		return fmt.Errorf("pluginrt/wasm: host module: %w", err)
	}

	mod, err := rt.InstantiateWithConfig(startCtx, h.cfg.ModuleBinary,
		wazero.NewModuleConfig().WithName(h.cfg.PluginID))
	if err != nil {
		h.failStart(err, "start_failed")
		return fmt.Errorf("pluginrt/wasm: instantiate: %w", err)
	}
	h.mu.Lock()
	h.module = mod
	h.mu.Unlock()

	// Fail closed if the guest does not implement the frame bridge.
	if mod.ExportedFunction(guestRequestFn) == nil || mod.ExportedFunction(guestAllocFn) == nil ||
		mod.Memory() == nil {
		abiErr := fmt.Errorf("pluginrt/wasm: guest must export %s, %s and memory", guestAllocFn, guestRequestFn)
		h.failStart(abiErr, "abi_mismatch")
		return abiErr
	}

	_ = h.emit(ctx, plugin.EventStart, ControlService, MethodHealth,
		"", nil, traceTier)

	if _, err := h.roundtrip(startCtx, ControlService, MethodHealth, nil); err != nil {
		reason := "start_failed"
		if errors.Is(startCtx.Err(), context.DeadlineExceeded) {
			reason = "start_timeout"
		}
		h.failStart(err, reason)
		return fmt.Errorf("pluginrt/wasm: health handshake: %w", err)
	}
	return nil
}

// failStart force-closes a partially started host and records terminal
// evidence. markExited is idempotent; the crash event is always emitted so a
// start/health deadline is observable even if the call path already recorded
// its own termination reason.
func (h *Host) failStart(err error, reason string) {
	h.markExited(err)
	if err != nil {
		_ = h.emit(context.Background(), plugin.EventTerminated, ControlService, MethodHealth,
			"", map[string]any{"reason": reason, "error": err.Error()}, traceTier)
	}
	h.closeModule(context.Background())
}

// Invoke sends one typed request and awaits the response, bounded by the
// host's InvokeTimeout, the caller's context, and the configured concurrency
// limit.
func (h *Host) Invoke(ctx context.Context, service, method string, payload []byte) ([]byte, error) {
	if !h.active() {
		return nil, h.notActive(ctx, service, method)
	}

	// Bound the number of simultaneous invocations. A cancelled caller — or a
	// host shutdown — waiting for capacity is released rather than parked.
	select {
	case h.sem <- struct{}{}:
		defer func() { <-h.sem }()
	case <-ctx.Done():
		return nil, contextCallError(ctx, h.cfg.PluginID, service, method)
	case <-h.hostCtx.Done():
		return nil, h.notActive(ctx, service, method)
	case <-h.exited:
		return nil, h.notActive(ctx, service, method)
	}

	if !h.active() {
		return nil, h.notActive(ctx, service, method)
	}

	cur := h.inflight.Add(1)
	defer h.inflight.Add(-1)
	for {
		peak := h.peakInflight.Load()
		if cur <= peak || h.peakInflight.CompareAndSwap(peak, cur) {
			break
		}
	}

	start := time.Now()
	callCtx, cancel := context.WithTimeout(ctx, h.cfg.InvokeTimeout)
	defer cancel()
	// Propagate a host-level Stop cancellation into the guest call so the
	// runtime's CloseOnContextDone terminates the guest immediately instead of
	// letting it run until InvokeTimeout.
	stopHost := context.AfterFunc(h.hostCtx, cancel)
	defer stopHost()

	resp, err := h.roundtrip(callCtx, service, method, payload)
	if err != nil {
		code := string(plugin.CodeInternal)
		if ce, ok := err.(*plugin.CallError); ok {
			code = string(ce.Code())
		}
		_ = h.emit(callCtx, plugin.EventFailure, service, method,
			"", map[string]interface{}{"code": code, "duration_ms": time.Since(start).Milliseconds()}, traceTier)
		return nil, err
	}
	_ = h.emit(callCtx, plugin.EventSuccess, service, method,
		"", map[string]interface{}{"duration_ms": time.Since(start).Milliseconds()}, traceTier)
	return resp.Payload, nil
}

// active reports whether the host can execute guest calls: it is started, not
// stopping, not terminal, and its module is present.
func (h *Host) active() bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.started && !h.stopped && h.exitErr == nil && h.module != nil
}

func (h *Host) notActive(ctx context.Context, service, method string) error {
	err := plugin.NewCallError(plugin.CodeNotActive, h.cfg.PluginID, service, method, "host not active")
	_ = h.emit(ctx, plugin.EventFailure, service, method,
		"", map[string]interface{}{"code": string(plugin.CodeNotActive)}, traceTier)
	return err
}

// roundtrip performs one request/response exchange through guest memory.
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
		return Response{}, plugin.NewCallError(plugin.CodeNotActive, h.cfg.PluginID, service, method, "plugin not running")
	}
	h.pending[id] = ch
	h.mu.Unlock()
	defer h.unregister(id)

	// Acquire the single-writer lock. Acquisition is context-aware so a
	// grace-bounded Stop returns at its deadline even if a guest holds it.
	select {
	case h.writeCh <- struct{}{}:
	case <-ctx.Done():
		return Response{}, contextCallError(ctx, h.cfg.PluginID, service, method)
	case <-h.exited:
		return Response{}, plugin.NewCallError(plugin.CodeNotActive, h.cfg.PluginID, service, method, "plugin exited")
	}
	defer func() { <-h.writeCh }()

	// Deliberately exclude the "stopped" flag here: Stop itself sends the
	// shutdown frame after setting stopped, and must still reach the guest.
	h.mu.Lock()
	mod := h.module
	exitErr := h.exitErr
	h.mu.Unlock()
	if mod == nil || exitErr != nil {
		return Response{}, plugin.NewCallError(plugin.CodeNotActive, h.cfg.PluginID, service, method, "plugin not running")
	}

	werr := h.writeGuestFrame(ctx, mod, frame)
	if werr != nil {
		return Response{}, h.classifyGuestError(ctx, service, method, werr)
	}

	select {
	case resp := <-ch:
		if !resp.OK {
			return Response{}, resp.callError(h.cfg.PluginID, service, method)
		}
		return resp, nil
	case <-h.exited:
		return Response{}, plugin.NewCallError(plugin.CodeInternal, h.cfg.PluginID, service, method, "plugin exited")
	case <-ctx.Done():
		return Response{}, contextCallError(ctx, h.cfg.PluginID, service, method)
	}
}

// classifyGuestError converts a bridge failure into a typed error and, for
// deadline/cancellation/guest faults, records terminal evidence. A guest that
// is terminated by a context becomes terminal: no further invocations run.
func (h *Host) classifyGuestError(ctx context.Context, service, method string, werr error) error {
	switch {
	case errors.Is(ctx.Err(), context.DeadlineExceeded):
		h.terminate(ctx.Err(), "invoke_timeout")
		return plugin.NewCallError(plugin.CodeTimeout, h.cfg.PluginID, service, method, "invoke deadline exceeded")
	case errors.Is(ctx.Err(), context.Canceled):
		h.terminate(ctx.Err(), "invoke_canceled")
		return plugin.NewCallError(CodeCanceled, h.cfg.PluginID, service, method, "invoke canceled")
	default:
		h.terminate(werr, "guest_trap")
		return plugin.NewCallError(plugin.CodeInternal, h.cfg.PluginID, service, method, "bridge: "+werr.Error())
	}
}

// contextCallError maps a done context to a typed call error, mirroring the
// timeout classification for cancellation.
func contextCallError(ctx context.Context, pluginID, service, method string) error {
	if errors.Is(ctx.Err(), context.DeadlineExceeded) {
		return plugin.NewCallError(plugin.CodeTimeout, pluginID, service, method, "invoke deadline exceeded")
	}
	return plugin.NewCallError(CodeCanceled, pluginID, service, method, "invoke canceled")
}

// terminate records terminal state exactly once and emits containment evidence.
// A caller/host cancellation is a distinct EventCanceled. A guest trap under an
// explicitly configured memory bound is attributed to EventResourceLimit (with
// the enforced limit and observed usage attached); every other forced
// termination is EventTerminated.
func (h *Host) terminate(err error, reason string) {
	if !h.markExited(err) {
		return
	}
	outcome := map[string]any{"reason": reason}
	if err != nil {
		outcome["error"] = err.Error()
	}
	ev := plugin.Event{
		Kind:        plugin.EventTerminated,
		Service:     ControlService,
		SandboxTier: traceTier,
		Detail:      outcome,
	}
	switch {
	case reason == "invoke_canceled":
		ev.Kind = plugin.EventCanceled
	case reason == "guest_trap" && h.memoryEnforced:
		ev.Kind = plugin.EventResourceLimit
		ev.Limits = h.memoryLimits()
		ev.Usage = h.memoryUsage()
		outcome["limit"] = "memory"
		outcome["max_memory_pages"] = h.cfg.MaxMemoryPages
	}
	_ = h.record(context.Background(), ev)
}

// memoryLimits expresses the configured page bound as a ResourceLimits fact.
func (h *Host) memoryLimits() plugin.ResourceLimits {
	bytes := uint64(h.cfg.MaxMemoryPages) * 64 * 1024
	return plugin.ResourceLimits{MemoryMB: int((bytes + (1 << 20) - 1) >> 20)}
}

// memoryUsage reports the guest's linear-memory footprint at termination.
func (h *Host) memoryUsage() plugin.ResourceUsage {
	h.mu.Lock()
	mod := h.module
	h.mu.Unlock()
	if mod == nil || mod.Memory() == nil {
		return plugin.ResourceUsage{}
	}
	bytes := uint64(mod.Memory().Size())
	return plugin.ResourceUsage{PeakMemoryMB: int((bytes + (1 << 20) - 1) >> 20)}
}

// writeGuestFrame copies the request frame into guest memory and invokes the
// guest entrypoint under the caller's context so that a done context (or a
// runtime configured with CloseOnContextDone) terminates the guest.
func (h *Host) writeGuestFrame(ctx context.Context, mod api.Module, frame []byte) error {
	alloc := mod.ExportedFunction(guestAllocFn)
	entry := mod.ExportedFunction(guestRequestFn)
	mem := mod.Memory()
	ptr, err := alloc.Call(ctx, uint64(len(frame)))
	if err != nil {
		return fmt.Errorf("alloc(%d): %w", len(frame), err)
	}
	if !mem.Write(uint32(ptr[0]), frame) {
		return fmt.Errorf("memory write at %d failed", ptr[0])
	}
	if _, err := entry.Call(ctx, uint64(ptr[0]), uint64(len(frame))); err != nil {
		return fmt.Errorf("guest trap: %w", err)
	}
	return nil
}

// guestRespond is the host-imported reply channel invoked by the guest.
func (h *Host) guestRespond(ctx context.Context, m api.Module, stack []uint64) {
	if len(stack) < 2 {
		return
	}
	ptr, size := uint32(stack[0]), uint32(stack[1])
	if size == 0 || size > uint32(h.cfg.MaxFrame) {
		return
	}
	data, ok := m.Memory().Read(ptr, size)
	if !ok {
		return
	}
	var resp Response
	if json.Unmarshal(data, &resp) != nil {
		return
	}
	h.mu.Lock()
	ch, ok := h.pending[resp.ID]
	if ok {
		delete(h.pending, resp.ID)
	}
	h.mu.Unlock()
	if ok {
		ch <- resp
	}
}

// Stop sends shutdown, waits up to GracePeriod for the guest to complete it,
// then force-closes the runtime. It returns as soon as shutdown completes — it
// does not deliberately burn the whole grace window — and at the grace
// deadline it cancels the host context so an uncooperative or CPU-bound guest
// is terminated rather than waited on. Idempotent.
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
		h.hostCancel()
		h.markExited(nil)
		return nil
	}

	graceCtx, cancel := context.WithTimeout(ctx, h.cfg.GracePeriod)
	defer cancel()

	// Cooperative shutdown attempt. write-lock acquisition is context-aware,
	// so this returns at the grace deadline even if a guest is busy.
	_, _ = h.roundtrip(graceCtx, ControlService, MethodShutdown, nil)

	// Force-terminate any guest still running (CloseOnContextDone).
	h.hostCancel()

	h.failPending("plugin stopped")
	h.closeModule(ctx)
	h.markExited(nil)

	_ = h.emit(ctx, plugin.EventStop, ControlService, MethodShutdown,
		"", map[string]interface{}{
			"exit_clean":      true,
			"grace_period_ms": h.cfg.GracePeriod.Milliseconds(),
		}, traceTier)
	return nil
}

func (h *Host) closeModule(ctx context.Context) {
	h.mu.Lock()
	mod := h.module
	rt := h.runtime
	h.module = nil
	h.runtime = nil
	h.mu.Unlock()
	if mod != nil {
		_ = mod.Close(ctx)
	}
	if rt != nil {
		_ = rt.Close(ctx)
	}
}

// markExited records terminal state exactly once and releases waiters by
// closing the stable Exited channel. A later non-nil error is retained if the
// first termination carried none.
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

// Exited returns a channel closed when the host reaches terminal state. The
// channel is stable across calls and never nil.
func (h *Host) Exited() <-chan struct{} {
	return h.exited
}

// ExitError reports how the plugin terminated, or nil while active.
func (h *Host) ExitError() error {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.exitErr
}

// Healthy is the live health probe the production assembly gates activation on.
// It returns nil only while the host is active AND the guest answers a health
// round-trip; a terminal host or a guest that fails to respond is unhealthy, so
// an assembly can never activate (or keep ACTIVE) a dead/unresponsive guest.
// Start already performs the initial handshake; Healthy re-verifies liveness at
// the assembly's activation gate and can be polled for ongoing health.
func (h *Host) Healthy(ctx context.Context) error {
	if !h.active() {
		if err := h.ExitError(); err != nil {
			return fmt.Errorf("pluginrt/wasm: unhealthy: host exited: %w", err)
		}
		return errors.New("pluginrt/wasm: unhealthy: host not active")
	}
	if _, err := h.roundtrip(ctx, ControlService, MethodHealth, nil); err != nil {
		return fmt.Errorf("pluginrt/wasm: unhealthy: %w", err)
	}
	return nil
}

// failPending terminates every outstanding call with an internal error.
func (h *Host) failPending(message string) {
	h.mu.Lock()
	orphans := h.pending
	h.pending = make(map[string]chan Response)
	h.mu.Unlock()
	for id, ch := range orphans {
		ch <- Response{ID: id, Version: ProtocolVersion, OK: false,
			Code: string(plugin.CodeInternal), Message: message}
	}
}

// unregister removes id from pending if the reply path has not delivered.
func (h *Host) unregister(id string) {
	h.mu.Lock()
	delete(h.pending, id)
	h.mu.Unlock()
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
		log.Printf("pluginrt/wasm: dropped evidence event: %v", err)
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
