package plugin

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"
)

// State is the lifecycle state of one runtime plugin instance. Only ACTIVE
// accepts new invocations; every other state is fail-closed.
type State string

// Lifecycle states.
const (
	StateFetched     State = "FETCHED"
	StateValidated   State = "VALIDATED"
	StateLoaded      State = "LOADED"
	StateActive      State = "ACTIVE"
	StateDraining    State = "DRAINING"
	StateStopped     State = "STOPPED"
	StateUnloaded    State = "UNLOADED"
	StateFailed      State = "FAILED"
	StateQuarantined State = "QUARANTINED"
)

// Sentinels returned by the lifecycle.
var (
	// ErrNotActive reports a call rejected because the instance is not ACTIVE.
	ErrNotActive = errors.New("pluginrt: instance not active")
	// ErrInvalidTransition reports a state transition that the guarded table rejects.
	ErrInvalidTransition = errors.New("pluginrt: invalid state transition")
	// ErrDrainTimeout reports that Drain did not complete within its bound.
	ErrDrainTimeout = errors.New("pluginrt: drain timed out")
	// ErrDrainCanceled reports that Drain was aborted by parent context
	// cancellation rather than by deadline expiry.
	ErrDrainCanceled = errors.New("pluginrt: drain canceled")
	// ErrUnderflow reports a Release with no matching acquired call.
	ErrUnderflow = errors.New("pluginrt: release without acquire (inflight underflow)")
)

// AcceptsNewInvocations reports whether an instance in s may receive new calls.
func AcceptsNewInvocations(s State) bool {
	return s == StateActive
}

// allowedTransitions is the guarded transition table. Every edge is explicit;
// states not listed as a destination are rejected. UNLOADED and QUARANTINED
// are terminal.
var allowedTransitions = map[State]map[State]bool{
	StateFetched:     {StateValidated: true, StateFailed: true},
	StateValidated:   {StateLoaded: true, StateFailed: true},
	StateLoaded:      {StateActive: true, StateStopped: true, StateFailed: true},
	StateActive:      {StateDraining: true, StateFailed: true, StateQuarantined: true},
	StateDraining:    {StateStopped: true, StateFailed: true, StateQuarantined: true},
	StateStopped:     {StateLoaded: true, StateUnloaded: true, StateFailed: true},
	StateFailed:      {StateQuarantined: true},
	StateUnloaded:    {},
	StateQuarantined: {},
}

// defaultDrainPollInterval bounds how often Drain re-checks in-flight calls.
const defaultDrainPollInterval = time.Millisecond

// Lifecycle is a guarded per-instance state machine. Acquire/Release track
// in-flight calls so that only ACTIVE admits new calls and Drain can wait for
// bounded completion before moving to STOPPED.
type Lifecycle struct {
	mu                sync.Mutex
	state             State
	inflight          int
	drainPollInterval time.Duration
}

// NewLifecycle returns a lifecycle starting in FETCHED.
func NewLifecycle() *Lifecycle {
	return &Lifecycle{
		state:             StateFetched,
		drainPollInterval: defaultDrainPollInterval,
	}
}

// State returns the current lifecycle state.
func (l *Lifecycle) State() State {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.state
}

// Inflight returns the number of currently accepted calls.
func (l *Lifecycle) Inflight() int {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.inflight
}

// Acquire admits a new invocation. Only ACTIVE accepts calls; every other
// state returns ErrNotActive.
func (l *Lifecycle) Acquire() error {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.state != StateActive {
		return fmt.Errorf("%w: state=%s", ErrNotActive, l.state)
	}
	l.inflight++
	return nil
}

// Release ends a previously acquired invocation. Releasing without a matching
// acquire (or releasing twice) is an underflow and returns ErrUnderflow.
func (l *Lifecycle) Release() error {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.inflight == 0 {
		return ErrUnderflow
	}
	l.inflight--
	return nil
}

// Transit moves to next, validating the edge against the guarded transition
// table.
func (l *Lifecycle) Transit(next State) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.transitLocked(next)
}

func (l *Lifecycle) transitLocked(next State) error {
	if !allowedTransitions[l.state][next] {
		return fmt.Errorf("%w: %s -> %s", ErrInvalidTransition, l.state, next)
	}
	l.state = next
	return nil
}

// Fail moves the instance to FAILED when the current state permits it.
func (l *Lifecycle) Fail() error {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.transitLocked(StateFailed)
}

// Quarantine moves the instance to QUARANTINED (terminal) when the current
// state permits it. Quarantine is reserved for security violations.
func (l *Lifecycle) Quarantine() error {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.transitLocked(StateQuarantined)
}

// Drain waits for in-flight calls to reach zero, bounded by ctx, then moves
// DRAINING -> STOPPED. It must be called while DRAINING; entering from a
// non-DRAINING state returns ErrInvalidTransition and leaves the instance in
// its actual state.
//
// Drain re-verifies the state is still DRAINING after every re-lock and again
// immediately before setting STOPPED. If another goroutine moved the instance
// DRAINING -> FAILED or DRAINING -> QUARANTINED while it waited, Drain returns
// ErrInvalidTransition without clobbering that terminal state.
//
// On context expiry Drain distinguishes a genuine deadline from a parent
// cancel: deadline expiry returns an error matching ErrDrainTimeout, while a
// parent cancel returns an error matching ErrDrainCanceled. Both leave the
// instance in DRAINING.
func (l *Lifecycle) Drain(ctx context.Context) error {
	ticker := time.NewTicker(l.drainPollInterval)
	defer ticker.Stop()

	l.mu.Lock()
	for {
		if l.state != StateDraining {
			err := fmt.Errorf("%w: drain requires DRAINING, have %s", ErrInvalidTransition, l.state)
			l.mu.Unlock()
			return err
		}
		if l.inflight == 0 {
			break
		}
		l.mu.Unlock()
		select {
		case <-ctx.Done():
			return drainContextErr(ctx)
		case <-ticker.C:
		}
		l.mu.Lock()
	}
	l.state = StateStopped
	l.mu.Unlock()
	return nil
}

// drainContextErr classifies why ctx ended: deadline expiry is reported as
// ErrDrainTimeout; a parent cancel is reported as ErrDrainCanceled.
func drainContextErr(ctx context.Context) error {
	if errors.Is(ctx.Err(), context.DeadlineExceeded) {
		return fmt.Errorf("%w: %v", ErrDrainTimeout, ctx.Err())
	}
	return fmt.Errorf("%w: %v", ErrDrainCanceled, ctx.Err())
}

// Revoke is the revocation path: ACTIVE -> DRAINING -> STOPPED -> UNLOADED.
// In-flight calls are drained within the context bound. Revoking from STOPPED
// skips the drain; revoking from UNLOADED is a no-op.
func (l *Lifecycle) Revoke(ctx context.Context) error {
	l.mu.Lock()
	cur := l.state
	l.mu.Unlock()

	switch cur {
	case StateActive:
		if err := l.Transit(StateDraining); err != nil {
			return err
		}
		if err := l.Drain(ctx); err != nil {
			return err
		}
		return l.Transit(StateUnloaded)
	case StateDraining:
		if err := l.Drain(ctx); err != nil {
			return err
		}
		return l.Transit(StateUnloaded)
	case StateStopped:
		return l.Transit(StateUnloaded)
	case StateUnloaded:
		return nil
	default:
		return fmt.Errorf("%w: revoke not allowed from %s", ErrInvalidTransition, cur)
	}
}
