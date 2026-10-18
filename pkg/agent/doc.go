// Package agent implements the governed agent loop and re-exports capability
// packages under one stable API.
//
// Capability packages:
//
//	types       shared run-state contracts (Session, Result, Middleware, Hooks)
//	context     budgets, compaction, summarization, offload, AGENTS.md memory
//	delegation  async subagent manager and isolated/fork modes
//	evaluation  rubrics and evaluators
//	hitl        approve/edit/reject/respond interrupt decisions
//	stream      typed values/updates/messages/tasks/debug/checkpoint projections
//	middleware  call limits, fallback, PII, structured output, tool selection
//
// The root package keeps Agent, Options, New, Run, and compatibility aliases.
// New capabilities should live in the matching subpackage and be re-exported
// from aliases.go when they are part of the public agent API.
package agent
