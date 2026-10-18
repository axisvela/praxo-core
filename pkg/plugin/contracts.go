// Package pluginrt defines the OSS-safe runtime plugin plane contract layer.
//
// It is the L5 (agent runtime) boundary for privileged runtime plugins that
// extend tools, model providers, policy, memory, and sandbox execution. Like
// the sibling pkg/contracts packages it is self-contained: it declares typed
// capability contracts, a guarded lifecycle, an adapter registry that binds by
// contract+version only, and per-plugin child scopes. It never resolves
// requirements (resolution belongs to the control plane) and it never imports
// plugin implementations.
package plugin

import (
	"context"
	"fmt"
	"time"
)

// Kind identifies a runtime plugin service contract. It is the canonical
// "<service>.<version>" string, for example "tool.provider.v1".
type Kind string

const (
	// KindToolProvider is the tool.provider.v1 service contract.
	KindToolProvider Kind = "tool.provider.v1"
	// KindModelProvider is the model.provider.v1 service contract.
	KindModelProvider Kind = "model.provider.v1"
	// KindPolicyProvider is the policy.provider.v1 service contract.
	KindPolicyProvider Kind = "policy.provider.v1"
	// KindMemoryProvider is the memory.provider.v1 service contract.
	KindMemoryProvider Kind = "memory.provider.v1"
	// KindSandboxProvider is the sandbox.provider.v1 service contract.
	KindSandboxProvider Kind = "sandbox.provider.v1"
)

// Contract describes one named, versioned runtime plugin service seam. The
// request and response schema names describe the JSON shapes exchanged over
// the payload; Timeout is the host-side default bound for a mediated call.
type Contract struct {
	Kind           Kind
	Service        string
	Version        string
	Capability     string
	RequestSchema  string
	ResponseSchema string
	Timeout        time.Duration
}

var (
	// ToolProvider is the canonical tool.provider.v1 contract.
	ToolProvider = Contract{
		Kind: KindToolProvider, Service: "tool.provider", Version: "v1",
		Capability:     "tool.invoke",
		RequestSchema:  "tool.provider.v1.invoke_request",
		ResponseSchema: "tool.provider.v1.invoke_response",
		Timeout:        30 * time.Second,
	}
	// ModelProvider is the canonical model.provider.v1 contract.
	ModelProvider = Contract{
		Kind: KindModelProvider, Service: "model.provider", Version: "v1",
		Capability:     "model.generate",
		RequestSchema:  "model.provider.v1.generate_request",
		ResponseSchema: "model.provider.v1.generate_response",
		Timeout:        2 * time.Minute,
	}
	// PolicyProvider is the canonical policy.provider.v1 contract.
	PolicyProvider = Contract{
		Kind: KindPolicyProvider, Service: "policy.provider", Version: "v1",
		Capability:     "policy.evaluate",
		RequestSchema:  "policy.provider.v1.evaluate_request",
		ResponseSchema: "policy.provider.v1.evaluate_response",
		Timeout:        5 * time.Second,
	}
	// MemoryProvider is the canonical memory.provider.v1 contract.
	MemoryProvider = Contract{
		Kind: KindMemoryProvider, Service: "memory.provider", Version: "v1",
		Capability:     "memory.access",
		RequestSchema:  "memory.provider.v1.access_request",
		ResponseSchema: "memory.provider.v1.access_response",
		Timeout:        10 * time.Second,
	}
	// SandboxProvider is the canonical sandbox.provider.v1 contract.
	SandboxProvider = Contract{
		Kind: KindSandboxProvider, Service: "sandbox.provider", Version: "v1",
		Capability:     "sandbox.execute",
		RequestSchema:  "sandbox.provider.v1.execute_request",
		ResponseSchema: "sandbox.provider.v1.execute_response",
		Timeout:        time.Minute,
	}
)

// Known returns the canonical runtime plugin service contracts in a stable
// order: tool, model, policy, memory, sandbox.
func Known() []Contract {
	return []Contract{ToolProvider, ModelProvider, PolicyProvider, MemoryProvider, SandboxProvider}
}

// Lookup returns the canonical contract for a Kind, reporting false for
// unknown kinds.
func Lookup(k Kind) (Contract, bool) {
	for _, c := range Known() {
		if c.Kind == k {
			return c, true
		}
	}
	return Contract{}, false
}

// CallErrorCode classifies a mediated invoke failure.
type CallErrorCode string

const (
	CodeCapabilityDenied CallErrorCode = "CAPABILITY_DENIED"
	CodeNotActive        CallErrorCode = "NOT_ACTIVE"
	CodeNotFound         CallErrorCode = "NOT_FOUND"
	CodeInvalidRequest   CallErrorCode = "INVALID_REQUEST"
	CodeTimeout          CallErrorCode = "TIMEOUT"
	CodeInternal         CallErrorCode = "INTERNAL"
)

// CallError is the typed error returned by the host invoke signature. Callers
// match on Code; identity fields carry the failing call. It interoperates with
// the lifecycle sentinels through Is: a CodeNotActive CallError matches
// ErrNotActive.
type CallError struct {
	code     CallErrorCode
	PluginID string
	Service  string
	Method   string
	Message  string
}

// Code returns the classification of the invoke failure.
func (e *CallError) Code() CallErrorCode {
	return e.code
}

// Is matches a CallError against lifecycle sentinels it stands in for. A nil
// receiver never matches.
func (e *CallError) Is(target error) bool {
	return e != nil && target == ErrNotActive && e.code == CodeNotActive
}

// Error implements error.
func (e *CallError) Error() string {
	return fmt.Sprintf("pluginrt: %s %s.%s.%s: %s", e.code, e.PluginID, e.Service, e.Method, e.Message)
}

// NewCallError builds a typed invoke error.
func NewCallError(code CallErrorCode, pluginID, service, method, message string) *CallError {
	return &CallError{code: code, PluginID: pluginID, Service: service, Method: method, Message: message}
}

// Host is the capability-gated invoke boundary for runtime plugins. It is
// implemented by the L5 runtime: it verifies instance state (ACTIVE) and the
// required capability before dispatch, then mediates the call under the
// contract timeout.
type Host interface {
	Invoke(ctx context.Context, pluginID string, service string, method string, payload []byte) ([]byte, error)
}

// InvokeFunc is the functional form of the host invoke signature.
type InvokeFunc func(ctx context.Context, pluginID string, service string, method string, payload []byte) ([]byte, error)

// Invoke adapts the function to the Host interface.
func (f InvokeFunc) Invoke(ctx context.Context, pluginID string, service string, method string, payload []byte) ([]byte, error) {
	return f(ctx, pluginID, service, method, payload)
}
