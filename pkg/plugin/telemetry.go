package plugin

import "context"

// EventKind classifies host lifecycle and security telemetry.
type EventKind string

// Host lifecycle event kinds (mirrored by the governance trace emitter).
const (
	EventStart   EventKind = "start"
	EventSuccess EventKind = "success"
	EventFailure EventKind = "failure"
	EventStop    EventKind = "stop"
	EventCrash   EventKind = "crash"
)

// Security denial and containment event kinds (G2-9). These are the fail-closed
// facts: verification, registration, and authorization denials must be durably
// recorded, and a denial whose evidence cannot be recorded must itself fail.
//
// Emission sites (all live as of G2-10):
//   - EventVerificationDenied is emitted by the production assembly at the
//     strict materialize/fetch seam (Code from the typed VerificationError).
//   - EventRegistrationDenied is emitted by the production assembly when the
//     guarded AdapterRegistry.Register refuses a bundle.
//   - EventAuthorizationDenied is emitted by the production assembly's policy
//     middleware whenever a mediated invocation is rejected (e.g. the instance
//     is no longer ACTIVE).
//
// Resource-limit, canceled, and terminated events are emitted directly by the
// WASM/process hosts.
const (
	EventVerificationDenied  EventKind = "verification_denied"
	EventRegistrationDenied  EventKind = "registration_denied"
	EventAuthorizationDenied EventKind = "authorization_denied"
	EventResourceLimit       EventKind = "resource_limit"
	EventCanceled            EventKind = "canceled"
	EventTerminated          EventKind = "terminated"
)

// Event is one structured telemetry fact emitted by a host, the update plane,
// or an enforcement seam (verification/registration/authorization). It carries
// the request/provider identity, the sandbox tier, and, for resource events,
// both the enforced limits and the observed usage so evidence is self-describing.
type Event struct {
	Kind        EventKind
	PluginID    string
	Provider    ProviderIdentity
	Service     string
	Method      string
	RequestID   string
	SandboxTier int
	Code        string
	Limits      ResourceLimits
	Usage       ResourceUsage
	Detail      map[string]any
}

// TelemetrySink receives structured host/runtime telemetry. Assembly wires it
// to the durable evidence plane; a nil sink disables emission in development
// hosts, while a production host requires a concrete sink.
//
// RecordPluginEvent returns an error so security evidence is fail-closed: a
// caller recording a denial must not proceed if the fact cannot be persisted.
type TelemetrySink interface {
	RecordPluginEvent(context.Context, Event) error
}
