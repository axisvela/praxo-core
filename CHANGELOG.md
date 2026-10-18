# Changelog

All notable changes to PRAXO-CORE are documented here.

## [Unreleased]

### Added

- Extracted PRAXOVELA's code formatter registry into `pkg/format`; PRAXOVELA
  now aliases the framework package.
- Added tool specs, middleware, and ordered wrapping.
- Added multi-sink and filter event sinks.
- Added an in-memory memory store and context assembler.
- Added the chat `Provider`/`ModelRouter` contract and `EchoProvider` from
  PRAXOVELA; PRAXOVELA's model contract package now aliases it.
- Added adapter bridges: `ChatModel`, tool `Gateway`, remote memory `Backend`,
  event `Publisher`, `policy.FuncHook`, and `sandbox.FuncSandbox`.

## [0.2.0] - 2026-10-18

### Added

- Extracted the scheduler engine from PRAXOVELA into `pkg/scheduler` with
  provenance recorded. PRAXOVELA now imports the framework scheduler and keeps
  only a thin product alias.
- Extracted tool-call parsing into `pkg/output` and JSON Schema validation into
  `pkg/tool/schema`. PRAXOVELA now aliases both framework packages.
- Added `pkg/flow` Runnable/Chain/Parallel composition.
- Added `pkg/prompt` template and chat-template interpolation.
- Added `pkg/retriever` Document/Retriever contracts.

### Changed

- Module path is `github.com/axisvela/praxo-core` (no major suffix while 0.x).

## [0.1.0] - 2026-10-18

### Added

- MIT-licensed framework baseline.
- Model, tool, memory, event, scheduler, policy, sandbox, and agent primitives.
- Minimal governed agent loop with tool calls, event emission, and policy hooks.
- Echo example and framework documentation.
