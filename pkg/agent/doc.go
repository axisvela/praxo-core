// Package agent implements the governed agent loop, middleware, context
// management, delegation, streaming, and human-in-the-loop decisions.
//
// The package is intentionally one Go package: the public API is frozen and
// middleware shares the run-state types. Files are grouped by capability:
//
//	Core loop:       agent.go, middleware.go, options.go, state.go, status.go
//	Context:         compact.go, compactor.go, agentsmd.go, offload.go
//	Delegation:      subagent.go
//	Evaluation:      rubric.go
//	HITL:            interrupt.go
//	Streaming:       stream.go
//	Middleware:      calllimit.go, fallback.go, pii.go, structured.go,
//	                 toolselect.go, toolselect_model.go
//
// New capabilities should follow the same pattern: a capability-named file
// with its tests, not a new subpackage, unless the code can be extracted
// without exporting new shared run-state types.
package agent
